#!perl -w

use strict;

use Test::More tests => 31;

# use Data::Dumper; $Data::Dumper::Terse = $Data::Dumper::Indent = 1;

# TODO: id test: make less lame: stop using $$
# TODO: check that void invocation prints its argument
# TODO: much more extensive any() tests

BEGIN {
    chdir 't' if (-d 't');;
    unshift @INC, qw(../lib ../blib/lib);
    use_ok('Acme::Util', qw(:misc)); # 1
}

my ($scalar1, $scalar2) = ('alpha', 'beta');
swap($scalar1, $scalar2);
is ($scalar1, 'beta', 'scalar1 swapped with scalar2');
is ($scalar2, 'alpha', 'scalar2 swapped with scalar1');

my ($arrayref1, $arrayref2) = ([], []);
($scalar1, $scalar2) = ("$arrayref1", "$arrayref2");
swap($arrayref1, $arrayref2);
is ($scalar1, $arrayref2, 'arrayref1 swapped with arrayref2');
is ($scalar2, $arrayref1, 'arrayref2 swapped with arrayref1');

my ($hashref1, $hashref2) = ({}, {});
($scalar1, $scalar2) = ("$hashref1", "$hashref2");
swap($hashref1, $hashref2);
is ($scalar1, $hashref2, 'hashref1 swapped with hashref2');
is ($scalar2, $hashref1, 'hashref2 swapped with hashref1');

my ($coderef1, $coderef2) = (sub { 1 }, sub { 2 });
($scalar1, $scalar2) = ("$coderef1", "$coderef2");
swap($coderef1, $coderef2);
is ($scalar1, $coderef2, 'coderef1 swapped with coderef2');
is ($scalar2, $coderef1, 'coderef2 swapped with coderef1');

# don't use an ARRAY ref: that makes -1 valid
my %seen = ();

# not sure how to reliably test a nondeterministic algorithm reliably
# unless srand() and rand() are the same on every perl ever

while ((scalar (keys %seen)) < 2) {
    my $any = any();
    $seen{$any} = 1;
}

ok (exists $seen{0}, 'any() returns 0');
ok (exists $seen{1}, 'any() returns 1');

# NOTE: clone() is checked in a separate file

is(scalarref (\""), 1, 'scalarref \\"" == 1');
is(scalarref (Scalarref::Test->new()), 1, 'scalarref Scalarref::Test->new() == 1');
isnt(scalarref (sub {}), 1, 'scalarref sub {} != 1');
isnt(scalarref ([]), 1, 'scalarref [] != 1');
isnt(scalarref ({}), 1, 'scalarref {} != 1');

is(arrayref ([]), 1, 'arrayref [] == 1');
is(arrayref (Arrayref::Test->new()), 1, 'arrayref Arrayref::Test->new() == 1');
isnt(arrayref ({}), 1, 'arrayref {} != 0');
isnt(arrayref (sub {}), 1, 'arrayref sub {} != 0');
isnt(arrayref (\""), 1, 'arrayref \\"" != 0');

is(hashref ({}), 1, 'hashref {} == 1');
is(hashref (Hashref::Test->new()), 1, 'hashref Scalarref::Test->new() == 1');
isnt(hashref ([]), 1, 'hashref [] != 0');
isnt(hashref (sub {}), 1, 'hashref sub {} != 0');
isnt(hashref (\""), 1, 'hashref \\"" != 0');
	
is(coderef (sub {}), 1, 'coderef sub {} == 1');
is(coderef (Coderef::Test->new()), 1, 'coderef Coderef::Test->new() == 1');
isnt(coderef ([]), 1, 'coderef [] != 0');
isnt(coderef ({}), 1, 'coderef {} != 0');
isnt(coderef (\""), 1, 'coderef \\"" != 0');

package Scalarref::Test;

use strict;

sub new {
    my $class = shift;
    my $self = "";
    bless \$self, ref $class || $class;
}

1;

package Arrayref::Test;

use strict;

sub new {
    my $class = shift;
    bless [], ref $class || $class;
}

1;

package Hashref::Test;

use strict;

sub new {
    my $class = shift;
    bless {}, ref $class || $class;
}

1;

package Coderef::Test;

use strict;

sub new {
    my $class = shift;
    bless sub {}, ref $class || $class;
}

1;
