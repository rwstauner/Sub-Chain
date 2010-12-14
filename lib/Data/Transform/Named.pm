package Data::Transform::Named;
# ABSTRACT: Simple, named interface to Data::Transform

=head1 SYNOPSIS

	Data::Transform::Named->new(arr => sub { "arr $_[0]" })

=cut

use strict;
use warnings;

sub new {
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my %subs = ref $_[0] ? %{$_[0]} : @_;
	$self->{named} = \%subs;

	return $self;
}

sub add {
	my ($self) = shift;
	my %subs = ref $_[0] ? %{$_[0]} : @_;

	# TODO: warn if already exists?
	@{ $self->{named} }{keys %subs} = values %subs;

	# chainable
	return $self;
}

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
