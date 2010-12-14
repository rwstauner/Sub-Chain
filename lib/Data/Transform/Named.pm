package Data::Transform::Named;
# ABSTRACT: Simple, named interface to Data::Transform

=head1 SYNOPSIS

	Data::Transform::Named->new(arr => sub { "arr $_[0]" })

=cut

use strict;
use warnings;

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

	my $common = 'Data::Transform::Named::Common';
	eval "require $common";
	die $@ if $@;

	$self->add($common->_all());

	# chainable
	return $self;
}

1;
