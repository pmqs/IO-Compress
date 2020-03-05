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
use IO::Compress::Zip 'zip' ;
use IO::Uncompress::Unzip 'unzip' ;

BEGIN
{
    plan(skip_all => "Examples needs Perl 5.005 or better - you have Perl $]" )
        if $] < 5.005 ;

    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 4 + $extra ;
}


my $Inc = join " ", map qq["-I$_"] => @INC;
$Inc = '"-MExtUtils::testlib"'
    if ! $ENV{PERL_CORE} && eval " require ExtUtils::testlib; " ;

my $Perl = ($ENV{'FULLPERL'} or $^X or 'perl') ;
$Perl = qq["$Perl"] if $^O eq 'MSWin32' ;

$Perl = "$Perl $Inc -w" ;
#$Perl .= " -Mblib " ;
my $binDir = $ENV{PERL_CORE} ? "../ext/IO-Compress/bin/"
                             : "./bin";

my $nestedUnzip = "$binDir/nested-unzip";

# my $tmpDir1 ;
# my $tmpDir2 ;
# my $LexDir $tmpDir1, $tmpDir2 ;

my ($file1, $file2, $stderr) ;
my $lex = new LexFile $file1, $file2, $stderr ;

my $UNZIP ;
my $ZIP ;


# sub ExternalGzipWorks
# {
#     my $lex = new LexFile my $outfile;
#     my $content = qq {
# Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Ut tempus odio id
#  dolor. Camelus perlus.  Larrius in lumen numen.  Dolor en quiquum filia
#  est.  Quintus cenum parat.
# };

#     writeWithGzip($outfile, $content)
#         or return 0;

#     my $got ;
#     readWithGzip($outfile, $got)
#         or return 0;

#     if ($content ne $got)
#     {
#         diag "Uncompressed content is wrong";
#         return 0 ;
#     }

#     return 1 ;
# }

# sub readWithGzip
# {
#     my $file = shift ;

#     my $lex = new LexFile my $outfile;

#     my $comp = "$GZIP -d -c" ;

#     if ( system("$comp $file >$outfile") == 0 )
#     {
#         $_[0] = readFile($outfile);
#         return 1
#     }

#     diag "'$comp' failed: \$?=$? \$!=$!";
#     return 0 ;
# }

sub check
{
    my $command = shift ;
    my $expected = shift ;

    my $lex = new LexFile my $stderr ;


    my $cmd = "$command 2>$stderr";
    my $stdout = `$cmd` ;

    my $aok = 1 ;

    $aok &= is $?, 0, "  exit status is 0" ;

    $aok &= is readFile($stderr), '', "  no stderr" ;

    $aok &= is $stdout, $expected, "  expected content is ok"
        if defined $expected ;

    if (! $aok) {
        diag "Command line: $cmd";
        my ($file, $line) = (caller)[1,2];
        diag "Test called from $file, line $line";
    }

    1 while unlink $stderr;

    return $stdout;
}

sub runNestedUnzip
{
    my $command = shift;
    my $expected = shift ;

    return check "$Perl $nestedUnzip $command", $expected;
}


sub createNestedZip
{
    my $tree = shift;
    my @tree = @$tree;

    die "first entry cannot be a ref"
        if ref $tree[0] ;

    my $out ;
    my $zip ;


    for my $entry (@$tree)
    {
        my $name = $entry;
        my @entries;
        my $payload = "This is $name";

        if (ref $entry && ref $entry eq 'ARRAY')
        {
            ($name, @entries) = @$entry;
            $payload = createNestedZip([ @entries ]) ;
        }

        if (! $zip)
        {
            $zip = new IO::Compress::Zip \$out, Name => $name
                or die "Cannot create zip file $name': $!\n";
        }
        else
        {
            $zip->newStream(Name => $name);
        }

        $zip->print($payload);
    }

    $zip->close();

    return $out;
}

sub createTestZip
{
    my $filename = shift ;
    my $tree = shift ;

    writeFile($filename, createNestedZip($tree));
}

sub checkOutputTree
{
    my $base = shift ;
    my $expected = shift ;

}

{
    title "List";
    my $zipfile = "/tmp/abc.zip";
    # my $lex = new LexFile $zipfile;
    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           'def',
         ]);
    runNestedUnzip("$zipfile", <<'EOM');
abc
def.zip : a
def.zip : b
def.zip : c
def
EOM

}
