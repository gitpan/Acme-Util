use 5.008;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		    =>	'Acme::Util',
    'VERSION_FROM'	=>	'Util.pm', 	# finds $VERSION
    'INSTALLDIRS'   =>	'perl',
    'PREREQ_PM'		=>	{ # e.g. Module::Name => 1.1
	'Test::More'	=> 0,
	'Test::Deep'	=> 0,
	'Math::Complex'	=> 0	# for Inf / infinity
    }, 		
    'LIBS'		    =>	[''], 		# e.g. '-lm'
    # 'DEFINE'		=>	'-DUTIL_DEBUG',
    # 'DEFINE'		=>	'-DUTIL_CLONE_DEBUG',
    # 'OPTIMIZE'	=>	'-g',
    # 'OPTIMIZE'	=>	'-pg',
    'OPTIMIZE'	    =>	'-O3',
    'INC'		    =>	'' 		# e.g. '-I/usr/include/other'
);
