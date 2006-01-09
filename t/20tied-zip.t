BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
local ($^W) = 1; #use warnings;

use IO::Compress::Zip     qw($ZipError) ;
use IO::Uncompress::Unzip qw($UnzipError) ;

sub identify
{
    'IO::Compress::Zip';
}

require "tied.pl" ;
run();
