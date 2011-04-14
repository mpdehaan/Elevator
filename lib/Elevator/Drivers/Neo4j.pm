# Elevator::Drivers::Neo4j
# 
# Neo4j NoSql driver that corresponds with the Elevator::Model::Roles::NoSql mixin
# this is actually a graph database, but it lines up enough to use the NoSql mixn
# and it's better than having an additional GraphDB mixin.
 
use MooseX::Declare;

class Elevator::Drivers::Neo4j {

    use Method::Signatures::Simple name => 'action';
    use LWP::UserAgent;
    use URI::Escape;
    use Carp;

    has _agent  => (is => 'rw', isa => 'Object', lazy => 1, builder => '_make_agent');

    # where's the server?
    action _server {
        # likely you'll want to read from a config, fix this in your subclass
        return "http://127.0.0.1:7474/db/data"
    }

    # make an object that can make requests
    action _make_agent() {
        my $ua = LWP::UserAgent->new();
        $ua->default_header('Content-Type' => 'application/json');
        return $ua;
    }

    # URL used to add nodes.
    action _node_url() {
        return $self->_server() . "/node";
    }


    # return a list of hash structures for a search.
    action find_by_criteria($bucket_name, $criteria) {
        die 'not implemented';
        #my @results = $self->_handle($bucket_name)->find($criteria)->all();
        #return \@results;
    }

    # return a single entry after specifying it's bucket key
    # NOTE: our key is *not actually unique in Neo4j, as we're looking up, not knowing the actual Neo4j integer, the application
    # method bucket_key must therefore always be unique, as if they are dups, this code will return the *FIRST* one ...
    # and maybe it should raise a warning.

    action find_by_key($bucket_name, $bucket_key) {
        my $key = $self->_key_for_strings($bucket_name, $bucket_key);
        #my $url = $self->_node_url() . '/' . $key;
        my $url = $self->_server() . "/index/node/my_nodes/__key/$key";
        warn "search url = $url\n";
        my $response = $self->_agent()->get($url);
        unless ($response->is_success()) {
            warn "Neo4j response: " . $response->content();
            return undef;
        }
        warn "Neo4j response: " . $response;

        # NOTE: here we probably have MORE data than just the object data, which may require returning something a little different
        # and having the role be aware of it... the driver may need to tweak things.

        # FIXME: this is a bit of a quirk, but we want only one result, so we must DE-JSONIFY, yet the calling driver expects
        # a JSON return, so... lie to it

        return $response;

    }
    
    # Neo4j doesn't have persistant reliable keys, let's make our own.
    action _key_for_object($obj) {
        return $obj->bucket_name() . '__' . $obj->bucket_key();
    }

    action _key_for_strings($bucket_name, $bucket_key) {
        return $bucket_name . '__' . $bucket_key;
    }

    # save a single record
    
    action save_one($bucket_name, $bucket_key, $obj) {
    
        my $data = $obj->to_datastruct();
        $data->{'__key'} = $self->_key_for_object($obj);
        my $url = $self->_node_url();
        warn "URL = $url\n";
        my $response = $self->_agent()->post($url, $data);

        unless ($response->is_success()) {
            warn "Neo4j response: " . $response->content();
            die $response->status_line();
        }

        my $content = $response->content();
        warn "Neo4j response: " . $content;

        my $decoded = Elevator::Model::Forge->instance->json->decode($content);
        $self->_add_to_index($bucket_name, $bucket_key, $obj, $decoded);

        return $content;

        # die "have to parse the response to return the id we saved, right?";

        #my $previous = $self->find_by_key($bucket_name, $bucket_key);
        #my $data = $obj->to_datastruct();
        #$data->{'_id'} = $bucket_key;
        #if ($previous) {
        #   $self->_handle($bucket_name)->update({ _id => $bucket_key }, $data); 
        #} else {
	#   $self->_handle($bucket_name)->insert($data);
        #}
    }

    # manual additions to the Neo4j index are required to search by index, and since the ID's are not
    # predictable, it's nice to be able to do that.  This adds them with every commit.   FIXME:
    # we should also remove indexes on deletes, right?

    action _add_to_index($bucket_name, $bucket_key, $obj, $decoded_result) {
         my $key = $self->_key_for_object($obj);
         my $url = $self->_server() . "/index/node/my_nodes/__key/$key";
         my $node_self_url = $decoded_result->{'self'};
         die "node doesn't have a self URL!" unless $node_self_url =~ /http/;
         warn "node self url = $node_self_url";
         # FIXME: we have to urlencode this string before sending it.
         # add quotes around the URL, per Neo4j docs

         # equivalent of curl -d with just a string, for some reason Neo4j is picky here
         # and won't take a straight POST from LWP::UserAgent, curl works fine though.
         my $request = HTTP::Request->new('POST', $url);
         $request->content_type('application/json');
         my $json = Elevator::Model::Forge->instance->json->encode($node_self_url);
         $request->content($json);
         
         my $response = $self->_agent()->request($request);
         unless ($response->is_success()) {
             warn "Neo4j response: " . $response->content();
             die $response->status_line();
         }
         warn "index addition ok\n";

    }

    # delete a single key
    action delete_by_key($bucket_name, $bucket_key) {
        #$self->delete_by_criteria($bucket_name, { _id => $bucket_key });
    }

    # delete_all matches to criteria
    action delete_by_criteria($bucket_name, $criteria) {
        #$self->_handle($bucket_name)->remove($criteria);
    }

}


