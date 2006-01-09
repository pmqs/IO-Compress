BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
local ($^W) = 1; #use warnings;

use Test::More skip_all => "not implemented yet";


use IO::Compress::Gzip     qw($GzipError) ;
use IO::Uncompress::Gunzip qw($GunzipError) ;

sub identify
{
    return 'IO::Compress::Gzip';
}

require "truncate.pl" ;
run();
