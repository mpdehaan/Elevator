# Acme::GraphNode
#
# Example node for Graph database (Neo4j) testing.
# Notice we override the default NoSql driver from BaseObject in this class.

use MooseX::Declare;

class Acme::GraphNode extends Elevator::Model::BaseObject with Elevator::Model::Roles::NoSql {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    data some_integer => (isa => 'Int');
    data some_string  => (isa => 'Str');
    data some_hash    => (isa => 'HashRef');
    data some_array   => (isa => 'ArrayRef');
    data some_keyval  => (isa => 'Str');

    # organizational specific driver imports
    use Acme::GraphDb;
    our $driver_graphdb  = Acme::GraphDb->new();

    # default BaseObject uses Mongo, this one uses Neo4j
    action nosql_driver() {
        return $driver_graphdb;
    }

    # needed by NoSQL role to make a unique ID
    action bucket_name() {
        return 'GraphNode';
    };

    # needed by NoSQL role to make a unique ID
    action bucket_key() {
        return $self->some_keyval();
    }
}

