package Sub::Chain::Group;
# ABSTRACT: Group chains of subs by field name

=head1 SYNOPSIS

	my $chain = Sub::Chain::Group->new();
	$chain->append(\&trim, fields => [qw(name address)]);
	# append other subs to this or other fields as desired...
	$trimmed = $chain->call(address => ' 123 Street Rd. ');

	# or, using a Sub::Chain subclass:

	my $chain = Sub::Chain::Group->new(
		chain_class => 'Sub::Chain::Named',
		chain_args  => {subs => {uc => sub { uc $_[0] } }}
	);
	$stack->group(fruits => [qw(apple orange banana)]);
	$stack->append('uc', groups => 'fruits');

	$uc_fruit = $chain->call({apple => 'green', orange => 'dirty'});
	# returns a hashref: {apple => 'GREEN', orange => 'DIRTY'}

=cut

use strict;
use warnings;
use Carp qw(croak carp);

# this seems a little dirty, but it's not appropriate to put it in Sub::Chain
use Sub::Chain;
push(@Sub::Chain::CARP_NOT, __PACKAGE__);

use Object::Enum 0.072 ();
use Set::DynamicGroups ();
use Sub::Chain ();

our %Enums = (
	warn_no_field => Object::Enum->new({unset => 0, default => 'single',
		values => [qw(never single always)]}),
);

=method new

	my $chain = Sub::Chain::Group->new(%opts);

	my $chain = Sub::Chain::Group->new(
		chain_class => 'Sub::Chain::Group',
		chain_args  => {subs => {happy => sub { ":-P" } } },
	);

Constructor;  Takes a hash or hashref of options.

Possible options:

=begin :list

* C<chain_class>
The L<Sub::Chain> class that will be instantiated for each field;
You can set this to L<Sub::Chain::Named> or another subclass.

* C<chain_args>
A hashref of arguments that will be sent to the
constructor of the C<chain_class> module.
Here you can set alternate default values (see L<Sub::Chain/OPTIONS>)
or, for example, include the C<subs> parameter
if you're using L<Sub::Chain::Named>.

* C<warn_no_field>
Whether or not to emit a warning if asked to call a sub chain on a field
but no subs were specified for that field
(specifically when L</chain> is called and no chain exists).
Valid values are:

=begin :list

* C<never> - never warn

* C<always> - always warn

=item *

C<single> - warn when called for a single field
(but not when L</call> is used with a hashref or arrayref).

=end :list

The default is C<single>.

=end :list

=cut

sub new {
	my $class = shift;
	my %opts = ref $_[0] ? %{$_[0]} : @_;

	my $self = {
		chain_class => delete $opts{chain_class} || 'Sub::Chain',
		chain_args  => delete $opts{chain_args}  || {},
		fields => {},
		groups => Set::DynamicGroups->new(),
		queue  => [],
	};
	while( my ($name, $enum) = each %Enums ){
		$self->{$name} = $enum->clone(
			exists $opts{$name} ? delete $opts{$name} : ()
		);
	};
	# remove any other characters
	$self->{chain_class} =~ s/[^:a-zA-Z0-9_]+//g;
	eval "require $self->{chain_class}";

	# TODO: warn about remaining unused options?

	bless $self, $class;
}

=method dequeue

Process the queue of group and field specifications.

Queuing allows you to specify subs
for a group before you specify what fields belong in that group.

This method is called when another method needs something
from the chain and there are still specifications in the queue
(like L</chain> and L</call>, for instance).

=cut

sub dequeue {
	my ($self) = @_;

	return unless my $queue = $self->{queue};
	my $dequeued = ($self->{dequeued} ||= []);

	# shift items off the queue until they've all been processed
	while( my $item = shift @$queue ){
		# save this item in case we need to reprocess the whole queue later
		CORE::push(@$dequeued, $item);

		my ($sub, $opts) = @$item;

		my $fields = $opts->{fields} || [];
		# keep fields unique
		my %seen = map { $_ => 1 } @$fields;
		# add unique fields from groups (if there are any)
		if( my $groups = $opts->{groups} ){
			CORE::push(@$fields, grep { !$seen{$_}++ }
				map { @$_ } values %{ $self->{groups}->groups(@$groups) }
			);
		}

		# create a single instance of the sub
		# and copy its reference to the various stacks
		foreach my $field ( @$fields ){
			($self->{fields}->{$field} ||= $self->new_sub_chain())
				->append($sub, @$opts{qw(args opts)});
		}
	}
	# let 'queue' return false so we can do simple 'if queue' checks
	delete $self->{queue};

	# what would be a good return value?
	return;
}

=method fields

	$chain->fields(@fields);

Add fields to the list of all known fields.
This tells the object which fields are available/expected
which can be useful for specifying groups based on exclusions.

For example:

	$chain->group(some => {not => [qw(primary secondary)]});
	$chain->fields(qw(primary secondary this that));
	# the 'some' group will now contain ['this', 'that']

	$chain->fields('another');
	# the 'some' group will now contain ['this', 'that', 'another']

This is a convenience method.
Arguments are passed to L<Set::DynamicGroups/add_items>.

=cut

sub fields {
	my ($self) = shift;
	$self->{groups}->add_items(@_);
	$self->reprocess_queue
		if $self->{dequeued};
	return $self;
}

=method group

	$chain->group(groupname => [qw(fields)]);

Add fields to the specified group name.

This is a convenience method.
Arguments are passed to L<Set::DynamicGroups/add>.

=cut

sub group {
	my ($self) = shift;
	croak("group() takes argument pairs.  Did you mean groups()?")
		if !@_;

	$self->{groups}->add(@_);
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

=method new_sub_chain

This method is used internally to instantiate a new L<Sub::Chain>
using the C<chain_class> and C<chain_args> options.

=cut

sub new_sub_chain {
	my ($self) = @_;
	return $self->{chain_class}->new($self->{chain_args});
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

	return \%norm;
}

=method append

	$chain->append($sub, %options); # or \%options
	$chain->append(\&trim,  fields => [qw(fld1 fld2)]);
	$chain->append(\&trim,  field  => 'col3', opts => {on_undef => 'blank'});
	# or, if using Sub::Chain::Named
	$chain->append('match', groups => 'group1', args => ['pattern']);

Append a sub onto the chain
for the specified fields and/or groups.

Possible options:

=for :list
* C<fields> (or C<field>)
An arrayref of field names
* C<groups> (or C<group>)
An arrayref of group names
* C<args> (or C<arguments>)
An arrayref of arguments to pass to the sub
(see L<Sub::Chain/append>)
* C<opts> (or C<options>)
A hashref of options for the sub
(see L<Sub::Chain/OPTIONS>)

If a single string is provided for C<fields> or C<groups>
it will be converted to an arrayref.

=cut

sub append {
	my ($self, $sub) = (shift, shift);
	my %opts = ref $_[0] ? %{$_[0]} : @_;

	CORE::push(@{ $self->{queue} ||= [] },
		[$sub, $self->_normalize_spec(\%opts)]);

	return $self;
}

=method reprocess_queue

Force the queue of chain specifications
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

=method chain

	$chain->chain($field);

Return the sub chain for the given field name.

=cut

sub chain {
	my ($self, $name, $opts) = @_;
	$opts ||= {};

	$self->dequeue
		if $self->{queue};

	if( my $chain = $self->{fields}{$name} ){
		return $chain;
	}

	carp("No subs chained for '$name'")
		if ($self->{warn_no_field}->is_always)
			|| ($self->{warn_no_field}->is_single && !$opts->{multi});

	return undef;
}

=method call

	my $values = $chain->call({key => 'value', ...});
	my $values = $chain->call([qw(fields)], [qw(values)]);
	my $value  = $chain->call('address', '123 Street Road');

Call the sub chain on the supplied data.

If a sole hash ref is supplied
it will be looped over
and a hash ref of result data will be returned.
For example:

	# for use with DBI
	$sth->execute;
	while( my $hash = $sth->fetchrow_hashref() ){
		my $new_hash = $chain->call($hash);
	}

If two array refs are supplied,
the first should be a list of field names,
and the second the corresponding data.
For example:

	# for use with Text::CSV
	my $header = $csv->getline($io);
	while( my $array = $csv->getline($io) ){
		my $new_array = $chain->call($header, $array);
	}

If two arguments are given,
and the first is a string,
it should be the field name,
and the second argument the data.
The return value will be the data after it has been
passed through the chain.

	# simple data
	my $trimmed = $chain->call('spaced', '  lots of space   ');

=cut

sub call {
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
			$out->{$key} = $self->_call_one($key, $value, $opts);
		}
	}
	elsif( $ref eq 'ARRAY' ){
		my @fields = @{$_[0]};
		my @data   = @{$_[1]};
		$out = [];
		foreach my $i ( 0 .. $#fields ){
			CORE::push(@$out,
				$self->_call_one($fields[$i], $data[$i], $opts));
		}
	}
	else {
		$out = $self->_call_one($_[0], $_[1]);
	}

	return $out;
}

sub _call_one {
	my ($self, $field, $value, $opts) = @_;
	return $value
		unless my $chain = $self->chain($field, $opts);
	return $chain->call($value);
}

1;

=head1 DESCRIPTION

This module provides an interface for managing multiple
L<Sub::Chain> instances for a group of fields.
It is mostly useful for applying a chain of subs
to a set of data (like a hash or array (like a database record)).
In addition to calling different L<Sub::Chain>s on specified fields
It uses L<Set::DynamicGroups> to allow you to build sub chains
for dynamic groups of fields.

=head1 SEE ALSO

=for :list
* L<Sub::Chain>
* L<Sub::Chain::Named>
* L<Set::DynamicGroups>
