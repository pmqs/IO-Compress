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

my $BZIP2 ;

sub ExternalBzip2Works
{
    my $lex = new LexFile my $outfile;
    my $content = qq {
Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Ut tempus odio id
 dolor. Camelus perlus.  Larrius in lumen numen.  Dolor en quiquum filia
 est.  Quintus cenum parat.
};

    writeWithBzip2($outfile, $content)
        or return 0;
    
    my $got ;
    readWithBzip2($outfile, $got)
        or return 0;

    if ($content ne $got)
    {
        diag "Uncompressed content is wrong";
        return 0 ;
    }

    return 1 ;
}

sub readWithBzip2
{
    my $file = shift ;

    my $lex = new LexFile my $outfile;

    my $comp = "$BZIP2 -dc" ;

    if (system("$comp $file >$outfile") == 0 )
    {
        $_[0] = readFile($outfile);
        return 1 ;
    }

    diag "'$comp' failed: $?";
    return 0 ;
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
    my $comp = "$BZIP2 -c $options $infile >$file" ;

    return 1 
        if system($comp) == 0  ;

    diag "'$comp' failed: $?";
    return 0 ;
}

BEGIN 
{

    # Check external bzip2 is available
    my $name = $^O =~ /mswin/i ? 'bzip2.exe' : 'bzip2';
    my $split = $^O =~ /mswin/i ? ";" : ":";

    for my $dir (reverse split $split, $ENV{PATH})    
    {
        $BZIP2 = "$dir/$name"
            if -x "$dir/$name" ;
    }

    plan(skip_all => "Cannot find $name")
        if ! $BZIP2 ;

    plan(skip_all => "$name doesn't work as expected")
        if ! ExternalBzip2Works();
    
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 7 + $extra ;

    use_ok('IO::Compress::Bzip2',     ':all') ;
    use_ok('IO::Uncompress::Bunzip2', ':all') ;

}

{
    title "Test interop with $BZIP2" ;

    my $file = 'a.bz2';
    my $file1 = 'b.bz2';
    my $lex = new LexFile $file, $file1;
    my $content = "hello world\n" ;
    my $got;

    ok writeWithBzip2($file, $content), "writeWithBzip2 ok";

    bunzip2 $file => \$got ;
    is $got, $content;


    bzip2 \$content => $file1;
    $got = '';
    ok readWithBzip2($file1, $got), "readWithBzip2 returns 0";
    is $got, $content, "got content";
}


