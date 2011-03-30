# example class to demo the Sql driver

use MooseX::Declare;

class Acme::SqlBar extends Acme::BaseObject with Elevator::Model::Roles::DbTable {
 
    use Acme::BaseObject; 
    use Method::Signatures::Simple name => 'action';
    use DateTime;

    # database fields are all marked with 'data'
    data id           => (isa => 'Int');
    data some_integer => (isa => 'Int');
    data some_string  => (isa => 'Str');

    # where is the table? (REQUIRED)
    action primary_table() {
        return "SqlBar";
    }

    # use memcache for this table?  (DEFAULT: 0)
    action is_memcache_enabled() {
        return 0;
    }

}
