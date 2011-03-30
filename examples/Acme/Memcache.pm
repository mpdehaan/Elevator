=pod

=head1 NAME

Acme::Memcache

=head1 DESCRIPTION

Example subclass for Elevator::Drivers::Sql 

=cut
########################################################################## 

use MooseX::Declare;

class Acme::Memcache extends Elevator::Drivers::Memcache {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    action servers() {
        return [ qw/127.0.0.1/ ];
    }

}

