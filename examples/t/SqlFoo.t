# tests against an example Sql-backed Elevator class

package SqlFoo;
use Test::Class;
use base qw/Test::Class/;

use strict;
use warnings;

use Elevator::Include;
use Test::More;
use Acme::SqlFoo;
use Acme::SqlBar;

sub test_go : Test(7) {
   my $self = shift();

   # first start out with a (more clean) test scenario (more or less)
   Acme::SqlFoo->delete_all({ some_string => 'narf' });
   Acme::SqlFoo->delete_all({ some_string => 'some object' });

   # verify that we can save an object
   my $foo  = Acme::SqlFoo->new({ some_string => 'narf' });
   ok(defined $foo->to_json_str(), "object is jsonable");
   $foo->commit();  

   # verify that we can fetch an object by key
   my $fetched = Acme::SqlFoo->find_one({ some_string => 'narf' });
   ok(defined $fetched, "got an object back from by_key");
   is($fetched->some_string(), $foo->some_string(), "same data sent as stored");

   # verify that we can delete what we've inserted
   # also that requesting an object that is not there returns undef
   Acme::SqlFoo->delete_all({ some_string => 'narf' });
   $fetched = Acme::SqlFoo->find_one({ some_string => 'narf' });
   is($fetched, undef, "finding something that is not there returns undef");   

   # verify that find_all works after multiple inserts
   Acme::SqlFoo->new(some_string => 'narf')->commit();
   Acme::SqlFoo->new(some_string => 'narf')->commit();
   my $all = Acme::SqlFoo->find_all({ some_string => 'narf' });
   is(scalar @$all, 2, 'correct number of results');

   # verify that delete_all works
   Acme::SqlFoo->delete_all({ some_string => 'narf' });
   my $all2 = Acme::SqlFoo->find_all({ some_string => 'narf' });
   is(scalar @$all2, 0, 'correct number of results');

   # insert a SqlBar and create a SqlFoo pointing to it to test that object lookups work
   my $bar1 = Acme::SqlBar->new(some_string => 'test associated lookup');
   $bar1->commit();

   # note that saving the foo does not save the associated bar.  That might be a possible
   # future feature request, if it's valuable behavior for folks.  Always save the children
   # first.  That's good advice in both shipwrecks and database code.
   
   my $foo1 = Acme::SqlFoo->new(some_string => 'some object', bar_id => $bar1->id());
   $foo1->commit();

   # now the database records for bar and foo are saved, when we get a foo
   # and ask for it's bar, the bar will be activated by an on-demand database
   # lookup (lazy load) and we don't need to pretend to know about what id's
   # are keyed to what ids.
   my $lookup = Acme::SqlFoo->find_one({ some_string => 'some object'});
   is($lookup->bar->some_string(), 'test associated lookup', 'ORM features work!');

   # NOTE: in future upgrades to Elevator, we should be able to pass question objects
   # into find and reasonably use object parameters to constructors instead of IDs.
   # actually you CAN pass in objects to constructors, but it's better to usually
   # pass the ID.

   # cleanup database from previous test results

   Acme::SqlFoo->delete_all({ some_string => 'some object' });
   Acme::SqlBar->delete_all({ some_string => 'test associated lookup' });
 
   print "ok\n";
}

SqlFoo->runtests();
1;
