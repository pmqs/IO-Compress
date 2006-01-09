BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
local ($^W) = 1; #use warnings;
# use bytes;

use Test::More ;
use ZlibTestUtils;

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };


    plan tests => 4 + $extra ;

    use_ok('Compress::Zlib', 2) ;
    use_ok('Compress::Gzip::Constants') ;

    use_ok('IO::Compress::Gzip', qw($GzipError)) ;
    use_ok('IO::Uncompress::Gunzip', qw($GunzipError)) ;

}

sub externalGzip
{
}

sub externalGunzipFile
{
    my $file = shift ;

    my $gunzip = 'gzip -dc' ;

    open F, "$gunzip $file |";
    local $/;
    $_[0] = <F>;
    close F;

    return $? ;
}



