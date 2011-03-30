# example class to demo the NoSql driver

use MooseX::Declare;

class Acme::SqlFoo extends Acme::BaseObject with Elevator::Model::Roles::DbTable {
 
    use Acme::BaseObject; 
    use Method::Signatures::Simple name => 'action';

    data some_integer => (isa => 'Int');
    data some_string  => (isa => 'Str');
    data some_hash    => (isa => 'HashRef');
    data some_array   => (isa => 'ArrayRef');
    data some_keyval  => (isa => 'Str');

    # name of the Riak bucket (Riak == default driver)
    action bucket_name() {
        return "NoSqlFoo";
    }

    # NoSql key for the object. 
    action bucket_key() {
        return $self->some_keyval();
    }

}
