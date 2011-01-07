use strict;
use warnings;
use Test::More;

my $mod = 'Sub::Chain::Named';
require_ok($mod);

my $sub = sub { ":-P" };
my $named = $mod->new;
isa_ok($named, $mod);
$named = $mod->new(subs => {tongue => $sub});
isa_ok($named, $mod);
is_deeply($named->{named}, {tongue => $sub}, 'got named sub through new()');

sub one   { 1 }
sub two   { 2 }
sub three { 3 }

$named->name_subs(one => \&one);
is_deeply($named->{named}, {tongue => $sub, one => \&one}, 'got named sub through name_subs()');
$named->name_subs(two => \&two, three => \&three);
is_deeply($named->{named}, {tongue => $sub, one => \&one, two => \&two, three => \&three}, 'got named subs through name_subs()');

$named->append('tongue');
is($named->(4), ':-P', 'got expected (last) value');
$named->append('one');
is($named->(4), '1', 'got expected (last) value');
$named->append('three');
is($named->(4), '3', 'got expected (last) value');

$named->name_subs({times2 => sub { $_[0] * 2 }});
is($named->call(8), 3, 'defined sub not added to stack');
$named->append('times2');
is($named->call(8), 6, 'chained values');

done_testing;
