# Elevator::Drivers::Mongo
# 
# Mongo NoSql driver that corresponds with the Elevator::Model::Roles::NoSql mixin
    
use MooseX::Declare;

class Elevator::Drivers::Mongo {

    use Method::Signatures::Simple name => 'action';
    use MongoDB;
    use Carp;

    # a MongoDB connection
    has connection => (is => 'rw', isa => 'Object', lazy => 1, builder => '_make_connection');

    # where's the NoSQL server?
    action _server {
        # fixme, read from config
        return "127.0.0.1"
    }

    # create a MongoDB connection
    action _make_connection() {
         # Mongo will create the "main_database" database on the fly, we're just using buckets
         # (collections) and don't need seperate databases.
         return MongoDB::Connection->new( host => $self->_server() )->main_database();
    }

    # provide a MongoDB bucket handle
    action _handle($bucket_name) {
        return $self->connection->$bucket_name;
    }

    # return a list of hash structures for a search.
    action find_by_criteria($bucket_name, $criteria) {
        my @results = $self->_handle($bucket_name)->find($criteria)->all();
        return \@results;
    }

    # return a single entry after specifying it's bucket key
    action find_by_key($bucket_name, $bucket_key) {
        my $result = $self->_handle($bucket_name)->find_one({
            _id => $bucket_key
        });
        return $result;
    }

    # save a single record
    action save_one($bucket_name, $bucket_key, $obj) {
        my $previous = $self->find_by_key($bucket_name, $bucket_key);
        my $data = $obj->to_datastruct();
        $data->{'_id'} = $bucket_key;
        if ($previous) {
           $self->_handle($bucket_name)->update({ _id => $bucket_key }, $data); 
        } else {
	   $self->_handle($bucket_name)->insert($data);
        }
        return undef; # no extended properties to store for this driver
    }

    # delete a single key
    action delete_by_key($bucket_name, $bucket_key) {
        $self->delete_by_criteria($bucket_name, { _id => $bucket_key });
    }

    # delete_all matches to criteria
    action delete_by_criteria($bucket_name, $criteria) {
        $self->_handle($bucket_name)->remove($criteria);
    }

}


