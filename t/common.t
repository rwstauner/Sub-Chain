use strict;
use warnings;
use Test::More;

	# [ \@args, {str => exp} ]
my %tests = (
	exchange => [
		[ [{qw(hello goodbye)}], {hello => 'goodbye'} ],
		[ [{qw(B bee C cee)}, 'dee'], {A => 'dee'} ],
		[ [{qw(B bee C cee)}, 'dee'], {B => 'bee'} ],
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
);

plan tests => (map { keys %{$$_[1]} } map { @$_ } values(%tests)) + 2 + 4; # function tests + require + _all()

my $mod = 'Data::Transform::Named::Common';
require_ok($mod);
my $nmod = 'Data::Transform::Named';
require_ok($nmod);

my $all = $mod->_all;

# test the return of _all(), and the Named->add_common (which should be the same)
foreach my $set ( $all, $nmod->new->add_common->{named} ){
	ok((grep { ref $_ eq 'CODE' } values %$set) == keys(%$set), 'all coderefs');
	is_deeply([sort keys %tests], [sort keys %$set], 'all functions expected/tested');
}

while( my ($name, $tests) = each %tests ){
	foreach my $test ( @$tests ){
		my ($args, $values) = @$test;
		while( my ($in, $exp) = each %$values ){
			is($all->{$name}->($in, @$args), $exp, "$name: $in => $exp");
		}
	}
}
