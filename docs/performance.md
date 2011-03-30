PERFORMANCE
===========

Elevator is actually pretty fast.  It uses Method::Signatures::Simple instead of Moose's method implementation,
for instance, and contains numerous caching layers.  Of course it's true that OO in Perl (or OO in general)
can sometimes be slow, and you don't want to be creating millions of objects or doing millions of SQL
queries.  This document is here to offer some strategies.

Elevator is a very object based system.   Usage for connected objects naturally trends to using lots of
Moose lazy loaders (which are great), though if not done carefully, this can lead to a lot of duplicate
SQL queries.

For this reason, there are multiple levels of caching available.  First off, considering enabling
memcache in your class, which is built in and 'free'.  Memcaching means that you *may* hit stale
results occasionally, depending on timeout.

For more bonus points, enable object caching, which mostly makes sense in web applications.
The object cache is typically manually cleared (by your program, reach into DbTable and erase
it... wrappers around that coming) before each new request so that it is not shared between
users.

If in the application you were to do this:

$SomeClass->find_all({ foo => 'bar' });
$SomeClass->find_all({ foo => 'bar' });

Not only would the SQL query be made only once (magic!) the objects produced from the return would
be created only once.

Further, to avoid lazy loading causing multiple queries for things in a list, use SQL::Abstract in a list
context like so:

$SomeClass->find_all({ 
   id => \@ids
});

And consider doing single queries for all things in a list, and then stitching objects back together
through judicious use of factories.  Remember that if you set the value of a lazy attribute before you
call the accessor for that attribute, the "builder" for that lazy method will never fire.


