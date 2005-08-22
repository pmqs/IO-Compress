
use lib 't';
 
use strict;
local ($^W) = 1; #use warnings;
# use bytes;

use Test::More ;
use MyTestUtils;

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 63 + $extra ;

    use_ok('Compress::Zlib', 2) ;

    use_ok('IO::Gzip', qw(gzip $GzipError)) ;
    use_ok('IO::Gunzip', qw(gunzip $GunzipError)) ;

    use_ok('IO::Deflate', qw(deflate $DeflateError)) ;
    use_ok('IO::Inflate', qw(inflate $InflateError)) ;

    use_ok('IO::RawDeflate', qw(rawdeflate $RawDeflateError)) ;
    use_ok('IO::RawInflate', qw(rawinflate $RawInflateError)) ;
    use_ok('IO::AnyInflate', qw(anyinflate $AnyInflateError)) ;
}

foreach my $Class ( map { "IO::$_" } qw( Gzip Deflate RawDeflate) )
{
    
    for my $trans ( 0, 1 )
    {
        title "AnyInflate(Transparent => $trans) with $Class" ;
        my $string = <<EOM;
some text
EOM

        my $buffer ;
        my $x = new $Class(\$buffer) ;
        ok $x, "  create $Class object" ;
        ok $x->write($string), "  write to object" ;
        ok $x->close, "  close ok" ;

        my $unc = new IO::AnyInflate \$buffer, Transparent => $trans  ;

        ok $unc, "  Created AnyInflate object" ;
        my $uncomp ;
        ok $unc->read($uncomp) > 0 
            or print "# $IO::AnyInflate::AnyInflateError\n";
        ok $unc->eof(), "  at eof" ;
        #ok $unc->type eq $Type;

        is $uncomp, $string, "  expected output" ;
    }

}

{
    title "AnyInflate with Non-compressed data" ;

    my $string = <<EOM;
This is not compressed data
EOM

    my $buffer = $string ;

    my $unc ;
    my $keep = $buffer ;
    $unc = new IO::AnyInflate \$buffer, -Transparent => 0 ;
    ok ! $unc,"  no AnyInflate object when -Transparent => 0" ;
    is $buffer, $keep ;

    $buffer = $keep ;
    $unc = new IO::AnyInflate \$buffer, -Transparent => 1 ;
    ok $unc, "  AnyInflate object when -Transparent => 1"  ;

    my $uncomp ;
    ok $unc->read($uncomp) > 0 ;
    ok $unc->eof() ;
    #ok $unc->type eq $Type;

    is $uncomp, $string ;
}
