package Data::Transform::Named;
# ABSTRACT: Collection of named data transformation subs

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

=method transformer

	$named->transformer('name', \@arguments, \%options);
	$named->transformer('match', ['yay', 'boo']);
	$named->transformer('match', ['yay', 'boo'], {});

Return a sub ready for one-time use
or for inclusion in a Stackable.

If the 'bind' option is true,
the sub will be wrapped in a closure with the provided \@arguments
passed after the first element (the data being transformed).

=cut

sub transformer {
	my ($self, $name, $args, $opts) = @_;
	my $sub = $self->{named}->{$name}
		or croak("Unknown Transformer name: '$name'");

	# bind arguments to sub if requested (useful outside of Stackable)
	$sub = sub { $sub->($_[0], @$args); }
		if $opts->{bind};

	return $sub;
}

1;

=for stopwords stackable

=head1 TODO

=for :list
* Consider a name change
* Consider options to the transformers (like {on_undef => 'do_what'})
