=pod

=head1 NAME

Acme::NoSql

=head1 DESCRIPTION

Example subclass for Elevator::Drivers::MongoDB {

=cut
########################################################################## 

use MooseX::Declare;

class Acme::NoSql extends Elevator::Drivers::MongoDB {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    # if no don't use nosql, just return undef
    action server() {
        return '127.0.0.1';
    }

}

