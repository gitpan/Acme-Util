#!perl

use strict;
use warnings;

use Test::More tests => 12;

BEGIN {
    chdir 't' if (-d 't');
    unshift @INC, qw(../lib ../blib/lib);
    use_ok('Acme::Util', qw(:io)); # 1
}

=pod
our %EXPORT_TAGS = (
    'io'        => [ qw(readfile writefile appendfile reader atime mtime ctime) ],
    'www'       => [ qw(html jscript jshtml xmlparse urlize redirect) ],
    'string'    => [ qw(plural trim ltrim rtrim quote capitalize commify) ],
    'misc'      => [ qw(any id respond clone) ],
    'math'      => [ qw(div isnum isuv isbig isfloat isneg isinf isnan inf infinity) ],
    'test'      => [ qw(weakref_is_defined) ]);
=cut

my $temp = "read.$$";

ok (writefile($temp, 'Alpha Beta'), 'writefile');
is (readfile($temp), 'Alpha Beta', 'readfile: writefile');
ok (writefile($temp, 'Alpha Beta', APPEND => 0), 'writefile: APPEND => 0');
is (readfile($temp), 'Alpha Beta', 'readfile: APPEND => 0');
ok (writefile($temp, ' Gamma', APPEND => 1), 'writefile: APPEND => 1');
is (readfile($temp), 'Alpha Beta Gamma', 'readfile: APPEND => 1');
ok (appendfile($temp, ' Vlissides'), 'appendfile');
is (readfile($temp), 'Alpha Beta Gamma Vlissides', 'readfile: appendfile');

is (atime($temp), (stat $temp)[8], 'atime');
is (mtime($temp), (stat $temp)[9], 'mtime');
is (ctime($temp), (stat $temp)[10], 'ctime');

END { 
    while (-f $temp) {
	unlink $temp or die "can't unlink temporary file '$temp': $!"
    }
}

=pod
my $reader = reader ($temp, DELIM => ' ');
while (&$reader) {
    is ($_, 'Aplha', 'reader: word 1');
    is ($_, 'Beta', 'reader: word 2');
    is ($_, 'Gamma', 'reader: word 3');
    is ($_, 'Delta', 'reader: word 4');
=cut
