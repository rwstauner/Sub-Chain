use strict;
use warnings;
use Test::More;

# Common functions tested elsewhere

my $mod = 'Data::Transform::Named';
require_ok($mod);
my $stack = $mod->new->add_common->stackable;
$stack->named->add('define' => sub { !defined $_[0] ? ' ~ ' : $_[0] });
$stack->named->add('no_undefs' => sub { die "I said no!" if !defined $_[0]; });

$stack->push('trim', fields => [qw(name address)]);
$stack->push('squeeze', fields => 'name');
$stack->push('exchange', fields => 'emotion', args => [{h => 'Happy'}]);
$stack->push('define', fields => 'silly', opts => {on_undef => 'proceed'});
$stack->push('no_undefs', fields => 'serious', opts => {on_undef => 'skip'});

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
	is($stack->transform($field, $in->{$field}), $exp->{$field}, "single value ($field) transformed");
}

is_deeply($stack->transform($in), $exp, 'hash transformed');
is_deeply($stack->transform(\@keys, [@$in{@keys}]), [@$exp{@keys}], 'array transformed');

done_testing;
