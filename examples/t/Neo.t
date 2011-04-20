# Tests against an example Neo4j backed Elevator classes
# (NoSql role based, with Neo4j drivers)

package Neo;
use Test::Class;
use base qw/Test::Class/;

use strict;
use warnings;

use Test::More;
use Acme::GraphNode;

sub _test_object {
   my ($self, $key, $someval) = @_;
   my $gn =  Acme::GraphNode->new({
       some_integer => 2,
       some_string  => $someval || '?',
       some_hash    => { 'hi' => 'mom' },
       some_array   => [ 1, 2, 3 ],
       some_keyval  => $key,
   });
   return $gn;

}

sub test_go : Test(6) {
   my $self = shift();

   # verify that we can save an object

   my $foo  = $self->_test_object('narf');
   # TEMPORARILY COMMENTING OUT UNTIL WE IMPLEMENT DELETE
   $foo->delete(); # just to make sure previous test was ok...

   ok(defined $foo->to_json_str(), "object is jsonable");
   $foo->commit();  # save to NoSql
   
   # verify that Neo4j inserted a boatload of hashrefs into our object
   # we'll want to use these later.  It also proves the commit worked.
   ok(defined $foo->extended_nosql_data()->{traverse}, 'we get back attributes');

   # verify that we can fetch an object by key
   my $fetched = Acme::GraphNode->by_key('narf');
   ok(defined $fetched, "got an object back from by_key");
   #my $ds1 = $fetched->to_datastruct();
   is($fetched->to_json_str(), $foo->to_json_str(), 'are things the same once retrieved');

   # verify that we can delete what we've inserted
   # also that requesting an object that is not there returns undef

   warn "BOOKMARK 1 ----\n";

   $fetched->delete();
   $fetched = Acme::GraphNode->by_key('narf');
   is($fetched, undef, "retrieving something that is not there returns undef");   

   # verify that it's cool to delete something that isn't there
   warn "BOOKMARK 2 ----\n";

   $self->_test_object('narf')->delete();
   ok(1, "delete of non-existant content did not explode");
   
   # TODO: verify that we can add a link coming off of a node
   warn "BOOKMARK 3 ----\n";
   $self->_test_object('uno')->commit();
   $self->_test_object('dos')->commit();
   # we must retrieve what we sent to get the internal Neo4j node IDs
   warn "BOOKMARK 4 ----\n";
   my $one = Acme::GraphNode->by_key('uno');
   my $two = Acme::GraphNode->by_key('dos');
   warn "BOOKMARK 5 ----\n";
   $one->add_link_to($two, 'FRIENDS');
   ok(1, 'adding a link did not explode');

   # TODO: verify we can list links coming off of nodes (and get objects back)

   # TODO: verify that we can delete a link coming off of a node

   # TODO: verify that we can find a path between A&B

   # TODO: verify that we can find a path between A&B with certain path follow criteria?

   # TODO: (perhaps) verify that we can find all properties between A&B

   # TODO: any other graph ops

   print "ok\n";
}

Neo->runtests();
1;
