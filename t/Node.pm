package Acme::Util::Test::Node;

# simple Node class to test Acme::Util's weakref cloning

use strict;
use warnings;
use Scalar::Util qw(weaken);

sub new {
    my ($class, $id) = @_;
    my $self = {
	CHILDREN    => [ ],
	ID	    => $id,
	INDEX	    => { },
	PARENT	    => undef
    };
    bless $self, $class;
}

sub add {
    my ($self, $child) = @_;
    my $child_id = $child->{ID};

    push @{$self->{CHILDREN}}, $child;
    $self->{INDEX}->{$child_id} = $child;
    weaken ($child->{PARENT} = $self);
    return $self;
}

1;
