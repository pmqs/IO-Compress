package MyTestUtils;

package main ;

use strict ;
local ($^W) = 1; #use warnings;

use Carp ;


sub title
{
    #diag "" ; 
    ok 1, $_[0] ;
    #diag "" ;
}

sub like_eval
{
    like $@, @_ ;
}

{
    package LexFile ;

    use vars qw($index);
    $index = '00000';
    
    sub new
    {
        my $self = shift ;
        foreach (@_)
        {
            # autogenerate the name unless if none supplied
            $_ = "tst" . $index ++ . ".tmp"
                unless defined $_;
        }
        unlink @_ ;
        bless [ @_ ], $self ;
    }

    sub DESTROY
    {
        my $self = shift ;
        unlink @{ $self } ;
    }

}

{
    package LexDir ;

    use File::Path;
    sub new
    {
        my $self = shift ;
        foreach (@_) { rmtree $_ }
        bless [ @_ ], $self ;
    }

    sub DESTROY
    {
        my $self = shift ;
        foreach (@$self) { rmtree $_ }
    }
}
sub readFile
{
    my $f = shift ;

    my @strings ;

    if (Compress::Zlib::Common::isaFilehandle($f))
    {
        my $pos = tell($f);
        seek($f, 0,0);
        @strings = <$f> ;	
        seek($f, 0, $pos);
    }
    else
    {
        open (F, "<$f") 
            or die "Cannot open $f: $!\n" ;
        @strings = <F> ;	
        close F ;
    }

    return @strings if wantarray ;
    return join "", @strings ;
}

sub touch
{
    foreach (@_) { writeFile($_, '') }
}

sub writeFile
{
    my($filename, @strings) = @_ ;
    open (F, ">$filename") 
        or die "Cannot open $filename: $!\n" ;
    binmode F;
    foreach (@strings) {
        local ($^W) = 0; #no warnings ;
        print F $_ ;
    }
    close F ;
}

sub GZreadFile
{
    my ($filename) = shift ;

    my ($uncomp) = "" ;
    my $line = "" ;
    my $fil = gzopen($filename, "rb") 
        or die "Cannopt open '$filename': $Compress::Zlib::gzerrno" ;

    $uncomp .= $line 
        while $fil->gzread($line) > 0;

    $fil->gzclose ;
    return $uncomp ;
}

sub hexDump
{
    my $d = shift ;

    if (Compress::Zlib::Common::isaFilehandle($d))
    {
        $d = readFile($d);
    }
    elsif (Compress::Zlib::Common::isaFilename($d))
    {
        $d = readFile($d);
    }
    else
    {
        $d = $$d ;
    }

    my $offset = 0 ;

    $d = '' unless defined $d ;
    #while (read(STDIN, $data, 16)) {
    while (my $data = substr($d, 0, 16)) {
        substr($d, 0, 16) = '' ;
        printf "# %8.8lx    ", $offset;
        $offset += 16;

        my @array = unpack('C*', $data);
        foreach (@array) {
            printf('%2.2x ', $_);
        }
        print "   " x (16 - @array)
            if @array < 16 ;
        $data =~ tr/\0-\37\177-\377/./;
        print "  $data\n";
    }

}

sub readHeaderInfo
{
    my $name = shift ;
    my %opts = @_ ;

    my $string = <<EOM;
some text
EOM

    ok my $x = new IO::Gzip $name, %opts 
        or diag "GzipError is $IO::Gzip::GzipError" ;
    ok $x->write($string) ;
    ok $x->close ;

    ok GZreadFile($name) eq $string ;

    ok my $gunz = new IO::Gunzip $name, Strict => 0
        or diag "GunzipError is $IO::Gunzip::GunzipError" ;
    ok my $hdr = $gunz->getHeaderInfo();
    my $uncomp ;
    ok $gunz->read($uncomp) ;
    ok $uncomp eq $string;
    ok $gunz->close ;

    return $hdr ;
}

sub cmpFile
{
    my ($filename, $uue) = @_ ;
    return readFile($filename) eq unpack("u", $uue) ;
}

sub uncompressBuffer
{
    my $compWith = shift ;
    my $buffer = shift ;

    my %mapping = ( 'IO::Gzip'                    => 'IO::Gunzip',
                    'IO::Gzip::gzip'               => 'IO::Gunzip',
                    'IO::Deflate'                  => 'IO::Inflate',
                    'IO::Deflate::deflate'         => 'IO::Inflate',
                    'IO::RawDeflate'               => 'IO::RawInflate',
                    'IO::RawDeflate::rawdeflate'   => 'IO::RawInflate',
                );

    my $out ;
    my $obj = $mapping{$compWith}->new( \$buffer, -Append => 1);
    1 while $obj->read($out) > 0 ;
    return $out ;

}

my %ErrorMap = (    'IO::Gzip'        => \$IO::Gzip::GzipError,
                    'IO::Gzip::gzip'  => \$IO::Gzip::GzipError,
                    'IO::Gunzip'  => \$IO::Gunzip::GunzipError,
                    'IO::Gunzip::gunzip'  => \$IO::Gunzip::GunzipError,
                    'IO::Inflate'  => \$IO::Inflate::InflateError,
                    'IO::Inflate::inflate'  => \$IO::Inflate::InflateError,
                    'IO::Deflate'  => \$IO::Deflate::DeflateError,
                    'IO::Deflate::deflate'  => \$IO::Deflate::DeflateError,
                    'IO::RawInflate'  => \$IO::RawInflate::RawInflateError,
                    'IO::RawInflate::rawinflate'  => \$IO::RawInflate::RawInflateError,
                    'IO::AnyInflate'  => \$IO::AnyInflate::AnyInflateError,
                    'IO::AnyInflate::anyinflate'  => \$IO::AnyInflate::AnyInflateError,
                    'IO::RawDeflate'  => \$IO::RawDeflate::RawDeflateError,
                    'IO::RawDeflate::rawdeflate'  => \$IO::RawDeflate::RawDeflateError,
               );

my %TopFuncMap = (  'IO::Gzip'        => 'IO::Gzip::gzip',
                    'IO::Gunzip'      => 'IO::Gunzip::gunzip',
                    'IO::Deflate'     => 'IO::Deflate::deflate',
                    'IO::Inflate'     => 'IO::Inflate::inflate',
                    'IO::RawDeflate'  => 'IO::RawDeflate::rawdeflate',
                    'IO::RawInflate'  => 'IO::RawInflate::rawinflate',
                    'IO::AnyInflate'  => 'IO::AnyInflate::anyinflate',
                 );

   %TopFuncMap = map { ($_              => $TopFuncMap{$_}, 
                        $TopFuncMap{$_} => $TopFuncMap{$_}) } 
                 keys %TopFuncMap ;

 #%TopFuncMap = map { ($_              => \&{ $TopFuncMap{$_} ) } 
                 #keys %TopFuncMap ;


my %inverse  = ( 'IO::Gzip'                    => 'IO::Gunzip',
                 'IO::Gzip::gzip'              => 'IO::Gunzip::gunzip',
                 'IO::Deflate'                 => 'IO::Inflate',
                 'IO::Deflate::deflate'        => 'IO::Inflate::inflate',
                 'IO::RawDeflate'              => 'IO::RawInflate',
                 'IO::RawDeflate::rawdeflate'  => 'IO::RawInflate::rawinflate',
             );

%inverse  = map { ($_ => $inverse{$_}, $inverse{$_} => $_) } keys %inverse;

sub getInverse
{
    my $class = shift ;

    return $inverse{$class} ;
}

sub getErrorRef
{
    my $class = shift ;

    return $ErrorMap{$class} ;
}

sub getTopFuncRef
{
    my $class = shift ;

    return \&{ $TopFuncMap{$class} } ;
}

sub getTopFuncName
{
    my $class = shift ;

    return $TopFuncMap{$class}  ;
}

sub compressBuffer
{
    my $compWith = shift ;
    my $buffer = shift ;

    my %mapping = ( 'IO::Gunzip'                  => 'IO::Gzip',
                    'IO::Gunzip::gunzip'          => 'IO::Gzip',
                    'IO::Inflate'                 => 'IO::Deflate',
                    'IO::Inflate::inflate'        => 'IO::Deflate',
                    'IO::RawInflate'              => 'IO::RawDeflate',
                    'IO::RawInflate::rawinflate'  => 'IO::RawDeflate',
                    'IO::AnyInflate'              => 'IO::Gzip',
                    'IO::AnyInflate::anyinflate'  => 'IO::Gzip',
                );

    my $out ;
    my $obj = $mapping{$compWith}->new( \$out);
    $obj->write($buffer) ;
    $obj->close();
    return $out ;

}

use IO::AnyInflate qw($AnyInflateError);
sub anyUncompress
{
    my $buffer = shift ;
    my $already = shift;

    my @opts = ();
    if (ref $buffer && ref $buffer eq 'ARRAY')
    {
        @opts = @$buffer;
        $buffer = shift @opts;
    }

    if (ref $buffer)
    {
        croak "buffer is undef" unless defined $$buffer;
        croak "buffer is empty" unless length $$buffer;

    }


    my $data ;
    if (Compress::Zlib::Common::isaFilehandle($buffer))
    {
        $data = readFile($buffer);
    }
    elsif (Compress::Zlib::Common::isaFilename($buffer))
    {
        $data = readFile($buffer);
    }
    else
    {
        $data = $$buffer ;
    }

    if (defined $already && length $already)
    {

        my $got = substr($data, 0, length($already));
        substr($data, 0, length($already)) = '';

        is $got, $already, '  Already OK' ;
    }

    my $out = '';
    my $o = new IO::AnyInflate \$data, -Append => 1, Transparent => 0, @opts
        or croak "Cannot open buffer/file: $AnyInflateError" ;

    1 while $o->read($out) > 0 ;

    croak "Error uncompressing -- " . $o->error()
        if $o->error() ;

    return $out ;

}

sub mkErr
{
    my $string = shift ;
    my ($dummy, $file, $line) = caller ;
    -- $line ;

    $file = quotemeta($file);

    return "/$string\\s+at $file line $line/" ;
}

sub mkEvalErr
{
    my $string = shift ;

    return "/$string\\s+at \\(eval /" ;
}

sub dumpObj
{
    my $obj = shift ;

    my ($dummy, $file, $line) = caller ;

    if (@_)
    {
        print "#\n# dumpOBJ from $file line $line @_\n" ;
    }
    else
    {
        print "#\n# dumpOBJ from $file line $line \n" ;
    }

    my $max = 0 ;;
    foreach my $k (keys %{ *$obj })
    {
        $max = length $k if length $k > $max ;
    }

    foreach my $k (sort keys %{ *$obj })
    {
        my $v = $obj->{$k} ;
        $v = '-undef-' unless defined $v;
        my $pad = ' ' x ($max - length($k) + 2) ;
        print "# $k$pad: [$v]\n";
    }
    print "#\n" ;
}


package MyTestUtils;

1;
