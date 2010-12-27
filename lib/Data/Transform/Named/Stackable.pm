package Data::Transform::Named::Stackable;
# ABSTRACT: Stack of data transformers to apply by name

=head1 SYNOPSIS

	my $stack = Data::Transform::Named::Stackable->new();

	$stack->push('trim', fields => [qw(name address)]);

	$stack->group(fruits => [qw(apple orange banana)]);
	$stack->push('trim', groups => 'fruits');

=cut

use strict;
use warnings;
use Carp qw(croak carp);

use Data::Transform::Named;
use Object::Enum 0.072 ();
use Set::DynamicGroups ();

our %Enums = (
	on_undef => Object::Enum->new({unset => 0, default => 'skip',
		values => [qw(skip blank proceed)]}),
	warn_no_field => Object::Enum->new({unset => 0, default => 'single',
		values => [qw(never single always)]}),
);

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

* I<on_undef>
What to do when a value is undefined.
Valid values are:

=begin :list

* C<proceed> - proceed as normal (as if it was defined)

* C<skip> - skip the transformation (don't call the sub)

* C<blank> - initialize the value to a blank string

=end :list

The default is C<skip> since must functions likely expect
some sort of value (like a string) to transform.

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
	};
	while( my ($name, $enum) = each %Enums ){
		$self->{$name} = $enum->clone(
			exists $opts{$name} ? delete $opts{$name} : ()
		);
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
		CORE::push(@$dequeued, $item);

		my ($tr, $opts) = @$item;

		my $fields = $opts->{fields} || [];
		# keep fields unique
		my %seen = map { $_ => 1 } @$fields;
		# append unique fields from groups (if there are any)
		if( my $groups = $opts->{groups} ){
			CORE::push(@$fields, grep { !$seen{$_}++ }
				map { @$_ } values %{ $self->{groups}->groups(@$groups) }
			);
		}

		# create a single instance of the sub
		# and copy its reference to the various stacks
		my $sub = $self->{named}->transformer($tr, @$opts{qw(args opts)});
		foreach my $field ( @$fields ){
			CORE::push(@{ $self->{fields}->{$field} ||= [] },
				[$sub, @$opts{qw(args opts)}]);
		}
	}
	# let 'queue' return false so we can do simple 'if queue' checks
	delete $self->{queue};
}

=method fields

	$stack->fields(@fields);

Append fields to the list of all known fields.
This tells the object which fields are available/expected
which can be useful for specifying groups based on exclusions.

For example:

	$stack->group(some => {not => [qw(primary secondary)]});
	$stack->fields(qw(primary secondary this that));
	# the 'some' group will now contain ['this', 'that']

	$stack->fields('another');
	# the 'some' group will now contain ['this', 'that', 'another']

This is a convenience method.
Arguments are passed to L<Set::DynamicGroups/append_items>.

=cut

sub fields {
	my ($self) = shift;
	$self->{groups}->append_items(@_);
	$self->reprocess_queue
		if $self->{dequeued};
	return $self;
}

=method group

	$stack->group(groupname => [qw(fields)]);

Append fields to the specified group name.

This is a convenience method.
Arguments are passed to L<Set::DynamicGroups/append>.

=cut

sub group {
	my ($self) = shift;
	croak("group() takes argument pairs.  Did you mean groups()?")
		if !@_;

	$self->{groups}->append(@_);
	$self->reprocess_queue
		if $self->{dequeued};
	return $self;
}

=method groups

Return the object's instance of L<Set::DynamicGroups>.

This can be useful if you need more advanced manipulation
of the groups than is available through the L</group> and L</fields> methods.

=cut

sub groups {
	my ($self) = shift;
	croak("groups() takes no arguments.  Did you mean group()?")
		if @_;

	return $self->{groups};
}

=method named

Returns the stack's instance of L<Data::Transform::Named>.

Useful if you want to add more named transformers.

=cut

sub named {
	$_[0]->{named};
}

sub _normalize_spec {
	my ($self, $opts) = @_;

	# Don't alter \%opts.  Limit %norm to desired keys.
	my %norm;
	my %aliases = (
		arguments => 'args',
		options   => 'opts',
		field     => 'fields',
		group     => 'groups',
	);
	while( my ($alias, $name) = each %aliases ){
		# store the alias in the actual key
		# overwrite with actual key if specified
		foreach my $key ( $alias, $name ){
			$norm{$name} = $opts->{$key}
				if exists  $opts->{$key};
		}
	}

	# allow a single string and convert it to an arrayref
	foreach my $type ( qw(fields groups) ){
		$norm{$type} = [$norm{$type}]
			if exists($norm{$type}) && !ref($norm{$type});
	}

	# simplify code later by initializing these to refs
	$norm{args} ||= [];
	$norm{opts} ||= {};
	$norm{opts}->{on_undef} = $self->{on_undef}->clone(
		exists $norm{opts}->{on_undef} ? $norm{opts}->{on_undef} : ());

	return \%norm;
}

=method push

	$stack->push($name, %options); # or \%options
	$stack->push('trim',  fields => [qw(fld1 fld2)]);
	$stack->push('trim',  field  => 'col3', opts => {on_undef => 'blank'});
	$stack->push('match', groups => 'group1', args => ['pattern']);

Push a named transformation onto the stack
for the specified fields and/or groups.

Possible options:

=for :list
* C<fields> (or C<field>)
An arrayref of field names to transform
* C<groups> (or C<group>)
An arrayref of group names to transform
* C<args> (or C<arguments>)
An arrayref of arguments to pass to the transformation function
* C<opts> (or C<options>)
A hashref of options for the transformer
(See L<Data::Transform::Named/transformer>)

If a single string is provided for C<fields> or C<groups>
it will be converted to an arrayref.

=cut

sub push {
	my ($self, $tr) = (shift, shift);
	my %opts = ref $_[0] ? %{$_[0]} : @_;

	CORE::push(@{ $self->{queue} ||= [] },
		[$tr, $self->_normalize_spec(\%opts)]);

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

Return the stack of transformations for the given field name.

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

sub _transform_one {
	my ($self, $field, $value, $opts) = @_;
	return $value
		unless my $stack = $self->stack($field, $opts);
	foreach my $tr ( @$stack ){
		my ($sub, $args, $opts) = @$tr;
		if( !defined($value) ){
			next if $opts->{on_undef}->is_skip;
			$value = ''
				if $opts->{on_undef}->is_blank;
		}
		$value = $sub->($value, @$args);
	}
	return $value;
}

1;

=head1 TODO

=for :list
* Finalizers to run in reverse order at the end of the stack

=head1 SEE ALSO

=for :list
* L<Set::DynamicGroups>
