package Acme::Util;

use 5.008;
use strict;
use warnings;
use Errno;
use Carp qw(carp confess croak);
use POSIX qw(floor);
use Fcntl ':flock'; # LOCK_SH, LOCK_EX, LOCK_UN
use Scope::Guard; # (for reader)

require Exporter;
require DynaLoader;
use AutoLoader 'AUTOLOAD';

our @ISA = qw(Exporter DynaLoader);

our %EXPORT_TAGS = (
'io'	=> [ qw(appendfile atime ctime mtime reader readfile writefile) ],
'www'	=> [ qw(html js text urlize xml xmlparse) ],
'text'	=> [ qw(capitalize commify csv ltrim plural rtrim squash trim) ], 
'misc'	=> [ qw(any arrayref clone coderef find hashref id respond scalarref swap) ],
'math'	=> [ qw(div inf infinity isbig isfloat isinf isint isnan isneg isnum isuv) ],
'test'	=> [ qw(backref_magic_is_defined) ]
);

our @EXPORT_OK = ( map { @$_ } values %EXPORT_TAGS );

our $VERSION = '0.11';

bootstrap Acme::Util $VERSION;

1;

__END__

=head1 NAME

Acme::Util - Frequently Hacked Functions

=head1 DESCRIPTION

A cookbook of tasty functions for the terminally lazy,
impatient and hubristic

=head1 TAGS

Rather than listing a group of functions by name,
related subs can be imported using the tag syntax:

use Acme::Util qw(:tag);

The following tags have been defined:

:io

    appendfile, atime, ctime, mtime, reader, readfile, writefile

:www

    html, js, text, xml, xmlparse

:text
    
    capitalize, commify, csv, ltrim, plural, rtrim, trim

:misc

    any, apply, arrayref, coderef, find, hashref, scalarref, clone, id, respond, swap

:math

    div, inf, infinity, isbig, isfloat, isinf, isnan, isneg, isnum, isuv

=head1 FUNCTIONS

=head2 any

=head3 usage

    # return 0 or 1
    my $flip = any();

    # return a random element of the ARRAY or a random HASH key
    my $el = any($hash_or_array_ref);

    # return a randomly selected list of ARRAY elements / HASH keys
    my @els = any($hash_or_array_ref, $number_of_items_to_pick);

    # as above, but return the elements as an ARRAY ref (if
    # $number_of_items_to_pick is greater than 1)
    my $els = any($hash_or_array_ref, $number_of_items_to_pick);

    # allow the same element to be picked multiple times
    my @els = any($hash_or_array_ref, $number_of_items_to_pick,
	$with_replacement);
    my $els = any($hash_or_array_ref, $number_of_items_to_pick,
	$with_replacement);

    # return a random number between 0 and $integer_max inclusive
    my $int = any($integer_max);

    # return a random number between $integer_min and $integer_max
    # inclusive
    my $int = any($integer_min, $integer_max);

=head3 description

Returns a randomly chosen member of the referenced ARRAY, or a
random key from the referenced HASH.

If the second argument is supplied, that number of items is chosen
and returned as a list - defaults to 1.

If the third argument is supplied, items can be repeatedly chosen -
defaults to 0 (false).

If the first argument is an integer x, an integer between 0 and x
(inclusive) is returned.

If no argument is supplied, 0 or 1 is returned randomly.

If the first and second arguments are integers x and y, then an
integer between x and y (inclusive) is returned.

    any($ref, ...) does not modify the original HASH/ARRAY.

    any($ref, $reflength) returns a shuffled list e.g.

    # perform a non-destructive shuffle of the elements of $array
    my @shuffled = any($array, $#$array + 1)

When supplied with a HASH or ARRAY ref, and a second argument
(specifying the number of items to pick) greater than 1, the
selected values are returned as a list in list context and an
ARRAY ref in scalar context.

=cut

sub any(;$$$) {
    my $ref = shift || 1;

    unless (ref $ref) {
        my $end = shift;
        if ($end && ($end > $ref)) {
            # pick a random number between $start and $end inclusive
            my $span = ($end - $ref) + 1;
            return int(rand($span)) + $ref;
        } else { # ignore end if it's not greater than start
            return int(rand($ref + 1));
        }
    }

    my $pick = shift || 1;
    my $repl = shift || 0;
    $ref = [ keys (%$ref) ] if (hashref $ref);

    croak ("any: invalid reference '$ref': expected ARRAY or HASH")
        unless (arrayref $ref);

    my $last = $#$ref + 1;

    # make sure we're not trying to pick more items than the list
    # contains
    $pick = $#$ref + 1 if ($pick > $last);

    # don't bother modifying the list if we're only picking one item
    if ($pick == 1) {
        return $ref->[int(rand($last))];
    } else {
        my @any = ();
        if ($repl) {
            push @any, $ref->[int(rand($last))] for (1 .. $pick);
        } else {
            my @ref = @$ref; # don't modify the original list
	    for (1 .. $pick) {
		# squashed bug: recalculate $top every time the
		# array is spliced 
		my $top = $#ref + 1;
		push @any, splice (@ref, int(rand($top)), 1);
	    }
        }
        return wantarray ? @any : [ @any ];
    }
}

=head2 appendfile

=head3 usage

    appendfile($file, $data, %args);

=head3 description

This is a simple wrapper for writefile()'s APPEND option.

Appends $data to the file whose path is specified by $file.

See writefile() for %args options.

=cut

# die and warn handlers for appendfile: saves allocating a
# closure every time

sub _appendfile_die  { die ('reader: ' . shift) }
sub _appendfile_warn { warn ('reader: ' . shift) }

sub appendfile ($$;%) {
    my ($file, $data, %args) = @_;
    $args{DIE} ||= \&_appendfile_die;
    $args{WARN} ||= \&_appendfile_warn;
    $args{APPEND} = 1;
    writefile($file, $data, %args);
}

=head2 apply

=head3 usage

    my $result = apply $coderef, @optional_args;

	# or 

    my $result = apply sub { do_something() }, @optional_args;

	# or 

    my $result = apply \&Name::Space::sub, @optional_args;

=head3 description

Invokes the subroutine supplied as the first argument,
passing any arguments in @optional_args as parameters.

Returns the result of the subroutine call.

=cut

sub apply ($;@) {
    my $sub = shift;
    confess "apply: sub '$sub' is not a CODE ref" unless (coderef $sub);
    &$sub;
}

=head2 arrayref

=head3 usage

    do_something() if (arrayref $arg);

=head3 description

Returns a true value if $arg is a blessed or unblessed
ARRAY reference.

Returns a false value otherwise.

=cut

sub arrayref ($) {
    my $ref = shift;
    my $refname = ref $ref;
    return ($refname && (($refname eq 'ARRAY') || UNIVERSAL::isa ($ref, 'ARRAY')));
}

=head2 atime

=head3 usage

    my $atime = atime($file);

=head3 description

Returns the time (in seconds since the epoch) the specified
file was last accessed.

=cut

sub atime($) {
    return (stat($_[0]))[8];
}

=head2 capitalize

=head3 usage

    my $capitalized = capitalize($string);

    # or 

    my $capitalized = capitalize($string, @do_not_capitalize_these_words);

=head3 description

Initial-capitalizes $string i.e. any words (defined as consecutive
characters between word-boundaries (\b)) in $string that don't already
contain capitals are lowercased and their initials are uppercased.

Note: apostrophes are treated as word characters, so:

    "There's more than one way to do it"

becomes:

    "There's More Than One Way To Do It"
	
rather than:
    
    "There'S More Than One Way To Do It"

Any arguments supplied after $string are treated as exceptions and
left as is.

For non-trivial capitalization see the { case => 'highlight' } option
of Damian Conway's Text::Autoformat.

In the absence of an explicit exception list, Acme::Util's capitalize()
(and Text::Autoformat's { case => 'title' }) mechanically renders
the text: 
    
    'what i did on my summer vacation in monterey'

as:

    'What I Did On My Summer Vacation In Monterey'

Whereas Text::Autoformat's { case => 'highlight' } option offers the
much more titular:

    'What I Did on my Summer Vacation in Monterey'

=cut

sub capitalize ($;@) {
    my $text = shift;

    if (@_) {
	my %exclude = map { $_ => 1 } @_;
	$text =~ s/([\w']+)/(($1 ne lc ($1)) || $exclude{$1}) ?
	    $1 : "\u\L$1"/ge;
    } else {
	$text =~ s/([\w']+)/$1 ne lc $1 ? $1 : "\u\L$1"/ge;
    }

    return $text;
}

=head2 clone

=head3 usage

    use Acme::Util qw(clone);

    $a = Foo->new();
    $b = { alpha => 'beta', gamma => 'vlissides' };

    tie %c, 'Foo::Bar';

    $d = clone($a);
    $e = clone($b);
    $f = clone(\%c);

    # or

    my $node2 = {
	name	    => 'node2',
	children    => [ $node3, $node4 ],
	parent	    => weaken ($node1)	    # weaken() to avoid memory leak
    };

    # clone $node2 but preserve the original $node1 (rather than cloning
    # through it all the way to the root)

    my $clone = clone($node2, [ $node1 ]);

	# or, equivalently

    my $clone = clone($node2, [ $node2->{parent} ]);

=head3 description

clone() returns a recursive copy of its argument, which can be an
arbitrary (scalar) type including nested HASH, ARRAY and reference types
(including weak references), tied variables and objects.

To duplicate non-scalar types (e.g. lists, ARRAYs and HASHes), pass them
to clone() by reference. e.g.
    
    my $copy = clone (\@array);

    # or

    my %copy = %{ clone (\%hash) };

clone() takes an optional second argument: a reference to an ARRAY
containing a list of exceptions i.e. values that should be 'passed-thru'
verbatim. This is useful for, amongst other things, cloning nodes in a
hierarchy without duplicating the structure all the way to the root.

For a slower, but more flexible solution see Storable's dclone().

=cut

=head2 coderef

=head3 usage

    do_something() if (coderef $arg);

=head3 description

Returns a true value if $arg is a blessed or unblessed
CODE reference.

Returns a false value otherwise.

=cut

sub coderef ($) {
    my $ref = shift;
    my $refname = ref $ref;
    return ($refname && (($refname eq 'CODE') || UNIVERSAL::isa ($ref, 'CODE')));
}

=head2 commify

=head3 usage

    my $pretty = commify($int);

=head3 description

Returns a reader-friendly representation of the supplied integer
punctuated with commas at the customary thousands/millions
(&c.) points.

Thus:

    printf "%-9u\t%11s%s", $_, commify($_), $/
        for (map { $_ x $_ } 1 .. 9);

prints:

    1                     1
    22                   22
    333                 333
    4444              4,444
    55555            55,555
    666666          666,666
    7777777       7,777,777
    88888888     88,888,888
    999999999   999,999,999

=cut

sub commify($) {
    my $r = reverse shift();
    $r =~ s/(\d{3})(?=\d)/$1,/g;
    # scalar() to prevent print() propagating list context to reverse()
    scalar reverse $r;
}

=head2 csv

=head3 usage

    my $csv = csv($fields, $arrayref);

	# or

    my $csv = csv [ 'alpha', 'beta', 'gamma', 'vlissides' ],
	[
	    { alpha => 'fee',   beta => 'fie',    gamma => 'foe',   vlissides => 'fum'    }, 
	    { alpha => 'foo',	beta => 'bar',	  gamma => 'baz',   vlissides => 'foobar'  }, 
	    { alpha => 'one',   beta => 'two',    gamma => 'three', vlissides => 'four' }
	];

	# or

     my $csv = csv [ 'alpha', 'beta', 'gamma', 'vlissides' ],
	[
	    [ qw(fee fie foe fum) ],
	    [ qw(foo bar baz foobar) ],
	    [ qw(one two three four) ],
	];

    # yields

    "alpha","beta","gamma","delta"
    "fee","fie","foe","fum"
    "foo","bar","baz","foobar"
    "one","two","three","four"

=head3 description

    $fields:	an ARRAY ref representing a list of field names
    $arrayref:	a reference to an ARRAY of HASH or ARRAY references

Returns either a string or (in list context) a list
representing the rows of a CSV (Comma Separated Values) document
generated from the supplied HASH or ARRAY refs and using the fields
listed in $fields as the field names.

Field names and values are double quoted.

=cut

sub csv ($$) {
    my ($fields, $arrayref) = @_;

    my $ref_arg1 = ref $fields || '';
    my $ref_arg2 = ref $arrayref || '';

    die ("csv: invalid arg 1: expected ref to an ARRAY of field names: got $ref_arg1")
	unless (arrayref $fields);
    die ("csv: invalid arg 2: expected ref to an ARRAY of ARRAY or HASH refs: " .
	 "got $ref_arg2") unless (arrayref $arrayref);

    my @out = join (',', map { _dquote $_ } @$fields);

    for my $ref (@$arrayref) {
	my @row = ();

	if (arrayref $ref) {
	    push (@row, $ref->[$_]) for (0 .. $#$fields);
	} elsif (hashref $ref) {
	    push (@row, $ref->{$_}) for (@$fields);
	} else {
	    my $reftype = ref $ref || '';
	    die ("csv: invalid arg 2: expected arg 2 element to be an ARRAY or HASH ref, got: '$reftype'");
	}

	push @out, join (',', map { _dquote $_ } @row);
    }

    return wantarray ? @out : join ($/, @out);
}

=head2 ctime

=head3 usage

    my $ctime = ctime($file);

=head3 description

Returns the time (in seconds since the epoch) the specified
file was created.

=cut

sub ctime($) {
    return (stat($_[0]))[10];
}

=head2 div

=head3 usage

    my ($quotient, $remainder) = div ($numerator, $denominator);

    # e.g.
    
    my ($q, $r) = div (13, 3);

    # $q = 4, $r = 1:
    # 13 ($numerator) = 4 ($quotient) x 3 ($denominator) + 1 ($remainder) 

=head3 description

Integer division operator: in list context, returns the quotient and remainder when the first
operand ($numerator) is divided by the second ($denominator).

i.e. 

    $numerator = $quotient * $denominator + $remainder

In scalar context, returns just the quotient. To return the
remainder, use %.

=cut

sub div ($$) {
    my ($numerator, $denominator) = @_;
    my ($quotient, $remainder) = (int ($numerator / $denominator),
	$numerator % $denominator);
    return wantarray ? ($quotient, $remainder) : $quotient;
}

# =head2 dquote
# 
# =head3 usage
# 
#     my $double_quoted = dquote($string);
# 
# =head3 description
# 
# Returns (a copy of) its argument surrounded by double quotes.
# 
# Any internal double quotes encountered inside $string are escaped with a backslash.
# 
# =cut

# PRIVATE METHOD

sub _dquote ($) {
    my $text = shift;
    $text =~ s/"/\\"/g;
    return sprintf '"%s"', $text;
}

=head2 find

=head3 usage

    my $index = find ($arrayref, $scalar)

	# or

    my $index = find ($arrayref, $scalar, $from)

=head3 description

Returns the offset of $scalar within $arrayref, with the first
position denoted by 0.

$scalar can be a number, string or reference.

-1 is returned if the item is not found.

If the third argument is supplied, the search begins at that index
(the offset is still calculated from the beginning of the ARRAY ref).

=cut

# TODO: negative $from could indicate backwards search
# TODO: user-supplied comparator - how to keep the interface clean?

sub find ($$;$) {
    my ($haystack, $needle, $from) = @_;

    $from = 0 unless (defined $from);

    if (isnum $needle) {
	($haystack->[$_] == $needle) && return ($_) for ($from .. $#$haystack);
    } else {
	($haystack->[$_] eq $needle) && return ($_) for ($from .. $#$haystack);
    }
    
    return -1;
}

=head2 hashref

=head3 usage

    do_something() if (hashref $arg);

=head3 description

Returns a true value if $arg is a blessed or unblessed HASH reference.

Returns a false value otherwise.

=cut

sub hashref ($) {
    my $ref = shift;
    my $refname = ref $ref;
    return ($refname && (($refname eq 'HASH') || UNIVERSAL::isa ($ref, 'HASH')));
}

=head2 html

=head3 usage

    html ($text);

	# or

    html ();

=head3 description

Returns $text with the 'text/html' Content-type header prefixed;
or just the header if no $text is provided.

Prints the prefixed page out directly if called in void context.

=cut

sub html (;$) {
    my $arg = scalar @_ ? shift : '';
    respond ("Content-type: text/html\n\n" . $arg);
}

=head2 id

=head3 usage

    id()

=head3 description

Returns a quick 'n' dirty Unique Identifier. Uses $$ (amongst
other things), so not necessarily reliable under SpeedyCGI,
mod_perl &c.

=cut

sub id () {
    srand ($$ | time); # FIXME: $$ isn't unique in SpeedyCGI mod_perl &c.
    return unpack "H*", pack "Nnn", time, $$, int (rand(60000));
}

=head2 infinity inf

=head3 usage

    my $inf = infinity()

        # or

    my $inf = inf()

=head3 description

Perl 5.8 claims to support infinity natively, but falls short on
many platforms. This utility function is a trivial wrapper for the
Swiss-Army $Inf provided by Math::Complex, which jumps through every
possible hoop to deliver a high-quality infinity product for your
reckoning pleasure.

=cut

sub infinity() {
    require Math::Complex;
    return $Math::Complex::Inf;
}

# predeclare to build autoload stub: code down to the next sub goes into inf.al
sub inf();
{
    no strict 'refs';
    *inf = \&infinity;
}

# sub inf() { goto &infinity; } # and beyond

=head2 isnum

=head3 usage

    isnum ($val)

=head3 description

Returns a nonzero value (indicating the numeric type) if $val is a number.

The numeric types are a conjunction of the following flags:

    0x01  IS_NUMBER_IN_UV		(number within UV range - maybe not int)
    0x02  IS_NUMBER_GREATER_THAN_UV_MAX (the pointed-to UV is undefined)
    0x04  IS_NUMBER_NOT_INT		(saw . or E notation)
    0x08  IS_NUMBER_NEG			(leading minus sign)
    0x10  IS_NUMBER_INFINITY		(this is big)
    0x20  IS_NUMBER_NAN			(this is not)

Rather than obliging the user to twiddle with bits, the following
flavours of isnum (corresponding to the flags above) are also available:

    isint
    isuv
    isbig
    isfloat
    isneg
    isinf
    isnan

isint returns -1 if its operand is a negative integer, 1 if
it's 0 or a positive integer, and 0 otherwise.

The others always return 1 or 0.

=cut

sub isnum ($) {
    return 0 unless defined (my $val = shift);
    # stringify - ironically, looks_like_number always returns 1 unless
    # arg is a string
    return is_num($val . '');
}

sub isint ($) {
    my $isnum = isnum(shift());
    return ($isnum == 1) ? 1 : ($isnum == 9) ? -1 : 0;
}

sub isuv ($) {
    return (isnum(shift()) & 1) ? 1 : 0;
}

sub isbig ($) {
    return (isnum(shift()) & 2) ? 1 : 0;
}

sub isfloat ($) {
    return (isnum(shift()) & 4) ? 1 : 0;
}

sub isneg ($) {
    return (isnum(shift()) & 8) ? 1 : 0;
}

sub isinf ($) {
    return (isnum(shift()) & 16) ? 1 : 0;
}

sub isnan ($) {
    return (isnum(shift()) & 32) ? 1 : 0;
}

=head2 js

=head3 usage

    js ($text);

	# or

    js ();

=head3 description

Returns the JavaScript in $text with the 'application/x-javascript'
Content-type header prefixed; or just the header if no $text is provided.

Prints the prefixed page out directly if called in void context

=cut

sub js (;$) {
    my $arg = scalar @_ ? shift : '';
    respond ("Content-type: application/x-javascript\n\n" . $arg);
}

=head2 ltrim

=head3 usage

    my $trimmed = ltrim ($string);

=head3 description

Returns a copy of $string with whitespace removed from the beginning.

=cut

sub ltrim ($) {
    my $spacey = shift;
    $spacey =~ s/^\s+//;
    return $spacey;
}

=head2 mtime

=head3 usage

    my $mtime = mtime($file);

=head3 description

Returns the time (in seconds since the epoch) the specified file
was last modified.

=cut

sub mtime($) {
    return (stat($_[0]))[9];
}

=head2 plural

=head3 usage

    my $plural = plural($stem, $count);

	# or

    my $plural = plural($stem, $count, $plural);

=head3 description

Plural() takes a singular word or word-stem as an argument; it
evaluates $count to see if it is equal to 1; if it is, $stem is
returned unchanged; otherwise $stem is pluralised by adding
$plural, or 's' if $plural hasn't been supplied.

Thus:

	my $plural = plural('error', $error);

	will return:
	
	    'errors' if $error == 0
	    'error'  if $error == 1
	    'errors' if $error >  1

This simple implementation does not support irregular plurals that
modify the stem. For solutions to that, and indeed, most other
non-trivial pluralization problems, the reader is referred to
Damian Conway's Lingua::EN::Inflect.

=cut

sub plural ($$;$) {
    my ($string, $count, $plural) = @_;
    $plural = 's' unless (defined $plural);
    return ($count == 1) ? $string : $string . $plural;
}

=head2 reader

=head3 usage

    my $source = '';
    my $read = reader($path, IRS => '...', CHOMP => 1);

    while ($read->(\$source)) {
	do_something_with($source);
    }

	# or

    while ($read->()) { # implied target: $_
	do_something_with($_);
    }

=head3 description
	
This method implements a generator/continuation interface to the
fine art of file slurpage. It provides a private (lexically scoped)
filehandle and an associated file reader (in the form of a closure).

This closure should be called with a reference to the variable
one wishes to be assigned the next line from the file.

If no argument is supplied then $_ is assumed to be the target.

The generator yields true while the file is slurping, and undef
thereafter.

The file is automatically closed either when the file has been read,
or the closure goes out of scope - whichever comes first.

=cut

#    For more information on the relative performance of
#    FileHandle v local (*FH) (local is used in 'vanilla' readfile())
#    vide:
#
#	http://groups.google.com/groups?
#	hl=en&frame=right&th=f6035f6588fa7bfe&seekm=tbaf8dq702.fsf%40blue.sea.net#s
#
#    Unfortunately, local() won't work in reader() (as a way of creating
#    anonymous, temporary filehandles) because close() is called automatically
#    on such filehandles at the end of the scope. The end of the scope
#    means the end of the call to reader() or the end of a (single)
#    call to $generator->() - neither of which correspond to the end of days
#    for the filehandle as far as the user is concerned.
#
#    What's needed is a solution similar to Alexander Alexandrescu's
#    ScopeGuard, and that's what's implemented here:
#
#	http://www.cuj.com/experts/1812/alexandr.htm?topic=experts
#

# die and warn handlers for reader: saves allocating a closure every time
sub _reader_die  { die ('reader: ' . shift) }
sub _reader_warn { warn ('reader: ' . shift) }

sub reader ($;%) {
    my ($file, %args) = @_;

    my ($die, $warn, $chomp) = @args{qw(DIE WARN CHOMP)};

    $die ||= \&_reader_die;
    $warn ||= \&_reader_warn;

    $die->("filename not defined") unless (defined $file);

    # Copy $/ before local() obliterates it below
    my $delim = $/;

    # Now $/ has been saved, we can override it if necessary
    # support aliases for the delimiter
    # tread carefully in case the delimiter is '' or 0
    for my $irs (qw(IRS DELIM SPLIT DELIMITER)) {
	next unless (exists $args{$irs});
	$delim = $args{$irs};
	last;
    }

    # $sg satisfies 3 requirements
    #	1. it's a lexical *reference* - needs to be a ref to give us a number
    #	2. it's referred to within the body of generator - a variable isn't
    #	   bound into a closure unless it's referred to
    #	3. it's private - the user is shielded from the implementation

    my $sg = Scope::Guard->new();
    my $handle = '_UTIL_READER_FH_' . int($sg);
	    
    {
	no strict 'refs';
	$die->("can't open <$file>: $!") unless (open($handle, $file));
	$handle = *$handle; # change $handle from a string into a filehandle
    }

    # wait until $handle is a filehandle before we guard it
    $sg->guard(\&myclose, $handle);

    unless (flock($handle, LOCK_SH)) {
	close $handle;
	$die->("Can't lock <$file>: $!");
    }

    # arg is optional but if supplied must be (or must be coercable into)
    # a scalar ref ... not that prototypes are honoured on subrefs... 
    my $generator = sub(;\$) {
	return unless ($sg);
	# ambient locals aren't (apparently) bound into closures
	local $/ = $delim;
	my $yield = $_[0] ? shift : \$_;

	if (defined ($$yield = readline($handle))) {
	    chomp ($$yield) if ($chomp);
	    return 1;
	} else {
	    flock ($handle, LOCK_UN); # release shared lock
	    # manually (indirectly) invoke the Scope::Guard dtor
	    return ($sg = undef);
	}
    };

    return $generator;
}

=head2 readfile

=head3 description

    Swiss-Army Slurp

=head3 usage

    # vanilla
    readfile $path; # print the file
	# or
    my $file = readfile $path;
	
    # handle warnings/fatal errors
    my $file = readfile $path, WARN => \&my_warn, DIE => sub { die @_ };
	
    # lines
    my @file = readfile $path;
	
    # set Input Record Separator
    my @file = readfile $path, IRS => '...';
	
    # strip Input Record Separator from result
    my @file = readfile $path, IRS => '...', CHOMP => 1;

    # open a binary file (e.g. on Windows/Cygwin)
    my $file = readfile $path, BINARY => 1;
	
    # all together now...
    my $file = readfile (
	$path,
	WARN	=> $warn,
	DIE	=> $die,
	IRS	=> '...',
	BINARY  => 1,
	CHOMP	=> 1);

    # synonyms for IRS	    => DELIM, SPLIT, DELIMITER
    # synonym  for BINARY   => BINMODE

=cut
	
# die and warn handlers for readfile: saves allocating a closure every time
sub _readfile_die  { die ('readfile: ' . shift) }
sub _readfile_warn { warn ('readfile: ' . shift) }

sub readfile($;%) { # this prototype doesn't do what it says on the tin
    my ($file, %args) = @_;
    my ($die, $warn, $chomp) = @args{qw(DIE WARN CHOMP)};
    # tread carefully in case the delimiter is '' or 0
    my $delim;

    for my $irs (qw(IRS DELIM SPLIT DELIMITER)) {
	next unless (exists $args{$irs});
	$delim = $args{$irs};
	last;
    }

    $die ||= \&_readfile_die;
    $warn ||= \&_readfile_warn;

    $die->("filename not defined") unless (defined $file);

    my @lines = ();

    local (*FILE);
    if (open(FILE, $file)) {
	binmode FILE if ($args{BINARY} || $args{BINMODE});
	local ($/, $_);

	if (flock(FILE, LOCK_SH)) { # LOCK_SH
	    $/ = $delim if (defined $delim);
	    while (<FILE>) {
		chomp if ($chomp);
		push @lines, $_; 
	    }
	    flock(FILE, LOCK_UN); # release shared lock
	} else {
	    close FILE;
	    $die->("Can't lock <$file>: $!") 
	}
    } else {
	$die->("Can't open <$file>: $!");
    }

    $warn->("Can't close <$file>: $!") unless (close FILE);

    respond @lines;
}

=head2 respond

=head3 usage

    respond ($scalar)
    respond (@list)

=head3 description

respond() performs a context-sensitive return:

    In void context the supplied arguments are printed.

    In scalar context it returns:
    
	the supplied argument if there's only one
	the concatenation of its arguments if there's more than one

    In list context it returns the arguments unchanged.

=cut

sub respond (@) { # Context-sensitive return: one or more args
    my $context = wantarray();

    if ($context) {			    # list context:	pass through
	return @_;
    } elsif (defined $context) {	    # scalar context:	join
	# $#_ is true if args >= 2
	return $#_ ? join '', @_ : $_[0];
    } else {				    # void context:	print
	print @_;
    }
}

=head2 rtrim

=head3 usage

    my $trimmed = rtrim ($string);

=head3 description

Returns a copy of $string with whitespace removed from the end.

=cut

sub rtrim ($) {
    my $spacey = shift;
    $spacey =~ s/\s+$//;
    return $spacey;
}

# =head2 squote
# 
# =head3 usage
# 
#     my $single_quoted = squote($string);
# 
# =head3 description
# 
# Returns (a copy of) its argument surrounded by single quotes.
# 
# Any internal single quotes encountered inside $string are escaped with a backslash.
# 
# =cut
# 
# PRIVATE METHOD

sub _squote ($) {
    my $text = shift;
    $text =~ s/'/\\'/g;
    return sprintf "'%s'", $text;
}

=head2 scalarref

=head3 usage

    do_something() if (scalarref $arg);

=head3 description

Returns a true value if $arg is a blessed or unblessed SCALAR reference.

Returns a false value otherwise.

=cut

sub scalarref ($) {
    my $ref = shift;
    my $refname = ref $ref;
    return ($refname && (($refname eq 'SCALAR') || UNIVERSAL::isa ($ref, 'SCALAR')));
}

=head2 squash

=head3 usage

    my $text = squash ($string);

=head3 description

Returns a 'flat' copy of $string i.e. with initial and terminal whitespace
removed and one or more internal whitespace characters (including
carriage-returns and newlines) squashed into a single space.

=cut

sub squash ($) { # Aaaaaaaaaaaaaagh!!!
    my $spacey = trim shift;
    $spacey =~ s/\s+/ /g; # includes \r, \n &c.
    return $spacey;
}

=head2 swap

=head3 usage

    swap($x, $y);

=head3 description

Sets the value of $x to $y and vice-versa.

swap() is prototyped to receive its arguments by reference, and modifies
its arguments in place like chop, chomp &c.

No value is returned

=cut

sub swap (\$\$) {
    my ($lhs, $rhs) = @_;
    ($$lhs, $$rhs) = ($$rhs, $$lhs);
}

=head2 text

=head3 usage

    text ($text);

	# or

    text ();

=head3 description

Returns $text with the 'text/plain' Content-type header prefixed;
or just the header if no $text is provided.

Prints the prefixed page out directly if called in void context.

=cut

sub text (;$) { 
    my $arg = scalar @_ ? shift : '';
    respond ("Content-type: text/plain\n\n" . $arg);
}

=head2 trim

=head3 usage

    my $trimmed = trim ($string);

=head3 description

Returns a copy of $string with whitespace removed from the beginning and end;
in addition, consecutive internal spaces are squashed to a single space.

=cut

sub trim ($) {
    my $spacey = shift;
    $spacey =~ s/^\s+//;
    $spacey =~ s/\s+$//;
    $spacey =~ tr/ / /s;
    return $spacey;
}

=head2 urlize

=head3 usage:

    my $url = urlize('Foo: BAR baz'); # returns 'foo_bar_baz'

    # or

    my $url = urlize('Foo - BAR - baz', 'html'); # returns 'foo_bar_baz.html'

=head3 description:
    
Makes its text argument URL-friendly.
    
Returns the first argument lowercased with any consecutive non-alphanumeric
characters replaced by an underscore.

If the optional second argument is provided, this is appended as an
extension prefixed by '.'

=cut

sub urlize($;$) {
    my $name = shift;
    croak ("urlize: name not defined") unless (defined $name);
    my $ext = scalar (@_) ? ".$_[0]" : '';
    # replace consecutive non-alphanumeric characters with an underscore
    $name =~ s/\W+/_/g;
    return lc($name) . $ext;
}

=head2 writefile

=head3 usage

    writefile($file, $data, %args);

=head3 description

Write $data to filename $file. Additional herbs and spices are
specified as a list of pairs, in the same manner as readfile (and reader).

Currently, the following options are supported:

APPEND		=> 1 for append (as opposed to truncate)
MODE		=> $mode (to roll your own file access mode)
BINARY/BINMODE	=> 1 to write a binary file (e.g. on Windows/Cygwin)

=cut

# die and warn handlers for reader: saves allocating a closure every time
sub _writefile_die  { die('writefile: ' . shift) }
sub _writefile_warn { warn('writefile: ' . shift) }

sub writefile ($$;%) {
    my ($file, $data, %args) = @_;
    my ($die, $warn) = @args{qw(DIE WARN)};

    $die ||= \&_writefile_die;
    $warn ||= \&_writefile_warn;

    my $mode = (exists $args{MODE}) ? $args{MODE} : ($args{APPEND} ? '>>' : '>');
    my $status = 0; # true or false depending on print() to FILEHANDLE

    local (*FILE);

    if (open(FILE, "$mode$file")) {
	binmode FILE if ($args{BINARY} || $args{BINMODE});
	if (flock(FILE, LOCK_EX)) {
	    $status = print FILE $data;
	    flock(FILE, LOCK_UN); # release exclusive lock
	} else {
	    close FILE;
	    $die->("Can't lock <$file>: $!");
	}
    } else {
	$die->("Can't open <$file>: $!");
    }

    # This is strictly unneccessary, as local (*FOO) takes care of
    # closing the file automatically at end-of-scope 
    # But we'll use that as a lifesaver rather than a way of life
    $warn->("Can't close <$file>: $!") unless (close FILE);
    return $status;
}

=head2 xml

=head3 usage

    xml ($text);

	# or

    xml ();

=head3 description

Returns (optional) $text with the 'text/xml' Content-type header prefixed;
or just the header if no $text is provided.

Prints the prefixed page out directly if called in void context.

=cut

sub xml (;$) { 
    my $arg = scalar @_ ? shift : '';
    respond ("Content-type: text/xml\n\n" . $arg);
}

=head2 xmlparse

=head3 usage

    xmlparse ($parser, $xml_path_or_data);

=head3 description

Convenience wrapper for XML::Parser (or XML::Parser::Expat - or
indeed any parser that supports parse() and parsefile())
that is agnostic with regard to whether $xml is a file/filehandle
or raw XML text.

The $parser should be prefabricated according to taste.

=cut

sub xmlparse ($$) {
    my ($parser, $xml) = @_;
    my $file = '';
    my $parsed = 1;

    {
        local $SIG{__DIE__} = sub {
            my $err = shift;
            confess ("xmlparse: Can't parse $file: $err");
        };

        local $SIG{__WARN__} = sub {
            my $err = shift;
            carp ("xmlparse $file: $err");
        };

        if ($xml =~ /^\s*</) {
            $file = 'xml';
            $parser->parse($xml);
        } elsif (-s $xml) {
            $file = $xml;
            $parser->parsefile($xml);
        } else {
            $parsed = 0;
        }
    }

    croak ("can't find file: $xml: $!") unless ($parsed);
}

# Used as an auxiliary filehandle destructor by reader()
# FIXME: could inherit warner to flag any close() problems

sub myclose {
    my $handle = shift;
    close $handle;
}

=head1 BUGS

clone() currently segfaults if it encounters a Regex object

=head1 SEE ALSO

Scalar::Util, List::Util, Clone, Storable, File::Butler, Toolbox

=head1 AUTHOR

chocolateboy: <chocolate.boy@email.com>

=head1 COPYRIGHT

Copyright (c) 2001-2004, chocolateboy.

This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

=cut
