So It Looks Like You're Storing a Graph In SQL
==============================================

You don't have to do that.

Elevator has two options for working with graphs.  Graphs really don't normally mesh with normal Sql/NoSql, these things
are great for small trees at best, but it's nice to have some tools to make graph capabilities easier.

Option 1
========

There's a Perl utilities class for storing a "compiled down" version of a graph in NoSql and quickly
converting it to a Perl library.  This is probably fine for small graphs.  see Elevator/Model/Util/Graphinator.

Option 2 
========

There's a NoSql driver for Neo4j that offers some graph operations not found in the other supplied
NoSql drivers.  Neo4j isn't exactly "NoSql" in the same sense, but had enough overlap that we're
reusing the same role.  See Elevator/Model/Roles/NoSql and Elevator/Drivers/Neo4j.

As your application can have only one nosql_driver() function per class (it's bad to store different
data in two places), you should override nosql_driver() in base classes that need a graph database
if you are also using another NoSql datastore.  The example code already does this with the GraphNode
class.

Trying Things Out
=================

Example tests for both are available in examples/t.

