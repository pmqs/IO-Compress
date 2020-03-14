BEGIN {
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = ("../lib", "lib/compress");
    }
}

use lib qw(t t/compress);

use strict;
use warnings;

use Cwd;
use Test::More ;
use CompTestUtils;
use IO::Compress::Zip 'zip' ;
# use IO::Uncompress::Unzip 'unzip' ;

BEGIN
{
    plan(skip_all => "Examples needs Perl 5.005 or better - you have Perl $]" )
        if $] < 5.005 ;

    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 112 + $extra ;
}


my $Inc = join " ", map qq["-I$_"] => @INC;
$Inc = '"-MExtUtils::testlib"'
    if ! $ENV{PERL_CORE} && eval " require ExtUtils::testlib; " ;

my $Perl = ($ENV{'FULLPERL'} or $^X or 'perl') ;
$Perl = qq["$Perl"] if $^O eq 'MSWin32' ;

$Perl = "$Perl $Inc -w" ;
#$Perl .= " -Mblib " ;

my $HERE = getcwd;
my $binDir = $HERE . '/' ;
$binDir .= $ENV{PERL_CORE} ? "../ext/IO-Compress/bin/"
                           : "./bin";

my $nestedUnzip = "$binDir/nested-unzip";


{
    package PushLexDir;

    use Cwd;

    sub new
    {
        my $class = shift;

        my $dir ;
        my $lexd = new LexDir $dir;

        my $here = getcwd;
        chdir $dir
            or die "Cannot chdir to '$lexd': $!\n";

        my %object = (Lex    => $lexd,
                      TmpDir => $dir,
                      Here   => $here
                     );

        return bless \%object, $class;
    }

    sub DESTROY
    {
        my $self = shift ;
        chdir $self->{Here}
            or die "Cannot chdir to '$self->{Here}': $!\n";
    }
}

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

    return ($aok, $stdout);
}

sub runNestedUnzip
{
    my $command = shift;
    my $expected = shift ;

    my ($aok, $got) = check "$Perl $nestedUnzip $command", $expected;

    if (! $aok) {
        my ($file, $line) = (caller)[1,2];
        diag "Test called from $file, line $line";
    }

    return $got ;
}


sub createNestedZip
{
    my $tree = shift;
    my $fullname = shift ;

    my @tree = @$tree;

    # die "first entry cannot be a ref"
    #     if ref $tree[0] ;

    my $out ;
    my $zip ;

    for my $entry (@$tree)
    {
        my $name = $entry;
        my @entries;
        my $payload = "This is $fullname/$entry\n";

        if (ref $entry && ref $entry eq 'ARRAY')
        {
            ($name, @entries) = @$entry;
            $payload = createNestedZip([ @entries ], "$fullname/$name") ;
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

        $zip->print($payload)
            if $name !~ m#/$# ;
    }

    $zip->close();

    return $out;
}

sub createTestZip
{
    my $filename = shift ;
    my $tree = shift ;

    writeFile($filename, createNestedZip($tree, ''));
}

sub getOutputTree
{
    my $base = shift ;

    use File::Find;

    my @found;
    find( sub { my $isDir = -d $_ ? " [DIR]" : "";
                push @found, "${File::Find::name}$isDir"
                    if ! /^\.\.?$/  # ignore . & .. directories
              },
          $base) ;

    return  [ sort @found ] ;
}


if (1)
{
    title "List default wildcard and wild-no-span";

    # chdir $HERE;

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', ['b/xx.zip' => 'b1', 'b2'], 'b/d', 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("-l $zipfile", <<"EOM");
Archive: $zipfile
abc
def.zip
def.zip/a
def.zip/b
def.zip/c
ghi.zip
ghi.zip/a
ghi.zip/b/xx.zip
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
ghi.zip/b/d
ghi.zip/c
def
EOM

    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

    runNestedUnzip("-lW $zipfile", <<"EOM");
Archive: $zipfile
abc
def.zip
def.zip/a
def.zip/b
def.zip/c
ghi.zip
ghi.zip/a
ghi.zip/b/xx.zip
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
ghi.zip/b/d
ghi.zip/c
def
EOM
    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

    # -l and -q
    runNestedUnzip("-l -q $zipfile", <<"EOM");
abc
def.zip
def.zip/a
def.zip/b
def.zip/c
ghi.zip
ghi.zip/a
ghi.zip/b/xx.zip
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
ghi.zip/b/d
ghi.zip/c
def
EOM

    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

    # -l and -q
    runNestedUnzip("-l -q -W $zipfile", <<"EOM");
abc
def.zip
def.zip/a
def.zip/b
def.zip/c
ghi.zip
ghi.zip/a
ghi.zip/b/xx.zip
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
ghi.zip/b/d
ghi.zip/c
def
EOM

    # Match the zip files themselves
    runNestedUnzip("-lq $zipfile **.zip", <<"EOM");
def.zip
ghi.zip
ghi.zip/b/xx.zip
EOM

    # Match the zip files themselves
    runNestedUnzip("-lqW $zipfile **.zip", <<"EOM");
def.zip
ghi.zip
ghi.zip/b/xx.zip
EOM

    # Match the zip files themselves
    runNestedUnzip("-lq $zipfile *.zip", <<"EOM");
def.zip
ghi.zip
ghi.zip/b/xx.zip
EOM

    # Match the zip files themselves
    runNestedUnzip("-lqW $zipfile *.zip", <<"EOM");
def.zip
ghi.zip
EOM

    # Match a single nested zip
    runNestedUnzip("-lq $zipfile **/*.zip", <<"EOM");
ghi.zip/b/xx.zip
EOM

    # Match a single nested zip
    runNestedUnzip("-lqW $zipfile **/*.zip", <<"EOM");
ghi.zip/b/xx.zip
EOM

    # contents of a single zip
    runNestedUnzip("-lq $zipfile **/*.zip/**", <<"EOM");
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
EOM

    # contents of a single zip
    runNestedUnzip("-lqW $zipfile **/*.zip/**", <<"EOM");
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
EOM

    # zip and one level deeper
    runNestedUnzip("-lq $zipfile g*.zip/* ", <<"EOM");
ghi.zip/a
ghi.zip/b/xx.zip
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
ghi.zip/b/d
ghi.zip/c
EOM

    # zip and one level deeper
    runNestedUnzip("-lqW $zipfile g*.zip/* ", <<"EOM");
ghi.zip/a
ghi.zip/c
EOM

    #
    runNestedUnzip("-lq $zipfile g*.zip/**", <<"EOM");
ghi.zip/a
ghi.zip/b/xx.zip
ghi.zip/b/xx.zip/b1
ghi.zip/b/xx.zip/b2
ghi.zip/b/d
ghi.zip/c
EOM

    #
    runNestedUnzip("-lq $zipfile g*.zip/*/b2", <<"EOM");
ghi.zip/b/xx.zip/b2
EOM

    runNestedUnzip("-lqW $zipfile g*.zip/*/b2", <<"EOM");
EOM

    runNestedUnzip("-lq $zipfile g*.zip/**/b2", <<"EOM");
ghi.zip/b/xx.zip/b2
EOM

    runNestedUnzip("-lq $zipfile g*.zip/**/b2", <<"EOM");
ghi.zip/b/xx.zip/b2
EOM

    #
    runNestedUnzip("-lq $zipfile g*.zip/*/b2", <<"EOM");
ghi.zip/b/xx.zip/b2
EOM

}

{
    diag "hide-nested-zip";


    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'def-a', 'def-b', 'def-c' ],
           [ 'ghi.zip' => 'ghi-a', ['ghi-b/xx.zip' => 'xx-b1', 'xx-b2'], 'ghi-b/d', 'ghi-c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("-lq --hide-nested-zip $zipfile", <<"EOM");
abc
def-a
def-b
def-c
ghi-a
xx-b1
xx-b2
ghi-b/d
ghi-c
def
EOM

    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

}

{
    title "Extract";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    # my $zipfile = "$HERE/$zipdir/zip1.zip";
    my $zipfile = "$HERE/zip1.zip";

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile");

    my $expected = [ sort map { "./" . $_ }  map { s/^\s*//; $_ } split "\n", <<EOM ];
        abc
        def
        def.zip.nested [DIR]
        def.zip.nested/a
        def.zip.nested/b
        def.zip.nested/c
        ghi.zip.nested [DIR]
        ghi.zip.nested/a
        ghi.zip.nested/c
        ghi.zip.nested/xx.zip.nested [DIR]
        ghi.zip.nested/xx.zip.nested/b1
        ghi.zip.nested/xx.zip.nested/b2
EOM

    my $got = getOutputTree('.') ;

    is_deeply $got, $expected, "Directory tree ok"
        or diag "Got [ @$got ]";
}


{
    title "Extract with --extract-dir";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    # my $zipfile = "$HERE/$zipdir/zip1.zip";
    my $zipfile = "$HERE/zip1.zip";

    my $extractDir ;
    my $lex2 = new LexDir $extractDir;

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile --extract-dir=$extractDir ");

    my $expected = [ sort map { "$extractDir/" . $_ }  map { s/^\s*//; $_ } split "\n", <<EOM ];
        abc
        def
        def.zip.nested [DIR]
        def.zip.nested/a
        def.zip.nested/b
        def.zip.nested/c
        ghi.zip.nested [DIR]
        ghi.zip.nested/a
        ghi.zip.nested/c
        ghi.zip.nested/xx.zip.nested [DIR]
        ghi.zip.nested/xx.zip.nested/b1
        ghi.zip.nested/xx.zip.nested/b2
EOM

    my $got = getOutputTree($extractDir) ;

    is_deeply $got, $expected, "Directory tree ok"
        or diag "Got [ @$got ]";
}

if (1)
{
    title "glob tests";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("-l $zipfile a?c **/c **b2", <<"EOM");
Archive: $zipfile
abc
def.zip/c
ghi.zip/xx.zip/b2
ghi.zip/c
EOM
    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

    runNestedUnzip("$zipfile a?c **/c **b2 **xx.zip");

    my $expected = [ sort map { "./" . $_ }  map { s/^\s*//; $_ } split "\n", <<EOM ];
        abc
        def.zip.nested [DIR]
        def.zip.nested/c
        ghi.zip.nested [DIR]
        ghi.zip.nested/c
        ghi.zip.nested/xx.zip.nested [DIR]
        ghi.zip.nested/xx.zip.nested/b2
EOM

    my $got = getOutputTree('.') ;
    is_deeply $got, $expected, "Directory tree ok"
        or diag "Got [ @$got ]";
}

if (1)
{
    title "Pipe tests";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("-l $zipfile a?c **/c **b2", <<"EOM");
Archive: $zipfile
abc
def.zip/c
ghi.zip/xx.zip/b2
ghi.zip/c
EOM
    is_deeply getOutputTree('.'), [], "Directory tree empty" ;

    my $expected =  join '',  map { "This is /" . $_ . "\n" } qw(
        abc
        def.zip/c
        ghi.zip/xx.zip/b2
        ghi.zip/c
        )  ;

    runNestedUnzip("$zipfile -p a?c **/c **b2", $expected);
}


if (1)
{
    title "Pipe tests";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip("-l $zipfile a?c **/c **b2", <<"EOM");
Archive: $zipfile
abc
def.zip/c
ghi.zip/xx.zip/b2
ghi.zip/c
EOM
    is_deeply getOutputTree('.'), [], "Directory tree empty" ;

    my $expected =  join '',  map { "This is /" . $_ . "\n" } qw(
        abc
        def.zip/c
        ghi.zip/xx.zip/b2
        ghi.zip/c
        )  ;

    runNestedUnzip("$zipfile -c a?c **/c **b2", <<"EOM");
Archive: $zipfile
  extracting: abc
This is /abc
  extracting: def.zip.nested/c
This is /def.zip/c
  extracting: ghi.zip.nested/xx.zip.nested/b2
This is /ghi.zip/xx.zip/b2
  extracting: ghi.zip.nested/c
This is /ghi.zip/c
EOM
}

{
    title "Extract: Badly formed names: default to drop '..' & strip leading '/'";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    # Create a zip with badly formed members
    my @create = (
            # name                ,
            "fred1"               ,
            "d1/../fred2"         ,
            "d2/////d3/d4/fred3"  ,
            "./dir2/../d4/"       ,
            "d3/"                 ,
     ) ;

    createTestZip($zipfile, [@create]);

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile");

    my $expected = [ sort  map { s/^\s*//; $_ } split "\n", <<EOM ];
            ./d1 [DIR]
            ./d1/fred2
            ./d2 [DIR]
            ./d2/d3 [DIR]
            ./d2/d3/d4 [DIR]
            ./d2/d3/d4/fred3
            ./d3 [DIR]
            ./dir2 [DIR]
            ./dir2/d4 [DIR]
            ./fred1
EOM

    my $got = getOutputTree('.') ;
    is_deeply $got, $expected, "Directory tree ok"
        or diag "Got [ @$got ]";
}


{
    title "Extract with 'do-double-dots:' : Badly formed names: Allow '..' & strip leading '/'";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    # Create a zip with badly formed members
    my @create = (
            "fred1"              ,
            "d1/./fred2"         ,
            "d2/////d3/d4/fred3" ,
            "./dir2/../d4/"      ,
            "d3/"                ,
     ) ;

    createTestZip($zipfile, [@create]);

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile --do-double-dots");

    my $expected = [ sort  map { s/^\s*//; $_ } split "\n", $^O eq 'MSWin32' ? <<EOM1 : <<EOM2];
            ./d1 [DIR]
            ./d1/fred2
            ./d2 [DIR]
            ./d2/d3 [DIR]
            ./d2/d3/d4 [DIR]
            ./d2/d3/d4/fred3
            ./d3 [DIR]
            ./d4 [DIR]
            ./fred1
EOM1
            ./d1 [DIR]
            ./d1/fred2
            ./d2 [DIR]
            ./d2/d3 [DIR]
            ./d2/d3/d4 [DIR]
            ./d2/d3/d4/fred3
            ./d3 [DIR]
            ./dir2 [DIR]
            ./d4 [DIR]
            ./fred1
EOM2

    my $got = getOutputTree('.') ;
    is_deeply $got, $expected, "Directory tree ok"
        or diag "Got [ @$got ]";
}


{
    title "Dos/Windows paths using \ as path seperator";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    # Create a zip with badly formed members
    my @create = map { my $a = $_ ; $a =~ s[/][\\]g ; $a } (
            'c:/fred1'           ,
            'd1/./fred2'         ,
            'd2/////d3/d4/fred3' ,
            './dir2/../d4/'      ,
            'D:d3/'              ,
     ) ;

    createTestZip($zipfile, [@create]);
    createTestZip("bad.zip", ['C:\abc\def\my.txt']);

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile --fix-windows-path");

    my $expected = [ sort  map { s/^\s*//; $_ } split "\n", <<EOM ];
            ./d1 [DIR]
            ./d1/fred2
            ./d2 [DIR]
            ./d2/d3 [DIR]
            ./d2/d3/d4 [DIR]
            ./d2/d3/d4/fred3
            ./d3 [DIR]
            ./dir2 [DIR]
            ./dir2/d4 [DIR]
            ./fred1
EOM

    my $got = getOutputTree('.') ;
    is_deeply $got, $expected, "Directory tree ok"
        or diag "Got [ @$got ]";
}