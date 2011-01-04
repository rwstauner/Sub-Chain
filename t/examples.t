use strict;
use warnings;
use Test::More;

my $mod = 'Sub::Chain';
require_ok($mod);

{
	# example from L<Sub::Chain/append>
	my $chain = $mod->new;
	sub sum { my $s = 0; $s += $_ for @_; $s; }
	$chain->append(\&sum, [3, 4]);
	is($chain->call(1, 2), 10, 'example from POD correct');
	is($chain->coderef->(1, 4), 12, 'coderef method');
	is($chain->(1, 3), 11, 'overload function dereference operator');

	# extra tests:
	is($chain->call(), 7, 'only predefined arguments');
	$chain = $mod->new->append(\&sum);
	is($chain->call(2, 1), 3, 'only sent arguments');
	is($chain->call(), 0, 'no arguments');
}

{
	# example from L<Sub::Chain/OPTIONS>
	my $chain = $mod->new;
	sub add_uc { $_[0] . ' ' . uc $_[0]  }
	sub repeat { $_[0] x $_[1] }
	my $s = 'hi';
	$s = add_uc($s);
	$s = repeat($s, 2);

	$chain->append(\&add_uc)->append(\&repeat, [2]);
	is($chain->call('hi'), $s, 'example of "replace" option from POD');

	$chain = $mod->new(result => 'discard');
	$chain->append(\&add_uc)->append(\&repeat, [2]);
	is($chain->call('hi'), 'hi', 'test "discard" option');
}

# TODO: test various contexts

done_testing;
