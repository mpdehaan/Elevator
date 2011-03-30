=pod

=head1 NAME

Elevator::Model::Roles::NoSql

=head1 DESCRIPTION

A mixin providing NoSql capabilities to a class.   
A class cannot have both NoSql and DbTable mixins, only one.

=head1 SYNOPSIS

   with 'NoSql'

   my $obj  = Elevator::Model::SomeObject->new(p1 => 'x', p2=> 'y');
   # the method /selection_criteria/ returns the key of the object

   Elevator::Model::SomeObject->lookup($key);
   Elevator::Model::SomeObject->find_all($criteria);
   Elevator::Model::SomeObject->find_one($criteria);
   $obj->commit();
   $obj->delete();

   # there is no 'retrieve' like in DbTable.

=cut
##########################################################################

package Elevator::Model::Roles::NoSql;
use Moose::Role;
#use Method::Signatures::Simple name => 'action';
use Carp;
use JSON::XS;
use Data::Dumper;
use Elevator::Model::Forge;
use Elevator::Drivers::Riak;
use Elevator::Drivers::Mongo;

# the NoSql mixin supports multiple NoSql drivers, the default is Riak
# and currently there are no other drivers.
our $riak_driver = Elevator::Drivers::Riak->new();
our $mongo_driver = Elevator::Drivers::Mongo->new();

# classes that use this Mixin must define the following methods
# to_datastruct/from_datastruct are provided by Elevator::Model::BaseObject
# and should not have to be resupplied.

requires 'bucket_name';
requires 'bucket_key';
requires 'to_datastruct';
requires 'from_datastruct';

# classes get the Riak driver unless they specify a different one.
sub nosql_driver {
    return $mongo_driver;
}

# find_all
#
# Given a hash of query parameters, return an array of objects corresponding
# to the values from the lookup.  
#
# Parameters passed for $criteria are those valid to SQL::Abstract select
# statements.

sub find_all {

    my ($self, $criteria) = @_; 
    my $result = [];
    die Elevator::Err::InternalError->new(text => "criteria is not a ref") unless ref($criteria);
    
    my $raw_data = $self->nosql_driver->find_by_criteria($self->bucket_name(), $criteria);
    unless (ref ($raw_data)) {
        $raw_data = Elevator::Model::Forge->instance->json->decode($raw_data);
    }
    foreach my $row (@$raw_data) {
        push @$result, $self->_data_to_object($row);
    }
    return $result;

}

# lookup a value by it's exact key.
# usage:  my $foo = Elevator::Model::Foo->new(x=>2)->by_key();

sub by_key {
    my ($self, $key) = @_;
    my $raw_data =  $self->nosql_driver()->find_by_key($self->bucket_name(), $key);
    return undef unless defined $raw_data;
    unless (ref($raw_data)) {
        $raw_data = Elevator::Model::Forge->instance->json->decode($raw_data);
    } 
    return $self->_data_to_object($raw_data);
}


# convert list of hashes into multiple objects

sub _data_to_objects {
    my ($self, $rows) = @_;
    my $results = [];
    foreach my $item (@$rows) {
        push @{$results}, $self->_data_to_object($item);
    }
    return $results;
}


# convert single hash into object.  

sub _data_to_object {
    my ($self, $data) = @_;
    my $obj = $self->from_datastruct($data);
    return $obj;
}

# find_one
# 
# Works like find_all but returns only a single object.  Warns if 
# the critera was too vague and returned more than one object.  

sub find_one {

    my $self      = shift();
    my $criteria  = shift();
    my $result    = $self->find_all($criteria);

    if (scalar @$result > 1) {
        carp("more than one result returned for find_one on " . $self->bucket_name() . " : " . Data::Dumper::Dumper $criteria);
    }

    return undef unless scalar @$result;
    return $result->[0];

}

# replaces an entry in NoSQL, there is no difference between inserts or updates, if you
# are concerned with the 

sub commit {
    my $self = shift();
    $self->pre_commit(); # run validation hooks if any, on the object
    my $driver = $self->nosql_driver();
    $self->nosql_driver()->save_one($self->bucket_name(), $self->bucket_key(), $self);
    return $self;
}    

# Deletes the item.   After this is called on an object,
# the object can be recreated by calling "commit" if needed

sub delete {
    my $self = shift();
    return $self->nosql_driver()->delete_by_key($self->bucket_name(), $self->bucket_key());
}

# delete_all items matching the given criteria

sub delete_all {
    my ($self, $criteria) = shift();
    return $self->nosql_driver()->delete_all($self->bucket_name(), $criteria);
}

1;