# for performance reasons, load lots of things up front.
# so they are loaded in the Apache parent, not the child.
# doesn't need to be everything, it does need to be most.
# (it's fine to use 'use' on these again later too)

# FIXME: write a script to auto-produce this file

use strict;
use warnings; 

BEGIN {

# BASE SUPPORT
# modules we're always going to want and want to defer startup cost
# and make tests easier if they import differently
use JSON::XS qw//;
use SQL::Abstract;

# FIXME: fill in

}
