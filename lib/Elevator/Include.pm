# if running from Apache, loading all your Moose classes as soon as possible, as opposed to in each
# fork, is strongly recommended when using immutable classes, which all MooseX::Declare classes
# are.

use strict;
use warnings; 

BEGIN {

# BASE SUPPORT

# FIXME: include other items in Elevator::Bundle::Elevator here
use JSON::XS qw//;
use SQL::Abstract;

# Model

use Elevator::Model::Types;
use Elevator::Model::Traits::Data;
use Elevator::Model::BaseObject;
use Elevator::Model::Forge;

# Drivers

use Elevator::Drivers::Riak;
use Elevator::Drivers::Mongo;
use Elevator::Drivers::Sql;
use Elevator::Drivers::Memcache;

# Roles

use Elevator::Model::Roles::DbTable;
use Elevator::Model::Roles::NoSql;

}

1;
