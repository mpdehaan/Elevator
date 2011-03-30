package SqlFoo;
use Test::Class;
use base qw/Test::Class/;

use strict;
use warnings;

use Elevator::Include;
use Test::More;
use Acme::SqlFoo;

sub test_go : Test(6) {
   my $self = shift();

   # first start out with a (more clean) test scenario
   Acme::SqlFoo->delete_all({ some_string => 'narf' });

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
   $fetched->delete();
   $fetched = Acme::SqlFoo->find_one({ some_string => 'narf' });
   is($fetched, undef, "finding something that is not there returns undef");   

   # verify that find_all works after multiple inserts
   Acme::SqlFoo->new({ some_string => 'narf' })->commit();
   Acme::SqlFoo->new({ some_string => 'narf' })->commit();
   my $all = Acme::SqlFoo->find_all({ some_string => 'narf' });
   is(scalar @$all, 2, 'correct number of results');

   # verify that delete_all works
   Acme::SqlFoo->delete_all({ some_string => 'narf' });
   my $all2 = Acme::SqlFoo->find_all({ some_string => 'narf' });
   is(scalar @$all2, 0, 'correct number of results');
 
   print "ok\n";
}

SqlFoo->runtests();
1;
