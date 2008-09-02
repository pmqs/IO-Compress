#! perl -w

use strict ;
require 5.004 ;

$::VERSION = '2.014' ;

use private::MakeUtil;
use ExtUtils::MakeMaker 5.16 ;

UpDowngrade(getPerlFiles('MANIFEST')) 
    unless $ENV{PERL_CORE};

# Modules supplied by this distribution    
my @myModules = qw( IO::Compress::RawDeflate
                    IO::Uncompress::RawInflate
                    IO::Compress::Deflate
                    IO::Uncompress::Inflate
                    IO::Compress::Gzip
                    IO::Uncompress::Gunzip
                    IO::Compress::Zip
                    IO::Uncompress::Unzip
                  );

# Direct dependencies                  
my @MainPREREQ = qw(Compress::Raw::Zlib
                    IO::Compress::Base
                    IO::Uncompress::Base
                   );

# Get indirect dependencies that will break if we install this version
push @MainPREREQ, FindBrokenDependencies($::VERSION, @myModules)
    unless $ENV{PERL_CORE} ;

my %MainPREREQ = map { $_ => $::VERSION } @MainPREREQ; 


WriteMakefile( 
    NAME         => 'IO::Compress::Zlib',
    VERSION_FROM => 'lib/IO/Compress/Gzip.pm',
    'dist'       => { COMPRESS     => 'gzip', 
                      TARFLAGS     => '-chvf',
                      SUFFIX       => 'gz',
                      DIST_DEFAULT => 'MyTrebleCheck tardist',
                    },

    (
      $ENV{SKIP_FOR_CORE}
        ? (MAN3PODS    => {})
	    : (PREREQ_PM   => { %MainPREREQ, 
		                    $] >= 5.005 && $] < 5.006   
                                ? ('File::BSDGlob' => 0) 
                                : () }
	      )
    ),
       
    (
    $] >= 5.005
        ? (ABSTRACT => 'Perl interface to zlib',
            AUTHOR  => 'Paul Marquess <pmqs@cpan.org>')
        : ()
    ),

    INSTALLDIRS => ($] >= 5.009 ? 'perl' : 'site'),

    (
    $] >= 5.009 && ! $ENV{PERL_CORE}
        ? (INST_LIB    => 'blib/arch')
        : ()
    ),


    ((ExtUtils::MakeMaker->VERSION() gt '6.30') ?
        ('LICENSE'  => 'perl')         : ()),    

) ;

# end of file Makefile.PL

