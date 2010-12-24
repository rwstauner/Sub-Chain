use strict;
use warnings;
use Test::More;

# Common functions tested elsewhere

my $mod = 'Data::Transform::Named';
require_ok($mod);
my $stack = $mod->new->add_common->stackable;
$stack->named->add('define' => sub { !defined $_[0] ? ' ~ ' : $_[0] });

$stack->push('trim', fields => [qw(name address)]);
$stack->push('squeeze', fields => 'name');
$stack->push('exchange', fields => 'emotion', {h => 'Happy'});

my $in = {
	name => "\t Mr.   Blarh  ",
	address => "\n123    Street\tRoad ",
	emotion => 'h',
};
my $exp = {
	name => 'Mr. Blarh',
	address => "123    Street\tRoad",
	emotion => 'Happy',
};
my @keys = keys %$in;

foreach my $field ( @keys ){
	is($stack->transform($field, $in->{$field}), $exp->{$field}, "single value ($field) transformed");
}

is_deeply($stack->transform($in), $exp, 'hash transformed');
is_deeply($stack->transform(\@keys, [@$in{@keys}]), [@$exp{@keys}], 'array transformed');

done_testing;
