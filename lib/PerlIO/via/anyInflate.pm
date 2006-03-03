package PerlIO::via::anyInflate ;

use strict;
use warnings;

use IO::AnyInflate ;

sub PUSHED 
{
    my ($class, $mode, $fh) = @_;

    return -1
        if $mode ne 'r';

    my $buffer ;    
    
    return bless { inflate => undef, buffer => \$buffer }, $class;
}


sub FILL 
{
    my ($self, $fh) = @_;

    read($fh, ${ $self->{buffer} }, 1024 * 16)
        or return undef ;

    if (! defined $self->{inflate})
    {
        $self->{inflate} = new IO::AnyInflate($self->{buffer}, Transparent => 1)
            or return undef ;
    }

    my $out ;
    $self->{inflate}->read($out)
        or return undef ;

    return $out ;
}

1;
