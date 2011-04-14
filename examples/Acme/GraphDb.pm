# Acme::GraphDB
#
# Example subclass for Elevator::Drivers::Neo4j
# this represents settings Acme organization uses for Neo4j

use MooseX::Declare;

class Acme::GraphDb extends Elevator::Drivers::Neo4j {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    # if no don't use nosql, just return undef
    action server() {
        return '127.0.0.1';
    }

}

