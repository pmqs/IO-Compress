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
use Data::Dumper ;
use Encode;
use charnames ':full';
# use IO::Uncompress::Unzip 'unzip' ;

BEGIN
{
    plan(skip_all => "Examples needs Perl 5.6.0 or better - you have Perl $]" )
        if $] < 5.006 ;

    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 210 + $extra ;
}

my $locale = getNativeLocale();

{
    diag "Locale Info" ;
    diag "  Derived Locale:\t'" . $locale->name . "'\n" ;
    if ($^O eq 'MSWin32')
    {
        my $chcp = `chcp`;
        $chcp =~ s/[\r\n]+$//;
        diag "  chcp output:\t'$chcp'\n";
    }

    for my $e (keys %ENV)
    {
        diag "  $e:\t'$ENV{$e}'\n"
            if $e =~ /^(LC_|LANG)/;
    }
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

my $ChkSums = {};

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
    my $payloads = shift;

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
        my $method = 8;

        if (ref $entry && ref $entry eq 'ARRAY')
        {
            ($name, @entries) = @$entry;
            $payload = createNestedZip([ @entries ], "$fullname/$name", $payloads) ;
            $method = 0;
        }

        if (! defined $zip)
        {
            $zip = new IO::Compress::Zip \$out, Name => $name, Stream => 0, Method => $method,
                or die "Cannot create zip file $name': $!\n";
        }
        else
        {
            $zip->newStream(Name => $name, Method => $method);
        }

        $zip->print($payload);
            # if $name !~ m#/$# ;

        $payloads->{"$fullname/$name"} = $payload;
    }

    $zip->close();

    return $out;
}

sub createTestZip
{
    my $filename = shift ;
    my $tree = shift ;
    my $payloads = shift ;

    writeFile($filename, createNestedZip($tree, '', $payloads));
}

sub getOutputTree
{
    my $base = shift ;
    my $payloads = shift;

    use File::Find;

    my %payloads ;
    my @found;
    find( sub { my $isDir = -d $_ ? " [DIR]" : "";
                return if /^\.\.?$/ ;  # ignore . & .. directories

                push @found, "${File::Find::name}$isDir" ;

                # system "pwd; ls -l";
                if (1 || $payloads)
                {
                    if ($isDir)
                    {
                        $payloads->{ ${File::Find::name} } = "DIRECTORY";
                    }
                    else
                    {
                        $payloads->{ ${File::Find::name} } = readFile($_);
                    }
                }

              },
          $base) ;

    return  [ sort @found ] ;
}

sub getOutputTreeAndData
{
    my $base = shift ;

    use File::Find;

    my %payloads ;
    my @found;
    find( sub { my $isDir = -d $_ ? " [DIR]" : "";
                return if /^\.\.?$/ ;  # ignore . & .. directories

                push @found, "${File::Find::name}$isDir" ;

                # system "pwd; ls -l";

                if ($isDir)
                {
                    $payloads{ ${File::Find::name} } = "DIRECTORY";
                }
                else
                {
                    my $payload = readFile($_);
                    $payload = "ZIPFILE" if $payload =~ /^PK/;
                    $payloads{ ${File::Find::name} } = $payload;
                }


              },
          $base) ;

    return  \%payloads
}

sub nameAndPayloadFil { my $k = shift ; my $n = shift || $k ; my $v = "This is /$n\n" ; $v =~ s/\.(\S+?).nested/.$1/g ; return "./$k", $v }
sub nameAndPayloadDir { my $k = shift ; return "./$k", 'DIRECTORY' }
sub nameAndPayloadZip { my $k = shift ; return "./$k", 'ZIPFILE' }

sub dosToUnixTime
{
	my $dt = shift;

	my $year = ( ( $dt >> 25 ) & 0x7f ) + 80;
	my $mon  = ( ( $dt >> 21 ) & 0x0f ) - 1;
	my $mday = ( ( $dt >> 16 ) & 0x1f );

	my $hour = ( ( $dt >> 11 ) & 0x1f );
	my $min  = ( ( $dt >> 5 ) & 0x3f );
	my $sec  = ( ( $dt << 1 ) & 0x3e );


    use POSIX 'mktime';

    my $time_t = mktime( $sec, $min, $hour, $mday, $mon, $year, 0, 0, -1 );
    return 0 if ! defined $time_t;
	return $time_t;
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

if (1)
{
    title "hide-nested-zip";


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

if (1)
{
    title "Extract";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";
    my $payloads = {};

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ],
         $payloads);

    # print "PAYLOADS IN -- " . Dumper($payloads) . "\n";

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile");


    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadFil('abc'),
        nameAndPayloadFil('def'),
        nameAndPayloadDir('def.zip.nested'),
        nameAndPayloadFil('def.zip.nested/a'),
        nameAndPayloadFil('def.zip.nested/b'),
        nameAndPayloadFil('def.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/a'),
        nameAndPayloadFil('ghi.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested/xx.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/xx.zip.nested/b1'),
        nameAndPayloadFil('ghi.zip.nested/xx.zip.nested/b2'),
    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ @$got ]";
}


if (1)
{
    title "match-zip";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";
    my $payloads = {};

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', ['jkl.zip' => 'd'] ], 'c' ],
           'def',
         ],
         $payloads);

    # print "PAYLOADS IN -- " . Dumper($payloads) . "\n";

    my $lexd = new PushLexDir();

    runNestedUnzip("--match-zip $zipfile */xx.zip def.zip");


    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadZip('def.zip'),
        nameAndPayloadDir('ghi.zip.nested'),
        nameAndPayloadZip('ghi.zip.nested/xx.zip'),

    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", keys (%$got)) . " ]";
}


if (1)
{
    title "match-zip - zip file contents";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";
    my $payloads = {};

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', ['jkl.zip' => 'd'] ], 'c1' ],
           'def',
         ],
         $payloads);

    # print "PAYLOADS IN -- " . Dumper($payloads) . "\n";

    my $lexd = new PushLexDir();

    runNestedUnzip("--match-zip $zipfile */xx.zip/* ");


    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadDir('ghi.zip.nested'),
        nameAndPayloadDir('ghi.zip.nested/xx.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/xx.zip.nested/b1'),
        nameAndPayloadZip('ghi.zip.nested/xx.zip.nested/jkl.zip'),

    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", keys (%$got)) . " ]";
}

if (1)
{
    title "Extract with --extract-dir";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

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

    chdir($extractDir);
    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadFil('abc'),
        nameAndPayloadFil('def'),
        nameAndPayloadDir('def.zip.nested'),
        nameAndPayloadFil('def.zip.nested/a'),
        nameAndPayloadFil('def.zip.nested/b'),
        nameAndPayloadFil('def.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/a'),
        nameAndPayloadFil('ghi.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested/xx.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/xx.zip.nested/b1'),
        nameAndPayloadFil('ghi.zip.nested/xx.zip.nested/b2'),
    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", keys (%$got)) . " ]";
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


    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadFil('abc'),
        nameAndPayloadDir('def.zip.nested'),
        nameAndPayloadFil('def.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested/xx.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/xx.zip.nested/b2'),
    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ @$got ]";
}


if (1)
{
    title "--exclude";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";
    my $payloads = {};

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b.c', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1.c', 'b2'], 'c.c' ],
           'def.c',
         ],
         $payloads);

    # print "PAYLOADS IN -- " . Dumper($payloads) . "\n";

    my $lexd = new PushLexDir();

    runNestedUnzip(qq[-x "*.c" --exclude "*/xx.zip/*" $zipfile]);


    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadFil('abc'),
        nameAndPayloadDir('def.zip.nested'),
        nameAndPayloadFil('def.zip.nested/a'),
        nameAndPayloadFil('def.zip.nested/c'),
        nameAndPayloadDir('ghi.zip.nested'),
        nameAndPayloadFil('ghi.zip.nested/a'),
    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
}


if(1)
{
    title "zip-wildcard";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    my $extractDir ;
    my $lex2 = new LexDir $extractDir;

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.xyz' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip(qq[-l --zip-wildcard "**.xyz" $zipfile ], <<"EOM");
Archive: $zipfile
abc
def.zip
ghi.xyz
ghi.xyz/a
ghi.xyz/xx.zip
ghi.xyz/c
def
EOM
    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

    runNestedUnzip(qq[ --zip-wildcard "**.xyz" $zipfile  ]);

    chdir($extractDir);
    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadFil('abc'),
        nameAndPayloadZip('def.zip'),
        nameAndPayloadDir('ghi.xyz.nested'),
        nameAndPayloadFil('ghi.xyz.nested/a'),
        nameAndPayloadZip('ghi.xyz.nested/xx.zip'),
        nameAndPayloadFil('ghi.xyz.nested/c'),
        nameAndPayloadFil('def'),

    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", keys (%$got)) . " ]";
}



if (1)
{
    title "Read Zip from stdin";

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

    runNestedUnzip("-l - a?c **/c **b2 <$zipfile", <<"EOM");
Archive: -
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

    $ChkSums = {};
    runNestedUnzip("-p -  a?c **/c **b2 <$zipfile", $expected);
    is_deeply getOutputTree('.', $ChkSums), [], "Directory tree empty" ;

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

    $ChkSums = {};
    runNestedUnzip("$zipfile -p a?c **/c **b2", $expected);
    is_deeply getOutputTree('.', $ChkSums), [], "Directory tree empty" ;

}


if (1)
{
    title "Pipe tests";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";

    my $payloads = {};

    createTestZip($zipfile,
        [
           'abc',
           [ 'def.zip' => 'a', 'b', 'c' ],
           [ 'ghi.zip' => 'a', [ 'xx.zip' => 'b1', 'b2'], 'c' ],
           'def',
         ],
         $payloads);

    my $lexd = new PushLexDir();

    runNestedUnzip("-l $zipfile a?c **/c **b2", <<"EOM");
Archive: $zipfile
abc
def.zip/c
ghi.zip/xx.zip/b2
ghi.zip/c
EOM
    is_deeply getOutputTree('.'), [], "Directory tree empty" ;


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

    is_deeply getOutputTree('.'), [], "Directory tree empty" ;

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

    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
        nameAndPayloadDir('d1'),
        nameAndPayloadFil('d1/fred2', "d1/../fred2"),
        nameAndPayloadDir('d2'),
        nameAndPayloadDir('d2/d3'),
        nameAndPayloadDir('d2/d3/d4'),
        nameAndPayloadFil('d2/d3/d4/fred3', "d2/////d3/d4/fred3"),
        nameAndPayloadDir('d3'),
        nameAndPayloadDir('dir2'),
        nameAndPayloadDir('dir2/d4', "./dir2/../d4/"),
        nameAndPayloadFil('fred1'),

    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", keys (%$got)) . " ]";
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
            "d3////"                ,
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
    # createTestZip("bad.zip", ['C:\abc\def\my.txt']);

    my $lexd = new PushLexDir();

    runNestedUnzip("$zipfile --fix-windows-path");

    my $got = getOutputTreeAndData('.') ;

    sub bks { my $a = shift ; $a =~ s[/][\\]g ; $a }
    my $expectedPayloads = {
        nameAndPayloadDir('d1'),
        nameAndPayloadFil('d1/fred2', bks 'd1/./fred2'),
        nameAndPayloadDir('d2'),
        nameAndPayloadDir('d2/d3'),
        nameAndPayloadDir('d2/d3/d4'),
        nameAndPayloadFil('d2/d3/d4/fred3', bks 'd2/////d3/d4/fred3'),
        nameAndPayloadDir('d3'),
        nameAndPayloadDir('dir2'),
        nameAndPayloadDir('dir2/d4', bks './dir2/../d4/'),
        nameAndPayloadFil('fred1', bks 'c:/fred1'),

    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", keys (%$got)) . " ]";
}

sub getFileTimes
{
    my $filename = shift ;
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks)
        = stat($filename);

    return $atime,$mtime,$ctime ;
}

{
    title "file timestamps -- default DOS";

    my $lexd = new PushLexDir();

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "time-dos.zip";

    # 0000 LOCAL HEADER #1       04034B50
    # 0004 Extract Zip Spec      0A '1.0'
    # 0005 Extract OS            00 'MS-DOS'
    # 0006 General Purpose Flag  0000
    # 0008 Compression Method    0000 'Stored'
    # 000A Last Mod Time         508B652E 'Sat Apr 11 12:41:28 2020'

    my $expectedTime = dosToUnixTime(0x508B652E);

    runNestedUnzip($zipfile);

    my ($atime,$mtime,$ctime) = getFileTimes("hello.txt");

    is $atime, $expectedTime, "  atime OK";
    is $mtime, $expectedTime, "  mtime OK";
}

{
    title "file timestamps -- extended (UT)";

    my $lexd = new PushLexDir();

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "time-ut.zip";

    # 0000 LOCAL HEADER #1       04034B50
    # 0004 Extract Zip Spec      0A '1.0'
    # 0005 Extract OS            00 'MS-DOS'
    # 0006 General Purpose Flag  0000
    # 0008 Compression Method    0000 'Stored'
    # 000A Last Mod Time         508B652E 'Sat Apr 11 12:41:28 2020'
    # 000E CRC                   363A3020
    # 0012 Compressed Length     00000006
    # 0016 Uncompressed Length   00000006
    # 001A Filename Length       0009
    # 001C Extra Length          001C
    # 001E Filename              'hello.txt'
    # 0027 Extra ID #0001        5455 'UT: Extended Timestamp'
    # 0029   Length              0009
    # 002B   Flags               '03 mod access'
    # 002C   Mod Time            5E91ACE7 'Sat Apr 11 12:41:27 2020'
    # 0030   Access Time         5E91ACFA 'Sat Apr 11 12:41:46 2020'
    # 0034 Extra ID #0002        7875 'ux: Unix Extra Type 3'


    my $expectedATime = 0x5E91ACFA;
    my $expectedMTime = 0x5E91ACE7;

    runNestedUnzip($zipfile);

    my ($atime,$mtime,$ctime) = getFileTimes("hello.txt");

    is $atime, $expectedATime, "  atime OK";
    is $mtime, $expectedMTime, "  mtime OK";
}

{
    title "file timestamps -- extended (UX)";

    my $lexd = new PushLexDir();

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "time-UX.zip";


    # 0000 LOCAL HEADER #1       04034B50
    # 0004 Extract Zip Spec      0A '1.0'
    # 0005 Extract OS            00 'MS-DOS'
    # 0006 General Purpose Flag  0000
    # 0008 Compression Method    0000 'Stored'
    # 000A Last Mod Time         30C5610B 'Sat Jun  5 12:08:22 2004'
    # 000E CRC                   00000000
    # 0012 Compressed Length     00000000
    # 0016 Uncompressed Length   00000000
    # 001A Filename Length       0001
    # 001C Extra Length          0010
    # 001E Filename              'a'
    # 001F Extra ID #0001        5855 'UX: Info-ZIP Unix (original; also
    #                            OS/2, NT, etc.)'
    # 0021   Length              000C
    # 0023   Access Time         41210249 'Mon Aug 16 19:51:53 2004'
    # 0027   Mod Time            40C19B96 'Sat Jun  5 11:08:22 2004'
    # 002B   UID                 01F5
    # 002D   GID                 0014


    my $expectedATime = 0x41210249;
    my $expectedMTime = 0x40C19B96;

    runNestedUnzip($zipfile);

    my ($atime,$mtime,$ctime) = getFileTimes("a");

    is $atime, $expectedATime, "  atime OK";
    is $mtime, $expectedMTime, "  mtime OK";
}

{
    title "file timestamps -- extended (NTFS)";

    my $lexd = new PushLexDir();

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "time-ntfs.zip";

    # 0DA6 LOCAL HEADER #D       04034B50
    # 0DAA Extract Zip Spec      0A '1.0'
    # 0DAB Extract OS            00 'MS-DOS'
    # 0DAC General Purpose Flag  0000
    # 0DAE Compression Method    0000 'Stored'
    # 0DB0 Last Mod Time         50477166 'Fri Feb  7 14:11:12 2020'
    # 0DB4 CRC                   F7A71113
    # 0DB8 Compressed Length     000006FC
    # 0DBC Uncompressed Length   000006FC
    # 0DC0 Filename Length       0008
    # 0DC2 Extra Length          0024
    # 0DC4 Filename              'meta.xml'
    # 0DCC Extra ID #0001        000A 'NTFS FileTimes'
    # 0DCE   Length              0020
    # 0DD0   Reserved            00000000
    # 0DD4   Tag1                0001
    # 0DD6   Size1               0018
    # 0DD8   Mtime               01D5DDEA5C6C8800 'Fri Feb  7 19:11:12
    #                            2020 0ns'
    # 0DE0   Ctime               01D5DDEA5C6C8800 'Fri Feb  7 19:11:12
    #                            2020 0ns'
    # 0DE8   Atime               01D5E12C35F9213F 'Tue Feb 11 22:40:07
    #                            2020 762771100ns'

    my $expectedATime = 1581460807;
    my $expectedMTime = 1581102672;

    runNestedUnzip($zipfile);

    my ($atime,$mtime,$ctime) = getFileTimes("meta.xml");
    # system("ls -l");

    is $atime, $expectedATime, "  atime OK";
    is $mtime, $expectedMTime, "  mtime OK";
}


if(1)
{
    title "Junk path ";

    my $zipdir ;
    my $lex = new LexDir $zipdir;
    my $zipfile = "$HERE/$zipdir/zip1.zip";



    createTestZip($zipfile,
        [
           'abc1',
           [ 'def.zip' => 'a2', 'b2', 'c2' ],
           [ 'ghi.zip' => 'xx.yy', [ 'xx.zip' => 'b3', 'c3', [ 'xx.zip' => 'x4', 'y4', 'z4'] ], 'd3' ],
           'def1',
         ]);

    my $lexd = new PushLexDir();

    runNestedUnzip(qq[ --1ist-as-extracted -j  $zipfile  ], <<"EOM");
Archive: $zipfile
abc1
def.zip
a2
b2
c2
ghi.zip
xx.yy
xx.zip
b3
c3
xx.zip
x4
y4
z4
d3
def1
EOM

    is_deeply getOutputTree('.'), [], "Directory tree ok" ;

    {
        title "Junk - - default remove the lot";

        my $extractDir ;
        my $lex2 = new LexDir $extractDir;

        chdir($extractDir);

        runNestedUnzip(qq[ -j $zipfile ]);

        my $got = getOutputTreeAndData('.') ;
        my $expectedPayloads = {
                nameAndPayloadFil('abc1'),
                nameAndPayloadFil('a2', 'def.zip.nested/a2'),
                nameAndPayloadFil('b2', 'def.zip.nested/b2'),
                nameAndPayloadFil('c2', 'def.zip.nested/c2'),
                nameAndPayloadFil('xx.yy', 'ghi.zip.nested/xx.yy'),
                nameAndPayloadFil('b3', 'ghi.zip.nested/xx.zip.nested/b3'),
                nameAndPayloadFil('c3', 'ghi.zip.nested/xx.zip.nested/c3'),
                nameAndPayloadFil('x4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/x4'),
                nameAndPayloadFil('y4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/y4'),
                nameAndPayloadFil('z4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/z4'),
                nameAndPayloadFil('d3', 'ghi.zip.nested/d3'),
                nameAndPayloadFil('def1')

        };

        is_deeply $got, $expectedPayloads, "Directory tree ok"
            or diag "Got [ " . join (" ", keys (%$got)) . " ]";
    }


    {
        title "Junk  -j1";

        my $extractDir ;
        my $lex2 = new LexDir $extractDir;

        chdir($extractDir);

        runNestedUnzip(qq[ -j 1 $zipfile ]);

        my $got = getOutputTreeAndData('.') ;
        my $expectedPayloads = {
                nameAndPayloadFil('abc1'),
                nameAndPayloadFil('a2', 'def.zip.nested/a2'),
                nameAndPayloadFil('b2', 'def.zip.nested/b2'),
                nameAndPayloadFil('c2', 'def.zip.nested/c2'),
                nameAndPayloadFil('xx.yy', 'ghi.zip.nested/xx.yy'),
                nameAndPayloadDir('xx.zip.nested'),
                nameAndPayloadFil('xx.zip.nested/b3', 'ghi.zip.nested/xx.zip.nested/b3'),
                nameAndPayloadFil('xx.zip.nested/c3', 'ghi.zip.nested/xx.zip.nested/c3'),
                nameAndPayloadDir('xx.zip.nested/xx.zip.nested'),
                nameAndPayloadFil('xx.zip.nested/xx.zip.nested/x4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/x4'),
                nameAndPayloadFil('xx.zip.nested/xx.zip.nested/y4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/y4'),
                nameAndPayloadFil('xx.zip.nested/xx.zip.nested/z4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/z4'),
                nameAndPayloadFil('d3', 'ghi.zip.nested/d3'),
                nameAndPayloadFil('def1')

        };


        is_deeply $got, $expectedPayloads, "Directory tree ok"
            or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
    }


    {
        title "Junk  -j2";

        my $extractDir ;
        my $lex2 = new LexDir $extractDir;

        chdir($extractDir);

        runNestedUnzip(qq[ -j2 $zipfile ]);

        my $got = getOutputTreeAndData('.') ;
        my $expectedPayloads = {
                nameAndPayloadFil('abc1'),
                nameAndPayloadFil('a2', 'def.zip.nested/a2'),
                nameAndPayloadFil('b2', 'def.zip.nested/b2'),
                nameAndPayloadFil('c2', 'def.zip.nested/c2'),
                nameAndPayloadFil('xx.yy', 'ghi.zip.nested/xx.yy'),
                nameAndPayloadFil('b3', 'ghi.zip.nested/xx.zip.nested/b3'),
                nameAndPayloadFil('c3', 'ghi.zip.nested/xx.zip.nested/c3'),
                nameAndPayloadDir('xx.zip.nested'),
                nameAndPayloadFil('xx.zip.nested/x4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/x4'),
                nameAndPayloadFil('xx.zip.nested/y4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/y4'),
                nameAndPayloadFil('xx.zip.nested/z4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/z4'),
                nameAndPayloadFil('d3', 'ghi.zip.nested/d3'),
                nameAndPayloadFil('def1')

        };


        is_deeply $got, $expectedPayloads, "Directory tree ok"
            or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
    }


    {
        title "Junk  -j3";

        my $extractDir ;
        my $lex2 = new LexDir $extractDir;

        chdir($extractDir);

        runNestedUnzip(qq[ -j3 $zipfile ]);

        my $got = getOutputTreeAndData('.') ;
        my $expectedPayloads = {
                nameAndPayloadFil('abc1'),
                nameAndPayloadFil('a2', 'def.zip.nested/a2'),
                nameAndPayloadFil('b2', 'def.zip.nested/b2'),
                nameAndPayloadFil('c2', 'def.zip.nested/c2'),
                nameAndPayloadFil('xx.yy', 'ghi.zip.nested/xx.yy'),
                nameAndPayloadFil('b3', 'ghi.zip.nested/xx.zip.nested/b3'),
                nameAndPayloadFil('c3', 'ghi.zip.nested/xx.zip.nested/c3'),
                nameAndPayloadFil('x4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/x4'),
                nameAndPayloadFil('y4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/y4'),
                nameAndPayloadFil('z4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/z4'),
                nameAndPayloadFil('d3', 'ghi.zip.nested/d3'),
                nameAndPayloadFil('def1')

        };
        #    'abc1',
        #    [ 'def.zip' => 'a2', 'b2', 'c2' ],
        #    [ 'ghi.zip' => 'xx.yy', [ 'xx.zip' => 'b3', 'c3', [ 'xx.zip' => 'x4', 'y4', 'z4'] ], 'd3' ],
        #    'def1',

        is_deeply $got, $expectedPayloads, "Directory tree ok"
            or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
    }


    {
        title "Junk  -j4";

        my $extractDir ;
        my $lex2 = new LexDir $extractDir;

        chdir($extractDir);

        runNestedUnzip(qq[ --junk-dirs 4 $zipfile ]);

        my $got = getOutputTreeAndData('.') ;
        my $expectedPayloads = {
                nameAndPayloadFil('abc1'),
                nameAndPayloadFil('a2', 'def.zip.nested/a2'),
                nameAndPayloadFil('b2', 'def.zip.nested/b2'),
                nameAndPayloadFil('c2', 'def.zip.nested/c2'),
                nameAndPayloadFil('xx.yy', 'ghi.zip.nested/xx.yy'),
                nameAndPayloadFil('b3', 'ghi.zip.nested/xx.zip.nested/b3'),
                nameAndPayloadFil('c3', 'ghi.zip.nested/xx.zip.nested/c3'),
                nameAndPayloadFil('x4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/x4'),
                nameAndPayloadFil('y4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/y4'),
                nameAndPayloadFil('z4', 'ghi.zip.nested/xx.zip.nested/xx.zip.nested/z4'),
                nameAndPayloadFil('d3', 'ghi.zip.nested/d3'),
                nameAndPayloadFil('def1')

        };
        #    'abc1',
        #    [ 'def.zip' => 'a2', 'b2', 'c2' ],
        #    [ 'ghi.zip' => 'xx.yy', [ 'xx.zip' => 'b3', 'c3', [ 'xx.zip' => 'x4', 'y4', 'z4'] ], 'd3' ],
        #    'def1',

        is_deeply $got, $expectedPayloads, "Directory tree ok"
            or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
    }
}

sub getNativeLocale
{
    my $enc;

    eval
    {
        require encoding ;
        my $encoding = encoding::_get_locale_encoding() ;
        $enc = Encode::find_encoding($encoding) ;
    } ;

    return $enc;
}

SKIP:
{
    title "Filename encoding cp850 -> utf8";

    # Only run if OS locale is UTF-8
    skip "Locale is not UTF-8", 7
        unless $locale && $locale->name =~ /^utf-8/i ;

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "valid-cp850.zip";

    my $extractDir ;
    my $lex2 = new LexDir $extractDir;

    chdir($extractDir);

    my $name = "Caf\N{LATIN SMALL LETTER E WITH ACUTE} Society" ;
    my $encodedName = Encode::encode('UTF-8', $name);

    my ($ok, $stdout) = check("$Perl $nestedUnzip -lq --input-filename-encoding cp850 $zipfile" );

    ok $ok;
    is $stdout, $encodedName ."\n" ;


    runNestedUnzip(qq[ --input-filename-encoding cp850 $zipfile ]);
    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
            nameAndPayloadFil($encodedName, " "),
    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
}


SKIP:
{
    title "Filename encoding utf8 -> utf8";

    # Only run if OS locale is UTF-8
    skip "Locale is not UTF-8", 7
        unless $locale && $locale->name =~ /^utf-8/i ;

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "valid-utf8-efs.zip";

    my $extractDir ;
    my $lex2 = new LexDir $extractDir;

    chdir($extractDir);

    my $name =  "\N{GREEK SMALL LETTER ALPHA}".
                "\N{GREEK SMALL LETTER BETA}".
                "\N{GREEK SMALL LETTER GAMMA}".
                "\N{GREEK SMALL LETTER DELTA}" ;
    my $encodedName = Encode::encode('UTF-8', $name);

    my ($ok, $stdout) = check("$Perl $nestedUnzip -lq $zipfile" );

    ok $ok;
    is $stdout, $encodedName ."\n" ;

    runNestedUnzip(qq[ $zipfile ]);
    my $got = getOutputTreeAndData('.') ;

    my $expectedPayloads = {
            nameAndPayloadFil($encodedName, " "),
    };

    is_deeply $got, $expectedPayloads, "Directory tree ok"
        or diag "Got [ " . join (" ", sort keys (%$got)) . " ]";
}

SKIP:
{
    title "Filename encoding cp850 -> cp850";

    my $locale = getNativeLocale();

    # Only run if OS locale is UTF-8
    skip "Local is not UTF-8", 5
        unless $locale && $locale->name =~ /^utf-8/i ;

    my $filesDir = "$HERE/t/files/";
    my $zipfile = $filesDir . "valid-cp850.zip";

    my $extractDir ;
    my $lex2 = new LexDir $extractDir;

    chdir($extractDir);

    my $name = "Caf\N{LATIN SMALL LETTER E WITH ACUTE} Society" ;
    my $encodedName = Encode::encode('cp850', $name);

    my ($ok, $stdout) = check("$Perl $nestedUnzip -lq --input-filename-encoding cp850 --output-filename-encoding cp850 $zipfile" );

    ok $ok;
    is $stdout, $encodedName ."\n" ;
}
