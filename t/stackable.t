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

my $filter;
sub filter {
	my ($name, $sub) = @_;
	return ($name, sub { $filter .= "$name|"; &$sub(@_) });
}

$stack = $nmod->new->add(filter('no-op', sub { $_[0] }), filter('razzberry' => sub { ":-P $_[0]" }))->stackable;
isa_ok($stack, $mod);

my @fruit1 = qw(apple orange kiwi);
my @fruit2 = qw(banana grape);
my @fruits = (@fruit1, @fruit2);

$stack->group(fruit => \@fruit1);
is_deeply($stack->groups->groups('fruit')->{fruit}, \@fruit1, 'group');
$stack->group(fruit => \@fruit2);
is_deeply($stack->groups->groups('fruit')->{fruit}, \@fruits, 'group');

my $dts_mod = 'Data::Transform::Stackable';

eval { $stack->push('no-op', 'goober') };
like($@, qr/invalid/, 'error with invalid type');

$stack->push('no-op', field => [qw(tree)]);
isa_ok($stack->stack('tree'), $dts_mod);

$stack->{named}->add(filter('multi' => sub { $_[0] x $_[1] }));
is($stack->{named}{named}{multi}->('boo', 2), 'booboo', 'test func');
$filter = '';

my $APPLESTACK; # increment APPLESTACK for each transformation to 'apple' field; we'll test later
my $FRUITSTACK; # increment FRUITSTACK for each transformation to 'fruit' group; we'll test later

$stack->push('multi', field => 'apple', 2); ++$APPLESTACK;

$stack->push('no-op', groups => 'fruit'); ++$APPLESTACK; ++$FRUITSTACK;
isa_ok($stack->stack('apple'), $dts_mod);
is_deeply($stack->stack('orange'), $stack->stack('grape'), 'two stacks from one group the same');

# white box testing for the queue

my $razz = sub { map { [qw(razzberry fields), [ ref $_ ? @$_ : $_ ], []] } @_ };

is($stack->{queue}, undef, 'queue empty');
$stack->push('razzberry', field => 'tree');
is_deeply($stack->{queue}, [ $razz->('tree') ], 'queue has entry');
$stack->dequeue;
is($stack->{queue}, undef, 'queue empty');

my @fields = qw(apple orange grape); ++$APPLESTACK;
for (my $i = 0; $i < @fields; ++$i ){
	$stack->push('razzberry', field => $fields[$i]);
	is_deeply($stack->{queue}, [ $razz->(@fields[0 .. $i ]) ], "queue has ${\($i + 1)}");
}

$stack->dequeue;

$stack->push('razzberry', group => 'fruit'); ++$APPLESTACK; ++$FRUITSTACK;
# want to test the resultant stacks...
ok((grep { $_ } map { $stack->stack($_) } @fruits) == @fruits, 'stack foreach field in group');

push(@fruits, 'strawberry');
$stack->group(qw(fruit strawberry));
$stack->dequeue;
ok((grep { $_ } map { $stack->stack($_) } @fruits) == @fruits, 'stack foreach field in group');

ok(($stack->stack('apple')->filters) == $APPLESTACK, 'apple stack has expected filters');
is($stack->transform('apple', 'pear'), ':-P :-P pearpear', 'transformed');
is($filter, 'multi|no-op|razzberry|razzberry|', 'filter names');

$filter = '';
ok(($stack->stack('strawberry')->filters) == $FRUITSTACK, 'strawberry stack has expected filters w/o explicit push()');
is($stack->transform('strawberry', 'pear'), ':-P pear', 'transformed');
is($filter, 'no-op|razzberry|', 'filter names');

# transform() tested elsewhere

SKIP: {
	my $testwarn = 'Test::Warn';
	eval "use $testwarn; 1";
	skip "$testwarn required for testing warnings" if $@;

	$stack->push('no-op', field => 'blue');
	warning_is(sub { $stack->transform( 'blue',  'yellow' ) }, undef, 'no warning for specified field');
	warning_is(sub { $stack->transform( 'green', 'orange' ) }, q/No transformations specified for 'green'/, 'warn single');
	warning_is(sub { $stack->transform({'green', 'orange'}) }, undef, 'no warn multi');

	no strict 'refs';
	my %enums = %{"${mod}::Enums"};
	$stack->{warn_no_field} = $enums{warn_no_field}->clone('always');
	warning_is(sub { $stack->transform({'green', 'orange'}) }, q/No transformations specified for 'green'/, 'warn always');
	$stack->{warn_no_field} = $enums{warn_no_field}->clone('never');
	warning_is(sub { $stack->transform( 'green', 'orange' ) }, undef, 'warn never');
}

SKIP: {
	my $testex = 'Test::Exception';
	eval "use $testex; 1";
	skip "$testex required for testing exceptions" if $@;

	foreach my $wnf ( qw(always single never) ){
		my $stack;
		lives_ok(sub { $stack = $mod->new(warn_no_field => $wnf) }, 'expected to live');
		isa_ok($stack, $mod);
	}
	throws_ok(sub { $mod->new(warn_no_field => 'anything else') }, qr/cannot be set to/i, 'die with invalid value');
}

my @items = @{$stack->groups->items};
$stack->fields('peach');
is_deeply($stack->groups->items, ['peach', @items], 'fields added to dynamic-groups');

{
	# test example from POD:
	my $stack = $mod->new;

	$stack->group(some => {not => [qw(primary secondary)]});
	$stack->fields(qw(primary secondary this that));
	is_deeply($stack->groups->groups('some')->{some}, [qw(this that)], 'POD example of group exclusion');

	$stack->fields('another');
	is_deeply($stack->groups->groups('some')->{some}, [qw(this that another)], 'POD example of group exclusion');
}

done_testing;
