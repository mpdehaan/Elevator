# How fast is Graphinator?

use strict;
use warnings;

use Elevator::Include;
use Test::More;
use Acme::GraphNode;
use Elevator::Util::Graphinator;
use Benchmark;

my $TEST_SIZE = 10_000;   
my $graph = Elevator::Util::Graphinator->new();

#######################
# PHASE 1: TEST ADDITIONS:

sub setup {

   my $previous = undef;
   for(my $i=0; $i< $TEST_SIZE; $i++) {
       my $node = Acme::GraphNode->new(x => $i, y => $i, z => $i);
       $graph->create_node($node);
       if (defined $previous) {
           $graph->add_edge($node, $previous);
       }
       my $previous = $node;
   }

}
timethese(5, { 'creation' => sub { setup() } });

#######################
# PHASE 2: TEST EDGE DELETIONS

setup();

sub edge_deletion {
    for(my $i=0; $i< $TEST_SIZE - 1 ; $i++) {
         $graph->delete_edge(Acme::GraphNode->new(x => $i), Acme::GraphNode->new(x => $i+1));
    }
}

timethese(5, { 'edge_deletion' => sub { edge_deletion() } });

########################
# PHASE 3: TEST NODE DELETIONS

setup();

sub node_deletion {
    for(my $i=0; $i< $TEST_SIZE; $i++) {
         $graph->delete_node(Acme::GraphNode->new(x => $i))
    }
}

timethese(5, { 'node_deletion' => sub { node_deletion() } });


########################
# PHASE 4:  TEST path (<A-B>)

setup();

sub long_path {
     my $path = $graph->path(Acme::GraphNode->new(x=>1), Acme::GraphNode->new(x => $TEST_SIZE-1));
     return scalar @$path;
}

timethese(5, { 'long_path' => sub { long_path() } });

########################
# PHASE 5:  TEST LOAD FROM DATASTRUCTURE/JSON

setup();

sub dump_restore {
     my $datastruct = $graph->to_datastruct();
     my $graph2      = Elevator::Util::Graphinator->from_datastruct($datastruct);
     return $graph2->regenerate_booster();
}

timethese(5, { 'dump_restore' => sub { dump_restore() } });



