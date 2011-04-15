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
#   my %some_hash = ( hi => 'mom' );
   my $gn =  Acme::GraphNode->new({
       some_integer => 2,
       some_string  => $someval || '?',
# currently experiencing some code problems with hashes in the Neo4j storage not being references
       some_array   => [ 1, 2, 3 ],
       some_keyval  => $key,
   });
#   $gn->some_hash(\%some_hash);
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
   is($fetched->to_json_str(), $foo->to_json_str(), "same data sent as stored");

   # verify that we can delete what we've inserted
   # also that requesting an object that is not there returns undef

   $fetched->delete();
   $fetched = Acme::GraphNode->by_key('narf');
   is($fetched, undef, "retrieving something that is not there returns undef");   

   # verify that it's cool to delete something that isn't there

   $self->_test_object('narf')->delete();
   ok(1, "delete of non-existant content did not explode");
   
   # TODO: verify that we can search without preparation and return a list of elements
   $self->_test_object('narf','a')->commit();
   $self->_test_object('troz','a')->commit();
   $self->_test_object('poyk','b')->commit();
   $self->_test_object('egad','c')->commit();
   $fetched = Acme::GraphNode->by_key('troz');

   # verify we can do a batch find.
   $self->_test_object('foo','x')->commit();
   $self->_test_object('bar','x')->commit();
   $self->_test_object('baz','x')->commit();
   $self->_test_object('glorp','x')->commit();
   
   #my $all = Acme::GraphNode->find_all({ some_string => 'x' });
   #foreach my $item (@$all) {
   #    warn $item->to_json_str();
   #} 
   #ok(scalar @$all >= 4, "sufficient results returned");

   # TODO: verify that we can add a link coming off of a node

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
