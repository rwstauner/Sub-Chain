package Data::Transform::Named::Common;
# ABSTRACT: Common data transformations

=head1 SYNOPSIS

	# get a hashref of subs defined here:
	Data::Transform::Named::Common->_all();

These functions are designed for use by
L<Data::Transform::Named>.

=cut

use strict;
use warnings;

# TODO: skip

=method _all

Return a hashref of the functions of this module.
This is used in L<Data::Transform::Named/add_common>
to add all the utility functions from this package.

=cut

sub _all {
	my $class = @_ ? (ref($_[0]) || $_[0]) : __PACKAGE__;
	no strict 'refs';
	my (%ns, %subs) = %{"${class}::"};
	# lowercase-only names (not with leading underscore) that are subs
	my @keys = grep { *{"${class}::$_"}{CODE} }
		grep { /^[a-z][a-z_]+$/ } keys(%ns);
	@subs{@keys} = @ns{@keys};
	return \%subs;
}

=func exchange

	exchange($str, {Y => 'yes', N => 'no'}, 'maybe');

Exchange one value for another.
If the string matches the first item of a pair, return the second item.
A fallback value can be specified if 

=cut

sub exchange {
	my ($data, $exchanges, $fallback) = @_;
	return exists $exchanges->{$data}
		? $exchanges->{data}
		: $fallback;
}

=func gsub

	gsub($str, qr/pattern/, "replacement $1");

=cut

# considered String::Gsub but it failed to install
sub gsub {
	my ($data, $pattern, $replacement) = @_;
	#String::Gsub::Functions::gsub($data, $pattern, $replacement);
	$data =~
		s/$pattern/
			# store the match vars from the \$pattern
			my $matched = do {
				no strict 'refs';
				['', map { ($$_) || '' } ( 1 .. $#- )];
			};
			# substitute them into \$replacement
			(my $rep = $replacement) =~
				s!\$(?:\{(\d+)\}|(\d))!$matched->[($1 or $2)]!ge;
			$rep;/xge;
	return $data;
}

=func match

	match($str, qr/regexp/);
	match($str, qr/regexp/, "yes", "no");

Match string against pattern.
Returns true or false (perl's C<1> or C<''>).
Alternate True and False values can be supplied.

=cut

sub match {
	my ($data, $regexp) = (shift, shift);
	my ($true, $false)  = (@_ ? @_ : (1, ''));
	return ($data =~ /$regexp/ ? $true : $false);
}

# TODO; make this less arbitrary?

=func remove_non_printing

	remove_non_printing($str);

Remove control characters (C</[[:cntrl:]]/>)
and convert non-printing (C</[^[:print:]]/>)
characters to underscores.

=cut

sub remove_non_printing {
	my ($data) = @_;
	# remove control characters
	$data =~ s/(?!\s)[[:cntrl:]]//g;
	# replacea non-printing characters (not whitespace) with underscore
	$data =~ s/(?!\s)[^[:print:]]/_/g;
	return $data;
}


=func squeeze

	squeeze($str);

Squeeze all occurances of one or more whitespace characters
into a single space character (C<\x20>).

=cut

sub squeeze {
	my ($data) = @_;
	$data =~ s/\s+/ /g;
	return $data;
}

=func trim

	trim($str);

Trim leading and trailing whitespace.

=cut

sub trim {
	my ($data) = @_;
	$data =~ s/(^\s+|\s+$)//g;
	return $data;
}

1;
