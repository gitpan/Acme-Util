package Scope::Guard;

=pod

=head1 DESCRIPTION

Confer lexical semantics on arbitrary resources

=head1 METHODS

=head2 new

=head3 usage

    my $sg = Scope::Guard->new();

        # or

    my $sg = Scope::Guard->new($handler);

        # or

    my $sg = Scope::Guard->new($handler, $resource);

=head3 description

Creates a new ScopeGuard object. ScopeGuard provides resource
management for a non-lexically-scoped variable
by wrapping that variable in a lexical whose destructor then
manages the bound resource.

Thus the lifetime of a non-lexical resource can be made
commensurate with that of a blessed lexical.

In other words, a resource that's messy, painful or
inconvenient to close/free/cleanup can be 'automagically' managed
as painlessly as any temporary. Forget about it, let it go out of
scope, or set it to undef and resource
management kicks in via the ScopeGuard destructor (DESTROY, of course)
which either invokes the supplied sub (typically a closure), or
feeds its bound resource to the specified handler.

For more information on ScopeGuard, vide:

http://www.cuj.com/documents/s=8000/cujcexp1812alexandr/

=cut

use strict;
use warnings;

our $VERSION = 0.02;

sub new {
    my ($class, $handler, $resource) = @_;
    my $self = [ $handler, $resource ];
    bless $self, ref $class || $class;
}

=pod

=head2 guard

=head3 usage

    $sg->guard($handler);
    
        # or

    $sg->guard($handler, $resource);

=head3 description

Initialize a ScopeGuard object with the resource it should
manage and the handler that should be called to implement
that management when the ScopeGuard object's destructor is called.

=cut

sub guard {
    my $self = shift;
    @$self = @_;
}

=pod

=head2 DESTROY

=head3 usage

    $sg->DESTROY();

=head3 description

Not called directly. The destructor is a thin wrapper around
the invocation of the handler; or (if supplied) the invocation
of the handler on the resource

=cut

sub DESTROY {
    my $self = shift;
    my ($handler, $resource) = @$self;
    $handler->($resource);
}

1;
