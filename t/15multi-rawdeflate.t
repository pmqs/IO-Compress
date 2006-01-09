BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
local ($^W) = 1; #use warnings;

use IO::Compress::RawDeflate   qw($RawDeflateError) ;
use IO::Uncompress::RawInflate qw($RawInflateError) ;

sub identify
{
    'IO::Compress::RawDeflate';
}

require "multi.pl" ;
run();
