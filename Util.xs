#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef UTIL_DEBUG
#include "debug.h"
#endif

#define CLONE_KEY(x) ((char *)((UVTYPE)x)) 

#define CLONE_STORE(x,y)						\
do {									\
    if (!hv_store(HSEEN, CLONE_KEY(x), UVSIZE, SvREFCNT_inc(y), 0)) {	\
	SvREFCNT_dec(y); /* Restore the refcount */			\
	croak("Can't store clone in seen hash (HSEEN)");		\
    }									\
} while (0)

#define CLONE_FETCH(x) (hv_fetch(HSEEN, CLONE_KEY(x), UVSIZE, 0))

typedef void (*Handler)(SV *, SV *);

static HV *HSEEN = NULL;
static void clone_hash (SV *, SV *);
static void clone_array (SV *, SV *);
static SV *clone_value (SV *, UV);

static void clone_hash (SV * ref, SV *target)
{
    char *key;
    SV *val, *sv_key;
    HV *original = (HV *)ref;
    HV *clone = (HV *)target;
    HE *next = NULL;
    void *ok = NULL;
    I32 retlen = 0;
    I32 riter;
    HE *eiter;

    /* Save iteration state */
    riter = HvRITER(original);
    eiter = HvEITER(original);

    hv_iterinit (original);

    while (next = hv_iternext (original)) {
	val = clone_value(hv_iterval (original, next), 0);
/*
	if (HeKLEN(next) == HEf_SVKEY) { // denotes an SV * key
	    sv_key = clone_value(HeSVKEY(next), 0);
	    ok = hv_store_ent(clone, sv_key, val, HeHASH(next));
	} else {
	    key = hv_iterkey (next, &retlen);
	    ok = hv_store (clone, key, retlen, val, HeHASH(next));
	}

	Soonish, support for UTF8 keys and restricted HASHes will go here
*/
	key = hv_iterkey (next, &retlen);
	ok = hv_store (clone, key, retlen, val, HeHASH(next));

	/*
	    1) HeHASH(next): no need to recalculate the hash code
	    2) We haven't incremented the value's refcount so
	       there's no need to decrement it here
	 */

	if (!ok)
	    warn("Can't store value in cloned hash");
    }

    /* Restore iteration state */
    HvRITER(original) = riter; 
    HvEITER(original) = eiter;
}

static void
clone_array (SV * ref, SV *target)
{
    I32 arrlen = 0;
    AV *original = (AV *)ref;
    AV *clone = (AV *)target;
    SV **svp;

    if ((arrlen = av_len (original)) != -1) {
	/* increment arrlen to compensate for postdecrement coming up */
	av_extend (clone, arrlen++);

	while (arrlen--) {
	    if (svp = av_fetch (original, arrlen, 0))
		av_store (clone, arrlen, clone_value (*svp, 0));
	}
    }

}

/**
 * The core dispatcher.
 *
 * Terminals (SVs, undef &c.) are copied (or passed through in the case
 * of code refs) without recursion.
 *
 * It is vitally important that source objects are registered in the
 * seen hash (HSEEN) before recursion takes place in order to properly
 * handle circular references.
 *
 * HSEEN is bypassed completetly (for speed) if the SV has a refcount
 * lower than 2: we know there's no way the object can be seen again
 * during the course of the duplication.
 * 
 * 2001-02-06
 */

static SV *
clone_value (SV *original, UV visible)
{
    SV *clone = &PL_sv_undef;
    /* SV *clone = Nullsv; */
    SV **seen = NULL;
    Handler clone_handler = NULL;

    /* 
       By default values with a refcount less than 2 are not cached.

       However, weak references - SvWEAKREF(original) - and weak referents
       - SvRMAGICAL(original) - will need to be cached
       even though their refcounts may be less than 2.
       
       In addition, the magical backref AV will be seen again, even
       though its refcount is fixed at 1. In this case 'visible'
       is (i.e. has been) set to 1 inside the MAGICAL handler below.

       SvWEAKREF is defined in Perl 5.6.1, but PERL_MAGIC_backref isn't
       so test for the superset rather than the subset of functionality
       we require.

       FIXME: Need to check the 5.6.1 source to make sure it's a new
       implementation/feature and not just a name change.
       
    */

#ifdef PERL_MAGIC_backref
    visible |= (SvREFCNT(original) > 1) || SvWEAKREF(original) || SvRMAGICAL(original);
#else
    /* 
       currently we're only caching SVs with random magic (RMG)
       to handle weak referents. We'll stick with '|=' (rather than '='),
       however, in case forced caching proves useful elsewhere (e.g for
       other clients/APIs).
     */
    visible |= (SvREFCNT(original) > 1);
#endif
    /* visible = 1; */

#ifdef UTIL_CLONE_DEBUG
    printf ("visible: 0x%x %d\n", original, visible);
#endif

    /* shortcircuit HSEEN lookup if possible */
    if (visible && (seen = CLONE_FETCH(original))) {
#ifdef PERL_MAGIC_backref
	return SvWEAKREF(*seen) ? *seen : SvREFCNT_inc(*seen);
#else
	return SvREFCNT_inc(*seen);
#endif
    }

=pod
typedef enum {
        SVt_NULL,       /* 0 */
        SVt_IV,         /* 1 */
        SVt_NV,         /* 2 */
        SVt_RV,         /* 3 */
        SVt_PV,         /* 4 */
        SVt_PVIV,       /* 5 */
        SVt_PVNV,       /* 6 */
        SVt_PVMG,       /* 7 */
        SVt_PVBM,       /* 8 */
        SVt_PVLV,       /* 9 */
        SVt_PVAV,       /* 10 */
        SVt_PVHV,       /* 11 */
        SVt_PVCV,       /* 12 */
        SVt_PVGV,       /* 13 */
        SVt_PVFM,       /* 14 */
        SVt_PVIO        /* 15 */
} svtype;
=cut

    switch (SvTYPE (original))
    {
	case SVt_PVCV: /* code ref - return the original FIXME: IO? FMT? FBM? */
	    clone = SvREFCNT_inc(original);
	    break;
	case SVt_PVHV:
	    clone = (SV *)newHV();
	    clone_handler = clone_hash;
	    break;
	case SVt_PVAV:
	    clone = (SV *)newAV();
	    clone_handler = clone_array;
	    break;
	default: 
	    /* 
	     * undef, RV, PVMG, FBM, PVIV, PVNV, GV, IO, FMT, PV &c. - don't
	     * reinvent the API
	     *
	     * Additional processing for references is performed below
	     */
	    clone = newSVsv(original);
    }

    /**
     * It is *vital* that this is performed *before* recursion,
     * to properly handle circular references. 2001-02-06
     */

    if (visible) { 
	/* protect this multi-line macro with braces, just to be on the safe side */
	CLONE_STORE(original, clone);
    }

    /*
     * We'll assume (in the absence of evidence to the contrary) that:
     *
     * A) a tied hash/array doesn't store its elements in the usual way (i.e.
     * the mg->mg_object(s) take full responsibility for them)
     *
     * and:
     *
     * B) references aren't tied.
     *
     * If these assumptions hold, the three options below are mutually
     * exclusive.
     *
     * More precisely: 1 & 2 are usually (see below) mutually exclusive; 2 & 3 are 
     * definitely mutually exclusive; we have to test 1 before giving 2
     * a chance; and we'll assume that 1 & 3 are mutually exclusive unless
     * and until we can be test-cased out of our delusion.
     *
     * Weak AV and HV referents are an exception to A) - they have both
     * a magical AV (containing backreferences) as well as 'normal' array or
     * hash values. If there are other exceptions, they can be handled
     * in the same way.
     *
     * 2001-05-29
     */

    /* 1: MAGICAL: TIED, WEAK REFERENT, ... */
    if (SvRMAGICAL(original) || SvGMAGICAL(original)) {
	MAGIC *mg, **mgp;
	SV *cloned;

#ifdef PERL_MAGIC_backref
	MAGIC *weakref;

	/* 
	   special-case weak referents - clone as a 'normal' AV/HV
	   then clone the magical AV
	 */

	if (clone_handler && (weakref = mg_find(original, PERL_MAGIC_backref))) {
	    clone_handler(original, clone); /* weak referent */
	    /* refcount special-casing is (i.e. has already been) handled in the REFERENCE section below */
	    /* SvREFCNT_dec(clone); */
	}
#endif

	for (mgp = &SvMAGIC(original); mg = *mgp; mgp = &mg->mg_moremagic) {
	    /* 
	       ensure the magical backref AV is cached, as it will be seen again
	       when we hit the self-ref
	     */
#ifdef PERL_MAGIC_backref
	    if (mg == weakref) { 
            cloned = clone_value(mg->mg_obj, 1); /* force caching */
            /* backref AV refcount is fixed at 1 pre 5.8.1 and 2 thereafter */
            /* FIXME: why isn't the original's refcount inc'd by CLONE_STORE()? */
            SvREFCNT(cloned) = SvREFCNT(mg->mg_obj);
	    } else {
            cloned = clone_value(mg->mg_obj, 0);
	    }
#else
	    cloned = clone_value(mg->mg_obj, 0);
#endif

	    sv_magic (clone,
		cloned,
		mg->mg_type,
		mg->mg_ptr,
		mg->mg_len);
	}

    /* 2: HASH/ARRAY - 'normal' (i.e. nonmagical) AV/HV with internal elements */
    } else if (clone_handler) {
    	clone_handler(original, clone);
    /* 3: REFERENCE */
    } else if (SvROK(original)) {
	/* Undo temporary increase to original's refcount caused by newSVsv() */
    	SvREFCNT_dec(SvRV(original));
	/* Clone the referent */
    	SvRV(clone) = clone_value (SvRV(original), 0);

	/* bless() if it's an object */
    	if (sv_isobject (original))
	    (void)sv_bless(clone, SvSTASH(SvRV(original)));
	
#ifdef PERL_MAGIC_backref
	/* 
	   flick the WEAKREF switch if it's a weak reference (newSVsv
	   doesn't clone this) and ensure the referent's refcount
	   is not increased by this reference
	 */
	if (SvWEAKREF(original)) {
	    SvREFCNT_dec(SvRV(clone));
	    SvWEAKREF_on(clone);
	}
#endif
    }

    return clone;
}

MODULE = Acme::Util		PACKAGE = Acme::Util		

PROTOTYPES: ENABLE

BOOT:
/* Initialize HSEEN */
HSEEN = newHV(); if (!HSEEN) croak ("Can't initialize seen hash (HSEEN)");

void
clone(original, passthru = NULL)
    SV *original
    SV *passthru
    PROTOTYPE: $;$
    PREINIT:
    SV *clone = &PL_sv_undef;
    PPCODE:

    /* 
     * The following allows an array ref of exceptions to be passed as a
     * second argument. These special cases are 'passed through' with
     * a refcount increase instead of being deep-cloned
     */

    if (passthru) {
	SV **svp;
	AV *exclude;
	I32 arrlen = 0;

	if ((!(SvROK(passthru))) || (SvTYPE(SvRV(passthru)) != SVt_PVAV)) {
	    croak ( "clone: invalid second argument type (%s) - please "
		    "supply an ARRAY ref", sv_reftype(SvRV(passthru), 0));
	}

	exclude = (AV *)SvRV(passthru);

	if ((arrlen = av_len(exclude)) != -1) {
	    /* increment arrlen to compensate for postdecrement coming up */
	    ++arrlen;

	    while (arrlen--) {
		if (svp = av_fetch (exclude, arrlen, 0)) {
		    if (SvROK(*svp)) {
			CLONE_STORE(SvRV(*svp), SvRV(*svp));
		    } else {
			CLONE_STORE(*svp, *svp);
		    }
		}
	    }
	}
    }

    /**
     * clone_value(), not rv_clone: let the dispatcher decide. It also
     * means the library can be used by low-level code (e.g. other XS
     * extensions) to clone arbitrary SVs. 2001-02-06
     */
 
    clone = clone_value(original, 0);

    /** 
     * Refcounts will be decremented, but they've already been
     * temporarily incremented by CLONE_STORE()
     */

    hv_clear(HSEEN); 
    
    EXTEND(SP,1);
    PUSHs(sv_2mortal(clone));

    /*
     *  There's probably an approved way to do this (export to perl space a
     *  boolean indicating whether SvWEAKREF is defined), but this is
     *  painless. Used by clone_weakref.t to determine if its tests should be skipped
     */

void
backref_magic_is_defined()
    PROTOTYPE:
    CODE:
#ifdef PERL_MAGIC_backref
    XSRETURN(1);
#else
    XSRETURN(0);
#endif

void
is_num(sv)
    SV *sv
    PROTOTYPE: $
    PREINIT:
    I32 num = 0;
    PPCODE:

    if (!(SvROK(sv) || (sv == (SV *)&PL_sv_undef))) {
	num = looks_like_number(sv);
    }

    EXTEND(SP,1);
    PUSHs(sv_2mortal(newSViv(num)));
