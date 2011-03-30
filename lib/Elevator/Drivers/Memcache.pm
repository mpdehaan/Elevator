# Elevator::Drivers::Memcache
# 
# Memcache driver that provides a connection to Memcache for use in classes that use the
# DbTable role.
# 
# Subclass this to provide a proper server address
# (and maybe if you want to tune memcache settings)
    
use MooseX::Declare;

class Elevator::Drivers::Memcache {
    
    use Method::Signatures::Simple name => 'action';
    use Cache::Memcached::Fast;

    our $memd = undef; # shared memcache handle

    # defaults can/should be overriden in organization-specific subclasses:
    # see Cache::Memcached::Fast for documentation...  

    action servers() {
        return [ qw/127.0.0.1/ ];
    }

    action compress_threshold() {
        return 5000;
    }

    action max_failures() {
        return 3;
    }

    action failure_timeout() {
        return 2;
    }

    action connect_timeout() {
        return 0.2;
    }

    action io_timeout() {
        return 0.5;
    }

    action init() {
        $memd = new Cache::Memcached::Fast {
            servers            => $self->servers(),
            compress_threshold => $self->compress_threshold(),
            max_failures       => $self->max_failures(),
            failure_timeout    => $self->failure_timeout(),
            connect_timeout    => $self->connect_timeout(),
            io_timeout         => $self->io_timeout(),
        };
    }

    action retrieve($key) {
        $self->init() unless $memd;
        $key = $self->_escape_key($key);
        return $memd->get($key);
    }

    action store($key, $val, $exptime) {
        $self->init() unless $memd;
        $key = $self->_escape_key($key);
        return $memd->set($key, $val, $exptime);
    }

    action delete($key) {
        $self->init();
        $key = $self->_escape_key($key);
        return $memd->delete($key);
    }

    action _escape_key($key) {
        # Check for control chars (so we can warn about them)
        my $has_control_chars = ($key =~ /[[:cntrl:]]/);
        # URI encode and whitespace or control chars
        $key =~ s/([[:space:][:cntrl:]])/sprintf("%%%02X", ord($1))/seg;
        # warn about control chars if there were any. Printing the uri-encoded version
        warn "cache key contains control characters: [$key]" if $has_control_chars;
        return $key;
    }

}
