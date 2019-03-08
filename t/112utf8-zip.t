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

use IO::Compress::Zip     qw($ZipError);
use IO::Uncompress::Unzip qw($UnzipError);

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 7 + $extra;
}

{
    title "Create a simple zip - language encoding flag set";

    my $lex = new LexFile my $file1;

    my $zip = new IO::Compress::Zip $file1,
                    Name => "one", Utf8 => 1;

    my $content = 'Hello, world!';
    is $zip->write($content), length($content), "write";
    $zip->newStream(Name=> "two", Utf8 => 1);
    is $zip->write($content), length($content), "write";
    $zip->newStream(Name=> "three", Utf8 => 0);
    is $zip->write($content), length($content), "write";
    $zip->newStream(Name=> "four");
    is $zip->write($content), length($content), "write";
    ok $zip->close(), "closed";

    my $u = new IO::Uncompress::Unzip $file1
        or die "Cannot open $file1: $UnzipError";

    my $status;
    my @utf8;
    for ($status = 1; $status > 0; $status = $u->nextStream())
    {
        push @utf8, $u->getHeaderInfo()->{Utf8};
    }

    die "Error processing $file1: $status $!\n"
        if $status < 0;

    is_deeply \@utf8, [1, 1, 0, 0], "language encoding flag set";
}