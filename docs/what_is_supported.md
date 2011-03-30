Supported Backends
==================

* Any SQL database.  Just write a subclass that provides a handle.
  Elevator works using SQL::Abstract so you do not need to write SQL.

* Memcache.
     Any database backed class can choose to use memcache if it wants
     and can define it's own (potentially variable) expiration timeout.

* Various NoSQL datastores.
  * MongoDB -- CRUD + search
  * Riak    -- CRUD.
  * RiakSearch -- CRUD, please send in a patch for search
  * others, but you'll have to write a driver -- contribute one if you're awesome.

* JSON
  * All base classes are jsonable, in terms of their 'data' flagged members.

* Perl datastructures
  * All base classes can be dumped and read from hashes automatically.

Any extensions on top of the above support is welcome and should be reasonably
trivial to add.  Ping Michael (see README file for info) if you'd like to discuss
ideas.


