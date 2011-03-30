=pod

=head1 NAME

Acme::Sql

=head1 DESCRIPTION

Example subclass for Elevator::Drivers::Sql 

=cut
########################################################################## 

use MooseX::Declare;

class Acme::Sql extends Elevator::Drivers::Sql {

    use Method::Signatures::Simple name => 'action';
    use Elevator::Model::BaseObject;

    use DBI;

    action database_handle() {
        return DBI->connect("dbi:SQLite:dbname=dbfile","","");
    }

}

