use strict;
use warnings;
use Test::More;

my $mod = 'Data::Transform::Named';
require_ok($mod);

my $sub = sub { ":-P" };
my $named = $mod->new;
isa_ok($named, $mod);
$named = $mod->new(tongue => $sub);
isa_ok($named, $mod);
is_deeply($named->{named}, {tongue => $sub}, 'got named sub through new()');

sub one   { 1 }
sub two   { 2 }
sub three { 3 }

$named->add(one => \&one);
is_deeply($named->{named}, {tongue => $sub, one => \&one}, 'got named sub  through add()');
$named->add(two => \&two, three => \&three);
is_deeply($named->{named}, {tongue => $sub, one => \&one, two => \&two, three => \&three}, 'got named subs through add()');

# add_common() tested in t/common.t

my $stackmod = 'Data::Transform::Named::Stackable';
my $stack = $named->stackable;
isa_ok($stack, $stackmod);
is($stack->{named}, $named, 'Named object transfered');

foreach my $tr ( qw(one two three) ){
	my $map = $named->transform($tr);
	isa_ok($map, 'Data::Transform::Map');
	no strict 'refs';
	is(@{$map->get([0])}[0], &$tr, "sub $tr transfered");
}

done_testing;
