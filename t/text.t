#!/usr/local/bin/perl

use strict;
use warnings;

use Test::More tests => 17;

BEGIN {
    chdir 't' if (-d 't');;
    unshift @INC, qw(../lib ../blib/lib);
    use_ok('Acme::Util', qw(:text)); # 1
}

my $commify = '';

is (plural('cat', 0), 'cats', 'plural: 0 cats');
is (plural('cat', 1), 'cat', 'plural: 1 cat');
is (plural('cat', 2), 'cats', 'plural: 2 cats');
is (plural('ox', 0, 'en'), 'oxen', 'plural: 0 oxen');
is (plural('ox', 1, 'en'), 'ox', 'plural: 1 ox');
is (plural('ox', 2, 'en'), 'oxen', 'plural: 2 oxen');
is (capitalize("salem's lot: UPPER lower Ucfirst iPod nVidia CeBIT"),
    "Salem's Lot: UPPER Lower Ucfirst iPod nVidia CeBIT", 'capitalize');
is (capitalize('foo bar baz nVidia', 'bar'),
    'Foo bar Baz nVidia', 'capitalize: with exclusions');
is(ltrim(' trim  test '), 'trim  test ', 'ltrim');
is(rtrim(' trim  test '), ' trim  test', 'rtrim');
is(trim(' trim  test '), 'trim test', 'trim');
is(squash(' trim  test '), 'trim test', 'squash: superset of trim');
is(squash(<<MULTILINE), 'alpha beta gamma vlissides', 'squash: multi-line');
    alpha
    beta
    gamma
    vlissides
MULTILINE

$commify .= sprintf "    %-9u %11s%s", $_, commify($_), $/
    for (map { $_ x $_ } 1 .. 9);

is ($commify, <<EOS, 'commify');
    1                   1
    22                 22
    333               333
    4444            4,444
    55555          55,555
    666666        666,666
    7777777     7,777,777
    88888888   88,888,888
    999999999 999,999,999
EOS

my $fields = [ qw(foo bar baz) ];
my $avalues = [ [ qw(alpha beta gamma) ], [ qw(fee fie foe) ], [ qw(one two three) ] ];
my $hvalues = [
    { foo => 'alpha', bar => 'beta', baz => 'gamma' },
    { foo => 'fee', bar => 'fie', baz => 'foe' },
    { foo => 'one', bar => 'two', baz => 'three' }
];

my $csv_want = <<CSV;
"foo","bar","baz"
"alpha","beta","gamma"
"fee","fie","foe"
"one","two","three"
CSV

chomp $csv_want;

is (csv($fields, $avalues), $csv_want, 'csv ARRAY ref values');
is (csv($fields, $hvalues), $csv_want, 'csv HASH ref values');
