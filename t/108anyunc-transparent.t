BEGIN {
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = ("../lib", "lib/compress");
    }
}

use lib qw(t t/compress);

use strict;
use warnings;
use bytes;

use Test::More ;
use CompTestUtils;

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  Test::NoWarnings->import; 1 };

    plan tests => 15 + $extra ;

    use_ok('IO::Uncompress::AnyUncompress', qw($AnyUncompressError)) ;

}

{

    my $string = <<EOM;
This is not compressed data
EOM

    my $buffer = $string ;

    for my $file (0, 1)
    {
        title "AnyUncompress with Non-compressed data (File $file)" ;

        my $lex = LexFile->new( my $output );
        my $input ;

        if ($file) {
            writeFile($output, $buffer);
            $input = $output;
        }
        else {
            $input = \$buffer;
        }


        my $unc ;
        my $keep = $buffer ;
        $unc = IO::Uncompress::AnyUncompress->new( $input, -Transparent => 0 );
        ok ! $unc,"  no AnyUncompress object when -Transparent => 0" ;
        is $buffer, $keep ;

        $buffer = $keep ;
        $unc = IO::Uncompress::AnyUncompress->new( \$buffer, -Transparent => 1 );
        ok $unc, "  AnyUncompress object when -Transparent => 1"  ;

        my $uncomp ;
        ok $unc->read($uncomp) > 0 ;
        ok $unc->eof() ;
        #ok $unc->type eq $Type;

        is $uncomp, $string ;
    }
}

1;
