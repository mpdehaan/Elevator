=pod

=head1 NAME

Acme::BaseObject

=head1 DESCRIPTION

Example subclass for Elevator::Model::BaseObject.
Provides organizational specific classes for data access.
Useful classes will all then subclass this and not have to redefine those later.
(though they could if desired).

=cut
########################################################################## 

use MooseX::Declare;

class Acme::BaseObject extends Elevator::Model::BaseObject {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    # organizational specific imports
    use Acme::Sql;
    use Acme::NoSql;
    use Acme::Memcache;

    # don't need to instantiate these more than once
    our $driver_sql      = Acme::Sql->new();
    our $driver_nosql    = Acme::NoSql->new();
    our $driver_memcache = Acme::Memcache->new();

    # if no don't use nosql, just return undef
    action nosql_driver() {
        return $driver_nosql;
    }

    # if you don't use sql, just return undef
    action sql_driver() {
        return $driver_sql;
    }

    # if you don't use memcache, just return undef
    action memcache_driver() {
        return $driver_memcache;
    }
}

