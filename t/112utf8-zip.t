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
use Data::Dumper;

use IO::Compress::Zip     qw($ZipError);
use IO::Uncompress::Unzip qw($UnzipError);

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 12 + $extra;
}

{
    title "Create a simple zip - language encoding flag set";

    my $lex = new LexFile my $file1;

    my @names = ( 'alpha \N{GREEK SMALL LETTER ALPHA}',
                  'beta \N{GREEK SMALL LETTER BETA}',
                  'gamma \N{GREEK SMALL LETTER GAMMA}',
                  'delta \N{GREEK SMALL LETTER DELTA}'
                ) ;

    my @n = @names;

    my $zip = new IO::Compress::Zip $file1,
                    Name =>  $names[0], Efs => 1;

    my $content = 'Hello, world!';
    ok $zip->print($content), "print";
    $zip->newStream(Name => $names[1], Efs => 1);
    ok $zip->print($content), "print";
    $zip->newStream(Name => $names[2], Efs => 0);
    ok $zip->print($content), "print";
    $zip->newStream(Name => $names[3]);
    ok $zip->print($content), "print";
    ok $zip->close(), "closed";

    my $u = new IO::Uncompress::Unzip $file1
        or die "Cannot open $file1: $UnzipError";

    my $status;
    my @efs;
    my @unzip_names;
    for ($status = 1; $status > 0; $status = $u->nextStream())
    {
        push @efs, $u->getHeaderInfo()->{efs};
        push @unzip_names, $u->getHeaderInfo()->{Name};
    }

    die "Error processing $file1: $status $!\n"
        if $status < 0;

    is_deeply \@efs, [1, 1, 0, 0], "language encoding flag set"
        or diag "Got " . Dumper(\@efs);
    is_deeply \@unzip_names, [@names], "Names round tripped"
        or diag "Got " . Dumper(\@unzip_names);
}

{
    title "Create a simple zip - filename not valid utf8 - language encoding flag set";

    my $lex = new LexFile my $file1;

    my $name = "\xEF\xAC";
    my $zip = new IO::Compress::Zip $file1,
                    Name =>  $name, Efs => 1;     
    ok $zip->print("abcd"), "print";
    ok $zip->close(), "closed";

    my $u = new IO::Uncompress::Unzip $file1
        or die "Cannot open $file1: $UnzipError";  

    is $u->getHeaderInfo()->{Name}, $name, "got bad filename";                     

}