# A Moose role adding Database powers to an existing class.
# 
# Assumes all constructor parameters correspond to database
# field names when they use the "Data" trait.
#
#
#   with 'DbTable'
#
#   my $obj  = Elevator::Model::SomeObject->new(p1 => 'x', p2=> 'y');
# 
#   Elevator::Model::SomeObject->find_one($criteria); # see SQL::Abstract for what's legal
#   $obj->find_all($criteria);
#   $obj->commit();
#   $obj->delete();
#
#   my $user = Elevator::Model::User->retrieve({ username => 'mdehaan@webassign' });
#   $user->ssn('3');
#   $user->commit();

package Elevator::Model::Roles::DbTable;
use Moose::Role;
use Method::Signatures::Simple name => 'action';
use Carp;
use JSON::XS;
use Data::Dumper;

# classes that use this Mixin must define the following methods
# to_datastruct/from_datastruct are provided by Elevator::Model::BaseObject
# and should not have to be resupplied.

requires 'primary_table';
requires 'to_datastruct';
requires 'from_datastruct';
requires 'selection_criteria';

# when we call $obj->delete() it's important that a second call
# to delete not do anything, especially for test purposes.
has '__is_deleted'  => (is => 'rw', isa => 'Bool', default => 0, init_arg => undef);

# flags whether we think the object has come from the database.  Used
# to do commit() in DbTable more efficiently.  
# no need to set manually.
has '__from_database' => (is => 'rw', isa => 'Bool', default => 0, init_arg => undef);

# the table name for each object is computed only once, and stored here.
# this is because the table name *could* be dynamic in the class to support
# pseudo-sharding by table name (hopefully not).
has '__table_name' => (is => 'rw', isa => 'Str', init_arg => undef);

# hold onto prepared statements to avoid re-preparing them
our $PREPARED_STATEMENTS = {};

# hold onto produced objects based on criteria from selection
# this must be explicitly enabled and is not on by default!
local our $OBJECT_CACHE = {};

###################################################################
=pod

=over

=item table_name

Returns the table name to be used with the DB utility functions.

subclasses must override if they want the stock DB code in

The function primary_table must be implemented.

=back

=cut
##################################################################

sub table_name {
    my $self = shift();
     # if what we are passed in is NOT a reference, do
    # not attempt to use the saved value, as we won't
    # have the instance variable.  
    return $self->actual_table_name() unless ref($self);
    my $saved = $self->__table_name();
    return $saved if defined($saved);
    $saved = $self->actual_table_name();
    $self->__table_name($saved);
    return $saved;
}

sub _database_handle() {
    my $self = shift();
    return $self->sql_driver()->database_handle();
}

# save prepared statements to not prepare them multiple times.
sub _prepare_statement {
    my ($self, $sql) = @_;
    my $sth = $PREPARED_STATEMENTS->{$sql};
    unless (defined $sth) {
        $sth = $self->_database_handle()->prepare($sql);
        $PREPARED_STATEMENTS->{$sql} = $sth; 
    }
    return $sth;
}

# produces a key for object hash lookup based on criteria
sub _cache_key {
    my ($self, $criteria) = @_;
    die "invalid query criteria: $criteria" unless ref($criteria);
    my $encoder = Elevator::Model::Forge->instance->json();
    my $key = $encoder->encode($criteria);
    my $md5 = Digest::MD5->new; 
    $md5->add($key);
    return $self->table_name() . '//' . $md5->hexdigest;
}

##########################################################################
=pod

=over

=item find_all & count.

Given a hash of (database) parameters, return an array of objects corresponding
to the values from the lookup.  See comments above about excluding transient
fields with "__fieldname".   

Parameters passed for $criteria are those valid to SQL::Abstract select
statements.

Count works just like find_all except it returns just an integer.  If you are
going to need the data, don't call count, count the objects, as otherwise
you'll be making extra calls.  Count(*) bypasses both layers of caching logic.

=back

=cut
##########################################################################

sub count {
    my ($self, $criteria, $order) = @_; 
    my $table = $self->table_name();
    die "criteria is not a reference" unless ref($criteria);
    my $sql             = Elevator::Model::Forge->instance->sql_abstract();
    my ($select, @bind) = $sql->select($table, 'count(*)', $criteria, $order);
    my $row             = undef;
    my $sth = $self->_prepare_statement($select);
    $sth->execute(@bind);
    $row = $sth->fetchrow_arrayref();
    return $row->[0];
}

sub find_all {
    my ($self, $criteria, $order) = @_; 
   
    my $table = $self->table_name();

    # this prevents errors like ->find_one(id => 2) which will somehow
    # make SQL::Abstract/MySQL spin wheels like crazy.  
    die "criteria is not a reference" unless ref($criteria);

    # the cache key is the based on the table name and criteria of the lookup
    my $cache_key = $self->_cache_key($criteria);
    my $memcache_should_update = 0;

    my $class = ref( $self ) ? ref( $self ) : $self;

    # if in the object cache already, consider using that if so enabled.
    # if the object cache is disabled, this will not do anything.
    unless( $OBJECT_CACHE->{$class} ) {
        $OBJECT_CACHE->{$class} = {};
    };
    my $cache_value = $OBJECT_CACHE->{$class}->{$cache_key};

    # object caching is disabled in test hooks and scripts by default
    # it must be explicitly enabled by a flag
    if ($self->enable_object_cache() && defined $cache_value) {
        return $cache_value;
    }

    # try to load from memcache
    if ($self->is_memcache_enabled()) {
        my ($result, $should_update) = $self->_memcache_load($cache_key, $table);
        return $result if $result;
        $memcache_should_update = $should_update;
    }
    
    my $result          = [];
    my $sql             = Elevator::Model::Forge->instance->sql_abstract();
    my ($select, @bind) = $sql->select($table, '*', $criteria, $order);
    my $row             = undef;

    # actual database load behavior here.
    my $sth = $self->_prepare_statement($select);
    $sth->execute(@bind);
    while ($row = $sth->fetchrow_hashref()) {
        push @$result, $self->_data_to_object($row);
    }

    # update object cache always, update memcache if so marked.
    if ($self->enable_object_cache()) {
        $OBJECT_CACHE->{$class}->{$cache_key} = $result;
    }

    if ($self->is_memcache_enabled() && $memcache_should_update) {
        $self->_update_memcache($cache_key, $table, $result);
    }

    # this shouldn't happen unless there's a major error, we expect an empty list on no hits
    unless ($result) {
       die 'find_all returned a null result.';
    } 
    return $result;

}

# attempts to load certain tables from memcache.  Returns the a tuple of (mc_value, update_flag).
# update_flag indicates whether we need to store the value, which is true if there was no match
# or the timeout has expired.

sub _memcache_load {
    my ($self, $cache_key, $table) = @_;
    # see if we have a cache hit
    my $memdata;
    if ($memdata = $self->memcache_driver()->retrieve($cache_key)) {
        my $result              = [];
        my ($expires_on, @rows) = @{$memdata};
        my $tolerance           = $self->memcache_timeout();
        my $now                 = Elevator::Model::Forge->instance->now->epoch();
        # if the hit is current, return the results
        if ($now - $tolerance < $expires_on) {
            # return results, but don't update, so expiration happens normally
            return ($self->_data_to_objects(\@rows), 0);
        }
        return (undef, 1); # no match, should update so it enters the cache
    }
    return (undef, 1); # no match, should update so it enters the cache
}

# convert an arrayref of datastructures into an arrayref of proper objects.

sub _data_to_objects {
    my ($self, $rows) = @_;
    my $results = [];
    foreach my $item (@$rows) {
        push @{$results}, $self->_data_to_object($item);
    }
    return $results;
}

# convert a serialized object into a real object

sub _data_to_object {
   my ($self, $data) = @_;
   my $obj = $self->from_datastruct($data);
   # mark that this came from the DB
   $obj->__from_database(1);
   return $obj;
}


# updates memcache if so marked.
sub _update_memcache {
     my ($self, $cache_key, $table, $result) = @_;
     my @elements = map { $_->to_datastruct() } @$result;
     my $tolerance = $self->memcache_timeout();
     # storing this in the actual value is kind of redundant, but allows us to at least
     # inquire as to the age.  Perhaps memcache allows us to do this as well.  Remove if so.
     my $mc_data = [ Elevator::Model::Forge->instance->now->epoch() + $tolerance , @elements];
     $self->memcache_driver()->store($cache_key, $mc_data, $tolerance);
}


# find_one
#
# Works like find_all but returns only a single object.  Warns if 
# the critera was too vague and returned more than one object.  
# 
# Parameters passed for $criteria are those valid to SQL::Abstract select
# statements. 

sub find_one {
    my $self     = shift();
    my $criteria = shift();

    my $result;
    $result = $self->find_all($criteria);

    if (scalar @{$result} > 1) {
        carp("more than one result returned for find_one on " . $self->table_name() . " : " . Data::Dumper::Dumper $criteria);
    }
    if (scalar @{$result} == 0) {
        return undef;
    }
    return $result->[0];
}

# insert_statement
# 
# Produces an insert statement and bind vars.   Subclasses can override this if they
# wish, they should not override insert, however.
# 

sub insert_statement {
    my $self = shift();
    my $sql = Elevator::Model::Forge->instance->sql_abstract();
    return $sql->insert($self->table_name(), $self->to_datastruct(), {});
}

# insert
# 
# Performs a SQL insert of the object in present state.   Returns the
# inserted id.  NOTE: in practice, don't call insert explicitly, use
# commit.
# 
# Subclasses needing custom behavior should not override this, they
# should override insert_statement, though this hasn't really come up either.

sub insert {
    my $self = shift();
    my ($insert, @bind) = $self->insert_statement();
    my $dbh = $self->_database_handle();
    my $statement = $self->_prepare_statement($insert);
    my $table = $self->table_name();
    $statement->execute(@bind) or croak("database insert failed ($? $!), " . Data::Dumper::Dumper $insert . " VALUES= " . Data::Dumper::Dumper \@bind);
    my $inserted = undef;
    if ($dbh->can('sqlite_last_insert_rowid')) {
       # sqlite seems to need special handling
       # last insert rowid, or the DBI version don't work (grr)
       my $lookup = "SELECT * FROM SQLITE_SEQUENCE WHERE name='$table'";
       my $all = $dbh->selectall_arrayref($lookup);
       $inserted = $all->[0][1];

    } else {
       # this at least works with MySQL ... may need changes elsewhere.
       $inserted = $dbh->last_insert_id(undef, undef, $table, undef);
    }  
    if ($self->meta->has_attribute('id')) {
        croak("failed to get insertion id") unless defined $inserted;
        $self->id($inserted);
    } 
    else {
        # this is a degenerate table with no id!  We'll just set inserted to -1
        $inserted = -1;
    }
    # mark that the object has been through a database transaction
    $self->__from_database(1);
    $self->invalidate_object_cache();
    return $inserted;
}


# actual_table_name
# 
# Return the name of the table

sub actual_table_name {
    my $self = shift();
    return $self->primary_table();
}


# update_statement
# 
# Produces an update statement and bind vars.   Subclasses can override this if they
# wish (hasn't come up yet).

sub update_statement {
    my $self = shift();
    my $criteria = $self->selection_criteria();
    croak("no selection criteria makes update impossible: ". $self->table_name()) unless defined $criteria;;
    my $sql = Elevator::Model::Forge->instance->sql_abstract();
    my $update_data = $self->to_datastruct();
    return $sql->update($self->table_name(), $update_data, $criteria);    
}


# update
# 
# Performs a SQL update statement, using the object in it's present state.
# End users should call commit() and not need to use this directly.

sub update {
    my $self = shift();
    my ($statement, @bind) = $self->update_statement();
    my $sth = $self->_prepare_statement($statement);
    $sth->execute(@bind) or croak("database update failed");
    # mark that this object has been involved in a DB transaction
    $self->__from_database(1);
    if ($self->meta->has_attribute('id')) {
        return $self->id();
    } else {
        return undef;
    }
}    

# Insert or update as required.     Returns the ID of the object,
# whether inserted new or already existing.   Could be thought of
# as an "upsert".

sub commit {
    my $self = shift();
    $self->pre_commit(); # run validation hooks if any, on the object
    my $rc = $self->_commit_db();
    $self->invalidate_object_cache();
    $self->invalidate_memcache();
    return $rc;
}

# called to remove rows in the object cache after changes are made

sub invalidate_object_cache() {
    my $self = shift();
    my $class = ref($self) ? ref($self) : $self;
    # blow away all cached objects of this class
    delete $OBJECT_CACHE->{$class}; 
}

# implementation of aforementioned upsert

sub _commit_db {

    my $self = shift();

    if ($self->__from_database()) {
        unless ($self->__is_deleted()) {
            return $self->update();
        }
    }
    # if the object was created new with exactly the right parameters
    # as what was in the database, an insert would fail so we have
    # to see if we can find it.
    my $criteria = $self->selection_criteria();
    unless (defined $criteria) {
        return $self->insert();
    }
    # I can't assume anything, see if it's already there first
    # and then insert or update.
    my $obj = $self->find_one($criteria);
    if (defined $obj) {
        return $self->update();
    } else {
        return $self->insert();
    }
}

# delete
#
# Deletes the item from the database.   After this is called on an object,
# the object can be recreated by calling "commit" but it will likely get a 
# new ID, so don't use objects after calling delete on them.   
# 
# The internal flag __is_deleted on the object is used to flag the object as deleted.
# Some test code relies on this to do auto-cleanup of objects that have not
# been manually cleaned up.

sub delete {
    my $self = shift();
    if ($self->__is_deleted()) {
        carp("database object already deleted once");
    }
    my $sql = Elevator::Model::Forge->instance->sql_abstract();
    my $criteria = $self->selection_criteria();
    unless (defined $criteria) {
        return undef;
    }
    my ($delete, @bind) = $sql->delete(
        $self->table_name(),
        $self->selection_criteria()
    );
    my $statement = $self->_prepare_statement($delete);
    my $result = $statement->execute(@bind);
    croak("deletion failed") unless defined $result;
    $self->__is_deleted(1);
    $self->invalidate_object_cache();
    return $result;
}

# delete_all
#
# Deletes all items matching criteria from the database.
#
# Currently the __is_deleted flag is not being
# set for deleted items, however we should not be using items after we delete them anyways.

sub delete_all {
    my $self = shift();
    my $criteria = shift();
    # this prevents errors like ->find_one(id => 2) which will somehow
    # make SQL::Abstract/MySQL spin wheels like crazy.  
    my $ref_type = ref($criteria);
    die 'criteria is not a hash/array reference' unless $ref_type eq 'ARRAY' or $ref_type eq 'HASH';
    
    if (
        (ref($criteria) eq 'HASH'  and scalar(keys %{$criteria}) == 0) or
        (ref($criteria) eq 'ARRAY' and scalar(@{$criteria}) == 0)
    ) {
        die 'criteria must contain at least 1 key';
    }
    
    my $sql             = Elevator::Model::Forge->instance->sql_abstract();
    my ($delete, @bind) = $sql->delete(
        $self->table_name(),
        $criteria
    );

    my $statement = $self->_prepare_statement($delete);
    my $result    = $statement->execute(@bind);
    croak("deletion failed") unless defined $result;
    $self->invalidate_object_cache();
    return $result;
}

##################################################################       
=pod

=over

=item retrieve

The inverse of commit(), load a new object given arbitrary criteria,
and if it cannot be found, create it with the same criteria, returning
the object.   

NOTE:  this implies all values to criteria must
come from the DB.   For additional values, set them after retrieval.

=back

=cut
##################################################################       

sub retrieve {
    my $self = shift();
    my $criteria = shift();
    my $obj = $self->find_one($criteria);
    if (defined $obj) {
        return $obj 
    } else {
        # object not found, we must create it. 
        my $obj = $self->from_datastruct($criteria);
        return $obj;

    }
}

# if there are any version4 memcaching going on, objects can return what
# they are and have them invalidated.
#
# Does nothing by default.  Implement in subclass.  Returns an ArrayRef.

sub legacy_memcache_keys {
   my ($self) = @_; 
   return []
}

# attempt to auto-invalidate some criteria on commit.  This doesn't work for more
# complex search criteria, but *does* work for ID based criteria.  To disable,
# a class fulfilling the role could replace this method with a no-op.

sub invalidate_memcache {
   my ($self) = @_;

   my $keys_to_invalidate = $self->legacy_memcache_keys();

   # new-style memcache keys   
   # NOTE: does selection criteria have default behavior?  It should.
   my $criteria = $self->selection_criteria();

   # NOTE: doesn't disable find_all type criteria, which we *do* actually cache.
   if ($self->is_memcache_enabled()) {
       push @{$keys_to_invalidate}, $self->_cache_key($criteria);
   }

   foreach my $invalid_key (@{$keys_to_invalidate}) {
       $self->memcache_driver()->delete($invalid_key);
   }
   
}

# for memcached items, the default timeout in seconds.  memcache is not default
# behavior.

sub memcache_timeout {
   return 300; # 5 minutes
}

# is memcache enabled for this table?   The default is no.   This refers to the Elevator::Model
# memcache logic.  If an object is memcached only by the legacy code, still say 0 here
# though it may be accessible to define a return result for "legacy_memcache_keys" if we
# have to invalidate them.

sub is_memcache_enabled {
   return 0;
}

# ask if a object called from retrieve is from the DB or not.  Occasionally this will be needed
# to create objects, such as logs, if they do not exist.

sub from_database {
   my ($self) = shift();
   return $self->__from_database();
}

# can be chained with a retrieve to ensure an object is in the DB after a lookup.
# ex:  Elevator::Model::Foo->retrieve({..})->ensure_real();
# requires that any fields have reasonable defaults

sub ensure_real {
   my ($self) = shift();
   unless ($self->from_database()) {
      $self->commit();
   }
   return $self;
}

1;
