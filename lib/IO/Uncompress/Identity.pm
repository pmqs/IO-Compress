
package IO::Uncompress::Identity;


package IO::Uncompress::Identity::Plugin ;

use strict ;
use warnings;
use bytes;
our ($VERSION, @ISA, @EXPORT);
@ISA = qw(IO::Uncompress::Adapter::Identity);

1;

package IO::Uncompress::Adapter::Identity;

use strict ;
use warnings;

our ($VERSION, @ISA, @EXPORT);

$VERSION = '2.000_05';


sub mkUncompObject
{
    my $class = shift ;

    bless { 'CompSize'   => 0,
            'UnCompSize' => 0,
            'CRC32'      => 0,
            'ADLER32'    => 0,
          }, $class ;
}

sub uncompress
{
    my $self = shift;

    $self->{CompSize} += length $_[0] ;
    $self->{UnCompSize} = $self->{CompSize} ;

    $_[1] .= $_[0];

    return STATUS_ENDSTREAM if $outer->smartEof()
    return RETURN_OK ;
}

sub count
{
    my $self = shift ;
    return $self->{UnCompSize} ;
}

sub sync
{
    return RETURN_OK ;
}


sub reset
{
    return RETURN_OK ;
}


1;

package IO::Uncompress::Identity;
 1;

__END__
