use strict;
use warnings;

use Data::Dumper;
use Devel::Peek;

package main;

sub debug($) {
    my $sv = shift;
    $sv = \$sv unless (ref $sv);
    Dump($sv);
    print STDERR Dumper($sv), $/;
}

1;
