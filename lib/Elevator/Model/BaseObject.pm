# Elevator::Model::BaseObject
# 
# Base Data Object.   For your application subclass this and redefine
# nosql_driver, database_driver, and memcache_driver to use appropriate
# subclasses of the classes provided in Elevator::Drivers:: such that they
# will be appropriate for your application.
# 
# All BaseObject subclasses get Elevator::Roles::Serializable functionality for free.
# *most* objects will want to also use the mixin Elevator::Model::Roles::DbTable to achieve
# basic ORM functionality. 
# 
#   my $obj  = BaseObject->new(p1 => 'x', p2=> 'y');
#   $obj->foo("something");
#   # see also docs in Elevator::Model::Roles::Serializable

BEGIN {
   # for Moose type loading purposes only.  Nothing else goes here and
   # other classes shouldn't have to do this.   
   use Elevator::Model::Types;
}

use MooseX::Declare;

class Elevator::Model::BaseObject with Elevator::Model::Roles::Serializable {
    
    # the default handler 'method' clashes with Moose
    # so we rename this action.   M:S:S is much faster
    # than Moose's action, and we only give up some
    # AOP potential.

    use Method::Signatures::Simple name => 'action';
    use Moose::Exporter;

    # add new methods to Moose classes
    Moose::Exporter->setup_import_methods(
        with_meta => [ 'data', 'attr', 'lazy' ],
    );
    
    # pseudo-ORM support.
    #
    # the 'data' attribute is a speical case of Moose 'has' that creates a read write variable
    # with an Object|Undef type.  While the field
    # in the database is an integer, this allows transparent access to the field as if it were
    # an object, traversing the foreign key and looking up the object in the other table.
    # If the actual integer is required, access via $fieldname_id is available.   
    #
    #   Suppose the following table Book exists:
    #       id | author | something_else
    #   and the table Author
    #       id | name
    #
    #   this allows $book->author() to return an object, and allow setting that field  
    #   value to an object, as with $book->author($author).  The ID is still accessible as
    #   $book->author_id()

    sub data {
        my ( $meta, $name, %options ) = @_;
    
        # the Moose attribute name matches the database field name unless overridden
        $options{field} = $name unless $options{field};
        my $actual_name = $name;
        my $name_key    = undef;
        
        if( $options{type} ) {
            my $type      = $options{type};
            my $key       = $options{key} || 'id';
            my $name_key  = $name . '_' . $key;
            my $method    = ($options{retrieve} && $options{retrieve} == 1) ? 'retrieve' : 'find_one';
            my $builder   = "_make_$name";
            my $clearer   = "_clear_$name";
            my $predicate = "has_$name";

            # add a dynamic lazy loader that will either retrieve or find_one on the remote object
            # note: class must import the other class for this to work.
            $meta->add_method($builder, sub {
                my $self  = shift;
                my $value = $self->$name_key();
                return $value
                    ? $type->$method( { $key => $value } )
                    : undef;
            });
            
            # add an attribute based on the attribute name given, which accepts either Object|Undef
            # the builder is as noted above, there is also a clearer set, and it's illegal to call
            # the builder if the value of the id field is null (see $predicate).  The trigger is used
            # so that if the object value is replaced the integer field representing the foreign key
            # is updated.
            $meta->add_attribute(
                $name,
                is        => 'rw',
                isa       => 'Object|Undef',
                lazy      => 1,
                builder   => $builder,
                clearer   => $clearer,
                predicate => $predicate,
                trigger   => sub {
                    my ($self, $new, $old) = @_;
                    $self->$name_key( defined $new ? $new->$key() : undef );
                }
            );
            
            $options{isa}   = 'Str|Undef'; # we allow strings but usually will be ints
            
            # if reassigning the id of the object, clear the object version
            $options{trigger} = sub {
                my ($self, $new, $old) = @_;
                if ($new) {
                    if ( $self->$predicate() && $self->$name->$key() ne $new ) {
                        $self->$clearer();
                    }
                } 
             
            };
            
            $actual_name = $name_key;
        }
       
        # create the attribute representing the actual ID key, and flag it as data
        # so that it will be serialized and will be included in SQL and JSON operations
        # options{field} is used in the serializer for the actual value name.

        $meta->add_attribute(
            $actual_name,  # same as '$name_key' here?
            is      => 'rw',
            traits  => ['Elevator::Model::Traits::Data'],
            %options
        );
    }

    # 'attr' works like moose's has but automatically marks the field as 'rw', saving a little
    # boilerplate.    
    sub attr {
        my ( $meta, $name, %options ) = @_;
        $meta->add_attribute(
            $name,
            is => 'rw',
            %options
        );
    }
    
    # lazy works like 'attr', but additionally assigns a builder method for lazy construction.
    # the builder method must still be added manually, and is prefixed with "_make_" before
    # the attribute name.
    sub lazy {
        my ( $meta, $name, %options ) = @_;
        $meta->add_attribute(
            $name,
            is      => 'rw',
            lazy    => 1,
            builder => "_make_${name}",
            %options
        );
    }
   
    # Return criteria needed to select the object for an update
    # or delete.  Must return undef if the object is unselectable
    # for retrieval or delete in it's present state due to not
    # having enough unique criteria being filled in.  

    action selection_criteria() {
         return undef unless defined $self->id();
         return {
             id => $self->id()
         };
    }

    # an optional hook for asserting values are valid pre-save
    action pre_commit() {
    }

    # driver functions must be subclassed, see examples directory in checkout

    action nosql_driver() {
        die "must subclass this class to use";
    }

    action sql_driver() {
        die "must subclass this to use";
    }

    action memcache_driver() {
        die "must subclass this to use";
    }

    # the object cache is an optimization that returns the same object for duplications
    # of the same queries.  It is appropriate for web requests, provided the object
    # cache is explicitly cleared at the begining of each web request, and then can
    # reduce SQL query volume by huge amounts.  It also prevents hits to memcache
    # as this is a RAM optimization.  However, it should almost never be used
    # in tests, or command line executation where something needs to be re-queried after
    # it is modified.  Turn on only when needed, it can create leaks if used incorrectly.
    # read Model/Roles/DbTable.pm for more details.

    action enable_object_cache() {
        return 0;
    }

}
