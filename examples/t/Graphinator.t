# Graphinator is a graph library that works well with classes that implement
# serializable and is designed to not keep 1000's of objets existant or make
# lots of queries.  Use it with your model classes by writing "add_foo" and
# other type methods that also keep the Graphinator graph in sync, or write
# a background process that periodically rebuilds the Graphinator graph.
#
# NOTE: graphs do not have to hold objects of the same type, but the node_key
# method on objects in the graph should contain the class name as a prefix.
# in lieu of the usual search API (find_one/find_all), pass in stub objects
# that are enough to find the key.  We need instances to generate the proper
# node keys.
#
# Tests should be largely self-explanatory

package Graphinator;
use Test::Class;
use base qw/Test::Class/;

use strict;
use warnings;

use Elevator::Include;
use Test::More;
use Acme::GraphNode;
use Elevator::Util::Graphinator;

sub test_basics : Test(9) {

   # these tests use a very simple graph:
   # 1-2-3-4-5

   my $self = shift();

   my $graph = Elevator::Util::Graphinator->new();

   my $gn1 = Acme::GraphNode->new(x => 1, y => 2, z => 3);
   my $gn2 = Acme::GraphNode->new(x => 2);
   my $gn3 = Acme::GraphNode->new(x => 3);
   my $gn4 = Acme::GraphNode->new(x => 4);
   my $gn5 = Acme::GraphNode->new(x => 5);
   $graph->create_node($gn1);
   $graph->create_node($gn2);
   $graph->create_node($gn3);
   $graph->create_node($gn4);
   $graph->create_node($gn5);
   $graph->add_edge($gn1, $gn2, { 'type' => 'neighbors' });
   $graph->add_edge($gn2, $gn3, { 'type' => 'neighbors' });
   $graph->add_edge($gn3, $gn4, { 'type' => 'neighbors' });
   $graph->add_edge($gn4, $gn5, { 'type' => 'neighbors' });

   # can I look for nodes I've made a record of?
   my $found_gn1 = $graph->find_node(Acme::GraphNode->new(x => 1));
   is($found_gn1->{y}, 2, 'able to retrieve node');

   # if I look for a node I never created, is it not there?
   my $found_gnx = $graph->find_node(Acme::GraphNode->new(x => 99999));
   is($found_gnx, undef, 'not able to retrieve imaginary node');

   # we then delete 4, leaving 1-2-3 5
   $graph->delete_node(Acme::GraphNode->new(x => 4));
   # did node 4 really go away?  Yes.
   my $found_gn3 = $graph->find_node(Acme::GraphNode->new(x => 4));
   is($found_gn3, undef, 'able to delete node');

   # can I get from 1 to 3?  How long is it?  (Yes, 2)
   my $path = $graph->path(Acme::GraphNode->new(x => 1), Acme::GraphNode->new(x => 3));
   is(scalar @$path, 2, 'is able to find a normal path between two nodes');

   # can I get from 1 to 2?  How long is it?  (Yes, 1); 
   $path = $graph->path(Acme::GraphNode->new(x => 1), Acme::GraphNode->new(x => 2));
   is(scalar @$path, 1, 'is able to find a trivial path between two nodes');

   # can I trivially get from 1 to 1?  No, because you're already there.
   $path = $graph->path(Acme::GraphNode->new(x => 1), Acme::GraphNode->new(x => 1));
   is(scalar @$path, 0, 'realizes that the same node is not a path');

   # can I get from 1 to 5 after I've deleted 4?  No.
   $path = $graph->path(Acme::GraphNode->new(x => 1), Acme::GraphNode->new(x => 5)); 
   #warn "** PATH FOUND = " . Data::Dumper::Dumper \@path;
   is(scalar @$path, 0, 'knows when it cannot find a path');

   # can I get from 1 to -3?  -3 isn't even a node, so no. 
   $path = $graph->path(Acme::GraphNode->new(x => 1), Acme::GraphNode->new(x => -3)); 
   #warn "PATH FOUND = " . Data::Dumper::Dumper \@path;
   is(scalar @$path, 0, 'cannot find a path to a non-existant node');

   # can I dump the entire datastructure object?
   #print $graph->to_json_str();
   ok(defined $graph->to_json_str(), 'can dump graph to JSON');

}


sub test_more_complex_graphs : Test(0) {
 
   # This is our test graph with multiple types of links
   # It is designed to include lots of circuits and a disconnected
   # segment.
   #
   #  2   3>>>>>>14>>>>15
   #   \ / \      \    ~ 
   #    4 - 8     10   ~        link properties on single lines: { 'type' : neighbors }
   #   /               ~                           double      : { 'type' : friends   }
   #  5   6=====9      ~                           tildas      : { 'type' : enemies   }
   #   \ /      <<     ~                           >>>>>>      : { 'type' : foo       }  # also unidirectional
   #    7    13~~11~~~12--18--19
   #
   #    15=====16~~~~~17


   # todo: more complex path test

   # todo: possibly a shortest path test

   # todo: validate edges returned along path are correct, not just the right length

   # todo: add a generalized propogate test

   # todo: tests for edit_edge
   
   # todo: tests for edit_node

   # todo: tests for find_edge

   # todo: tests for neighbor_edges

   # todo: tests for neighbors
  
}

# todo: benchmark test

Graphinator->runtests();
1;
