=pod

=head1 NAME

Elevator::ModelTypes

=head1 DESCRIPTION

Types for all Elevator Moose classes.

=head1 SYNOPSIS

Types in Moose are essentially global.   These are loaded automatically by Elevator::ModelBaseObject.

See http://search.cpan.org/~drolsky/Moose-1.09/lib/Moose/Manual/Types.pod

=cut
##########################################################################

use Moose;
use Moose::Util::TypeConstraints;
use Readonly;

use DateTime;
# note: we seem to use this to round in v4, may not be most efficient.

##########################################################################
# 'Date' holds DateTime perl objects, but also knows how to accept strings
# and ints as input.   Conversion from DateTimes to strings for json
# and DB purposes is handled in Elevator::ModelBaseObject::to_datastruct().  Code
# should ONLY think in terms of datetime elsewhere, it should *not* do
# it's own parsing and conversions.  The controller/view should care
# about timezones, the model thinks in GMT.

subtype 'Date' => as class_type 'DateTime';
  
coerce 'Date'  => from 'Int' => via { 
                       return DateTime->from_epoch(epoch => $_); 
                  }
               => from 'Str' => via {
                        my $value = $_;
                        if (($value  =~ /^0000-00-00/) || ! $value) {
                            return DateTime->from_epoch(epoch => 0);
                        }
                        # must explicitly specify timezone as UTC, otherwise it is set to 'floating'
                        eval {
                            return Elevator::Model::Forge->instance->datetime_formatter->parse_datetime($value);
                        }
                        or do {
                            # this is hideous, but timed assignments sometimes produce bad log strings
                            # so let's try another format since we have to deal with legacy
                            # data in the DB.
                            return Elevator::Model::Forge->instance->datetime_formatter_no_spaces->parse_datetime($value);
                        };
                  };


# by default the Moose bool will accept things with Perl truthiness, however we also
# use 'y' or 'n' in the database.  Make those string values work too.

coerce 'Bool' => from 'Str' => via {
                     $_ = uc($_);
                     return ($_ eq 'Y' || $_ eq 'T' || $_ eq 'TRUE' || $_ eq '1') ? 1 : 0;
                 }
              => from 'Int' => via {
                     return ($_ != 0);
                 };                   
                   
                   
##########################################################################
                    
1;
