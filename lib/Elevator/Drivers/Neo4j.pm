# Elevator::Drivers::Neo4j
# 
# Neo4j NoSql driver that corresponds with the Elevator::Model::Roles::NoSql mixin
# this is actually a graph database, but it lines up enough to use the NoSql mixn
# and it's better than having an additional GraphDB mixin.

# for reference, some properties returned when creating nodes.  These are eventually stored
# in 

#  "outgoing_relationships" : "http://127.0.0.1:7474/db/data/node/26/relationships/out",
#  "data" : {
#    "some_array" : [ "1", "2", "3" ],
#    "__key" : "GraphNode__glorp",
#    "some_integer" : "2",
#    "some_keyval" : "glorp",
#    "some_string" : "x"
#  },
#  "traverse" : "http://127.0.0.1:7474/db/data/node/26/traverse/{returnType}",
#  "all_typed_relationships" : "http://127.0.0.1:7474/db/data/node/26/relationships/all/{-list|&|types}",
#  "property" : "http://127.0.0.1:7474/db/data/node/26/properties/{key}",
#  "self" : "http://127.0.0.1:7474/db/data/node/26",
#  "properties" : "http://127.0.0.1:7474/db/data/node/26/properties",
#  "outgoing_typed_relationships" : "http://127.0.0.1:7474/db/data/node/26/relationships/out/{-list|&|types}",
#  "incoming_relationships" : "http://127.0.0.1:7474/db/data/node/26/relationships/in",
#  "extensions" : {
#  },
#  "create_relationship" : "http://127.0.0.1:7474/db/data/node/26/relationships",
#  "all_relationships" : "http://127.0.0.1:7474/db/data/node/26/relationships/all",
#  "incoming_typed_relationships" : "http://127.0.0.1:7474/db/data/node/26/relationships/in/{-list|&|types}"

 
use MooseX::Declare;

class Elevator::Drivers::Neo4j {

    use Method::Signatures::Simple name => 'action';
    use LWP::UserAgent;
    use URI::Escape;
    use Carp qw/croak confess/;
    use Clone;
    use Data::Dumper;
    use Try::Tiny;

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
        #return \@results;
    }
    
    # return a single entry after specifying it's bucket key. Neo always returns a list, though in our
    # implementation, find_by_key needs to return only one result, so always use the first
    # result.

    action find_by_key($bucket_name, $bucket_key) {
        confess "invalid bucket name" unless defined $bucket_name;
        confess "invalid bucket key"  unless defined $bucket_key;
        my $results = $self->__index_search({ __key => $self->_key_for_strings($bucket_name, $bucket_key) });
        return undef unless defined $results;
        my $json_results = Elevator::Model::Forge->instance->json->decode($results);
        # the JSON that we get back actually has a subelement called 'json' that we do because we want to protect
        # our original data from Neo4j's weird "I prefer encodings as POST DATA" preferences (appparent, not proven).
        my $result_count = scalar @$json_results;
        warn "[?] find results returned = $result_count\n";
        return undef unless ($result_count > 0);
        warn "too many results returned ($result_count), using 0th" if ($result_count > 1);
        my $ct = 0;
        foreach my $json_result (@$json_results) {
              $ct++;
              next if $ct == 1;
              my $self_url = $json_result->{self};
              warn "[!] cleanup time, deleting extra results beyond the 0th: $self_url\n";
              $self->__delete_by_node_url($self_url, $bucket_name, $bucket_key);
        }
        # if more than one result is returned, immediately deal with the problem by removing the duplicate results.

        warn "DEBUG: INPUT RESULT = " . Data::Dumper::Dumper $json_results;
        my $result = $self->__unmangle_neo4j_hash($json_results->[0]);
        # warn "RAW HASH RESULTS FOR find_by_key($bucket_name, $bucket_key)" . Data::Dumper::Dumper($results);
        return $result;
    }
    
    # Neo4j returns a lot of extended info and the actual data is inside a 'data' subhash
    # because of the way we post, this 'data' subhash has a key called json, and our real data lies within THAT.
    # we'll mangle the returns and return the data as the outer hash with the extended data
    # in a 'extended_nosql_data' subhash. 

    action __unmangle_neo4j_hash($single_result) {
        my $new_result = { extended_nosql_data => {} };
        #warn "DEBUG: RAW SINGLE RESULT = " . Data::Dumper::Dumper $single_result;
        foreach my $key (keys(%$single_result)) {
            unless ($key eq 'data') {
               $new_result->{extended_nosql_data}->{$key} = Clone::clone $single_result->{$key}; 
            } 
            else {
                my $data_block = $single_result->{'data'}->{'json'};
                if ($data_block) {
                    warn "* decoding json: $data_block\n";
                    my $decoded    = Elevator::Model::Forge->instance->json->decode($data_block);
                    foreach my $dkey (keys %$decoded) {
                        $new_result->{$dkey} = $decoded->{$dkey};
                    }
                }
            }
        }
        return $new_result;
    }

    # search for a node based on a key.  NOTE: in order for this to work, it *must* be added to the index.
    # FIXME: each class should have a method of which keys/values to add to the index
    # FIXME: this may not accurately support multiple search results
    # FIXME: Neo has better REST APIs for index lookups in 1.3, investigate

    action __index_search($criteria) {

        my $url = $self->_server() . "/index/node/my_nodes"; # __key/$key";
        foreach my $key (keys(%$criteria)) {
             my $value = $criteria->{$key};
             $url = $url . "/$key/" . URI::Escape::uri_escape($value);
        }
        my $response = $self->_agent()->get($url);
        unless ($response->is_success()) {
            warn "[!] Neo4j index search returned no hits";
            return undef;
        }
        return $response->content();

    }
    
    # Neo4j doesn't have persistant reliable keys, let's make our own.
    action _key_for_object($obj) {
        return $obj->bucket_name() . '__' . $obj->bucket_key();
    }

    action _key_for_strings($bucket_name, $bucket_key) {
        confess "invalid bucket name" unless defined $bucket_name;
        confess "invalid bucket key" unless defined $bucket_key;
        return $bucket_name . '__' . $bucket_key;
    }

    # save a single record
    
    action save_one($bucket_name, $bucket_key, $obj) {
        my $data = $obj->to_datastruct();
        $data->{'__key'} = $self->_key_for_object($obj);
        my $url = $self->_node_url();
        # because Neo4j doesn't like JSON submissions in some cases and seems to perform POSTS and then proceeds
        # to mangle scalar numbers into strings, etc, it's safest if we just store JSON in it and not data directly.
        # hence one additional level of indirection.
        my $json = $obj->to_json_str();
        my $post_data = {
             'json' => $json,
        };
        my $response = $self->_agent()->post($url, $post_data);
        unless ($response->is_success()) {
            warn "Neo4j response: " . $response->content();
            die $response->status_line();
        }

        my $content = $response->content();
        warn "******** ON SAVE VERY RAW ****** Neo4j response: " . $content;
        my $decoded = Elevator::Model::Forge->instance->json->decode($content);
        $self->_add_to_index($bucket_name, $bucket_key, $obj, $decoded);
        return $content;
    }

    # manual additions to the Neo4j index are required to search by index, and since the ID's are not
    # predictable, it's nice to be able to do that.  This adds them with every commit.   FIXME:
    # we should also remove indexes on deletes, right?

    action _add_to_index($bucket_name, $bucket_key, $obj, $decoded_result) {
         my $key = $self->_key_for_object($obj);
         my $url = $self->_server() . "/index/node/my_nodes/__key/$key";
         my $node_self_url = $decoded_result->{'self'};
         #die "node doesn't have a self URL!" unless $node_self_url =~ /http/;
         # FIXME: we have to urlencode this string before sending it.
         # add quotes around the URL, per Neo4j docs

         # equivalent of curl -d with just a string, for some reason Neo4j is picky here
         # and won't take a straight POST from LWP::UserAgent, curl works fine though.
         my $request = HTTP::Request->new('POST', $url);
         $request->content_type('application/json');
         #my $json = Elevator::Model::Forge->instance->json->encode($node_self_url);
         $request->content("\"$node_self_url\"");
         
         my $response = $self->_agent()->request($request);
         unless ($response->is_success()) {
             #warn "Neo4j response: " . $response->content();
             die $response->status_line();
         }
         return $obj;
    }

    # delete object assigned to a single key
    action delete_by_key($bucket_name, $bucket_key) {
        my $hash_data = $self->find_by_key($bucket_name, $bucket_key);
        return 0 unless defined $hash_data;
        warn "DEBUG: hash data = " . Data::Dumper::Dumper $hash_data;
        die "missing extended info?" unless $hash_data->{extended_nosql_data};
        my $self_url = $hash_data->{extended_nosql_data}->{self};
        die "missing extended info(2)?" unless $self_url;
        return $self->__delete_by_node_url($self_url, $bucket_name, $bucket_key);
    }

    # low level delete implementation
    action __delete_by_node_url($node_url, $bucket_name, $bucket_key) {
        my $request = HTTP::Request->new('DELETE', $node_url);
        my $response = $self->_agent()->request($request);
        warn "[!] Neo4j delete failed for $node_url, already gone?" unless $response->is_success();
        # warn "DELETE SUCCESS: $node_url\n";
        my @node_parts = split /\//, $node_url;
        my $node_id = $node_parts[-1];
        $self->__delete_from_key_index($bucket_name, $bucket_key, $node_id);
    }

    action __delete_from_key_index($bucket_name, $bucket_key, $node_id) {
        my $key = $self->_key_for_strings($bucket_name, $bucket_key);
        my $delete_url = $self->_server() . "/index/node/my_nodes/__key/$key/$node_id";
        my $request = HTTP::Request->new('DELETE', $delete_url);
        my $response = $self->_agent()->request($request);
        warn "[!] Neo4j index delete failed for $delete_url, already gone?" unless $response->is_success();
    }

    #$self->delete_by_criteria($bucket_name, { _id => $bucket_key });
    #}

    # delete_all matches to criteria
    action delete_by_criteria($bucket_name, $criteria) {
        die "not implemented\n";
        #$self->_handle($bucket_name)->remove($criteria);
    }

    # TODO: methods to add links (with properties)
    # TODO: methods to query link information on a node
    # TODO: traversal and path methods
    # TODO: surface other useful Neo4j REST methods (which?)


   # add a link between two nodes
   # objects both must have already been commited and populated with their Neo4j internals.
   # in other words, call "by_key" on both of them to ensure you've got that.
   # calling code has the responsibility of ensuring no duplicate link exists for now
   # FIXME: use find_links methods to prevent sending duplicate call first if link is already there.
   action  add_link_to($other, $link_type) {

       # FIXME: ensure linktype is passed in role
       #my $url_of_second = $other->extended_nosql_data->{'self'};
       #my $packet = {
       #   to  => $url_of_second,
       #   type => $link_type,
       #};
       #my $response = $self->_agent()->put($add_link_url, $packet); # again, not JSON?

   }

   # make this object *not* link to another object.
   # deletes any outgoing links, regardless of type
   # we may later need to change this to support removing links of only certain types
   # or only links with certain data elements

   action remove_links_to($other) {
   }

   # what are the links leading out of this node?
   # returns a list like [[ "type", "key" ], ... ] 

   action list_links_from() {
   }

   # what are the links leading into this node?
   # returns a list like [[ "type", "key" ], ... ]
  
   action list_links_to() {
   }


}


