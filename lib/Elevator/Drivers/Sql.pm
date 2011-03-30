=pod

=head1 NAME

Elevator::Drivers::Sql

=head1 DESCRIPTION

Sql driver that corresponds with the Elevator::Model::Roles::DbTable mixin.

Subclass this to provide a proper server address

=cut
##########################################################################
    
use MooseX::Declare;

class Elevator::Drivers::Sql {

    use Method::Signatures::Simple name => 'action';

    action database_handle() {
        return undef;
    }

}
