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
#             my ($foo_obj, $bar_obj) = @_;
#             $foo_obj->bar($bar_obj);
#             return $foo_obj;
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

    action go() {
         my $abstract = SQL::Abstract->new();
         my ($select, @bind) = $abstract->select(
               $self->_table_names(),
               $self->_all_fields(),
               $self->where()
         );
         warn "GENERATED SELECT IS THUS: $select\n";
         # obviously this means no joins across seperate database connections :)
         # TODO: assert that we have at least two classes/tables to join
         my $sth = $self->unite->[0]->[1]->sql_driver->database_handle->prepare($select);
         $sth->execute(@bind);


         # thank you PerlMonks: 
         my  $data = $sth->fetchall_arrayref();

         my $all_rows = [];
         my $i = 0;
 
         foreach my $row (@$data) {
              my $translated_row = $self->_arrayref_to_hashref($row, $self->_table_names()->[$i]);
              my $i++;
              push @$all_rows, $translated_row;
         }

         my $results = [];
         foreach my $row2 (@$all_rows) {
             warn "TRANSATED ROW = " . JSON::XS::encode_json($row2) . "\n";
             my $objects = $self->_convert_to_objects($self->_partitioned_hashrefs($row2));
             push @$results, $self->stitching->($objects);
         }

         return $results;
    }

    # getting around stupidity in fetchrow_hashref by not using it.
    action _arrayref_to_hashref($row, $table_name) {
          my $fields = $self->_all_fields();
          my $result = {};
          my $i=0;
          foreach my $item (@{$fields}) {
              $result->{$item} = $row->[$i];
              $i++;
          }
          return $result;
    }


    action _make__class_names() {
        my $result = [];
        foreach my $item (@{$self->unite()}) { push @$result, $item->[1]; }
        return $result;
    }
    
    action _make__call_names() {
        my $result = [];
        foreach my $item (@{$self->unite()}) { push @$result, $item->[0]; }
        return $result;
    }

    action _make__table_names() {
        my @table_names = map { $_->table_name() } @{$self->_class_names()};
        my $i = 0;
        my $results = [];
        foreach my $item (@{$self->unite()}) {
           push @$results, $table_names[$i] . ' ' . $item->[0];
           $i++;
        }
        return $results;
    }

    # [ FooClass, BarClass ] -> [ foo.id, foo.x, foo.y, bar.id, bar.abc, bar.def ... ]
    action _make__all_fields() {
        my $results = [];
        my $i = 0;
        foreach my $class (@{$self->_class_names()}) {
           my $attributes = $class->new()->my_attributes();
           my $call_name = $self->_call_names()->[$i];
           foreach my $attr (@$attributes) {
               push @$results, $call_name . '.' . $attr->field() if $attr->does('Elevator::Model::Traits::Data');
           }
           $i++;
        }
        warn JSON::XS::encode_json($results);
        return $results;
    }

    # [ { a.x, a.y }, { b.x } ] -> [ $a_instance, $b_instance ]
    action _convert_to_objects($list_of_hashrefs) {
        my $class_names = $self->_class_names();
        my $called_names = $self->_call_names();
        my $i=0;
        my $results = [];
        foreach my $item (@$class_names) {
            warn "CONVERTING " . JSON::XS::encode_json($list_of_hashrefs->[$i]) . " to " . $item . "\n";
            my $obj = $item->from_datastruct($list_of_hashrefs->[$i++]);
            warn "OBJECTIFIED: " . $obj->to_datastruct();
            push @$results, $obj;

        }
        return $results;
    }
    
    # { a.foo => 1, a.bar => 2, b.cat => 3} -> [ { foo => 1, bar => 2 }, { cat => 3} ]
    action _partitioned_hashrefs($row_hashref) {
        warn "INPUT = " . JSON::XS::encode_json($row_hashref) . "\n";
        my $bucketized = {};
        my @keyz = keys(%$row_hashref);
        foreach my $key (@keyz) {
            my $value = $row_hashref->{$key};
            my ($called_as, $field) = split /\./, $key;
            #warn "CALLED AS = $called_as\n";
            #warn "FIELD     = $field\n";
            #warn "VALUE     = $value\n";
            $bucketized->{$called_as} ||= {};
            $bucketized->{$called_as}->{$field} = $value;
        }

        # now make sure we return them in ORDER
        my $results = [];
        foreach my $item (@{$self->_call_names()}) {
            push @$results, $bucketized->{$item};
        }
        warn "partitioned in order = " . JSON::XS::encode_json($results); 
        return $results;


    }

}
