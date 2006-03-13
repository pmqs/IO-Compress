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

my $BZIP2 ;

BEGIN {

    # Check external bzip2 is available
    my $name = 'bzip2';
    for my $dir (reverse split ":", $ENV{PATH})
    {
        $BZIP2 = "$dir/$name"
            if -x "$dir/$name" ;
    }

    plan(skip_all => "Cannot find $name")
        if ! $BZIP2 ;

    
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 7 + $extra ;

    use_ok('IO::Compress::Bzip2',     ':all') ;
    use_ok('IO::Uncompress::Bunzip2', ':all') ;

}

use CompTestUtils;

sub readWithBzip2
{
    my $file = shift ;

    my $lex = new LexFile my $outfile;

    my $comp = "$BZIP2 -dc" ;

    #diag "$comp $file >$outfile" ;

    system("$comp $file >$outfile") == 0
        or die "'$comp' failed: $?";

    $_[0] = readFile($outfile);

    return 1 ;
}

sub getBzip2Info
{
    my $file = shift ;
}

sub writeWithBzip2
{
    my $file = shift ;
    my $content = shift ;
    my $options = shift || '';

    my $lex = new LexFile my $infile;
    writeFile($infile, $content);

    unlink $file ;
    my $gzip = "$BZIP2 -c $options $infile >$file" ;

    system($gzip) == 0 
        or die "'$gzip' failed: $?";

    return 1 ;
}


{
    title "Test interop with $BZIP2" ;

    my $file = 'a.bz2';
    my $file1 = 'b.bz2';
    my $lex = new LexFile $file, $file1;
    my $content = "hello world\n" ;
    my $got;

    is writeWithBzip2($file, $content), 1, "writeWithBzip2 ok";

    bunzip2 $file => \$got ;
    is $got, $content;


    bzip2 \$content => $file1;
    $got = '';
    is readWithBzip2($file1, $got), 1, "readWithBzip2 returns 0";
    is $got, $content, "got content";
}


