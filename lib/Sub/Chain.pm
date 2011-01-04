package Sub::Chain;
# ABSTRACT: Chain subs together and call in succession

=head1 SYNOPSIS

	my $chain = Sub::Chain->new();

	$chain->push(\&wash, ['cold']);
	$chain->push(\&dry,  [{tumble => 'low'}]);
	$chain->push(\&fold);

	my @clean_laundry = $chain->call(@clothes);

	# if only it were that simple

=cut

use strict;
use warnings;
use Carp;

# enable object to be called like a coderef
use overload
	'&{}' => \&coderef,
	fallback => 1;

use Object::Enum 0.072 ();

our %Enums = (
	result => Object::Enum->new({unset => 0, default => 'replace',
		values => [qw(replace discard)]}),
	on_undef => Object::Enum->new({unset => 0, default => 'proceed',
		values => [qw(skip blank proceed)]}),
);

=method new

	my $chain = Sub::Chain->new();
	my $chain = Sub::Chain->new( option => $value );
	my $chain = Sub::Chain->new({option => $value});

Constructor.
Takes a hash or hashref of arguments.

Accepts values as described in L<OPTIONS|/OPTIONS>
that will be used as defaults
for any sub that doesn't override them.

=cut

sub new {
	my $class = shift;
	my %opts = ref $_[0] ? %{$_[0]} : @_;

	my $self = {
		chain => []
	};
	bless $self, $class;

	$self->_copy_enums(\%opts);

	return $self;
}

=method append

	$chain->append(\&sub, \@args, \%opts);

Append a sub to the chain.
The C<\@args> arrayref will be flattened and passed to the C<\&sub>
after any arguments to L</call>.

	sub sum { my $s = 0; $s += $_ for @_; $s; }

	$chain->append(\&sum, [3, 4]);

	$chain->call(1, 2);
	# returns 10
	# equivalent to: sum(1, 2, 3, 4)

If you don't want to send any additional arguments to the sub
an empty arrayref (C<[]>) can be used.

This method returns the object so that it can be chained for simplicity:

	$chain->append(\&sub, \@args)->append(\&sub2)->append(\&sub3, [], \%opts);

The C<\%opts> hashref can be any of the options described in L</OPTIONS>
to override the defaults on the object for this particular sub.

=cut

sub append {
	my ($self, $sub, $args, $opts) = @_;

	# TODO: normalize_spec (better than this):
	$args ||= [];
	$opts ||= {};
	$self->_copy_enums($opts, $opts);

	CORE::push(@{ $self->{chain} }, [$sub, $args, $opts]);
	# allow calls to be chained
	return $self;
}

=method call

	$chain->call(@args);

Calls each method in the chain
with the supplied (and any predetermined) arguments
according to any predefined options.

=cut

sub call {
	my ($self, @args) = @_;
	# cache function call
	my $wantarray = wantarray;

	my @chain = @{ $self->{chain} };
	foreach my $tr ( @chain ){
		my ($sub, $extra, $opts) = @$tr;
		my @all = (@args, @$extra);
		my @result;

		# TODO: instead of duplicating enum objects do %opts = (%$self, %$opts)
		if( @args && $opts->{on_undef} && !defined($args[0]) ){
			next if $opts->{on_undef}->is_skip;
			$args[0] = ''
				if $opts->{on_undef}->is_blank;
		}

		# call sub with same context as this
		if( !defined $wantarray ){
			$sub->(@all);
		}
		elsif( $wantarray ){
			@result    = $sub->(@all);
		}
		else {
			$result[0] = $sub->(@all);
		}
		@args = @result
			if $opts->{result}->is_replace;
	}

	# if 'result' isn't 'replace' what would be a good return value?
	# would they expect one?

	# return value appropriate for context
	if( !defined $wantarray ){
		return;
	}
	elsif( $wantarray ){
		return @args;
	}
	else {
		return $args[0];
	}
}

=method coderef

	my $sub = $chain->coderef;
	$sub->(@args);

Wrap C<< $self->call >> in a closure.
This is used to overload the function dereference operator
so you can pretend the instance is a coderef: C<< $chain->(@args) >>

=cut

sub coderef {
	my ($self) = @_;
	return sub { $self->call(@_); }
}

sub _copy_enums {
	my ($self, $from, $to) = @_;
	$to ||= $self;
	while( my ($name, $enum) = each %Enums ){
		$to->{$name} = ($self->{$name} || $enum)->clone(
			# use the string passed in
			exists $from->{$name} ? $from->{$name} :
				# clone from the default value saved on the instance
				$self->{$name} ? $self->{$name}->value : ()
		);
	};
}

=method push

Alias for L</append>.

=cut

*push = \&append;

1;

=head1 OPTIONS

These options can define how a sub should be handled.
Specified in the options hashref for L</append>
they apply to that particular sub.
Specified in the constructor they can set the default
for how to handle any sub that doesn't override the option.

=begin :list

* C<result>

What to do with the result;
Valid values are:

=begin :list

* C<replace> - replace the argument list with the return value of each sub

* C<discard> - discard the return value of each sub

=end :list

The arguments to L</call> are passed to each sub in the chain.
When C<replace> is specified the return value of one sub
is the argument list to the next.
This is useful, for instance, when chaining a number of
data cleaning or transformation functions together:

	sub add_uc { $_[0] . ' ' . uc $_[0]  }
	sub repeat { $_[0] x $_[1] }

	$chain->append(\&add_uc)->append(\&repeat, [2]);
	$chain->call('hi');

	# returns 'hi Hihi HI', similar to:

	my $s = 'hi';
	$s = add_uc($s);
	$s = repeat($s, 2);

When C<discard> is specified, the same arguments are sent to each sub.
This is useful when chaining subs that are called for their side effects
and you aren't interested in the return values.

	# assume database handle has RaiseError set
	$chain
		->append(\&log)
		->append(\&save_to_database)
		->append(\&email_to_user);

	# call in void context because we don't care about the return value
	$chain->call($object);

The default is C<replace> since that (arguably) makes this module more useful.

* C<on_undef>

What to do when a value is undefined;
Valid values are:

=begin :list

* C<proceed> - proceed as normal (as if it was defined)

* C<skip> - skip (don't call) the sub

* C<blank> - initialize the value to a blank string

=end :list

The default is C<proceed>.

=end :list
