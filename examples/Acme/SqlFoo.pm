# example class to demo the NoSql driver
#
# FIXME: this demo does not illustrate associated classes yet.  It should.
# i.e.
#    data other_foo => (type => 'Acme::OtherFoo')
# which is a main point of this data layer.

use MooseX::Declare;

class Acme::SqlFoo extends Acme::BaseObject with Elevator::Model::Roles::DbTable {
 
    use Acme::BaseObject; 
    use Method::Signatures::Simple name => 'action';
    use DateTime;

    # database fields are all marked with 'data'
    data id           => (isa => 'Int');
    data some_integer => (isa => 'Int');
    data some_string  => (isa => 'Str');
    # classes can work with $obj->bar() automatically as an object, note type not isa
    # though you must use bar_id in constructors.  You may use "field => N" if the database
    # field name is not bar, for instance, to alias bar_id if that's your convention.
    data bar          => (type => 'Acme::SqlBar');

    # it's ok to have non-database fields too
    attr blippy       => (isa => 'Str');
    lazy foo          => (isa => 'Str');

    # Moose has constructors, if you want them
    action BUILD() {
        # attributes are already set when we get here, hence no parameters.
    }

    # this string is only build once, cool, eh?
    action _make_foo() {
        return DateTime->now();
    }

    # where is the table? (REQUIRED)
    action primary_table() {
        return "SqlFoo";
    }

    # use memcache for this table?  (DEFAULT: 0)
    action is_memcache_enabled() {
        return 1;
    }

    # how long before expiring memcache key?
    action memcache_timeout() {
        return 600;
    }

}
