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

use Data::Transform::Named;

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

=method group

	$stack->group(groupname => [qw(fields)]);

Append fields to the specified group name.

=cut

sub group {
	my ($self) = shift;
	my %groups = ref $_[0] ? %{$_[0]} : @_;
	while( my ($group, $fields) = each %groups ){
		$fields = [$fields]
			unless ref $fields;
		push(@{ $self->{groups}->{$group} ||= [] }, @$fields);
	}
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
	my ($collection) = ("${type}s" =~ /(fields|groups)/)
		or croak("'$type' invalid; Must be field(s) or group(s)");

	$collection = $self->{$type};

	foreach my $name ( @$names ){
		($collection->{$name} ||=
			Data::Transform::Stackable->new())
		->push(
			$self->{named}->transform($tr, @args)
		);
	}
}

=method stack

	$stack->stack($field);

Return the L<Data::Transform::Stackable> object for the given field name.

=cut

sub stack {
	my ($self, $name) = @_;
	return $self->{fields}{$name};
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
the first should be a list of column names,
and the second the corresponding data.
For example:

	# for use with Text::CSV
	my $header = $csv->getline($io);
	while( my $array = $csv->getline() ){
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

	my $out;
	# Data::Transform::get expects and returns an arrayref
	my $get = sub { @{ $self->stack($_[0])->get([$_[1]]) }[0] };

	if( ref $_[0] eq 'HASH' ){
		my %in = %{$_[0]};
		$out = {};
		while( my ($key, $value) = each %in ){
			$out->{$key} = $get->($key, $value);
		}
	}
	elsif( ref $_[0] eq 'ARRAY' ){
		my @columns = @{$_[0]};
		my @data    = @{$_[1]};
		$out = [];
		foreach my $i ( 0 .. $#columns ){
			CORE::push(@$out, $get->($columns[$i], $data[$i]));
		}
	}
	else {
		$out = $get->($_[0], $_[1]);
	}

	return $out;
}
# TODO: alias to 'get'?  Is it too different?

1;
