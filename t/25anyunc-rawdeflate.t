BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
local ($^W) = 1; #use warnings;

use IO::Uncompress::AnyUncompress qw($AnyUncompressError) ;

use IO::Compress::RawDeflate   qw($RawDeflateError) ;
use IO::Uncompress::RawInflate qw($RawInflateError) ;

sub getClass
{
    'AnyUncompress';
}


sub identify
{
    'IO::Compress::RawDeflate';
}

require "any.pl" ;
run();
