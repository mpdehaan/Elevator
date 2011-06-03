# The Elevator data layer provides a way to turn data reads on single tables into objects, but what if we 
# want to efficiently retrieve objects without lots of extra database calls.  While this won't work
# for many-to-many relationships (just yet), here's an example usage:
#
#  my @foos = Elevator::Util::Joiner->join(
#        unite => [
#             [ 'foo' => 'Acme::SqlFoo' ],
#             [ 'bar' => 'Acme::SqlBar' ]
#        ],
#        where => {
#              'foo.bar' => 'bar.id',
#        },
#        stitching  => sub {
#             my $objects = shift();
#             my $foo = $objects->[0];
#             my $bar = $objects->[1];
#             $foo->bar($bar);
#             return $foo;
#        }
#
#  this somewhat like a map/reduce operation for SQL databases

use MooseX::Declare;

class Elevator::Util::Joiner extends Elevator::Model::BaseObject {

    use Carp qw/croak/;
    use Elevator::Model::BaseObject;
    use Method::Signatures::Simple name => 'action';

    # inputs
    data unite           => (isa => 'ArrayRef', required => 1);
    data where           => (isa => 'HashRef', required => 1);
    data stitching       => (isa => 'CodeRef', required => 1);

    # intermediate results based on inputs (built only once)
    
    # ex: [ FooClass, BarClass ] 
    lazy _class_names     => (isa => 'ArrayRef');
    # ex: [ foo, bar ] ... the names of the tables being used
    lazy _table_names     => (isa => 'ArrayRef');
    # ex: [ foo, bar ] ... labels used in selects
    lazy _call_names      => (isa => 'ArrayRef');
    # ex: [ foo.id, foo.abc, bar.id, ... ] ... all fields with "call name" prefixes
    lazy _all_fields      => (isa => 'ArrayRef');

    # the only public function in the class, return this to get back a list of objects
    # see usage above.

    action go() {

         # we're building up q query against all tables associated with all objects
         # to get back all fields associated with all objects

         my $abstract = SQL::Abstract->new();
         my ($select, @bind) = $abstract->select(
               $self->_table_names(),
               $self->_all_fields(),
               $self->where()
         );

         # get the handle from the object. In Elevator, each object CAN have a seperate handle.
         # obviously this means no joins across seperate database connections :)
         # TODO: assert that we have at least two classes/tables to join

         my $sth = $self->unite->[0]->[1]->sql_driver->database_handle->prepare($select);
         $sth->execute(@bind);

         # when using fetchall_hashref you don't get back the table names as column prefixes
         # so we have to jump through some hoops
         # thanks PerlMonks for some pointers, though this implementation is more DB agnostic

         my  $data = $sth->fetchall_arrayref();
         my $all_rows = [];
         my $i = 0;
 
         # add table name prefixes on all rows
         foreach my $row (@$data) {
              push @$all_rows, $self->_arrayref_to_hashref($row, $self->_table_names()->[$i++]);
         }

         # now run our simulated map reduce like function against things.
         my $results = [];
         foreach my $row2 (@$all_rows) {
             push @$results, $self->stitching->($self->_objectify_row($row2));
         }

         return $results;
    }

    # given a hash of database row results, return the associated objects, as a reference
    # [ { foo.x => 1, foo.y => 2, bar.x => 99, bar.z => 3 } ] => [ $foo, $bar ]
    action _objectify_row($row) {
         return $self->_convert_to_objects($self->_partitioned_hashrefs($row));
    }

    # getting around stupidity in DBI fetchrow_hashref by not using it.
    # this converts an array like [ 1, 2, 3, 4 ] to something like:
    # { foo.x => 1, foo.y => 2, foo.z => 3, foo.splat => 4 }
    action _arrayref_to_hashref($row, $table_name) {
          my $fields = $self->_all_fields();
          my $result = {};
          my $i=0;
          foreach my $item (@{$fields}) {
              $result->{$item} = $row->[$i++];
          }
          return $result;
    }

    # the input "unite" contains query labels and classes, this returns just
    # the classes, in order.  FIXME: this is a map
    action _make__class_names() {
        my $result = [];
        foreach my $item (@{$self->unite()}) { push @$result, $item->[1]; }
        return $result;
    }
    
    # the input "unite" contains query labels and classes, this returns just
    # the query labels, in order.  FIXME: this is a map
    action _make__call_names() {
        my $result = [];
        foreach my $item (@{$self->unite()}) { push @$result, $item->[0]; }
        return $result;
    }

    # from the list of class names, get the list of table names
    # if you're using a sharded implementation, you'll want to pass these in straight
    # so this builder doesn't file, as the class used here doesn't have enough context
    # to determine which shard to use, not like a fully formed instance of an object
    # would.
    action _make__table_names() {
        my @table_names = map { $_->table_name() } @{$self->_class_names()};
        my $i = 0;
        my $results = [];
        foreach my $item (@{$self->unite()}) {
           push @$results, $table_names[$i++] . ' ' . $item->[0];
        }
        return $results;
    }

    # given the class list, get the attributes of each class, with the "called name" of the table
    # as an alias.  This is used to form the field list in the SQL select.
    # [ FooClass, BarClass ] -> [ foo.id, foo.x, foo.y, bar.id, bar.abc, bar.def ... ]
    action _make__all_fields() {
        my $results = [];
        my $i = 0;
        foreach my $class (@{$self->_class_names()}) {
           my $attributes = $class->new()->my_attributes();
           my $call_name = $self->_call_names()->[$i++];
           foreach my $attr (@$attributes) {
               push @$results, $call_name . '.' . $attr->field() if $attr->does('Elevator::Model::Traits::Data');
           }
        }
        return $results;
    }

    # given a list of object properties (with called names as prefixes), convert them into full fledged objects.
    # [ { a.x, a.y }, { b.x } ] -> [ $a_instance, $b_instance ]
    action _convert_to_objects($list_of_hashrefs) {
        my $class_names = $self->_class_names();
        my $called_names = $self->_call_names();
        my $i=0;
        my $results = [];
        foreach my $item (@$class_names) {
            push @$results, $item->from_datastruct($list_of_hashrefs->[$i++]);
        }
        return $results;
    }
    
    # given a list of attributes with prefixes, break them up into lists without prefixes
    # this is used to process the results back from the DB to a point where we can inject them into our deserializer
    # { a.foo => 1, a.bar => 2, b.cat => 3} -> [ { foo => 1, bar => 2 }, { cat => 3} ]
    action _partitioned_hashrefs($row_hashref) {
        my $bucketized = {};
        my @keyz = keys(%$row_hashref);
        foreach my $key (@keyz) {
            my $value = $row_hashref->{$key};
            my ($called_as, $field) = split /\./, $key;
            $bucketized->{$called_as} ||= {};
            $bucketized->{$called_as}->{$field} = $value;
        }

        # now make sure we return them in ORDER
        my $results = [];
        foreach my $item (@{$self->_call_names()}) {
            push @$results, $bucketized->{$item};
        }
        return $results;
    }

}
