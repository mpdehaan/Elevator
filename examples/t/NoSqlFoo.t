# Tests against an example NoSql backed Elevator class

package NoSqlFoo;
use Test::Class;
use base qw/Test::Class/;

use strict;
use warnings;

use Test::More;
#use Elevator::Include;
#use IO::All;
use Acme::NoSqlFoo;

sub _test_object {
   my ($self, $key, $someval) = @_;
   return Acme::NoSqlFoo->new(
       some_integer => 2,
       some_string  => $someval || '?',
       some_hash    => { hi => 'mom' },
       some_array   => [ 1, 2, 3 ],
       some_keyval  => $key,
   );

}

sub test_go : Test(5) {
   my $self = shift();

   # verify that we can save an object

   my $foo  = $self->_test_object('narf');
   $foo->delete(); # just to make sure previous test was ok...

   ok(defined $foo->to_json_str(), "object is jsonable");
   $foo->commit();  # save to NoSql

   # verify that we can fetch an object by key

   my $fetched = Acme::NoSqlFoo->by_key('narf');
   ok(defined $fetched, "got an object back from by_key");
   is($fetched->to_json_str(), $foo->to_json_str(), "same data sent as stored");

   # verify that we can delete what we've inserted
   # also that requesting an object that is not there returns undef

   $fetched->delete();
   $fetched = Acme::NoSqlFoo->by_key('narf');
   is($fetched, undef, "retrieving something that is not there returns undef");   

   # verify that it's cool to delete something that isn't there

   $self->_test_object('narf')->delete();
   ok(1, "delete of non-existant content did not explode");
   
   # TODO: verify that we can search without preparation and return a list of elements
   $self->_test_object('narf','a')->commit();
   $self->_test_object('troz','a')->commit();
   $self->_test_object('poyk','b')->commit();
   $self->_test_object('egad','c')->commit();
   $fetched = Acme::NoSqlFoo->by_key('troz');

   # verify we can do a batch find.
   $self->_test_object('foo','x')->commit();
   $self->_test_object('bar','x')->commit();
   $self->_test_object('baz','x')->commit();
   $self->_test_object('glorp','x')->commit();
   my $all = Acme::NoSqlFoo->find_all({ some_string => 'x' });
   #foreach my $item (@$all) {
   #    warn $item->to_json_str();
   #} 
   ok(scalar @$all >= 4, "sufficient results returned");

   # TODO: verify that we can run prepared map_reduce queries

   # TODO: verify we can manipulate bucket properties (later?)

   # TODO: verify we can list the names of buckets we have

   # TODO: verify that if needed we can exterminate a whole bucket (later?)

   print "ok\n";
}

NoSqlFoo->runtests();
1;
