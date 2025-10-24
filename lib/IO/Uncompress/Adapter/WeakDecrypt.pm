package IO::Uncompress::Adapter::WeakDecrypt;

use warnings;
use strict;
use bytes;


use IO::Compress::Base::Common  2.214 qw(:Status);
use IO::Compress::Zip::Constants ;

our ($VERSION);

$VERSION = '2.214';

sub mkDecryptObject
{
    my $inner = shift;
    my $decrypt = shift;

    my $crc32 = 1; #shift ;
    my $adler32 = shift;

    bless { #'CompSize'   => U64->new(), # 0,
            #'UnCompSize' => 0,
            #'wantCRC32'  => $crc32,
            # 'CRC32'      => Compress::Raw::Zlib::crc32(''),
            #'wantADLER32'=> $adler32,
            # 'ADLER32'    => Compress::Raw::Zlib::adler32(''),
            #'ConsumesInput' => 1,
            # 'Streaming'  => $streaming,
            # 'Zip64'      => $zip64,
            # 'DataHdrSize'  => $zip64 ? 24 :  16,
            # 'Pending'   => '',

            'Inner'     => $inner,
            'Decrypt'   => $decrypt,

          } ;
}


sub uncompr
{
    my $self = shift ;
    my $from = shift ;
    my $to   = shift ;
    my $eof  = shift ;

    my $encrypted ;
use Data::Peek;
#  DHexDump ($$from);
# warn "\n\nINNER compressed \n"; DHexDump ($$from);

    my $status = $self->{Inner}->uncompr($from, $to, $eof);
# warn "OUTER uncompressed \n"; DHexDump ($$to);

# use Compress::Raw::Zlib  2.214 qw(Z_OK Z_BUF_ERROR Z_STREAM_END );

    # TODO - need to understand status from other compressors like bzip2, identiry etc
    return $status
        # unless  $status == STATUS_OK || $status == STATUS_ENDSTREAM ;
        unless  $status == STATUS_OK  ;

    # $$from = '';

    if (length $$to)
    {
        $$to = $self->{Decrypt}->decode($to, 0) ;
#  warn "decrypted :" . $self->{Decrypt}->getError() . "\n" ; DHexDump ($$to);

        $self->{Error} = $self->{Decrypt}->getError();
        $self->{ErrorNo} = $self->{Decrypt}->getErrorNo() ;
    }
    else
    {
        die "EMPTY"
    }

        # if (length $$in) {
        #     $self->{CompSize}->add(length $$in) ;

        #     $self->{CRC32} = Compress::Raw::Zlib::crc32($$in,  $self->{CRC32})
        #         if $self->{wantCRC32};

        #     $self->{ADLER32} = Compress::Zlib::adler32($$in,  $self->{ADLER32})
        #         if $self->{wantADLER32};
        # }

        # ${ $_[1] } .= $$in;
        # $$in  = $remainder;

# warn "stXXXXX Status " unless defined $$to;


    # return STATUS_ERROR unless defined $$to;
    return $status;
    # return STATUS_ENDSTREAM if $eof;
    # return STATUS_OK ;
}

sub reset
{
    my $self = shift;

    $self->{Inner}->reset();

    return STATUS_OK ;
}

#sub count
#{
#    my $self = shift ;
#    return $self->{UnCompSize} ;
#}

sub compressedBytes
{
    my $self = shift ;
    return $self->{Inner}->{CompSize} ;
}

sub uncompressedBytes
{
    my $self = shift ;
    return $self->{Inner}->{CompSize} ;
}

sub sync
{
    return STATUS_OK ;
}

sub crc32
{
    my $self = shift ;
    return $self->{Inner}->{CRC32};
}

sub adler32
{
    my $self = shift ;
    return $self->{Inner}->{ADLER32};
}


1;

__END__
