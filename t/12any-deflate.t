BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
local ($^W) = 1; #use warnings;


use IO::Uncompress::AnyInflate qw($AnyInflateError) ;

use IO::Compress::Deflate   qw($DeflateError) ;
use IO::Uncompress::Inflate qw($InflateError) ;

sub getClass
{
    'AnyInflate';
}

sub identify
{
    'IO::Compress::Deflate';
}

require "any.pl" ;
run();
