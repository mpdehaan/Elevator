# A low-level graph class that has support for arbitrary traversals and metadata on the individual link attributes.
# intended as a middle ground from Neo4j and offers some capabilities (namely, link metadata) that other graph
# libs do not.  Elevator doesn't really include a lot of low-level bits like this, though it's nice to have
# something to cover the bases for what SQL/NoSQL doesn't do well. see examples/t/Graphinator.t
#    
# internal representations of the graph data structure are designed for performance and are not
# really object oriented.  They are intended for storing the object structure as someone would
# really want in NoSQL/SQL/etc and then ALSO using this class to mix it down to an efficient structure
# for computations, deserializing and serializing as neccessary and then storing the resultant data
# back in NoSQL/SQL elsewhere, as a non-canonical copy.

use MooseX::Declare;

class Elevator::Util::Graphinator extends Elevator::Model::BaseObject {

    use Carp qw/croak/;
    use Elevator::Model::BaseObject;
    use Method::Signatures::Simple name => 'action';

    data node_edges      => (isa => 'HashRef'); # $id => [ $edge_id, $edge_id ]
    data node_properties => (isa => 'HashRef'); # $id => { properties }
    data edge_properties => (isa => 'HashRef'); # $edge_id => { properties }

    # constructor creates an empty graph, call to/from_json_str if you want to serialize
    action BUILD() {
        $self->node_edges({});
        $self->node_properties({});
        $self->edge_properties({});
    }

    # add a new node with a given key and properties hash.  Does not add any links.
    # replaces the node if it already exists, which means any edges no longer point to it.
    action create_node($obj) {
        my $node_key = $obj->node_key();
        $self->_clear_node_edges($obj);
        $self->_set_node_properties($obj);
    }

    # internals: there's a record of what edges come out of each node (not into, that would be redundant)
    # this erases them.
    action _clear_node_edges($obj) {
        $self->node_edges()->{$obj->node_key()} = [];
    }

    # internals: the properties of each object are stored keyed against the node name.
    # this adds a record of them.
    action _set_node_properties($obj) {
        $self->node_properties()->{$obj->node_key()} = $obj->to_datastruct();
    }
    
    # internals: erase the property information about a node.
    action _clear_node_properties($obj) {
        $self->node_properties()->{$obj->node_key()} = {};
    }

    # replaces the properties of a given node
    # does not affect any edges
    action edit_node($obj) {
        $self->_set_node_properties($obj);
    }

    # internals: get the properties for a given node
    action _get_node_properties($obj) {
        return $self->node_properties()->{$obj->node_key()};
    }

    # returns the properties of a node if present, or undef if the node can't be found
    # FIXME: counter-intuitively, this does NOT create an object for you.  Yet.

    action find_node($obj) {
        return $self->_get_node_properties($obj);
    }

    # given a node key, delete anything referencing the node
    action delete_node($obj) {
        foreach my $edge ($self->neighbor_edges($obj)) {
            $self->_delete_edge_node_records($edge);
        }
        $self->_delete_node_records($obj);
    }

    # internals: to avoid having semantic meaning in the name of an edge key, there's a simple
    # set of records that says what the left and right end of each edge is.  This clears those.
    # this also clears the property info.
    action _delete_edge_node_records($edge) {
       delete $self->edge_properties()->{$edge} if $self->edge_properties()->{$edge};
    }

    # internals: for fast lookups and such, we store some things redundantly.  This erases the
    # information about a node when the node is deleted.
    action _delete_node_records($obj) {
        my $node_key = $obj->node_key();
        my $edges = $self->node_edges();
        my $properties = $self->node_properties();
        delete $edges->{$node_key} if defined $edges->{$node_key};
        delete $properties->{$node_key} if defined $properties->{$node_key};
    }
   
    # edges are stored in the internal datastructure using a combined key
    # of both node key names.  NOTE: this implementation does NOT allow
    # multiple direct links between A and B, to denote these semantics, make the properties
    # of the link differ. (A->B, B->A is of course fine and supported).
    action _edge_key($obj_a, $obj_b) {
        croak "bad object" unless (ref($obj_a) && ref($obj_b));
        return $obj_a->node_key() . '//' . $obj_b->node_key();
    }

    # add a new edge between a and b, with given properties.  This is bidirectional by default,
    # which means internally there really are two links.
    # FIXME: the type of edge MUST be in the edge key, do we need properties or is type enough?
    action add_edge($obj_a, $obj_b, $properties, $unidirectional) {
        $self->remove_edge($obj_a, $obj_b, 0);
        $properties ||= {}; 
        $self->edge_properties()->{$self->_edge_key($obj_a, $obj_b)} = $properties;
        $self->_set_node_edge_records($obj_a, $obj_b, $properties);
        unless ($unidirectional) {
            $self->edge_properties()->{$self->_edge_key($obj_b, $obj_a)} = $properties;
            $self->_set_node_edge_records($obj_b, $obj_a, $properties);
        }
    }

    # internals:  the datastructure is redundant about some info.  Here's info about what leads out of the nodes
    # versus info about the edges themselves.
    action _set_node_edge_records($obj_a, $obj_b, $properties) {
        my $node_key_a = $obj_a->node_key();
        my $edge_key = $self->_edge_key($obj_a, $obj_b);
        my $obj_a_edges = $self->node_edges()->{$node_key_a} || [];
        push @$obj_a_edges, $edge_key;
        #warn "adding edge to node $node_key_a, $edge_key\n";
        $self->node_edges()->{$node_key_a} = $obj_a_edges;
    }

    # remove an edge between a and b.  The default bidirectional mode removes links in both
    # directions, though it is possible to pass in unidirectional and convert a bidirectional
    # link to a unidirectional one.
    action remove_edge($obj_a, $obj_b, $unidirectional) {
        $self->_remove_edge_records($obj_a, $obj_b);
        $self->_remove_node_edge_records($obj_a, $obj_b);
        unless ($unidirectional) {
            $self->_remove_edge_records($obj_b, $obj_a);
            $self->_remove_node_edge_records($obj_b, $obj_a);
        }
    }

    # internals: removes the low level records that say things about the edge between A and B.
    action _remove_edge_records($obj_a, $obj_b) {
        my $edge_key   = $self->_edge_key($obj_a, $obj_b);
        delete $self->edge_properties()->{$edge_key};
    }

    # internals: remove info about edges related to node upon removing a node
    action _remove_node_edge_records($obj_a, $obj_b) {
        my $node_key_a = $obj_a->node_key();
        my $node_key_b = $obj_b->node_key();
        my $edge_key   = $self->_edge_key($obj_a, $obj_b);
        my $obj_a_edges = $self->node_edges()->{$node_key_a};
        my @new_a_edges = grep { $_ ne $edge_key } @$obj_a_edges;
        $self->node_edges()->{$node_key_a} = \@new_a_edges;
    }
   
    # return if there is a direct link between and b (returning link properties as a hashref) or undef
    # if no direct link exists.  Find_edge is always unidirectional because the implementation will store
    # a double set of links on bidirectional edges.  
    action find_edge($obj_a, $obj_b) {
        my $edge_key = $self->_edge_key($obj_a, $obj_b);
        return $self->edge_properties()->{$edge_key};
    }

    # return the names of the edges that connect to this node.  There will be duplicates if the edges
    # are bidirectional.  
    action neighbor_edges($obj) {
        return $self->node_edges->{$obj->node_key()};
    }

    # return the names of the nodes adjacent to this node.   
    action neighbors($obj) {
        my $results = [];
        my $edge_keys = $self->node_edges->{$obj->node_key()};
        foreach my $edge (@$edge_keys) {
           my ($head, $tail) = $self->_edge_endpoints($edge);
           push @$results, $tail;
        }
        return $results;
    }

    action is_directly_connected($obj_a, $obj_b, $depth_limit) {
        my @matches = grep { $_ eq $obj_b->node_key() } @{$self->neighbors($obj_a)};
        return ((scalar @matches) > 0) ? 1 : 0;
    }

    # hash merge the node properties data alongside the walking path between A and B.
    #action merge_alongside_path($obj_a, $obj_b, $depth_limit) {
    #}

    action _edge_endpoints($edge_key) {
        return split /\/\//, $edge_key;
    }

    # call a given callback on all nodes for which another callback is true reachable from a current node.
    # this can be used to implement "path"
   
    action propogate($node_key_a, $seen_nodes, $traverse_callback, $depth_limit, @accumulator_in) {

         # enforce depth limits on search and avoid revisiting nodes
         $depth_limit = 10 unless $depth_limit;

         $seen_nodes->{$node_key_a} = 1;
         my @accumulator = @accumulator_in;

         foreach my $edge (@{$self->node_edges->{$node_key_a}}) {
             # update accumulator at each node.  return 2 to complete, return 0 to skip, return 1 to continue to descend.
             my $should_traverse = $traverse_callback->($self, $edge, \@accumulator);
             my ($head, $tail) = $self->_edge_endpoints($edge);
             #warn "considering edge $head to $tail and should_traverse is $should_traverse\n";
             #warn "   current accumulator = " . join ' , ', @accumulator;
             return @accumulator if ($should_traverse == 2);
             next if $seen_nodes->{$tail};
             next unless $should_traverse;
             next unless $depth_limit > 0;
             my @rc = $self->propogate($tail, $seen_nodes, $traverse_callback, --$depth_limit, @accumulator);
             return @rc if (scalar @rc > 0);
         };

         #warn "END OF PROPOGATE\n";
         return ();
    }

    # return the edge names between A and B, or undef if no pat
    # this only returns the first found path, we'll need another implementation for shortest paths or all paths
    # if we need that.  

    action path($obj_a, $obj_b, $depth_limit) {
         my @accumulator_in = ();
         my $seen_nodes = {};
         # update accumulator at each node.  return 2 to complete, return 0 to skip, return 1 to continue to descend.
         my $traverse_callback = sub {
               my ($graphinator, $edge_key, $accumulator) = @_;
               my ($edge_head, $edge_tail) = $self->_edge_endpoints($edge_key);
               #warn "pushing onto accumulator ... $edge_key";
               push @$accumulator, $edge_key;
               if ($edge_tail eq $obj_b->node_key()) {
                    return 2;
               }
               # FIXME -- is this right?
               return 1;
         };
         # FIXME: make accumulator be a reference and copy it, and tolerate it being a hash or an array

         my @results = $self->propogate($obj_a->node_key(), $seen_nodes, $traverse_callback, $depth_limit, @accumulator_in);
         # we now have the edges upon the possibly successful path in $accumulator.  We need to determine if the last
         # edge tails out into $obj_b to know it's really successful.
         #warn "RAW RESULTS = " . join ',', @results;
         return undef unless (scalar @results > 0);
         #warn "LAST EDGE = " . $results[-1] . "\n";
         my ($head_result, $tail_result) = $self->_edge_endpoints($results[-1]);
         return ($tail_result eq $obj_b->node_key()) ? @results : undef;
    }

    # call a given function on all edges between A and B
    #action foreach_edge_on_path($obj_a, $obj_b, $depth_limit) {
    #}

    # call a given function on each node between A and B
    # action foreach_node_on_path($obj_$edge_list) {
    #}

}
