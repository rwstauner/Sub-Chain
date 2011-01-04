use strict;
use warnings;
use Test::More;

my $mod = 'Sub::Chain::Group';
require_ok($mod);
my $stack = $mod->new(
	chain_class => 'Sub::Chain::Named',
	chain_args  => {subs => {
		'define' => sub { !defined $_[0] ? ' ~ ' : $_[0] },
		'no_undefs' => sub { die "I said no!" if !defined $_[0]; },
	}},
);

$stack->append('trim', fields => [qw(name address)]);
$stack->append('squeeze', fields => 'name');
$stack->append('exchange', fields => 'emotion', args => [{h => 'Happy'}]);
$stack->append('define', fields => 'silly', opts => {on_undef => 'proceed'});
$stack->append('no_undefs', fields => 'serious', opts => {on_undef => 'skip'});

my $in = {
	name => "\t Mr.   Blarh  ",
	address => "\n123    Street\tRoad ",
	emotion => 'h',
	silly => undef,
	serious => undef,
};
my $exp = {
	name => 'Mr. Blarh',
	address => "123    Street\tRoad",
	emotion => 'Happy',
	silly => ' ~ ',
	serious => undef,
};
my @keys = keys %$in;

foreach my $field ( @keys ){
	is($stack->call($field, $in->{$field}), $exp->{$field}, "single value ($field) transformed");
}

is_deeply($stack->call($in), $exp, 'hash transformed');
is_deeply($stack->call(\@keys, [@$in{@keys}]), [@$exp{@keys}], 'array transformed');

done_testing;
