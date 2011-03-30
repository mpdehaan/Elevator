=pod

=head1 NAME

Acme::BaseObject

=head1 DESCRIPTION

Example subclass for Elevator::Model::BaseObject.

Useful classes will all subclass this.

=cut
########################################################################## 

use MooseX::Declare;

class Acme::BaseObject extends Elevator::Model::BaseObject {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    our $driver_nosql    = Acme::Mongo->new();
    our $driver_sql      = Acme::Sqlite->new();
    our $memcache_driver = Acme::Memcache->new();

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

