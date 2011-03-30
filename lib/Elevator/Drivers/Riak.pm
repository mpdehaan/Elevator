=pod

=head1 NAME

Elevator::Drivers::Riak

=head1 DESCRIPTION

Riak NoSql driver that corresponds with the Elevator::Model::Roles::NoSql mixin

=cut
##########################################################################
    
use MooseX::Declare;

class Elevator::Drivers::Riak {

    # TODO: make sure buckets are created with allow_mult=False as this implementation
    # ignores VClock for now.  Could easily be changed later.

    use Method::Signatures::Simple name => 'action';

    our $WRITE_QUORUM = 2;
    our $READ_QOUROM  = 2;

    action _write_url($bucket, $key) {
         return "http://" . $self->server() . "/riak/$bucket/$key?w=" . $Elevator::Drivers::Riak::WRITE_QUORUM;
    }

    action _read_url($bucket, $key) {
         return "http://" . $self->server() . "/riak/$bucket/$key?r=" . $Elevator::Drivers::Riak::READ_QUORUM;
    }
    
    action _delete_url($bucket, $key) {
         return "http://" . $self->server() . "/riak/$bucket/$key";
    }
   
    action _map_reduce_url() {
         return "http://" . $self->server() . "/mapred";
    }
 
    action _agent() {
         my $ua = LWP::UserAgent->new();
         $ua->default_header('Content-Type' => 'text/json');
         return $ua;
    }

    # where's the NoSQL server?
    action server {
        # fixme, read from config
        # consider load balanced pool
        # alternate: 192.168.0.241:8098
        # return "192.168.0.240:8098"
        return "127.0.0.1:8098"
    }

    # return a list of hash structures for a search.
    action find_by_criteria($bucket_name, $criteria) {
        die "riak search not implemented yet";
    }

    # return a single entry after specifying it's bucket key
    action find_by_key($bucket_name, $bucket_key) {
        my $url = $self->_write_url($bucket_name, $bucket_key); 
        my $response = $self->_agent()->get($url);
        return undef unless $response->is_success();
        return $response->content();
    }

    # save a single record
    action save_one($bucket_name, $bucket_key, $obj) {
         my $url = $self->_write_url($bucket_name, $bucket_key); 
         my $response = $self->_agent()->post(
             $url,
             Content => $obj->to_json_str()
         );
         unless ($response->is_success()) {
             warn "Riak response: " . $response->content();
             die $response->status_line();
         }
    }

    # delete a single key
    action delete_by_key($bucket_name, $bucket_key) {
        my $url = $self->_delete_url($bucket_name, $bucket_key); 
        my $request = HTTP::Request->new('DELETE', $url);
        $self->_agent()->request($request);
        return 1;
    }

    # delete_all is to be implemented as a find_by_criteria/loop + delete
    action delete_by_criteria($bucket_name, $criteria) {
        die "not implemented yet";
        return 1;
    }

}


