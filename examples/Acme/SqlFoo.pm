# example class to demo the NoSql driver

use MooseX::Declare;

class Acme::SqlFoo extends Acme::BaseObject with Elevator::Model::Roles::DbTable {
 
    use Acme::BaseObject; 
    use Method::Signatures::Simple name => 'action';

    data some_integer => (isa => 'Int');
    data some_string  => (isa => 'Str');

    # where is the table?
    action primary_table() {
        return "SqlFoo";
    }

    # use memcache for this table?  
    action is_memcache_enabled() {
        return 1;
    }

    # how long before expiring memcache key?
    action memcache_timeout() {
        return 600;
    }

}
