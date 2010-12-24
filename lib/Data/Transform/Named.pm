package Data::Transform::Named;
# ABSTRACT: Simple, named interface to Data::Transform

=head1 SYNOPSIS

	Data::Transform::Named->new(arr => sub { "arr $_[0]" })

=cut

use strict;
use warnings;
use Carp qw(croak);

=method new

	my $named = Data::Transform::Named->new(
		action => sub {},
	)->add_common;

Instantiate a collection of named functions.
A hash[ref] of named functions can be passed.

=cut

sub new {
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my %subs = ref $_[0] ? %{$_[0]} : @_;
	$self->{named} = \%subs;

	return $self;
}

=method add

	$named->add('goober' => \&peant_butter);

Add a named function to the collection.

=cut

sub add {
	my ($self) = shift;
	my %subs = ref $_[0] ? %{$_[0]} : @_;

	# TODO: warn if already exists?
	@{ $self->{named} }{keys %subs} = values %subs;

	# chainable
	return $self;
}

=method add_common

Load all the functions from
L<Data::Transform::Named::Common>.

=cut

sub add_common {
	my ($self) = @_;

	$self->add(_require('Data::Transform::Named::Common')->_all());

	# chainable
	return $self;
}

# convenience method for lazy loading the module
# and returning the package name string so you can chain it
sub _require {
	my ($mod) = @_;
	eval "require $mod";
	die $@ if $@;
	return $mod;
}

=method stackable

	$stack = $named->stackable();

Sends $self as the I<named> parameter to
L<Data::Transform::Named::Stackable/new>.

It's a convenience shortcut for:

	$named = Data::Transform::Named->new() ...
	$stack = Data::Transform::Named::Stackable->new(named => $named);

=cut

sub stackable {
	my ($self) = @_;
	return _require('Data::Transform::Named::Stackable')->new(
		named => $self
	);
}

=method transform

	$named->transform('name', @arguments);
	$named->transform('match', 'yay', 'boo');

Return a sub ready for inclusion in the stack.
Returns a L<Data::Transform::Map> with a I<Code>
parameter of the named sub called with the provided arguments.

=cut

sub transform {
	my ($self, $name, @args) = @_;
	my $sub = $self->{named}->{$name}
		or croak("Unknown Transform name: '$name'");

	return _require('Data::Transform::Map')->new(
		Code => sub { $sub->($_[0], @args); }
	);
}

1;

=for stopwords stackable

=for Pod::Coverage _require

=head1 TODO

=for :list
* Replace Data::Transform with a simpler, more appropriate implementation
* Consider a name change
