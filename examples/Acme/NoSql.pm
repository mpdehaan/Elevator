# Acme::NoSql
# 
# Example subclass for Elevator::Drivers::Mongo 
# this represents settings Acme organization uses for MongoDB

use MooseX::Declare;

class Acme::NoSql extends Elevator::Drivers::Mongo {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    # if no don't use nosql, just return undef
    action server() {
        return '127.0.0.1';
    }

}

