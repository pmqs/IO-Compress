
use warnings;
use strict;

use IO::Uncompress::Unzip qw($UnzipError);

my $zipfile = "mf.zip";

my $transparent = 1;

my $u = new IO::Uncompress::Unzip $zipfile, Transparent => $transparent
    or die "Cannot open $zipfile: $UnzipError";

my $status;
for ($status = 1; $status > 0; $status = $u->nextStream())
{
    my $name = $u->getHeaderInfo()->{Name};
    warn "Processing member $name\n" ;
}

die "Error processing $zipfile: $!\n"
    if $status < 0 ;

