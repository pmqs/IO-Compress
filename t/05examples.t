
use lib 't';

use strict;
local ($^W) = 1; #use warnings;
# use bytes;

use Test::More ;
use MyTestUtils;

BEGIN 
{ 
    plan(skip_all => "Examples needs Perl 5.005 or better - you have Perl $]" )
        if $] < 5.005 ;
    
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 25 + $extra ;
}


my $Inc = join " ", map qq["-I$_"] => @INC;
 
my $Perl = '' ;
$Perl = ($ENV{'FULLPERL'} or $^X or 'perl') ;
$Perl = qq["$Perl"] if $^O eq 'MSWin32' ;
 
$Perl = "$Perl -w" ;
my $examples = $ENV{PERL_CORE} ? "../ext/Compress/Zlib/examples" : "./examples";

my $hello1 = <<EOM ;
hello
this is 
a test
message
x ttttt
xuuuuuu
the end
EOM

my @hello1 = grep(s/$/\n/, split(/\n/, $hello1)) ;

my $hello2 = <<EOM;

Howdy
this is the
second
file
x ppppp
xuuuuuu
really the end
EOM

my @hello2 = grep(s/$/\n/, split(/\n/, $hello2)) ;




# gzcat
# #####

my $file1 = "hello1.gz" ;
my $file2 = "hello2.gz" ;

unlink $file1, $file2 ;

my $hello1_uue = <<'EOM';
M'XL("(W#+3$" VAE;&QO,0#+2,W)R><JR<@L5@ BKD2%DM3B$J[<U.+BQ/14
;K@J%$A#@JB@% Z"Z5(74O!0N &D:".,V    
EOM

my $hello2_uue = <<'EOM';
M'XL("*[#+3$" VAE;&QO,@#C\L@O3ZGD*LG(+%8 HI*,5*[BU.3\O!2NM,R<
A5*X*A0(0X*HH!0.NHM3$G)Q*D#*%5* : #) E6<^    
EOM

# Write a test .gz file
{
    #local $^W = 0 ;
    writeFile($file1, unpack("u", $hello1_uue)) ;
    writeFile($file2, unpack("u", $hello2_uue)) ;
}

 
title "gzcat.zlib" ;
$a = `$Perl $Inc ${examples}/gzcat.zlib $file1 $file2 2>&1` ;

is $?, 0, "  exit status is 0" ;
is $a, $hello1 . $hello2, "  content is ok" ;

title "gzcat - command line" ;
$a = `$Perl $Inc ${examples}/gzcat $file1 $file2 2>&1` ;

is $?, 0, "  exit status is 0" ;
is $a, $hello1 . $hello2, "  content is ok";

title "gzcat - stdin" ;
$a = `$Perl $Inc ${examples}/gzcat <$file1 2>&1` ;

is $?, 0, "  exit status is 0" ;
is $a, $hello1, "  content is ok";


# gzgrep
# ######

title "gzgrep";
$a = ($^O eq 'MSWin32' || $^O eq 'VMS'
     ? `$Perl $Inc ${examples}/gzgrep "^x" $file1 $file2 2>&1`
     : `$Perl $Inc ${examples}/gzgrep '^x' $file1 $file2 2>&1`) ;
is $?, 0, "  exit status is 0" ;

is $a, join('', grep(/^x/, @hello1, @hello2)), "  content is ok" ;


unlink $file1, $file2 ;


# filtdef/filtinf
# ##############


my $stderr = "err.out" ;
unlink $stderr ;
writeFile($file1, $hello1) ;
writeFile($file2, $hello2) ;

title "filtdef" ;
# there's no way to set binmode on backticks in Win32 so we won't use $a later
$a = `$Perl $Inc ${examples}/filtdef $file1 $file2 2>$stderr` ;
is $?, 0, "  exit status is 0" ;
is -s $stderr, 0, "  no stderr" ;

unlink $stderr;

title "filtdef | filtinf";
$a = `$Perl $Inc ${examples}/filtdef $file1 $file2 | $Perl $Inc ${examples}/filtinf 2>$stderr`;
is $?, 0, "  exit status is 0" ;
is -s $stderr, 0, "  no stderr" ;
is $a, $hello1 . $hello2, "  content is ok";

# gzstream
# ########

{
    title "gzstream" ;
    writeFile($file1, $hello1) ;
    $a = `$Perl $Inc ${examples}/gzstream <$file1 >$file2 2>$stderr` ;
    is $?, 0, "  exit status is 0" ;
    is -s $stderr, 0, "  no stderr" ;

    title "gzcat" ;
    my $b = `$Perl $Inc ${examples}/gzcat $file2 2>&1` ;
    is $?, 0, "  exit status is 0" ;
    is $b, $hello1, "  content is ok" ;
    #print "? = $? [$b]\n";
}


END
{
    for ($file1, $file2, $stderr) { 1 while unlink $_ } ;
}

