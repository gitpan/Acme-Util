static void debug (SV *);

/*
 * If a subroutine called &main::debug is defined (just require()
 * debug.pl), and the supplied SV is a reference, call it with the
 * reference as its argument. Otherwise fall back on the basic
 * version of Devel::Peek::Dump() available to all internal routines
 * courtesy of dump.c.
 *
 * To include this header, define UTIL_DEBUG. e.g 'DEFINE' => '-DUTIL_DEBUG' in
 * Makefile.PL.
 *
 * A somewhat more sane way to debug XS than plain ol' assert().
 *
 * Warning: Don't include dump.h here as it redefines various core
 * macros (SvREFCNT_inc among them) with hilarious consequences. 
 * 
 * Particularly recommended is the use of Data::Dumper and/or
 * Devel::Peek in the perl-space debug routine:
 *
 * #!/usr/bin/perl -w
 *
 * use strict;
 *
 * use Data::Dumper; $Data::Dumper::Terse = $Data::Dumper::Indent = 1;
 * use Devel::Peek;
 *
 * sub debug($) {
 *	my $sv = shift;
 *	$sv = \$sv unless (ref $sv);
 *	Dump ($sv);
 *	print STDERR Dumper ($sv), $/;
 * }
 * 
 * Used to be called debug (rather than dump) so that it can be aliased to dump in
 * the debugger. For instance, in gdb:
 *
 *	define dump
 *	    p debug((SV *)$arg0)
 *	end
 *
 * But as of gdb 5.3 dump appears to be a gdb builtin. So it's now
 * called dumper:
 *
 *	define debug
 *	    p dumper((SV *)$arg0)
 *	end
 *
 * or:
 *
 *	define pdump
 *	    p dumper((SV *)$arg0)
 *	end
 *
 * 2001-02-06 - 2003-03-09
 */ 

static void
dumper (SV *sv)
{

    if (!sv)
	return;
    printf ("inside debug.h: %x\n", sv);
    
    if (SvROK(sv)) {
    	dSP ;

    	PUSHMARK(SP) ;
    	XPUSHs(sv);
    	PUTBACK ;
	/* FIXME: need to check for &main::debug */
    	perl_call_pv("main::debug", G_DISCARD);
    } else {
	/* dump lite */
	do_sv_dump(0, Perl_debug_log, sv, 0, 4, 0, 0);
    }

    /*
     * Don't callback to perl unless it's a reference: most pure perl subs can't handle it.
     * It's tempting to implement mortality here (using sv2mortal)
     * but we have to be careful to roundtrip the clone for diagnostic purposes.
     */
}
