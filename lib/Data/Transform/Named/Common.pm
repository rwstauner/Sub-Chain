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
	my $coderef;
	while( my ($name, $sub) = each %ns ){
		# lowercase-only names (not with leading underscore) that are subs
		next unless $name =~ /^[a-z][a-z_]+$/;
		$subs{$name} = $coderef
			if $coderef = *{"${class}::${name}"}{CODE};
	}
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
		? $exchanges->{$data}
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

	match($str, $regexp, 'yes', 'no');
	match($str, $regexp);

Match string against pattern.
Optional arguments are values to return
upon success or failure, respectively.

If alternate true/false values are not supplied (only 2 arguments)
then the return value will be similar to the result of the m// operator:
On success, either the value of C<$1> if there was a group captured,
or a C<1> if there were no parentheses.
If the string does not match, perl's false value will be returned (C<''>).

	match('str',  't' ); # returns 1
	match('str', '(t)'); # returns 't'
	match('str', '(e)'); # returns ''

=cut

sub match {
	my ($data, $regexp, @truefalse) = @_;
	# $1 if it was captured, otherwise a true value (empty on failure)
	my @match = ($data =~ /$regexp/);

	# if true/false values were supplied
	return scalar @truefalse
		# return first on success, second on failure
		? ($truefalse[ @match ? 0 : 1 ])
		# else, return the value from m/// (but prefer '' to undef)
		: (@match ? $match[0] : '');
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

Squeeze all occurrences of one or more whitespace characters
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

=for stopwords gsub
