#!perl

use strict;
use warnings;
use Config;
use Test::More tests => 30;

BEGIN {
    chdir 't' if (-d 't');
    unshift @INC, qw(../lib ../blib/lib);
    use_ok('Acme::Util', qw(:math)); # 1
}

my $uvmax = ~0;

is (isnum(0), 1, 'isnum(0) == 1');			# 2
is (isnum('0.00'), 5, "isnum('0.00') == 5");		# 3
is (isnum(undef), 0, "isnum(undef) == 0");		# 4
is (isnum('A'), 0, "isnum('A') == 0");			# 5
is (isnum('A0'), 0, "isnum('A0') == 0");		# 6
is (isnum('0A'), 0, "isnum('0A') == 0");		# 7
is (isnum(\&ok), 0, "isnum(\\&ok) == 0");		# 8
is (isuv($uvmax), 1, "isuv(\$uvmax) == 1");		# 9
is (isuv(-1), 1, "isuv(-1) == 1");			# 10
is (isbig($uvmax + 1), 1, "isbig(\$uvmax + 1) == 1");	# 11
is (isbig($uvmax), 0, "isbig(\$uvmax) == 0");		# 12
is (isfloat(3.1415927), 1, "isfloat(3.1415927) == 1");	# 13
is (isfloat(3), 0, "isfloat(3) == 0");			# 14
is (isneg(-1), 1, "isneg(-1) == 1");			# 15
is (isneg(-3.1415927), 1, "isneg(-3.1415927) == 1");	# 16
is (isneg(1), 0, "isneg(1) == 0");			# 17
is (isneg(3.1415927), 0, "isneg(3.1415927) == 0");	# 18
is (isinf('Inf'), 1, "isinf('Inf') == 1");		# 19
is (isinf(3.1415927), 0, "isinf(3.1415927) == 0");	# 20
is (isinf(inf()), 1, "isinf(inf()) == 1");		# 21
is (isinf(infinity()), 1, "isinf(infinity()) == 1");	# 22
is (isint(-99), -1, "isint(-99) == -1");		# 23
is (isint(0), 1, "isint(0) == 1");			# 24
is (isint(3.1415927), 0, "isint(3.1415927) == 0");	# 25
is (isint(-3.1415927), 0, "isint(-3.1415927) == 0");	# 26
is (isint($uvmax), 1, "isint(\$uvmax) == 1");		# 27
is (isint(inf()), 0, "isint(inf()) == 0");		# 28

SKIP: {
    skip ('NaN is not supported by this platform', 2) unless($Config{d_isnan});
    is (isnan('NaN'), 1, "isnan('NaN') == 1");		# 29
    is (isnan(42), 0, "isnan(42) == 0");		# 30
}
