# Elevator::Model::Roles::Serializable
# 
# A Moose Role that allows an object to jsonify itself, as well as dump
# and load datastructures.
#
#   my $obj  = BaseObject->new(p1 => 'x', p2=> 'y');
#   my $json = $obj->to_json();
#   my $obj2 = BaseObject->from_json($json);
#   $obj->log_msg("something");
#

package Elevator::Model::Roles::Serializable;
use Moose::Role;
use JSON::XS;
use Scalar::Util;

    # don't lookup meta attributes more than once, it's expensive.
    sub my_attributes {
        my $self = shift();
        my $class_name = ref($self) ? ref($self) : $self;
        # we let forge hold onto a copy but it might as well be this class
        my $attributes_copy = $Elevator::Model::Forge::ATTRIBUTES_COPY->{$class_name};
        return $attributes_copy if defined $attributes_copy;
        my @attribs = $self->meta->get_all_attributes();
        $Elevator::Model::Forge::ATTRIBUTES_COPY->{$class_name} = \@attribs;
        return \@attribs;
    }
   
    # optimization: is a given attribute data (should be serialized?)
    sub _does_data {
        my ($self, $attr) = @_;
        my $attribs = $self->_data_attribs($attr);
        return $attribs->{'does_data'};
    }

    # optimization: what's the writer for an attribute?
    sub _write_method_ref {
        my ($self, $attr) = @_;
        my $attribs = $self->_data_attribs($attr);
        return $attribs->{'write_method_ref'};
    }

    # optimization: what's the field name to use?
    sub _field_or_name {
        my ($self, $attr) = @_;
        my $attribs = $self->_data_attribs($attr);
        return $attribs->{'field_or_name'};
    }

    # optimization: returns metadata but only asks once per class type.  This is horrendous
    # and low level but we execute this many hundreds of times per request and therefore care
    # quite a lot.
    sub _data_attribs {
        # input is the class and a given meta attribute to get details about
        my $self = shift();
        my $attr = shift();
        my $variable = $attr->name();
        my $class_name = ref($self) ? ref($self) : $self;
        # a global hash of attributes is keyed off each class name
        my $attr_hash = $Elevator::Model::Forge::DATA_ATTRIBUTES;
        my $class_hash = $attr_hash->{$class_name};
        unless ($class_hash) {
            $class_hash = $attr_hash->{$class_name} = {};
        }
        my $value = $class_hash->{$variable};
        unless (defined $value) {
            # if the instance for this class does not exist, we must create it.
            my $does_it = $attr->does('Elevator::Model::Traits::Data');
            $value = $class_hash->{$variable} = {
                'does_data'        => $does_it,
            };
            if ($does_it) {
                #$value->{'write_method_ref'} = $attr->get_write_method_ref();
                $value->{'field_or_name'}    = $attr->field() || $variable;
            };
        }
        return $value;
    }

    # return the object's data members as a hash.
    sub to_datastruct {
        my $self = shift();
        my $result = {};
        # for each attribute
        foreach my $attr (@{$self->my_attributes()}) {
            # the custom attribute data must be true in order
            # for this field to be serialized.  Default is no.
            if ($self->_does_data($attr)) {
                my $value = $attr->get_value($self);
                # manually marshal things that don't auto-jsonify
                # we don't have to worry about this in the reverse direction
                # because we're using Moose coercions (Elevator/Types.pm)
                if ($attr->type_constraint() =~ /Bool/) {
                    $value = ($attr->get_value($self)) ? 'y' : 'n';
                }
                elsif (blessed($value)) {
                    if ($value->isa('DateTime')) {
                        $value = Elevator::Model::Util::Utils::date_to_str( $value );
                    }
                }
                # store the value in a hash based on the field or name of the attribute
                my $name = $self->_field_or_name($attr);
                $result->{$name} = $value;
            }
                    
        }
        return $result;
    }
    
# from_datastruct
# 
# Given a hash, return a new object with the values from the hash.
# This can be a complete dump of 'from_datastruct' or a partial list.   
# This respects mutator validation, if present.
# 
# NOTE:  If any Moose values do "required => 1" then this won't work.  Don't
# use required in Moose.  Instead, check for required fields using a seperate
# post_construct validation method (We'll add support for one later).
#

    sub from_datastruct {
        my $self            = shift();
        my $datastruct      = shift();
        my $obj             = $self->new();        
        # for each attribute
        foreach my $attr (@{$self->my_attributes()}) {
            # the custom attribute data must be true in order
            # for this field to be serialized.  Default is no.
            my $attribs = $self->_data_attribs($attr);

            if ($attribs->{'does_data'}) {
                #my $writer = $attribs->{'write_method_ref'};
                my $name   = $attribs->{'field_or_name'};
                my $new_value = $datastruct->{$name}; 
                # only set if the value isn't undef, such that Moose default will be respected.
                if (defined $new_value) {
                    #$writer->($obj,$new_value);
                    $attr->set_value($obj, $new_value);
                }
            }
        }

        # return the now populated/complete object.
        return $obj;
    }

# to_json_str
#
# Returns a jsonified version of the object's member variables, suitable for usage with
# from_json.

    sub to_json_str {
        my $self = shift();
        return Elevator::Model::Forge->instance->json->encode($self->to_datastruct());
    }
   
#  from_json_str($self, $json)
#
# Updates member variables of an object using JSON data.  Can be used on a relatively 'bare'
# class or as a form of batch update.  As with from_datastruct this respects any 
# mutators that are configured.
#

    sub from_json_str {
        my $self = shift();
        my $json = shift();
        return $self->from_datastruct(Elevator::Model::Forge->instance->json->decode($json));
    }

# pretty print a datastructure
# TODO: a list of fields to not show would be nice in the case of 'frozen' perl objects.
# when we hit those, add in a method in the base class we can ask for fields to not show in pretty print.
# TODO: filter id and name to the top.

    sub pretty_print {
        my ($self) = @_;
        my $data = $self->to_datastruct();
        my @keys = sort keys(%$data);
        my $result = "";
        foreach my $key (@keys) {
            $result .= sprintf("%15s : %s\n", $key, $data->{$key} || '');
        }
        return $result;
    }
    
##########################################################################
  
1;
