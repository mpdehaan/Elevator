=pod

=head1 NAME

Elevator::Drivers::Memcache

=head1 DESCRIPTION

Memcache driver that provides a connection to Memcache for use in classes that use the
DbTable role.

Subclass this to provide a proper server address

=cut
##########################################################################
    
use MooseX::Declare;

class Elevator::Drivers::Memcache {

    use Method::Signatures::Simple name => 'action';

    # FIXME: complete this.
    action memcache_handle() {
        return undef;
    }
    
    action server() {
        die 'implement this in a subclass';
    }


}
