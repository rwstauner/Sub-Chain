use strict;
use warnings;
use Test::More;

	# [ \@args, {str => exp} ]
my %tests = (
	exchange => [
		[ [{qw(hello goodbye)}], {hello => 'goodbye'} ],
		[ [{qw(B bee C cee)}, 'dee'], {A => 'dee'} ],
		[ [{qw(B bee C cee)}, 'dee'], {B => 'bee'} ],
		[ [{qw(B bee C cee)}, undef], {A => undef} ],
		[ [{qw(B bee C cee)}], {A => 'A'} ],
	],
	gsub => [
		[ [q/^h(e)l(l)(o)(!?)$/, '$1${2}$3$4'], {'hello!' => 'elo!', hello => 'elo'}], 
		[ [q/^[Rr]e?d$/, 'Green'], {qw(Rd Green red Green)}], 
		[ [q/^\d{0,3}$/, ''],     {'1234' => '1234', '123' => '', '12' => '', '1' => ''}], 
		[ [q/([a-z])oo/, '${1}00'], {goober => 'g00ber', 'floo goo noo' => 'fl00 g00 n00'}], 
		[ [q/what/, 'how'], {'what in the?' => 'how in the?'}], 
		[ [q/0/, ''], {0 => '', 1 => 1}], 
		[ [q/(hello)/, '$1 there, you'], {goodbye => 'goodbye', 'hello' => 'hello there, you'}], 
		[ [q/^0$/, '0-0-0 0:0:0'], {1 => 1, 0 => '0-0-0 0:0:0'}], 
		[ [q/(\d{4})(\d{2})(\d{2})/, '$1/$2/$3 00:00:00'], {20060222 => '2006/02/22 00:00:00', '' => ''}], 
	],
	match => [
		[ [q/y/              ], {Y =>   '', y => 1,       n => '',   aye => 1,     arr => ''  }],
		[ [q/y/,   qw(yes no)], {Y => 'no', y => 'yes',   n => 'no', aye => 'yes', arr => 'no'}],

		[ [q/(y)/,           ], {Y =>   '', y => 'y',     n => '',   aye => 'y',   arr => ''  }],
		[ [q/(y)/, qw(yes no)], {Y => 'no', y => 'yes',   n => 'no', aye => 'yes', arr => 'no'}],

		[ [q/^(\d{3})$/,     ], {Y =>   '', 123 => '123', n => '',    12 => '',   4321 => ''  }],
		[ [q/^(\d{3})$/, 1, 0], {Y => 0   , 123 => 1,     n =>  0,    12 => 0,    4321 => 0   }],
	],
	remove_non_printing => [
		[ [], {"\0hello" => 'hello', "\x13a\x11b\x1" => 'ab'}]
	],
	squeeze => [
		[ [], {'  arr  ' => ' arr ', "\ttab" => ' tab', "t\t\tab" => "t ab", "t\tab" => "t ab", "t2\t " => 't2 '}]
	],
	trim => [
		[ [], {'  arr  ' => 'arr', "\ttab" => 'tab', "t\tab" => "t\tab", "t2\t " => 't2'}]
	],
	'lc' => [
		[ [], {'lc' => 'lc', 'Lc' => 'lc', 'LC' => 'lc'}]
	],
	'lcfirst' => [
		[ [], {'lc' => 'lc', 'Lc' => 'lc', 'LC' => 'lC'}]
	],
	'uc' => [
		[ [], {'uc' => 'UC', 'Uc' => 'UC', 'UC' => 'UC'}]
	],
	'ucfirst' => [
		[ [], {'uc' => 'Uc', 'Uc' => 'Uc', 'UC' => 'UC'}]
	],
);
foreach my $args ( values %tests ){
	foreach my $arg ( @$args ){
		$arg->[1] = [map { $_ => $arg->[1]{$_} } keys %{$arg->[1]}]
			if ref $arg->[1] eq 'HASH';
	}
}

my $mod = 'Data::Transform::Named::Common';
my $nmod = 'Data::Transform::Named';

my @test_all = (
	sub { ($mod->_all, [keys %tests]) },
	sub { ($nmod->new->add_common->{named}, [keys %tests]) },
);
foreach my $list ( [qw(squeeze trim)], [qw(lc uc lcfirst ucfirst)], [qw(match)] ){
	push(@test_all, sub { ($mod->_all(@$list), [@$list]) });
}

sub sum { my $s = 0; $s += $_ for @_; $s; }
plan tests => sum(map { @{$$_[1]}/2 } map { @$_ } values(%tests)) + 2 + (2 * @test_all); # function tests + require + _all()

require_ok($mod);
require_ok($nmod);

# test the return of _all(), and the Named->add_common (which should be the same)
foreach my $sub ( @test_all ){
	my ($set, $exp) = $sub->();
	ok((grep { ref $_ eq 'CODE' } values %$set) == keys(%$set), 'all coderefs');
	is_deeply([sort @$exp], [sort keys %$set], 'all functions expected/tested');
}

my $all = $mod->_all;

while( my ($name, $tests) = each %tests ){
	foreach my $test ( @$tests ){
		my ($args, $values) = @$test;
		for( my $i = 0; $i < @$values; $i += 2 ){
			my ($in, $exp) = @$values[$i, $i + 1];
			is($all->{$name}->($in, @$args), $exp,
				sprintf("%s: %s => %s",
					map { defined $_ ? $_ : '~' } $name, $in, $exp));
		}
	}
}
