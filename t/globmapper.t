
use lib 't';
use strict ;
local ($^W) = 1; #use warnings ;

use Test::More ;
use MyTestUtils;


BEGIN 
{ 
    plan(skip_all => "File::GlobMapper needs Perl 5.005 or better - you have
Perl $]" )
        if $] < 5.005 ;

    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 68 + $extra ;

    use_ok('File::GlobMapper') ; 
}

{
    title "Error Cases" ;

    my $gm;

    for my $delim ( qw/ ( ) { } [ ] / )
    {
        $gm = new File::GlobMapper("${delim}abc", '*.X');
        ok ! $gm, "  new failed" ;
        is $File::GlobMapper::Error, "Unmatched $delim in input fileglob", 
            "  catch unmatched $delim";
    }

    for my $delim ( qw/ ( ) [ ] / )
    {
        $gm = new File::GlobMapper("{${delim}abc}", '*.X');
        ok ! $gm, "  new failed" ;
        is $File::GlobMapper::Error, "Unmatched $delim in input fileglob", 
            "  catch unmatched $delim inside {}";
    }

    
}

{
    title "input glob matches zero files";

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;

    my $gm = new File::GlobMapper("$tmpDir/*", '*.X');
    ok $gm, "  created GlobMapper object" ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 0, "  returned 0 maps";
    is_deeply $map, [], " zero maps" ;

    my $hash = $gm->getHash() ;
    is_deeply $hash, {}, "  zero maps" ;
}

{
    title 'test wildcard mapping of * in destination';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $gm = new File::GlobMapper("$tmpDir/ab*", "*.X");
    ok $gm, "  created GlobMapper object" ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 3, "  returned 3 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 abc1.X)],
          [map { "$tmpDir/$_" } qw(abc2 abc2.X)],
          [map { "$tmpDir/$_" } qw(abc3 abc3.X)],
        ], "  got mapping";

    my $hash = $gm->getHash() ;
    is_deeply $hash,
        { map { "$tmpDir/$_" } qw(abc1 abc1.X
                                  abc2 abc2.X
                                  abc3 abc3.X),
        }, "  got mapping";
}

{
    title 'no wildcards in input or destination';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $gm = new File::GlobMapper("$tmpDir/abc2", "$tmpDir/abc2");
    ok $gm, "  created GlobMapper object" ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 1, "  returned 1 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc2 abc2)],
        ], "  got mapping";

    my $hash = $gm->getHash() ;
    is_deeply $hash,
        { map { "$tmpDir/$_" } qw(abc2 abc2),
        }, "  got mapping";
}

{
    title 'test wildcard mapping of {} in destination';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $gm = new File::GlobMapper("$tmpDir/abc{1,3}", "*.X");
    #diag "Input pattern is $gm->{InputPattern}";
    ok $gm, "  created GlobMapper object" ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 2, "  returned 2 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 abc1.X)],
          [map { "$tmpDir/$_" } qw(abc3 abc3.X)],
        ], "  got mapping";

    $gm = new File::GlobMapper("$tmpDir/abc{1,3}", "$tmpDir/X.#1.X")
        or diag $File::GlobMapper::Error ;
    #diag "Input pattern is $gm->{InputPattern}";
    ok $gm, "  created GlobMapper object" ;

    $map = $gm->getFileMap() ;
    is @{ $map }, 2, "  returned 2 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 X.1.X)],
          [map { "$tmpDir/$_" } qw(abc3 X.3.X)],
        ], "  got mapping";

}


{
    title 'test wildcard mapping of multiple * to #';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $gm = new File::GlobMapper("$tmpDir/*b(*)", "$tmpDir/X-#2-#1-X");
    ok $gm, "  created GlobMapper object" 
        or diag $File::GlobMapper::Error ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 3, "  returned 3 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 X-c1-a-X)],
          [map { "$tmpDir/$_" } qw(abc2 X-c2-a-X)],
          [map { "$tmpDir/$_" } qw(abc3 X-c3-a-X)],
        ], "  got mapping";
}

{
    title 'test wildcard mapping of multiple ? to #';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $gm = new File::GlobMapper("$tmpDir/?b(*)", "$tmpDir/X-#2-#1-X");
    ok $gm, "  created GlobMapper object" ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 3, "  returned 3 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 X-c1-a-X)],
          [map { "$tmpDir/$_" } qw(abc2 X-c2-a-X)],
          [map { "$tmpDir/$_" } qw(abc3 X-c3-a-X)],
        ], "  got mapping";
}

{
    title 'test wildcard mapping of multiple ?,* and [] to #';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $gm = new File::GlobMapper("$tmpDir/?b[a-z]*", "$tmpDir/X-#3-#2-#1-X");
    ok $gm, "  created GlobMapper object" ;

    #diag "Input pattern is $gm->{InputPattern}";
    my $map = $gm->getFileMap() ;
    is @{ $map }, 3, "  returned 3 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 X-1-c-a-X)],
          [map { "$tmpDir/$_" } qw(abc2 X-2-c-a-X)],
          [map { "$tmpDir/$_" } qw(abc3 X-3-c-a-X)],
        ], "  got mapping";
}

{
    title 'input glob matches a file multiple times';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch "$tmpDir/abc";

    my $gm = new File::GlobMapper("$tmpDir/{a*,*c}", '*.X');
    ok $gm, "  created GlobMapper object" ;

    my $map = $gm->getFileMap() ;
    is @{ $map }, 1, "  returned 1 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc abc.X)], ], "  got mapping";

    my $hash = $gm->getHash() ;
    is_deeply $hash,
        { map { "$tmpDir/$_" } qw(abc abc.X) }, "  got mapping";

}

{
    title 'multiple input files map to one output file';

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc def) ;

    my $gm = new File::GlobMapper("$tmpDir/*", "$tmpDir/fred");
    ok ! $gm, "  did not create GlobMapper object" ;

    is $File::GlobMapper::Error, 'multiple input files map to one output file', "  Error is expected" ;

    #my $map = $gm->getFileMap() ;
    #is @{ $map }, 1, "  returned 1 maps";
    #is_deeply $map,
    #[ [map { "$tmpDir/$_" } qw(abc1 abc.X)], ], "  got mapping";
}

{
    title "globmap" ;

    my $tmpDir = 'td';
    my $lex = new LexDir $tmpDir;
    mkdir $tmpDir, 0777 ;

    touch map { "$tmpDir/$_" } qw( abc1 abc2 abc3 ) ;

    my $map = File::GlobMapper::globmap("$tmpDir/*b*", "$tmpDir/X-#2-#1-X");
    ok $map, "  got map" 
        or diag $File::GlobMapper::Error ;

    is @{ $map }, 3, "  returned 3 maps";
    is_deeply $map,
        [ [map { "$tmpDir/$_" } qw(abc1 X-c1-a-X)],
          [map { "$tmpDir/$_" } qw(abc2 X-c2-a-X)],
          [map { "$tmpDir/$_" } qw(abc3 X-c3-a-X)],
        ], "  got mapping";
}

# input & output glob with no wildcards is ok
# input with no wild or output with no wild is bad
# input wild has concatenated *'s
# empty string for either both from & to
# escaped chars within [] and {}, including the chars []{}
# escaped , within {}
# missing ] and missing }
# {} and {,} are special cases
# {ab*,de*}
# {abc,{},{de,f}} => abc {} de f

