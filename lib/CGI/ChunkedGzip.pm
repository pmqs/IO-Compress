package CGI::ChunkedGzip;

use strict;
use warnings;

require Tie::Handle;
@ISA = qw(Tie::Handle);

sub enable
{
    my $readSTDOUT


    tie \*STDOUT, 'CGI::ChunkedGzip', $gzip;
}


sub TIEHANDLE
{
    my $gzip = new IO::Gzip \$buffer, Minimal => 1;
}

sub WRITE
{
    my $self = shift ;
    my $gzip = ??

    print pack("", $length), "\r\n";
    
}

sub CLOSE
{
    my $self = shift ;
    print "0\r\n";
}

sub DESTROY
{
    my $self = shift ;
    $self->CLOSE();
}

sub outputLastChunk
{
    print "0\r\n\r\n";
}
sub outputChunk
{
    printf "%X\r\n$_[0]\r\n", length($_[0]) if length $_[0];
}

1;
