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
use Carp qw(croak carp);

use Data::Transform 0.06;
use Data::Transform::Stackable;

use Data::Transform::Named;
use Object::Enum 0.072 ();
use Set::DynamicGroups ();

our $WarnNoField = Object::Enum->new({unset => 0, default => 'single',
	values => [qw(never single always)]});

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

Possible options:

=begin :list

* I<named>
An instance of Data::Transform::Named.
A default (with all the functions from L<Data::Transform::Named::Common>)
will be created if not supplied.

* I<warn_no_field>
Whether or not to emit a warning if asked to transform a field
but transformations were not specified for that field
(specifically when L</stack> is called and no stack exists).
Valid values are:

=begin :list

* C<never> - never warn

* C<always> - always warn

=item *

C<single> - warn when called for a single transformation
(but not when L</transform> is called with a hashref or arrayref).

=end :list

The default is C<single>.

=end :list

=cut

sub new {
	my $class = shift;
	my %opts = ref $_[0] ? %{$_[0]} : @_;

	my $named = delete $opts{named} || Data::Transform::Named->new->add_common;
	my $self = {
		named  => $named,
		fields => {},
		groups => Set::DynamicGroups->new(),
		queue  => [],
		warn_no_field =>
			$WarnNoField->clone(delete $opts{warn_no_field} || 'single'),
	};

	bless $self, $class;
}

=method dequeue

Process the queue of group and field specifications.

Queuing allows you to specify a transformation
for a group before you specify what fields belong in that group.

This method is called when another method needs something
from the stack and there are still specifications in the queue
(L</stack> and L</transform>, for instance).

=cut

sub dequeue {
	my ($self) = @_;

	return unless my $queue = $self->{queue};
	my $dequeued = ($self->{dequeued} ||= []);

	# shift items off the queue until they've all been processed
	while( my $item = shift @$queue ){
		# save this item in case we need to reprocess the whole queue later
		push(@$dequeued, $item);

		my ($tr, $type, $names, $args) = @$item;

		# flatten to a single list of fields
		my $fields = $type eq 'groups'
			? [map { @$_ } values %{ $self->{groups}->groups(@$names) }]
			: $names;

		# create a single instance of the sub
		# and copy its reference to the various stacks
		my $map = $self->{named}->transform($tr, @$args);
		foreach my $field ( @$fields ){
			( $self->{fields}->{$field} ||=
				Data::Transform::Stackable->new() )->push( $map );
		}
	}
	# let 'queue' return false so we can do simple if queue checks
	delete $self->{queue};
}

=method group

	$stack->group(groupname => [qw(fields)]);

Append fields to the specified group name.

This is a convenience method.
Arguments are passed to L<Set::DynamicGroups/append>.

=cut

sub group {
	my ($self) = shift;
	$self->{groups}->append(@_);
	$self->reprocess_queue
		if $self->{dequeued};
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

	# accept singular or plural... we want the plural
	$type =~ s/^(field|group).*$/$1s/
		or croak("'$type' invalid: Must be field(s) or group(s)");

	push(@{ $self->{queue} ||= [] }, [$tr, $type, $names, \@args]);

	return $self;
}

=method reprocess_queue

Force the queue of transformation specifications
to be completely reprocessed.

This gets called automatically when groups are changed
after the queue was initially processed.

=cut

sub reprocess_queue {
	my ($self) = @_;
	return unless my $dequeued = delete $self->{dequeued};

	# reset the queue and the stacks so that it will all be rebuilt
	$self->{queue}  = [@$dequeued, @{ $self->{queue} || [] } ];
	$self->{fields} = {};
	# but don't actually rebuild it until necessary
}

=method stack

	$stack->stack($field);

Return the L<Data::Transform::Stackable> object for the given field name.

=cut

sub stack {
	my ($self, $name, $opts) = @_;
	$opts ||= {};

	$self->dequeue
		if $self->{queue};

	if( my $stack = $self->{fields}{$name} ){
		return $stack;
	}

	carp("No transformations specified for '$name'")
		if ($self->{warn_no_field}->is_always)
			|| ($self->{warn_no_field}->is_single && !$opts->{multi});

	return undef;
}

=method transform

	my $values = $stack->tramsform({key => 'value', ...});
	my $values = $stack->tramsform([qw(fields)], [qw(values)]);
	my $value  = $stack->transform('address', '123 Street Road');

Apply the stack of transformations to the supplied data.

If a sole hash ref is supplied
it will be looped over
and a hash ref of transformed data will be returned.
For example:

	# for use with DBI
	$sth->execute;
	while( my $hash = $sth->fetchrow_hashref() ){
		my $tr_hash = $stack->transform($hash);
	}

If two array refs are supplied,
the first should be a list of field names,
and the second the corresponding data.
For example:

	# for use with Text::CSV
	my $header = $csv->getline($io);
	while( my $array = $csv->getline($io) ){
		my $tr_array = $stack->transform($header, $array);
	}

If two arguments are given,
and the first is a string,
it should be the field name,
and the second argument the data.
The return value will be the data after it has been
passed through the stack of transformations.

	# simple data
	my $trimmed = $stack->transform('trim', '  lots of space   ');

=cut

sub transform {
	my ($self) = shift;

	$self->dequeue
		if $self->{queue};

	my $out;
	my $opts = {multi => 1};
	my $ref = ref $_[0];

	if( $ref eq 'HASH' ){
		my %in = %{$_[0]};
		$out = {};
		while( my ($key, $value) = each %in ){
			$out->{$key} = $self->_transform_one($key, $value, $opts);
		}
	}
	elsif( $ref eq 'ARRAY' ){
		my @fields = @{$_[0]};
		my @data   = @{$_[1]};
		$out = [];
		foreach my $i ( 0 .. $#fields ){
			CORE::push(@$out,
				$self->_transform_one($fields[$i], $data[$i], $opts));
		}
	}
	else {
		$out = $self->_transform_one($_[0], $_[1]);
	}

	return $out;
}
# TODO: alias to 'get'?  Is it too different?

sub _transform_one {
	my ($self, $field, $value, $opts) = @_;
	return $value
		unless my $stack = $self->stack($field, $opts);
	# Data::Transform::get expects and returns an arrayref
	return @{ $stack->get([$value]) }[0];
}

1;

=head1 SEE ALSO

=for :list
* L<Set::DynamicGroups>
