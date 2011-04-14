
# a singleton factory that produces singleton instances of useful
# modules like JSON::XS, DateTimes, and so forth

use MooseX::Declare;

class Elevator::Model::Forge {
    
    use Method::Signatures::Simple name => 'action';
    use DateTime;
    use JSON::XS;
    use Digest::MD5;
    use DateTime::Format::Strptime;

    # this might need overriding if your database doesn't like these formats    
    use constant DB_DATETIME_FORMAT => "%Y-%m-%d %H:%M:%S";
    use constant DB_DATETIME_FORMAT_NO_SPACES => "%Y%m%d%H:%M:%S";
    
    # *** LOW LEVEL EVILS **
    # a cache of class attributes to avoid repeated lookups
    # only for use by Elevator::Model::Serializable, no exceptions!
    our $ATTRIBUTES_COPY = {};
    # for each class attributes, a hash of which attribute names
    # have  Elevator::Model::Traits::Data.  Also do not touch!
    our $DATA_ATTRIBUTES = {};
    # *** END LOW LEVEL EVILS **
    
    # holds a reference to the singleton
    our $INSTANCE;
    
    # a JSON::XS instance
    has 'json'                          => (is => 'rw', lazy => 1, builder => '_make_json');
    # a Digest::MD5'er
    has 'md5'                           => (is => 'rw', lazy => 1, builder => '_make_md5');
    # the current DateTime
    has 'now'                           => (is => 'rw', lazy => 1, builder => '_make_now',);
    has 'datetime_formatter'            => (is => 'rw', lazy => 1, builder => '_make_datetime_formatter');
    has 'datetime_formatter_no_spaces'  => (is => 'rw', lazy => 1, builder => '_make_datetime_formatter');
    has 'sql_abstract'                  => (is => 'rw', lazy => 1, builder => '_make_sql_abstract');
    
    action _make_json {
       return JSON::XS->new()->allow_nonref(1)->canonical(1);
    }
    
    action _make_now {
       return DateTime->now();
    }
    
    action _make_md5 {
       return Digest::MD5->new();
    }
    
    action _make_sql_abstract {
       return SQL::Abstract->new();
    }
    
    action _make_datetime_formatter {
       return DateTime::Format::Strptime->new(
           pattern  => DB_DATETIME_FORMAT,
           on_error => 'croak',
           time_zone => 'UTC'
       );
    }
    
    action _make_datetime_formatter_no_spaces {
       return DateTime::Format::Strptime->new(
           pattern  => DB_DATETIME_FORMAT_NO_SPACES,
           on_error => 'croak',
           time_zone => 'UTC'
       );
    }
    
    action instance() {
        return $INSTANCE if $INSTANCE;
        $INSTANCE = Elevator::Model::Forge->new();
    }
}
