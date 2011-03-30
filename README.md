Elevator
========

Elevator is a object oriented pluggable data-layer for Perl, built on top of MooseX::Declare.

Elevator makes it easy to do data-driven OO.   Elevator is a scaffolding for making and using
objects that lets you stop thinking about how they are stored.  You work with elevator by subclassing it,
it is not a module that you just instantiate instances of.

Elevator objects all have built-in ability to load and save themselves to JSON or raw perl datastructures.
Additional roles may be added to objects to allow them to be serialized to-and-from a database, memcache,
or NoSql.

For instance, one could simultaneously use multiple NoSQL datastores without having to know the quirks of either,
or use sqlite locally and MySQL on a different environment.

It's also much lighter than most ORMs.  Code looks like code.  There's no configuration.

Starting out
============

To begin work with elevator, first create a subclass of Elevator::Model::BaseObject that returns
subclasses of WA::Drivers::* that return suitable SQL, NoSQL, and Memcache connections for your
data environment.  See the examples directory for how to proceed.  All further model classes in
your application will then inherit from your new BaseObject subclass(es).

The examples directory shows how to do this and includes a test program that drives some of
these objects.

Just do what the examples do.

Additional capabilities
=======================

Elevator provides some shorthand ('data', 'attr', and 'lazy') around Moose attribute boilerplate.
Attributes must be flagged with 'data' to show up in the serializer or database/NoSql saving.

Lazy is a shortcut around Moose's excellent lazy loading, and attr is a thin wrapper around Moose's has.
You should really read the Moose tutorials to fully understand things.

Elevator does not hide Moose from you, it just makes some things simpler.

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

Testing
=======

run "make" in a checkout to run the full test battery.

Tests will assume MongoDB and sqlite are available, and will try to hit memcache all on
localhost.  If they are not available, you may have some minor things to change.

Site/App Specifics
==================

Many features specific to the original implementation have been removed to make this a more
general purpose module.  These include typed exception handling and specialized sharding
support.  A generalized method of supporting these for existing sites and web frameworks
didn't make sense, so you may wish to add these in your own way by subclassing any
of the existing classes.  Sharding is still possible on a class-by-class basis, but is not
yet really supported as a 1st class concept.  

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

