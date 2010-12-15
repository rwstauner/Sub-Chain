use strict;
use warnings;
use Test::More;

my $mod = 'Data::Transform::Named::Stackable';
require_ok($mod);
my $stack = $mod->new();
isa_ok($stack, $mod);

my $nmod = 'Data::Transform::Named';
isa_ok($stack->{named}, $nmod);
is_deeply($stack->{named}, $nmod->new->add_common, 'Named initialized correctly');

$stack = $mod->new(named => $nmod->new);
isa_ok($stack->{named}, $nmod);
is_deeply($stack->{named}, $nmod->new, 'Named initialized correctly');

$stack = $nmod->new->add('no-op', sub { $_[0] })->stackable;
isa_ok($stack, $mod);

my @fruit1 = qw(apple orange kiwi);
my @fruit2 = qw(banana grape);
$stack->group(fruit => \@fruit1);
is_deeply($stack->{groups}{fruit}, \@fruit1, 'group');
$stack->group(fruit => \@fruit2);
is_deeply($stack->{groups}{fruit}, [@fruit1, @fruit2], 'group');

my $dts_mod = 'Data::Transform::Stackable';

eval { $stack->push('no-op', 'goober') };
like($@, qr/invalid/, 'error with invalid type');

$stack->push('no-op', field => [qw(tree)]);
isa_ok($stack->stack('tree'), $dts_mod);

$stack->push('no-op', groups => 'fruit');
isa_ok($stack->stack('apple'), $dts_mod);
is_deeply($stack->stack('orange'), $stack->stack('grape'), 'two stacks from one group the same');

# transform() tested elsewhere

done_testing;
