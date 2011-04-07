# example Graph Node class, for illustrating Graphinator.  This could mixin either NoSql or DbTable.
# here it doesn't do either because it is just for the tests.

use MooseX::Declare;

class Acme::GraphNode extends Acme::BaseObject {
 
    use Method::Signatures::Simple name => 'action';
    use Acme::BaseObject;

    # database fields are all marked with 'data'
    data x            => (isa => 'Int');
    data y            => (isa => 'Int');
    data z            => (isa => 'Int');

    # what key to use for graph indexing
    action node_key() {
        return "GraphNode/" . $self->x();
    }

}
