# A moderately-low-level graph class that adds two-major properties to Graph::Undirected
#   * serializable, so it can be saved in NoSQL/SQL and quickly reloaded without doing lots of object lookups
#     for instance, a very complex graph could be represented in SQL and then we could store the compiled-down
#     version elsewhere (like NoSQL), and quickly evaluate it.
#   * supports properties for each link
#
# Classes needing this behavior are expected to make calls to update a graphinator object
# each time they update the objects represented inside the graph, though this could also be used for
# batch purposes.

use MooseX::Declare;

class Elevator::Util::Graphinator extends Elevator::Model::BaseObject {

    use Carp qw/croak/;
    use Elevator::Model::BaseObject;
    use Method::Signatures::Simple name => 'action';
    use Graph::Undirected;

    # internal state, do NOT implement/access directly.
    data node_properties => (isa => 'HashRef', default => sub { return {} }); # $id => { properties }
    data edge_properties => (isa => 'HashRef', default => sub { return {} }); # $edge_id => { properties }
    lazy booster         => (isa => 'Object');

    # constructor will create a graph instance for us.
    action BUILD() {
        $self->booster(Graph::Undirected->new()) unless $self->booster();
    }

    # while it shouldn't be needed, someone might decide to not trust the graph implementation and
    # might want to rebuild it.
    action regenerate_booster() {
        $self->booster($self->_make_booster());
    }

    # when loading from a datastructure, rebuild the graph in memory
    action _make_booster() {
        my $booster = Graph::Undirected->new();
        foreach my $node (@{$self->nodes()}) {
            $booster->add_vertex($node);
        }
        foreach my $edge (@{$self->edges()}) {
            my ($head, $tail) = $self->_edge_endpoints($edge);
            $booster->add_edge($head, $tail);
        }
        return $booster;

    }
 
    # add a new node based on a BaseObject
    action create_node($obj) {
        my $node_key = $obj->node_key();
        $self->node_properties()->{$node_key} = $obj->to_datastruct();
        $self->booster->add_vertex($node_key);
    }

    # edit properites of existing node
    action edit_node($obj) {
        my $node_key = $obj->node_key();
        $self->node_properites()->{$node_key} = $obj->to_datastruct();
    }

    # is a Node in the graph, return properties if so
    action find_node($obj) {
        return $self->node_properties->{$obj->node_key()};
    }
 
    # is an edge in the graph?, return properties if so
    action find_edge($obj_a, $obj_b) {
        my $edge_key = $self->_edge_key($obj_a, $obj_b);
        return $self->edge_properties->{$edge_key};
    }

    # return all the node names in the graph
    action nodes() {
        my @keys = keys %{$self->node_properties()};
        return \@keys;
    }

    # return all the edge keys, call $self->_edge_endpoints
    # to retrieve the nodes on either side of them.
    action edges() {
        my @keys = keys %{$self->edge_properties()};
        return \@keys;
    }

    # given a node, delete the node and connected edges
    action delete_node($obj) {
        my $node_key = $obj->node_key();
        my $properties = $self->node_properties();
        delete $properties->{$node_key} if defined $properties->{$node_key};
        foreach my $edge (@{$self->edges()}) {
            my ($head, $tail) = $self->_edge_endpoints($edge);
            $self->delete_edge($head, $tail) if $head eq $node_key;
        }
        $self->booster->delete_vertex($obj->node_key());
    }
  
    # given two nodes, delete the edge between them
    action delete_edge($key_a, $key_b) {
        $key_a = $key_a->node_key() if ref($key_a);
        $key_b = $key_b->node_key() if ref($key_b);
        my $edge_key = $self->_edge_key($key_a, $key_b);
        my $properties = $self->edge_properties();
        delete $properties->{$edge_key} if defined $properties->{$edge_key};
        $self->booster->delete_edge($key_a, $key_b);
    }
 
    # given two nodes (or two node keys) return the edge key between them
    action _edge_key($obj_a, $obj_b) {
        croak "undefined edge" unless defined $obj_a;
        croak "undefined edge" unless defined $obj_b;
        if ((!ref($obj_a)) || (!ref ($obj_b))) {
            return $obj_a . '//' . $obj_b;
        }
        return $obj_a->node_key() . '//' . $obj_b->node_key();
    }

    # connect nodes A and B, assigning properties to the link
    action add_edge($obj_a, $obj_b, $properties) {
        my $edge_key = $self->_edge_key($obj_a, $obj_b);
        $self->edge_properties()->{$edge_key} = $properties;
        $self->booster->add_edge($obj_a->node_key(), $obj_b->node_key());
    }

    # return the nodes bordering a node
    #action neighbors($obj) {
    #}
  
    # given an internal edge key, return the nodes on either side
    action _edge_endpoints($edge_key) {
        return split /\/\//, $edge_key;
    }

    # convert arrayref of node names to array of edge names
    action _nodes_to_edges($path) {
        my $index = 0;
        my $results = [];
        foreach my $node (@$path) {
            unless ($index == (scalar @$path) - 1) {
                push @$results, $self->_edge_key($node, $path->[$index+1]);
            };
            $index++;
        }
        return $results;
    }

    # return the edge names between A and B, or () if no path
    # FIXME: we'll likely want to wrap this so we return a list of node pairs instead.
    action path($obj_a, $obj_b, $depth_limit) {
         my @path = $self->booster->SP_Dijkstra($obj_a->node_key(), $obj_b->node_key());
         return $self->_nodes_to_edges(\@path);
    }

}
