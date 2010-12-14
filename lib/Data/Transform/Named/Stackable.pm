package Data::Transform::Named::Stackable;
# ABSTRACT: Simple, named interface to Data::Transform::Stackable

=head1 SYNOPSIS

	my $stack = Data::Transform::Named::Stackable->new();

	$stack->push('trim', fields => [qw(name address)]);

=cut

use strict;
use warnings;
use Carp qw(croak cluck);
use Data::Transform 0.06;
use Data::Transform::Stackable;

sub new {
	my $class = shift;
	my $named = $_[0] || Data::Transform::Named->new->add_common;
	my $self = {
		named  => $named,
		fields => {},
		groups => {},
	};

	bless $self, $class;
}

sub push {
	my ($self, $tr, $type, $names, @args) = @_;

	# allow a single name and convert it to an arrayref
	$names = [$names]
		if ! ref $names;

	my $collection = $type . 's';
	croak("'$type' unrecognized")
		unless $collection = $self->{$collection};

	foreach my $name ( @names ){
		($collection->{$name} ||=
			Data::Transform::Stackable->new())
		->push(
			$self->{named}->tr($tr, @args)
		);
	}
}

1;
