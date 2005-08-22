
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

    plan tests => 21 + $extra ;


    use_ok('Compress::Zlib::Common');

    use_ok('Compress::Zlib::ParseParameters');

#    use_ok('Compress::Zlib', 2) ;
#
#    use_ok('IO::Gzip', qw(gzip $GzipError)) ;
#    use_ok('IO::Gunzip', qw(gunzip $GunzipError)) ;
#
#    use_ok('IO::Deflate', qw(deflate $DeflateError)) ;
#    use_ok('IO::Inflate', qw(inflate $InflateError)) ;
#
#    use_ok('IO::RawDeflate', qw(rawdeflate $RawDeflateError)) ;
#    use_ok('IO::RawInflate', qw(rawinflate $RawInflateError)) ;
}


# Compress::Zlib::Common;

sub My::testParseParameters()
{
    eval { ParseParameters(1, {}, 1) ; };
    like $@, mkErr(': Expected even number of parameters, got 1'), 
            "Trap odd number of params";

    eval { ParseParameters(1, {}, undef) ; };
    like $@, mkErr(': Expected even number of parameters, got 1'), 
            "Trap odd number of params";

    eval { ParseParameters(1, {}, []) ; };
    like $@, mkErr(': Expected even number of parameters, got 1'), 
            "Trap odd number of params";

    eval { ParseParameters(1, {'Fred' => [Parse_unsigned, 0]}, Fred => undef) ; };
    like $@, mkErr("Parameter 'Fred' must be an unsigned int, got undef"), 
            "wanted unsigned, got undef";

    eval { ParseParameters(1, {'Fred' => [Parse_signed, 0]}, Fred => undef) ; };
    like $@, mkErr("Parameter 'Fred' must be a signed int, got undef"), 
            "wanted signed, got undef";

    eval { ParseParameters(1, {'Fred' => [Parse_signed, 0]}, Fred => 'abc') ; };
    like $@, mkErr("Parameter 'Fred' must be a signed int, got 'abc'"), 
            "wanted signed, got 'abc'";

    my $got = ParseParameters(1, {'Fred' => [Parse_store_ref, 0]}, Fred => 'abc') ;
    is ${ $got->value('Fred') }, "abc", "Parse_store_ref" ;

    $got = ParseParameters(1, {'Fred' => [0x1000000, 0]}, Fred => 'abc') ;
    is $got->value('Fred'), "abc", "other" ;

}

My::testParseParameters();


{
    title "isaFilename" ;
    ok   isaFilename("abc"), "'abc' isaFilename";

    ok ! isaFilename(undef), "undef ! isaFilename";
    ok ! isaFilename([]),    "[] ! isaFilename";
    $main::X = 1; $main::X = $main::X ;
    ok ! isaFilename(*X),    "glob ! isaFilename";
}

{
    title "whatIs" ;

    my $out_file = "abc";
    my $lex = new LexFile($out_file) ;
    open FH, ">$out_file" ;
    is whatIs(*FH), 'handle', "Match filehandle" ;
    close FH ;

    is whatIs("abc"),        'filename', "Match filename";
    is whatIs(\"abc"),       'buffer',   "Match buffer";
    is whatIs(sub { 1 }, 1), 'code',     "Match code";
    is whatIs(sub { 1 }),    ''   ,      "Don't match code";

}
