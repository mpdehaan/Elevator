How to use and test the examples
================================

The examples written depend on subclassing of stock Elevator modules to work.
Your application will need to do the same.

The tests written on the example classes assume some very limited capabilities.

* Sqlite is installed
* The sqlite schema in the examples directory has been applied
* MongoDB is running on localhost on the default port.
* Memcache is running on localhost on the default port.

In your own environment, creating different subclasses can use different
NoSQL drivers, can return a different database handle, 
can choose to use memcache or not, etc.


