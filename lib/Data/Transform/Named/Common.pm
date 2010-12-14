package Data::Transform::Named::Common;
# ABSTRACT: Common data transformations

=head1 SYNOPSIS

=cut

use strict;
use warnings;

# TODO: skip

=func date

Convert string to a date using provided format (default).

=cut

use DateTime ();

sub date {
	my ($data, $format, $parser) = @_;
	die("interface not defined!");
	$format ||= '%Y-%m-%d %H:%M:%S';
	#$parser = DateTime::Format::Strptime->new(pattern => $parser)
		#unless ref $parser;
	return $parser->parse_datetime($data)->strftime($format);
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

See L<String::Gsub::Functions/gsub>.

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
