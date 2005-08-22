
package Compress::Gzip::Info ;

use strict ;
local ($^W) = 1; #use warnings;
use Carp ;

use Compress::Gzip::Constants;

our $NULL = pack("C", 0) ;

sub CloseAndRet
{
    my $keep = $! ;
    close F ;
    $! = $keep ;
    return undef ;
}

sub isZlibFormat($)
{
    my $data = shift ; 

    my $hdr = unpack("n", $data) ;

    return ($hdr % 31 == 0);
}

# Constant names derived from RFC 1950

use constant ZLIB_HEADER_SIZE       => 2;
use constant ZLIB_TRAILER_SIZE      => 4;

use constant ZLIB_CMF_CM_OFFSET     => 0;
use constant ZLIB_CMF_CM_BITS       => 0b1111;

use constant ZLIB_CMF_CINFO_OFFSET  => 4;
use constant ZLIB_CMF_CINFO_BITS    => 0b1111;

use constant ZLIB_FLG_FCHECK_OFFSET => 0;
use constant ZLIB_FLG_FCHECK_BITS   => 0b11111;

use constant ZLIB_FLG_FDICT_OFFSET  => 5;
use constant ZLIB_FLG_FDICT_BITS    => 0b1;

use constant ZLIB_FLG_LEVEL_OFFSET  => 6;
use constant ZLIB_FLG_LEVEL_BITS    => 0b11;

use constant ZLIB_FDICT_SIZE        => 4;

sub bits
{
    my $data   = shift ;
    my $offset = shift ;
    my $mask  = shift ;


    ($data >> $offset ) & $mask & 0xFF ;
}


sub ZlibInfo
{
    my $data = shift ; 

    return undef unless isZlibFormat($data);

    return undef if length $data < ZLIB_HEADER_SIZE ;
    my ($CMF, $FLG) = unpack "C C", $data;
    my $FDICT = vec($FLG, ZLIB_FLG_FDICT_OFFSET, ZLIB_FLG_FDICT_BITS);

    my $DICTID;
    if ($FDICT) {
        return undef if length $data < ZLIB_HEADER_SIZE + ZLIB_FDICT_SIZE;
        my $dummy;
        ($dummy, $DICTID) = unpack("n N", $data) ;
    }

    return (
        CMF     =>      $CMF                                               ,
        CM      => bits($CMF, ZLIB_CMF_CM_OFFSET,     ZLIB_CMF_CM_BITS    ),
        CINFO   => bits($CMF, ZLIB_CMF_CINFO_OFFSET,  ZLIB_CMF_CINFO_BITS ),
        FLG     =>      $FLG                                               ,
        FCHECK  => bits($FLG, ZLIB_FLG_FCHECK_OFFSET, ZLIB_FLG_FCHECK_BITS),
        FDICT   => bits($FLG, ZLIB_FLG_FDICT_OFFSET,  ZLIB_FLG_FDICT_BITS ),
        FLEVEL  => bits($FLG, ZLIB_FLG_LEVEL_OFFSET,  ZLIB_FLG_LEVEL_BITS ),
        DICT    =>      $DICTID                                            ,
            
        );

}

sub isGZ($)
{
    my ($filename) = @_ ;
    my ($buffer) = '' ;

    open(F, "<$filename") or return undef ;

    read(F, $buffer, GZIP_MIN_HEADER_SIZE) == GZIP_MIN_HEADER_SIZE 
        or return CloseAndRet() ;

    # now split out the various parts
    my ($id1, $id2, $cm, $flag, $mtime, $xfl, $os) = 
            unpack("C C C C V C C", $buffer) ;

    close F ; 

    return ($id1 == GZIP_ID1 and $id2 == GZIP_ID2 
                and $cm == GZIP_CM_DEFLATED and !eof(F) )  ;
}

sub GzInfo($)
{
    my ($filename) = @_ ;
    my ($origname, $comment, $XLEN, $HeaderCRC) ;
    my ($buffer) = "" ;
    my ($keep) ;

    open(F, "<$filename") or return undef ;

    read(F, $buffer, GZIP_MIN_HEADER_SIZE) == GZIP_MIN_HEADER_SIZE 
        or return CloseAndRet() ;

    # now split out the various parts
    my ($id1, $id2, $cm, $flag, $mtime, $xfl, $os) = 
            unpack("C C C C V C C", $buffer) ;

my $dat = localtime $mtime ;
print <<EOM if 0 ;
id1     $id1
id2     $id2
cm      $cm
flag    $flag
mtime   $mtime $dat
xfl     $xfl
os      $os $GZIP_OS_Names{$os}

EOM
    ($id1 == GZIP_ID1 and $id2 == GZIP_ID2 
                and $cm == GZIP_CM_DEFLATED and !eof(F) ) or return CloseAndRet() ; 

    if ($flag & GZIP_FLG_FEXTRA) {
        read(F, $buffer, GZIP_FEXTRA_HEADER_SIZE) == GZIP_FEXTRA_HEADER_SIZE or return CloseAndRet() ;

        $XLEN = unpack("v", $buffer) ;
        seek (F, $XLEN, 1) or return CloseAndRet() ;
    }

    $origname = "" ;
    if ($flag & GZIP_FLG_FNAME) {
        $origname .= $buffer 
            while read(F, $buffer,1) == 1 and $buffer ne $NULL ;
    }

    if ($flag & GZIP_FLG_FCOMMENT) {
        $comment .= $buffer 
            while read(F, $buffer,1) == 1 and $buffer ne $NULL ;
    }

    if ($flag & GZIP_FLG_FHCRC) {
        read(F, $buffer, GZIP_FHCRC_SIZE) == GZIP_FHCRC_SIZE or return CloseAndRet() ;
        $HeaderCRC = unpack("v", $buffer) ;
    }

    # Assume compression method is deflated for xfl tests
    if ($xfl) {
#print "Max Compression, Slowest\n" if $xfl & 2 ;
#print "Fast Compression\n" if $xfl & 4 ;
    }

    # seek to eof - 8
    seek(F, -8, 2) or return CloseAndRet() ;
    read(F, $buffer, 8) == 8 or return CloseAndRet() ;

    my ($CRC32, $ISIZE) = unpack("V V", $buffer) ;
    my $compsize = (stat F) [7] ;
   
    close F ;

    return {
        'Method'    => $cm == GZIP_CM_DEFLATED ? "Deflated" : "Unknown" ,
        'Type'      => $flag & GZIP_FLG_FTEXT ? "Text" : "Binary" ,
        'Name'      => $origname,
        'Comment'   => $comment,
        'CompSize'  => $compsize,
        'Time'      => $mtime,
        'OsId'      => $os,
        'OsName'    => defined $GZIP_OS_Names{$os} ? $GZIP_OS_Names{$os} : "Unknown",
        'HeaderCRC' => $HeaderCRC,

        'CRC'       => $CRC32,
        'OrigSize'  => $ISIZE,
      }
}

1 ;
__END__


