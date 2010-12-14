package Data::Transform::Named::Stackable;
# ABSTRACT: Simple, named interface to Data::Transform::Stackable

=head1 SYNOPSIS

	my $stack = Data::Transform::Named::Stackable->new();

	$stack->push('trim', fields => [qw(name address)]);

	$stack->group(fruits => [qw(apple orange banana)]);
	$stack->push('trim', groups => 'fruits');

=cut

use strict;
use warnings;
use Carp qw(croak cluck);

use Data::Transform 0.06;
use Data::Transform::Stackable;

# TODO: all-others group? (all the fields that haven't been done so far)

=method new

	# use the default functions from Data::Transform::Named::Common
	Data::Transform::Named::Stackable->new();

	# or define your own set of functions:
	my $named = Data::Transform::Named->new()->add(
		something => sub {}
	);

	my $stack = Data::Transform::Named::Stackable->new(named => $named);
	# or
	my $stack = $named->stackable()

If you're creating your own collection of named functions,
it may be easier to use L<Data::Transform::Named/stackable>.

=cut

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

=method push

	$stack->push($name,   $type, [qw(fields)], @arguments);
	$stack->push('trim',  fields => [qw(fld1 fld2)]);
	$stack->push('match', 'groups', 'group1', "matched", "not matched");

Push a named transformation onto the stack
for the specified fields or groups
and pass the supplied arguments.

=cut

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
