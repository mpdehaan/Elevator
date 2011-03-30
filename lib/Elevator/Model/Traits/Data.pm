# a custom Moose trait

package Elevator::Model::Traits::Data;
use Moose::Role;

# This trait is used by Elevator::Model::Roles::Serializable
# to decide whether an element should be included in to_datastruct
# and from_datastruct calls, which in turn affects whether it is
# available for JSON operations.   Elevator::Model::Roles::DbTable
# adds on to this and uses this meaning to infer the field
# is a database parameter.  The default is *not* to include
# the object in datastructures, JSON, or database calls, and
# must be explicitly set.

# Usage:
#   data owner => (isa => 'Str', field => 'instructor');
#
# This allows a class attribute to be named differently than the actual db field
# For example, several objects have a concept of an owner, however in the db,
# the field may be called 'instructor', 'author', 'creator', 'user', etc, depending
# on the table.  In these cases, the 'field' flag can be used to map an attribute
# to a db-field regardless of the names of either. 
has field => (
    is  => 'rw',
    isa => 'Str|Undef'
);

# Usage:
#   data user => (type => 'Elevator::Model::User');
#
# Adding this flag to an attribute does 2 things:
#
# 1.  It creates a 'rw' attribute called user_id which will contain the data
#     from the 'user' field in the db
# 2.  It creates a 'rw' attribute called user which will be lazily built and
#     will contain a reference to a Elevator::Model::User object that was found using
#     the criteria of { id => $self->user_id() }
# Also see 'key' and 'retrieve'
has type => (
    is => 'rw',
    isa => 'Str|Undef'
);

# Usage:
#   data user => (type => 'Elevator::Model::User', key => 'uid');
#
# This flag modifies the search criteria of the lazy builder created by the 'type' flag above
# by allowing you to specify which field to use as the search criteria to a find_one call.
# By default, 'id' will be used.
has key => (
    is      => 'rw',
    isa     => 'Str|Undef'
);

# Usage:
#   data user => (type => 'Elevator::Model::User', retrieve => 1)
#
# This flag modifies the behavior of the lazy builder created by the 'type' flag above
# to use 'retrieve' vs 'find_one' when looking up the object.
has retrieve => (
    is  => 'rw',
    isa => 'Bool',
    default => 0
);

package Moose::Meta::Attribute::Custom::Trait::Data;
sub register_implementation {'Elevator::Model::Traits::Data'}

1;
