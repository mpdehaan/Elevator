Supported Backends
==================

* Any SQL database.  Just write a subclass that provides a DBI handle.
  Elevator works using SQL::Abstract so you do not need to write SQL.
  NOTE: tested with MySQL and Sqlite, the "last_insert_id" logic of DbTable.pm
  may need patching for other databases, contributions very welcome for wider
  database support.

* Memcache.
     Any database backed class can choose to use memcache if it wants
     and can define it's own (potentially variable) expiration timeout.

* Various NoSQL datastores.
  * MongoDB -- CRUD + search
  * Riak    -- CRUD, note: no map_reduce integration yet
  * RiakSearch -- CRUD, please send in a patch for search
  * others, but you'll have to write a driver -- contribute one if you're awesome.
    (would very much like Redis, CouchDB)

* JSON
  * All base classes are jsonable, in terms of their 'data' flagged members.

* Perl datastructures
  * All base classes can be dumped and read from hashes automatically.

Any extensions on top of the above support is welcome and should be reasonably
trivial to add.  Ping Michael (see README file for info) if you'd like to discuss
ideas.


