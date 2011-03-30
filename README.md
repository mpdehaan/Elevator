Elevator
========

Elevator is a object oriented pluggable data-layer for Perl, built on top of MooseX::Declare.
It ensures objects are easy to use (not so easy in Perl) and basically acts as a lightweight
ORM.   Elevator is there to make your own objects, by subclassing, it is not a library that
you use directly.

Elevator objects all have built-in ability to load and save themselves to JSON or raw perl datastructures.
Additional roles may be added to objects to allow them to be serialized to-and-from a database
(with optional memcache fronting), or a pluggable NoSQL datastore.  It is then easily possible to swap
out databases or move objects between SQL and NoSQL datastores.

For instance, one could simultaneously use multiple NoSQL datastores without having to know the quirks of either,
or use sqlite locally and MySQL on a different environment.

Starting out
============

To begin work with elevator, first create a subclass of Elevator::Model::BaseObject that returns
subclasses of WA::Drivers::* that return suitable SQL, NoSQL, and Memcache connections for your
data environment.  See the examples directory for how to proceed.  All further model classes in
your application will then inherit from your new BaseObject subclass(es).

The examples directory shows how to do this and includes a test program that drives some of
these objects.

Additional capabilities
=======================

Elevator provides some shorthand ('data', 'attr', and 'lazy') around Moose attribute boilerplate.
Attributes must be flagged with 'data' to show up in the serializer, and because they are based
on the serializer, the NoSql or Sql drivers.   Lazy is a shortcut around Moose's excellent lazy
loading, and attr is just a simple wrapper around 'has'.  This is explained in the documentation
for BaseObject.

Elevator also provides some basic error classes for raising typed exceptions in Moose, along with
an ErrorCatcher module for intercepting them and producing reasonable stack traces.  This allows
for installing a global error handler around a program with polymorphic error handling behavior.
Use of the error handling piece of Elevator is optional though Elevator does use these exception
objects internally.  Also see the examples directory for a demo of a global error handling loop.

Documentation
=============

The Elevator team likes comments, but dislikes pod. Expect to see some more user-level and generated 
API documentation shortly, but do read the code. Elevator wishes that you understand how it works 
(so you can become a contributor), and there's not really much to it.

Installation
============

Prerequisite libraries are listed in the Bundle directory.
Otherwise, just make sure Elevator if findable via PERL5LIB.
CPAN package pending.

Site/App Specifics
==================

Many features specific to the original implementation have been removed to make this a more
general purpose module.  These include typed exception handling and specialized sharding
support.  A generalized method of supporting these for existing sites and web frameworks
didn't make sense, so you may wish to add these in your own way by subclassing any
of the existing classes.

License
=======
Elevator is MIT licensed open source software.  See COPYING for more details.

Questions/Comments?  Want to send in a patch?
=============================================

For now, send bugs at patch requests to github.com/webassign, you will need a github account.

Until a discussion list is available, feel free to email mpdehaan@webassign.net.

Contributors
============

Elevator was originally created by Michael DeHaan for http://webassign.net/, and contains some differences in this release to make it more generic than the original.

### In Order of Appearance: ###

* Michael DeHaan <michael.dehaan@gmail.com/mpdehaan@webassign.net>
* Mike Morella
* Shawn Page
* Robert Johnson
* Ben Wheeler

Send in a patch to get your name here.

