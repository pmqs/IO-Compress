
package IO::Uncompress::Base ;

use strict ;
local ($^W) = 1; #use warnings;
# use bytes;

use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS);

$VERSION = '2.000_05';

use constant G_EOF => 0 ;
use constant G_ERR => -1 ;

use Compress::Zlib::Common ;
use Compress::Zlib::ParseParameters ;

use IO::File ;
use Symbol;
use Scalar::Util qw(readonly);
use List::Util qw(min);
use Carp ;

%EXPORT_TAGS = ( );
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
#Exporter::export_ok_tags('all') ;


sub smartRead
{
    my $self = $_[0];
    my $out = $_[1];
    my $size = $_[2];
    $$out = "" ;

    my $offset = 0 ;


    if ( length *$self->{Prime} ) {
        #$$out = substr(*$self->{Prime}, 0, $size, '') ;
        $$out = substr(*$self->{Prime}, 0, $size) ;
        substr(*$self->{Prime}, 0, $size) =  '' ;
        if (length $$out == $size) {
            #*$self->{InputLengthRemaining} -= length $$out;
            return length $$out ;
        }
        $offset = length $$out ;
    }

    my $get_size = $size - $offset ;

    if ( defined *$self->{InputLength} ) {
        #*$self->{InputLengthRemaining} += length *$self->{Prime} ;
        #*$self->{InputLengthRemaining} = *$self->{InputLength}
        #    if *$self->{InputLengthRemaining} > *$self->{InputLength};
        $get_size = min($get_size, *$self->{InputLengthRemaining});
    }

    if (defined *$self->{FH})
      { *$self->{FH}->read($$out, $get_size, $offset) }
    elsif (defined *$self->{InputEvent}) {
        my $got = 1 ;
        while (length $$out < $size) {
            last 
                if ($got = *$self->{InputEvent}->($$out, $get_size)) <= 0;
        }

        if (length $$out > $size ) {
            #*$self->{Prime} = substr($$out, $size, length($$out), '');
            *$self->{Prime} = substr($$out, $size, length($$out));
            substr($$out, $size, length($$out)) =  '';
        }

       *$self->{EventEof} = 1 if $got <= 0 ;
    }
    else {
       local ($^W) = 0; #no warnings 'uninitialized';
       my $buf = *$self->{Buffer} ;
       $$buf = '' unless defined $$buf ;
       #$$out = '' unless defined $$out ;
       substr($$out, $offset) = substr($$buf, *$self->{BufferOffset}, $get_size);
       *$self->{BufferOffset} += length($$out) - $offset ;
    }

    *$self->{InputLengthRemaining} -= length $$out;
        
    $self->saveStatus(length $$out < 0 ? STATUS_ERROR : 0) ;

    return length $$out;
}

sub pushBack
{
    my $self = shift ;

    return if ! defined $_[0] || length $_[0] == 0 ;

    if (defined *$self->{FH} || defined *$self->{InputEvent} ) {
        *$self->{Prime} = $_[0] . *$self->{Prime} ;
    }
    else {
        my $len = length $_[0];

        if($len > *$self->{BufferOffset}) {
            *$self->{Prime} = substr($_[0], 0, $len - *$self->{BufferOffset}) . *$self->{Prime} ;
            *$self->{InputLengthRemaining} = *$self->{InputLength};
            *$self->{BufferOffset} = 0
        }
        else {
            *$self->{InputLengthRemaining} += length($_[0]);
            *$self->{BufferOffset} -= length($_[0]) ;
        }
    }
}

sub smartSeek
{
    my $self   = shift ;
    my $offset = shift ;
    my $truncate = shift;
    #print "smartSeek to $offset\n";

    # TODO -- need to take prime into account
    if (defined *$self->{FH})
      { *$self->{FH}->seek($offset, SEEK_SET) }
    else {
        *$self->{BufferOffset} = $offset ;
        substr(${ *$self->{Buffer} }, *$self->{BufferOffset}) = ''
            if $truncate;
        return 1;
    }
}

sub smartWrite
{
    my $self   = shift ;
    my $out_data = shift ;

    if (defined *$self->{FH}) {
        # flush needed for 5.8.0 
        defined *$self->{FH}->write($out_data, length $out_data) &&
        defined *$self->{FH}->flush() ;
    }
    else {
       my $buf = *$self->{Buffer} ;
       substr($$buf, *$self->{BufferOffset}, length $out_data) = $out_data ;
       *$self->{BufferOffset} += length($out_data) ;
       return 1;
    }
}

sub smartReadExact
{
    return $_[0]->smartRead($_[1], $_[2]) == $_[2];
}

sub smartEof
{
    my ($self) = $_[0];

    return 0 if length *$self->{Prime};

    if (defined *$self->{FH})
     { *$self->{FH}->eof() }
    elsif (defined *$self->{InputEvent})
     { *$self->{EventEof} }
    else 
     { *$self->{BufferOffset} >= length(${ *$self->{Buffer} }) }
}

sub clearError
{
    my $self   = shift ;

    *$self->{ErrorNo}  =  0 ;
    ${ *$self->{Error} } = '' ;
}

sub saveStatus
{
    my $self   = shift ;
    my $errno = shift() + 0 ;
    #return $errno unless $errno || ! defined *$self->{ErrorNo};
    #return $errno unless $errno ;

    *$self->{ErrorNo}  = $errno;
    ${ *$self->{Error} } = '' ;

    return *$self->{ErrorNo} ;
}


sub saveErrorString
{
    my $self   = shift ;
    my $retval = shift ;

    #return $retval if ${ *$self->{Error} };

    ${ *$self->{Error} } = shift ;
    *$self->{ErrorNo} = shift() + 0 if @_ ;

    #warn "saveErrorString: " . ${ *$self->{Error} } . " " . *$self->{Error} . "\n" ;
    return $retval;
}

sub croakError
{
    my $self   = shift ;
    $self->saveErrorString(0, $_[0]);
    croak $_[0];
}


sub closeError
{
    my $self = shift ;
    my $retval = shift ;

    my $errno = *$self->{ErrorNo};
    my $error = ${ *$self->{Error} };

    $self->close();

    *$self->{ErrorNo} = $errno ;
    ${ *$self->{Error} } = $error ;

    return $retval;
}

sub error
{
    my $self   = shift ;
    return ${ *$self->{Error} } ;
}

sub errorNo
{
    my $self   = shift ;
    return *$self->{ErrorNo};
}

sub HeaderError
{
    my ($self) = shift;
    return $self->saveErrorString(undef, "Header Error: $_[0]", STATUS_ERROR);
}

sub TrailerError
{
    my ($self) = shift;
    return $self->saveErrorString(G_ERR, "Trailer Error: $_[0]", STATUS_ERROR);
}

sub TruncatedHeader
{
    my ($self) = shift;
    return $self->HeaderError("Truncated in $_[0] Section");
}

sub checkParams
{
    my $self = shift ;
    my $class = shift ;

    my $got = shift || Compress::Zlib::ParseParameters::new();
    
    my $Valid = {
                    'BlockSize'     => [1, 1, Parse_unsigned, 16 * 1024],
                    'AutoClose'     => [1, 1, Parse_boolean,  0],
                    'Strict'        => [1, 1, Parse_boolean,  0],
                   #'Lax'           => [1, 1, Parse_boolean,  1],
                    'Append'        => [1, 1, Parse_boolean,  0],
                    'Prime'         => [1, 1, Parse_any,      undef],
                    'MultiStream'   => [1, 1, Parse_boolean,  0],
                    'Transparent'   => [1, 1, Parse_any,      1],
                    'Scan'          => [1, 1, Parse_boolean,  0],
                    'InputLength'   => [1, 1, Parse_unsigned, undef],
                    'BinModeOut'    => [1, 1, Parse_boolean,  0],

                    $self->getExtraParams(),


                    #'Todo - Revert to ordinary file on end Z_STREAM_END'=> 0,
                    # ContinueAfterEof
                } ;

        
    $got->parse($Valid, @_ ) 
        or $self->croakError("${class}: $got->{Error}")  ;


    return $got;
}

sub _create
{
    my $obj = shift;
    my $got = shift;
    my $append_mode = shift ;

    my $class = ref $obj;
    $obj->croakError("$class: Missing Input parameter")
        if ! @_ && ! $got ;

    my $inValue = shift ;

    if (! $got)
    {
        $got = $obj->checkParams($class, undef, @_)
            or return undef ;
    }

    my $inType  = whatIsInput($inValue, 1);

    $obj->ckInputParam($class, $inValue, 1) 
        or return undef ;

    *$obj->{InNew} = 1;

    $obj->ckParams($got)
        or $obj->croakError("${class}: $obj->{Error}");

    if ($inType eq 'buffer' || $inType eq 'code') {
        *$obj->{Buffer} = $inValue ;        
        *$obj->{InputEvent} = $inValue 
           if $inType eq 'code' ;
    }
    else {
        if ($inType eq 'handle') {
            *$obj->{FH} = $inValue ;
            *$obj->{Handle} = 1 ;
            # Need to rewind for Scan
            #seek(*$obj->{FH}, 0, SEEK_SET) if $got->value('Scan');
            *$obj->{FH}->seek(0, SEEK_SET) if $got->value('Scan');
        }  
        else {    
            my $mode = '<';
            $mode = '+<' if $got->value('Scan');
            *$obj->{StdIO} = ($inValue eq '-');
            *$obj->{FH} = new IO::File "$mode $inValue"
                or return $obj->saveErrorString(undef, "cannot open file '$inValue': $!", $!) ;
            *$obj->{LineNo} = 0;
        }
        
        setBinModeInput(*$obj->{FH}) ;

        my $buff = "" ;
        *$obj->{Buffer} = \$buff ;
    }


    *$obj->{InputLength}       = $got->parsed('InputLength') 
                                    ? $got->value('InputLength')
                                    : undef ;
    *$obj->{InputLengthRemaining} = $got->value('InputLength');
    *$obj->{BufferOffset}      = 0 ;
    *$obj->{AutoClose}         = $got->value('AutoClose');
    *$obj->{Strict}            = $got->value('Strict');
    #*$obj->{Strict}            = ! $got->value('Lax');
    *$obj->{BlockSize}         = $got->value('BlockSize');
    *$obj->{Append}            = $got->value('Append');
    *$obj->{AppendOutput}      = $append_mode || $got->value('Append');
    *$obj->{Transparent}       = $got->value('Transparent');
    *$obj->{MultiStream}       = $got->value('MultiStream');

    # TODO - move these two into RawDeflate
    *$obj->{Scan}              = $got->value('Scan');
    *$obj->{ParseExtra}        = $got->value('ParseExtra') 
                                  || $got->value('Strict')  ;
                                  #|| ! $got->value('Lax')  ;
    *$obj->{Type}              = '';
    *$obj->{Prime}             = $got->value('Prime') || '' ;
    *$obj->{Pending}           = '';
    *$obj->{Plain}             = 0;
    *$obj->{PlainBytesRead}    = 0;
    *$obj->{InflatedBytesRead} = 0;
    *$obj->{UnCompSize_32bit}  = 0;
    *$obj->{TotalInflatedBytesRead} = 0;
    *$obj->{NewStream}         = 0 ;
    *$obj->{EventEof}          = 0 ;
    *$obj->{ClassName}         = $class ;
    *$obj->{Params}            = $got ;

    my $status = $obj->mkUncomp($class, $got);

    return undef
        unless defined $status;

    if ( !  $status) {
        return undef 
            unless *$obj->{Transparent};

        $obj->clearError();
        *$obj->{Type} = 'plain';
        *$obj->{Plain} = 1;
        #$status = $obj->mkIdentityUncomp($class, $got);
        $obj->pushBack(*$obj->{HeaderPending})  ;
    }

    push @{ *$obj->{InfoList} }, *$obj->{Info} ;

    $obj->saveStatus(0) ;
    *$obj->{InNew} = 0;
    *$obj->{Closed} = 0;

    return $obj;
}

sub ckInputParam
{
    my $self = shift ;
    my $from = shift ;
    my $inType = whatIsInput($_[0], $_[1]);

    $self->croakError("$from: input parameter not a filename, filehandle, array ref or scalar ref")
        if ! $inType ;

    if ($inType  eq 'filename' )
    {
        $self->croakError("$from: input filename is undef or null string")
            if ! defined $_[0] || $_[0] eq ''  ;

        if ($_[0] ne '-' && ! -e $_[0] )
        {
            return $self->saveErrorString(undef, 
                            "input file '$_[0]' does not exist", STATUS_ERROR);
        }
    }

    return 1;
}


sub _inf
{
    my $obj = shift ;

    my $class = (caller)[0] ;
    my $name = (caller(1))[3] ;

    $obj->croakError("$name: expected at least 1 parameters\n")
        unless @_ >= 1 ;

    my $input = shift ;
    my $haveOut = @_ ;
    my $output = shift ;


    my $x = new Validator($class, *$obj->{Error}, $name, $input, $output)
        or return undef ;
    
    push @_, $output if $haveOut && $x->{Hash};
    
    my $got = $obj->checkParams($name, undef, @_)
        or return undef ;

    $x->{Got} = $got ;

    if ($x->{Hash})
    {
        while (my($k, $v) = each %$input)
        {
            $v = \$input->{$k} 
                unless defined $v ;

            $obj->_singleTarget($x, 1, $k, $v, @_)
                or return undef ;
        }

        return keys %$input ;
    }
    
    if ($x->{GlobMap})
    {
        $x->{oneInput} = 1 ;
        foreach my $pair (@{ $x->{Pairs} })
        {
            my ($from, $to) = @$pair ;
            $obj->_singleTarget($x, 1, $from, $to, @_)
                or return undef ;
        }

        return scalar @{ $x->{Pairs} } ;
    }

    #if ($x->{outType} eq 'array' || $x->{outType} eq 'hash')
    if (! $x->{oneOutput} )
    {
        my $inFile = ($x->{inType} eq 'filenames' 
                        || $x->{inType} eq 'filename');

        $x->{inType} = $inFile ? 'filename' : 'buffer';
        my $ot = $x->{outType} ;
        $x->{outType} = 'buffer';
        
        foreach my $in ($x->{oneInput} ? $input : @$input)
        {
            my $out ;
            $x->{oneInput} = 1 ;

            $obj->_singleTarget($x, $inFile, $in, \$out, @_)
                or return undef ;

            if ($ot eq 'array')
              { push @$output, \$out }
            else
              { $output->{$in} = \$out }
        }

        return 1 ;
    }

    # finally the 1 to 1 and n to 1
    return $obj->_singleTarget($x, 1, $input, $output, @_);

    croak "should not be here" ;
}

sub retErr
{
    my $x = shift ;
    my $string = shift ;

    ${ $x->{Error} } = $string ;

    return undef ;
}

sub _singleTarget
{
    my $self      = shift ;
    my $x         = shift ;
    my $inputIsFilename = shift;
    my $input     = shift;
    my $output    = shift;
    
    $x->{buff} = '' ;

    my $fh ;
    if ($x->{outType} eq 'filename') {
        my $mode = '>' ;
        $mode = '>>'
            if $x->{Got}->value('Append') ;
        $x->{fh} = new IO::File "$mode $output" 
            or return retErr($x, "cannot open file '$output': $!") ;
        binmode $x->{fh} if $x->{Got}->valueOrDefault('BinModeOut');

    }

    elsif ($x->{outType} eq 'handle') {
        $x->{fh} = $output;
        binmode $x->{fh} if $x->{Got}->valueOrDefault('BinModeOut');
        if ($x->{Got}->value('Append')) {
                seek($x->{fh}, 0, SEEK_END)
                    or return retErr($x, "Cannot seek to end of output filehandle: $!") ;
            }
    }

    
    elsif ($x->{outType} eq 'buffer' )
    {
        $$output = '' 
            unless $x->{Got}->value('Append');
        $x->{buff} = $output ;
    }

    if ($x->{oneInput})
    {
        defined $self->_rd2($x, $input, $inputIsFilename)
            or return undef; 
    }
    else
    {
        my $inputIsFilename = ($x->{inType} ne 'array');

        for my $element ( ($x->{inType} eq 'hash') ? keys %$input : @$input)
        {
            defined $self->_rd2($x, $element, $inputIsFilename) 
                or return undef ;
        }
    }


    if ( ($x->{outType} eq 'filename' && $output ne '-') || 
         ($x->{outType} eq 'handle' && $x->{Got}->value('AutoClose'))) {
        $x->{fh}->close() 
            or return retErr($x, $!); 
            #or return $gunzip->saveErrorString(undef, $!, $!); 
        delete $x->{fh};
    }

    return 1 ;
}

sub _rd2
{
    my $self      = shift ;
    my $x         = shift ;
    my $input     = shift;
    my $inputIsFilename = shift;
        
    my $z = createSelfTiedObject($x->{Class}, *$self->{Error});
    
    $z->_create($x->{Got}, 1, $input, @_)
        or return undef ;

    my $status ;
    my $fh = $x->{fh};
    
    while (($status = $z->read($x->{buff})) > 0) {
        if ($fh) {
            print $fh $x->{buff} 
                or return $z->saveErrorString(undef, "Error writing to output file: $!", $!);
            $x->{buff} = '' ;
        }
    }

    return $z->closeError(undef)
        if $status < 0 ;

    $z->close() 
        or return undef ;

    return 1 ;
}

sub TIEHANDLE
{
    return $_[0] if ref($_[0]);
    die "OOPS\n" ;

}
  
sub UNTIE
{
    my $self = shift ;
}


sub getHeaderInfo
{
    my $self = shift ;
    wantarray ? @{ *$self->{InfoList} } : *$self->{Info};
}

sub readBlock
{
    my $self = shift ;
    my $buff = shift ;
    my $size = shift ;

    if (defined *$self->{CompressedInputLength}) {
        if (*$self->{CompressedInputLengthRemaining} == 0) {
            delete *$self->{CompressedInputLength};
            #$$buff = '';
            return STATUS_OK ;
        }
        $size = min($size, *$self->{CompressedInputLengthRemaining} );
        *$self->{CompressedInputLengthRemaining} -= $size ;
    }
    
    my $status = $self->smartRead($buff, $size) ;
    return $self->saveErrorString(STATUS_ERROR, "Error Reading Data")
        if $status < 0  ;

    if ($status == 0 ) {
        *$self->{Closed} = 1 ;
        *$self->{EndStream} = 1 ;
        return $self->saveErrorString(STATUS_ERROR, "unexpected end of file", STATUS_ERROR);
    }

    return STATUS_OK;

}

sub postBlockChk
{
    return STATUS_OK;
}

sub _raw_read
{
    # return codes
    # >0 - ok, number of bytes read
    # =0 - ok, eof
    # <0 - not ok
    
    my $self = shift ;

    return G_EOF if *$self->{Closed} ;
    #return G_EOF if !length *$self->{Pending} && *$self->{EndStream} ;
    return G_EOF if *$self->{EndStream} ;

    my $buffer = shift ;
    my $scan_mode = shift ;

    if (*$self->{Plain}) {
        my $tmp_buff ;
        my $len = $self->smartRead(\$tmp_buff, *$self->{BlockSize}) ;
        
        return $self->saveErrorString(G_ERR, "Error reading data: $!", $!) 
                if $len < 0 ;

        if ($len == 0 ) {
            *$self->{EndStream} = 1 ;
        }
        else {
            *$self->{PlainBytesRead} += $len ;
            $$buffer .= $tmp_buff;
        }

        return $len ;
    }

    if (*$self->{NewStream}) {

        *$self->{NewStream} = 0 ;
        *$self->{EndStream} = 0 ;
        *$self->{Uncomp}->reset();

        return G_ERR
            unless  my $magic = $self->ckMagic();
        *$self->{Info} = $self->readHeader($magic);

        return G_ERR unless defined *$self->{Info} ;

        push @{ *$self->{InfoList} }, *$self->{Info} ;

        # For the headers that actually uncompressed data, put the
        # uncompressed data into the output buffer.
        $$buffer .=  *$self->{Pending} ;
        my $len = length  *$self->{Pending} ;
        *$self->{Pending} = '';
        return $len; 
    }

    my $temp_buf ;
    my $outSize = 0;
    my $status = $self->readBlock(\$temp_buf, *$self->{BlockSize}, $outSize) ;
    return G_ERR
        if $status == STATUS_ERROR  ;

    my $buf_len = 0;
    if ($status == STATUS_OK) {
        my $before_len = defined $$buffer ? length $$buffer : 0 ;
        $status = *$self->{Uncomp}->uncompr(\$temp_buf, $buffer,
                                    (defined *$self->{CompressedInputLength} &&
                                        *$self->{CompressedInputLengthRemaining} <= 0) ||
                                                $self->smartEof(), $outSize);

        return $self->saveErrorString(G_ERR, *$self->{Uncomp}{Error}, *$self->{Uncomp}{ErrorNo})
            if $self->saveStatus($status) == STATUS_ERROR;

        $self->postBlockChk($buffer) == STATUS_OK
            or return G_ERR;

        #$buf_len = *$self->{Uncomp}->count();
        $buf_len = length($$buffer) - $before_len;

    
        *$self->{InflatedBytesRead} += $buf_len ;
        *$self->{TotalInflatedBytesRead} += $buf_len ;
        my $rest = 0xFFFFFFFF - *$self->{UnCompSize_32bit} ;
        if ($buf_len > $rest) {
            *$self->{UnCompSize_32bit} = $buf_len - $rest - 1;
        }
        else {
            *$self->{UnCompSize_32bit} += $buf_len ;
        }
    }

    if ($status == STATUS_ENDSTREAM) {

        *$self->{EndStream} = 1 ;
        $self->pushBack($temp_buf)  ;
        $temp_buf = '';

        my $trailer;
        if (*$self->{Info}{TrailerLength})
        {
            my $trailer_size = *$self->{Info}{TrailerLength} ;

            my $got = $self->smartRead(\$trailer, $trailer_size) ;
            if ($got != $trailer_size) {
                return $self->TrailerError("trailer truncated. Expected " . 
                                          "$trailer_size bytes, got $got")
                    if *$self->{Strict};
                $self->pushBack($trailer)  ;
            }
        }

        $self->chkTrailer($trailer) == G_ERR
            and return G_ERR;

        if (*$self->{MultiStream} &&  ! $self->smartEof()) {
                    #&& (length $temp_buf || ! $self->smartEof())){
            *$self->{NewStream} = 1 ;
            *$self->{EndStream} = 0 ;
            return $buf_len ;
        }

    }
    

    # return the number of uncompressed bytes read
    return $buf_len ;
}

#sub isEndStream
#{
#    my $self = shift ;
#    return *$self->{NewStream} ||
#           *$self->{EndStream} ;
#}

sub streamCount
{
    my $self = shift ;
    return 1 if ! defined *$self->{InfoList};
    return scalar @{ *$self->{InfoList} }  ;
}

sub read
{
    # return codes
    # >0 - ok, number of bytes read
    # =0 - ok, eof
    # <0 - not ok
    
    my $self = shift ;

    return G_EOF if *$self->{Closed} ;
    return G_EOF if !length *$self->{Pending} && *$self->{EndStream} ;

    my $buffer ;

    #$self->croakError(*$self->{ClassName} . 
    #            "::read: buffer parameter is read-only")
    #    if Compress::Zlib::_readonly_ref($_[0]);

    if (ref $_[0] ) {
        $self->croakError(*$self->{ClassName} . "::read: buffer parameter is read-only")
            if readonly(${ $_[0] });

        $self->croakError(*$self->{ClassName} . "::read: not a scalar reference $_[0]" )
            unless ref $_[0] eq 'SCALAR' ;
        $buffer = $_[0] ;
    }
    else {
        $self->croakError(*$self->{ClassName} . "::read: buffer parameter is read-only")
            if readonly($_[0]);

        $buffer = \$_[0] ;
    }

    my $length = $_[1] ;
    my $offset = $_[2] || 0;

    # the core read will return 0 if asked for 0 bytes
    return 0 if defined $length && $length == 0 ;

    $length = $length || 0;

    $self->croakError(*$self->{ClassName} . "::read: length parameter is negative")
        if $length < 0 ;

    $$buffer = '' unless *$self->{AppendOutput}  || $offset ;

    # Short-circuit if this is a simple read, with no length
    # or offset specified.
    unless ( $length || $offset) {
        if (length *$self->{Pending}) {
            $$buffer .= *$self->{Pending} ;
            my $len = length *$self->{Pending};
            *$self->{Pending} = '' ;
            return $len ;
        }
        else {
            my $len = 0;
            $len = $self->_raw_read($buffer) 
                while ! *$self->{EndStream} && $len == 0 ;
            return $len ;
        }
    }

    # Need to jump through more hoops - either length or offset 
    # or both are specified.
    my $out_buffer = \*$self->{Pending} ;

    while (! *$self->{EndStream} && length($$out_buffer) < $length)
    {
        my $buf_len = $self->_raw_read($out_buffer);
        return $buf_len 
            if $buf_len < 0 ;
    }

    $length = length $$out_buffer 
        if length($$out_buffer) < $length ;

    if ($offset) { 
        $$buffer .= "\x00" x ($offset - length($$buffer))
            if $offset > length($$buffer) ;
        #substr($$buffer, $offset) = substr($$out_buffer, 0, $length, '') ;
        substr($$buffer, $offset) = substr($$out_buffer, 0, $length) ;
        substr($$out_buffer, 0, $length) =  '' ;
    }
    else {
        #$$buffer .= substr($$out_buffer, 0, $length, '') ;
        $$buffer .= substr($$out_buffer, 0, $length) ;
        substr($$out_buffer, 0, $length) =  '' ;
    }

    return $length ;
}

sub _getline
{
    my $self = shift ;

    # Slurp Mode
    if ( ! defined $/ ) {
        my $data ;
        1 while $self->read($data) > 0 ;
        return \$data ;
    }

    # Paragraph Mode
    if ( ! length $/ ) {
        my $paragraph ;    
        while ($self->read($paragraph) > 0 ) {
            if ($paragraph =~ s/^(.*?\n\n+)//s) {
                *$self->{Pending}  = $paragraph ;
                my $par = $1 ;
              return \$par ;
            }
        }
        return \$paragraph;
    }

    # Line Mode
    {
        my $line ;    
        my $endl = quotemeta($/); # quote in case $/ contains RE meta chars
        while ($self->read($line) > 0 ) {
            if ($line =~ s/^(.*?$endl)//s) {
                *$self->{Pending} = $line ;
                $. = ++ *$self->{LineNo} ;
                my $l = $1 ;
                return \$l ;
            }
        }
        $. = ++ *$self->{LineNo} if defined($line);
        return \$line;
    }
}

sub getline
{
    my $self = shift;
    my $current_append = *$self->{AppendOutput} ;
    *$self->{AppendOutput} = 1;
    my $lineref = $self->_getline();
    *$self->{AppendOutput} = $current_append;
    return $$lineref ;
}

sub getlines
{
    my $self = shift;
    $self->croakError(*$self->{ClassName} . 
            "::getlines: called in scalar context\n") unless wantarray;
    my($line, @lines);
    push(@lines, $line) while defined($line = $self->getline);
    return @lines;
}

sub READLINE
{
    goto &getlines if wantarray;
    goto &getline;
}

sub getc
{
    my $self = shift;
    my $buf;
    return $buf if $self->read($buf, 1);
    return undef;
}

sub ungetc
{
    my $self = shift;
    *$self->{Pending} = ""  unless defined *$self->{Pending} ;    
    *$self->{Pending} = $_[0] . *$self->{Pending} ;    
}


sub trailingData
{
    my $self = shift ;
    #return \"" if ! defined *$self->{Trailing} ;
    #return \*$self->{Trailing} ;

    if (defined *$self->{FH} || defined *$self->{InputEvent} ) {
        return *$self->{Prime} ;
    }
    else {
        my $buf = *$self->{Buffer} ;
        my $offset = *$self->{BufferOffset} ;
        return substr($$buf, $offset, -1) ;
    }
}


sub eof
{
    my $self = shift ;

    return (*$self->{Closed} ||
              (!length *$self->{Pending} 
                && ( $self->smartEof() || *$self->{EndStream}))) ;
}

sub tell
{
    my $self = shift ;

    my $in ;
    if (*$self->{Plain}) {
        $in = *$self->{PlainBytesRead} ;
    }
    else {
        $in = *$self->{TotalInflatedBytesRead} ;
    }

    my $pending = length *$self->{Pending} ;

    return 0 if $pending > $in ;
    return $in - $pending ;
}

sub close
{
    # todo - what to do if close is called before the end of the gzip file
    #        do we remember any trailing data?
    my $self = shift ;

    return 1 if *$self->{Closed} ;

    untie *$self 
        if $] >= 5.008 ;

    my $status = 1 ;

    if (defined *$self->{FH}) {
        if ((! *$self->{Handle} || *$self->{AutoClose}) && ! *$self->{StdIO}) {
        #if ( *$self->{AutoClose}) {
            $! = 0 ;
            $status = *$self->{FH}->close();
            return $self->saveErrorString(0, $!, $!)
                if !*$self->{InNew} && $self->saveStatus($!) != 0 ;
        }
        delete *$self->{FH} ;
        $! = 0 ;
    }
    *$self->{Closed} = 1 ;

    return 1;
}

sub DESTROY
{
    my $self = shift ;
    $self->close() ;
}

sub seek
{
    my $self     = shift ;
    my $position = shift;
    my $whence   = shift ;

    my $here = $self->tell() ;
    my $target = 0 ;


    if ($whence == SEEK_SET) {
        $target = $position ;
    }
    elsif ($whence == SEEK_CUR) {
        $target = $here + $position ;
    }
    elsif ($whence == SEEK_END) {
        $target = $position ;
        $self->croakError(*$self->{ClassName} . "::seek: SEEK_END not allowed") ;
    }
    else {
        $self->croakError(*$self->{ClassName} ."::seek: unknown value, $whence, for whence parameter");
    }

    # short circuit if seeking to current offset
    return 1 if $target == $here ;    

    # Outlaw any attempt to seek backwards
    $self->croakError( *$self->{ClassName} ."::seek: cannot seek backwards")
        if $target < $here ;

    # Walk the file to the new offset
    my $offset = $target - $here ;

    my $buffer ;
    $self->read($buffer, $offset) == $offset
        or return 0 ;

    return 1 ;
}

sub fileno
{
    my $self = shift ;
    return defined *$self->{FH} 
           ? fileno *$self->{FH} 
           : undef ;
}

sub binmode
{
    1;
#    my $self     = shift ;
#    return defined *$self->{FH} 
#            ? binmode *$self->{FH} 
#            : 1 ;
}

*BINMODE  = \&binmode;
*SEEK     = \&seek; 
*READ     = \&read;
*sysread  = \&read;
*TELL     = \&tell;
*EOF      = \&eof;

*FILENO   = \&fileno;
*CLOSE    = \&close;

sub _notAvailable
{
    my $name = shift ;
    #return sub { croak "$name Not Available" ; } ;
    return sub { croak "$name Not Available: File opened only for intput" ; } ;
}


*print    = _notAvailable('print');
*PRINT    = _notAvailable('print');
*printf   = _notAvailable('printf');
*PRINTF   = _notAvailable('printf');
*write    = _notAvailable('write');
*WRITE    = _notAvailable('write');

#*sysread  = \&read;
#*syswrite = \&_notAvailable;

#package IO::_infScan ;
#
#*_raw_read = \&IO::Uncompress::Base::_raw_read ;
#*smartRead = \&IO::Uncompress::Base::smartRead ;
#*smartWrite = \&IO::Uncompress::Base::smartWrite ;
#*smartSeek = \&IO::Uncompress::Base::smartSeek ;

#sub mkIdentityUncomp
#{
#    my $self = shift ;
#    my $class = shift ;
#    my $got = shift ;
#
#    *$self->{Uncomp} = UncompressPlugin::Identity::mkUncompObject($self, $class, $got)
#        or return undef;
#
#    return 1;
#
#}
#
#
#package UncompressPlugin::Identity;
#
#use strict ;
#use warnings;
#
#our ($VERSION, @ISA, @EXPORT);
#
#$VERSION = '2.000_05';
#
#use constant STATUS_OK        => 0;
#use constant STATUS_ENDSTREAM => 1;
#use constant STATUS_ERROR     => 2;
#
#sub mkUncompObject
#{
#    my $class = shift ;
#
#    bless { 'CompSize'   => 0,
#            'UnCompSize' => 0,
#            'CRC32'      => 0,
#            'ADLER32'    => 0,
#          }, __PACKAGE__ ;
#}
#
#sub uncompr
#{
#    my $self = shift ;
#    my $from = shift ;
#    my $to   = shift ;
#    my $eof  = shift ;
#
#
#    $self->{CompSize} += length $$from ;
#    $self->{UnCompSize} = $self->{CompSize} ;
#
#    $$to = $$from ;
#
#    return STATUS_ENDSTREAM if $eof;
#    return STATUS_OK ;
#}
#
#sub count
#{
#    my $self = shift ;
#    return $self->{UnCompSize} ;
#}
#
#sub sync
#{
#    return STATUS_OK ;
#}
#
#
#sub reset
#{
#    return STATUS_OK ;
#}


package IO::Uncompress::Base ;


1 ;
__END__


=head1 NAME

IO::Gunzip - Perl interface to read RFC 1952 files/buffers

=head1 SYNOPSIS

    use IO::Gunzip qw(gunzip $GunzipError) ;

    my $status = gunzip $input => $output [,OPTS]
        or die "gunzip failed: $GunzipError\n";

    my $z = new IO::Gunzip $input [OPTS] 
        or die "gunzip failed: $GunzipError\n";

    $status = $z->read($buffer)
    $status = $z->read($buffer, $length)
    $status = $z->read($buffer, $length, $offset)
    $line = $z->getline()
    $char = $z->getc()
    $char = $z->ungetc()
    $status = $z->inflateSync()
    $z->trailingData()
    $data = $z->getHeaderInfo()
    $z->tell()
    $z->seek($position, $whence)
    $z->binmode()
    $z->fileno()
    $z->eof()
    $z->close()

    $GunzipError ;

    # IO::File mode

    <$z>
    read($z, $buffer);
    read($z, $buffer, $length);
    read($z, $buffer, $length, $offset);
    tell($z)
    seek($z, $position, $whence)
    binmode($z)
    fileno($z)
    eof($z)
    close($z)


=head1 DESCRIPTION



B<WARNING -- This is a Beta release>. 

=over 5

=item * DO NOT use in production code.

=item * The documentation is incomplete in places.

=item * Parts of the interface defined here are tentative.

=item * Please report any problems you find.

=back





This module provides a Perl interface that allows the reading of 
files/buffers that conform to RFC 1952.

For writing RFC 1952 files/buffers, see the companion module 
IO::Gzip.



=head1 Functional Interface

A top-level function, C<gunzip>, is provided to carry out "one-shot"
uncompression between buffers and/or files. For finer control over the uncompression process, see the L</"OO Interface"> section.

    use IO::Gunzip qw(gunzip $GunzipError) ;

    gunzip $input => $output [,OPTS] 
        or die "gunzip failed: $GunzipError\n";

    gunzip \%hash [,OPTS] 
        or die "gunzip failed: $GunzipError\n";

The functional interface needs Perl5.005 or better.


=head2 gunzip $input => $output [, OPTS]

If the first parameter is not a hash reference C<gunzip> expects
at least two parameters, C<$input> and C<$output>.

=head3 The C<$input> parameter

The parameter, C<$input>, is used to define the source of
the compressed data. 

It can take one of the following forms:

=over 5

=item A filename

If the C<$input> parameter is a simple scalar, it is assumed to be a
filename. This file will be opened for reading and the input data
will be read from it.

=item A filehandle

If the C<$input> parameter is a filehandle, the input data will be
read from it.
The string '-' can be used as an alias for standard input.

=item A scalar reference 

If C<$input> is a scalar reference, the input data will be read
from C<$$input>.

=item An array reference 

If C<$input> is an array reference, the input data will be read from each
element of the array in turn. The action taken by C<gunzip> with
each element of the array will depend on the type of data stored
in it. You can mix and match any of the types defined in this list,
excluding other array or hash references. 
The complete array will be walked to ensure that it only
contains valid data types before any data is uncompressed.

=item An Input FileGlob string

If C<$input> is a string that is delimited by the characters "<" and ">"
C<gunzip> will assume that it is an I<input fileglob string>. The
input is the list of files that match the fileglob.

If the fileglob does not match any files ...

See L<File::GlobMapper|File::GlobMapper> for more details.


=back

If the C<$input> parameter is any other type, C<undef> will be returned.



=head3 The C<$output> parameter

The parameter C<$output> is used to control the destination of the
uncompressed data. This parameter can take one of these forms.

=over 5

=item A filename

If the C<$output> parameter is a simple scalar, it is assumed to be a filename.
This file will be opened for writing and the uncompressed data will be
written to it.

=item A filehandle

If the C<$output> parameter is a filehandle, the uncompressed data will
be written to it.  
The string '-' can be used as an alias for standard output.


=item A scalar reference 

If C<$output> is a scalar reference, the uncompressed data will be stored
in C<$$output>.


=item A Hash Reference

If C<$output> is a hash reference, the uncompressed data will be written
to C<$output{$input}> as a scalar reference.

When C<$output> is a hash reference, C<$input> must be either a filename or
list of filenames. Anything else is an error.


=item An Array Reference

If C<$output> is an array reference, the uncompressed data will be pushed
onto the array.

=item An Output FileGlob

If C<$output> is a string that is delimited by the characters "<" and ">"
C<gunzip> will assume that it is an I<output fileglob string>. The
output is the list of files that match the fileglob.

When C<$output> is an fileglob string, C<$input> must also be a fileglob
string. Anything else is an error.

=back

If the C<$output> parameter is any other type, C<undef> will be returned.

=head2 gunzip \%hash [, OPTS]

If the first parameter is a hash reference, C<\%hash>, this will be used to
define both the source of compressed data and to control where the
uncompressed data is output. Each key/value pair in the hash defines a
mapping between an input filename, stored in the key, and an output
file/buffer, stored in the value. Although the input can only be a filename,
there is more flexibility to control the destination of the uncompressed
data. This is determined by the type of the value. Valid types are

=over 5

=item undef

If the value is C<undef> the uncompressed data will be written to the
value as a scalar reference.

=item A filename

If the value is a simple scalar, it is assumed to be a filename. This file will
be opened for writing and the uncompressed data will be written to it.

=item A filehandle

If the value is a filehandle, the uncompressed data will be
written to it. 
The string '-' can be used as an alias for standard output.


=item A scalar reference 

If the value is a scalar reference, the uncompressed data will be stored
in the buffer that is referenced by the scalar.


=item A Hash Reference

If the value is a hash reference, the uncompressed data will be written
to C<$hash{$input}> as a scalar reference.

=item An Array Reference

If C<$output> is an array reference, the uncompressed data will be pushed
onto the array.

=back

Any other type is a error.

=head2 Notes

When C<$input> maps to multiple files/buffers and C<$output> is a single
file/buffer the uncompressed input files/buffers will all be stored in
C<$output> as a single uncompressed stream.



=head2 Optional Parameters

Unless specified below, the optional parameters for C<gunzip>,
C<OPTS>, are the same as those used with the OO interface defined in the
L</"Constructor Options"> section below.

=over 5

=item AutoClose =E<gt> 0|1

This option applies to any input or output data streams to C<gunzip>
that are filehandles.

If C<AutoClose> is specified, and the value is true, it will result in all
input and/or output filehandles being closed once C<gunzip> has
completed.

This parameter defaults to 0.



=item -Append =E<gt> 0|1

TODO



=back




=head2 Examples

To read the contents of the file C<file1.txt.gz> and write the
compressed data to the file C<file1.txt>.

    use strict ;
    use warnings ;
    use IO::Gunzip qw(gunzip $GunzipError) ;

    my $input = "file1.txt.gz";
    my $output = "file1.txt";
    gunzip $input => $output
        or die "gunzip failed: $GunzipError\n";


To read from an existing Perl filehandle, C<$input>, and write the
uncompressed data to a buffer, C<$buffer>.

    use strict ;
    use warnings ;
    use IO::Gunzip qw(gunzip $GunzipError) ;
    use IO::File ;

    my $input = new IO::File "<file1.txt.gz"
        or die "Cannot open 'file1.txt.gz': $!\n" ;
    my $buffer ;
    gunzip $input => \$buffer 
        or die "gunzip failed: $GunzipError\n";

To uncompress all files in the directory "/my/home" that match "*.txt.gz" and store the compressed data in the same directory

    use strict ;
    use warnings ;
    use IO::Gunzip qw(gunzip $GunzipError) ;

    gunzip '</my/home/*.txt.gz>' => '</my/home/#1.txt>'
        or die "gunzip failed: $GunzipError\n";

and if you want to compress each file one at a time, this will do the trick

    use strict ;
    use warnings ;
    use IO::Gunzip qw(gunzip $GunzipError) ;

    for my $input ( glob "/my/home/*.txt.gz" )
    {
        my $output = $input;
        $output =~ s/.gz// ;
        gunzip $input => $output 
            or die "Error compressing '$input': $GunzipError\n";
    }

=head1 OO Interface

=head2 Constructor

The format of the constructor for IO::Gunzip is shown below


    my $z = new IO::Gunzip $input [OPTS]
        or die "IO::Gunzip failed: $GunzipError\n";

Returns an C<IO::Gunzip> object on success and undef on failure.
The variable C<$GunzipError> will contain an error message on failure.

If you are running Perl 5.005 or better the object, C<$z>, returned from 
IO::Gunzip can be used exactly like an L<IO::File|IO::File> filehandle. 
This means that all normal input file operations can be carried out with C<$z>. 
For example, to read a line from a compressed file/buffer you can use either 
of these forms

    $line = $z->getline();
    $line = <$z>;

The mandatory parameter C<$input> is used to determine the source of the
compressed data. This parameter can take one of three forms.

=over 5

=item A filename

If the C<$input> parameter is a scalar, it is assumed to be a filename. This
file will be opened for reading and the compressed data will be read from it.

=item A filehandle

If the C<$input> parameter is a filehandle, the compressed data will be
read from it.
The string '-' can be used as an alias for standard input.


=item A scalar reference 

If C<$input> is a scalar reference, the compressed data will be read from
C<$$output>.

=back

=head2 Constructor Options


The option names defined below are case insensitive and can be optionally
prefixed by a '-'.  So all of the following are valid

    -AutoClose
    -autoclose
    AUTOCLOSE
    autoclose

OPTS is a combination of the following options:

=over 5

=item -AutoClose =E<gt> 0|1

This option is only valid when the C<$input> parameter is a filehandle. If
specified, and the value is true, it will result in the file being closed once
either the C<close> method is called or the IO::Gunzip object is
destroyed.

This parameter defaults to 0.

=item -MultiStream =E<gt> 0|1



Allows multiple concatenated compressed streams to be treated as a single
compressed stream. Decompression will stop once either the end of the
file/buffer is reached, an error is encountered (premature eof, corrupt
compressed data) or the end of a stream is not immediately followed by the
start of another stream.

This parameter defaults to 0.



=item -Prime =E<gt> $string

This option will uncompress the contents of C<$string> before processing the
input file/buffer.

This option can be useful when the compressed data is embedded in another
file/data structure and it is not possible to work out where the compressed
data begins without having to read the first few bytes. If this is the case,
the uncompression can be I<primed> with these bytes using this option.

=item -Transparent =E<gt> 0|1

If this option is set and the input file or buffer is not compressed data,
the module will allow reading of it anyway.

This option defaults to 1.

=item -BlockSize =E<gt> $num

When reading the compressed input data, IO::Gunzip will read it in blocks
of C<$num> bytes.

This option defaults to 4096.

=item -InputLength =E<gt> $size

When present this option will limit the number of compressed bytes read from
the input file/buffer to C<$size>. This option can be used in the situation
where there is useful data directly after the compressed data stream and you
know beforehand the exact length of the compressed data stream. 

This option is mostly used when reading from a filehandle, in which case the
file pointer will be left pointing to the first byte directly after the
compressed data stream.



This option defaults to off.

=item -Append =E<gt> 0|1

This option controls what the C<read> method does with uncompressed data.

If set to 1, all uncompressed data will be appended to the output parameter of
the C<read> method.

If set to 0, the contents of the output parameter of the C<read> method will be
overwritten by the uncompressed data.

Defaults to 0.

=item -Strict =E<gt> 0|1



This option controls whether the extra checks defined below are used when
carrying out the decompression. When Strict is on, the extra tests are carried
out, when Strict is off they are not.

The default for this option is off.









=over 5

=item 1 

If the FHCRC bit is set in the gzip FLG header byte, the CRC16 bytes in the
header must match the crc16 value of the gzip header actually read.

=item 2

If the gzip header contains a name field (FNAME) it consists solely of ISO
8859-1 characters.

=item 3

If the gzip header contains a comment field (FCOMMENT) it consists solely of
ISO 8859-1 characters plus line-feed.

=item 4

If the gzip FEXTRA header field is present it must conform to the sub-field
structure as defined in RFC1952.

=item 5

The CRC32 and ISIZE trailer fields must be present.

=item 6

The value of the CRC32 field read must match the crc32 value of the
uncompressed data actually contained in the gzip file.

=item 7

The value of the ISIZE fields read must match the length of the uncompressed
data actually read from the file.

=back






=item -ParseExtra =E<gt> 0|1

If the gzip FEXTRA header field is present and this option is set, it will
force the module to check that it conforms to the sub-field structure as
defined in RFC1952.

If the C<Strict> is on it will automatically enable this option.

Defaults to 0.



=back

=head2 Examples

TODO

=head1 Methods 

=head2 read

Usage is

    $status = $z->read($buffer)

Reads a block of compressed data (the size the the compressed block is
determined by the C<Buffer> option in the constructor), uncompresses it and
writes any uncompressed data into C<$buffer>. If the C<Append> parameter is set
in the constructor, the uncompressed data will be appended to the C<$buffer>
parameter. Otherwise C<$buffer> will be overwritten.

Returns the number of uncompressed bytes written to C<$buffer>, zero if eof or
a negative number on error.

=head2 read

Usage is

    $status = $z->read($buffer, $length)
    $status = $z->read($buffer, $length, $offset)

    $status = read($z, $buffer, $length)
    $status = read($z, $buffer, $length, $offset)

Attempt to read C<$length> bytes of uncompressed data into C<$buffer>.

The main difference between this form of the C<read> method and the previous
one, is that this one will attempt to return I<exactly> C<$length> bytes. The
only circumstances that this function will not is if end-of-file or an IO error
is encountered.

Returns the number of uncompressed bytes written to C<$buffer>, zero if eof or
a negative number on error.


=head2 getline

Usage is

    $line = $z->getline()
    $line = <$z>

Reads a single line. 

This method fully supports the use of of the variable C<$/>
(or C<$INPUT_RECORD_SEPARATOR> or C<$RS> when C<English> is in use) to
determine what constitutes an end of line. Both paragraph mode and file
slurp mode are supported. 


=head2 getc

Usage is 

    $char = $z->getc()

Read a single character.

=head2 ungetc

Usage is

    $char = $z->ungetc($string)


=head2 inflateSync

Usage is

    $status = $z->inflateSync()

TODO

=head2 getHeaderInfo

Usage is

    $hdr = $z->getHeaderInfo()

TODO





This method returns a hash reference that contains the contents of each of the
header fields defined in RFC1952.






=over 5

=item Comment

The contents of the Comment header field, if present. If no comment is present,
the value will be undef. Note this is different from a zero length comment,
which will return an empty string.

=back




=head2 tell

Usage is

    $z->tell()
    tell $z

Returns the uncompressed file offset.

=head2 eof

Usage is

    $z->eof();
    eof($z);



Returns true if the end of the compressed input stream has been reached.



=head2 seek

    $z->seek($position, $whence);
    seek($z, $position, $whence);




Provides a sub-set of the C<seek> functionality, with the restriction
that it is only legal to seek forward in the input file/buffer.
It is a fatal error to attempt to seek backward.



The C<$whence> parameter takes one the usual values, namely SEEK_SET,
SEEK_CUR or SEEK_END.

Returns 1 on success, 0 on failure.

=head2 binmode

Usage is

    $z->binmode
    binmode $z ;

This is a noop provided for completeness.

=head2 fileno

    $z->fileno()
    fileno($z)

If the C<$z> object is associated with a file, this method will return
the underlying filehandle.

If the C<$z> object is is associated with a buffer, this method will
return undef.

=head2 close

    $z->close() ;
    close $z ;



Closes the output file/buffer. 



For most versions of Perl this method will be automatically invoked if
the IO::Gunzip object is destroyed (either explicitly or by the
variable with the reference to the object going out of scope). The
exceptions are Perl versions 5.005 through 5.00504 and 5.8.0. In
these cases, the C<close> method will be called automatically, but
not until global destruction of all live objects when the program is
terminating.

Therefore, if you want your scripts to be able to run on all versions
of Perl, you should call C<close> explicitly and not rely on automatic
closing.

Returns true on success, otherwise 0.

If the C<AutoClose> option has been enabled when the IO::Gunzip
object was created, and the object is associated with a file, the
underlying file will also be closed.




=head1 Importing 

No symbolic constants are required by this IO::Gunzip at present. 

=over 5

=item :all

Imports C<gunzip> and C<$GunzipError>.
Same as doing this

    use IO::Gunzip qw(gunzip $GunzipError) ;

=back

=head1 EXAMPLES




=head1 SEE ALSO

L<Compress::Zlib>, L<IO::Gzip>, L<IO::Deflate>, L<IO::Inflate>, L<IO::RawDeflate>, L<IO::RawInflate>, L<IO::AnyInflate>

L<Compress::Zlib::FAQ|Compress::Zlib::FAQ>

L<File::GlobMapper|File::GlobMapper>, L<Archive::Tar|Archive::Zip>,
L<IO::Zlib|IO::Zlib>

For RFC 1950, 1951 and 1952 see 
F<http://www.faqs.org/rfcs/rfc1950.html>,
F<http://www.faqs.org/rfcs/rfc1951.html> and
F<http://www.faqs.org/rfcs/rfc1952.html>

The primary site for the gzip program is F<http://www.gzip.org>.

=head1 AUTHOR

The I<IO::Gunzip> module was written by Paul Marquess,
F<pmqs@cpan.org>. The latest copy of the module can be
found on CPAN in F<modules/by-module/Compress/Compress-Zlib-x.x.tar.gz>.

The I<zlib> compression library was written by Jean-loup Gailly
F<gzip@prep.ai.mit.edu> and Mark Adler F<madler@alumni.caltech.edu>.

The primary site for the I<zlib> compression library is
F<http://www.zlib.org>.

=head1 MODIFICATION HISTORY

See the Changes file.

=head1 COPYRIGHT AND LICENSE
 

Copyright (c) 2005 Paul Marquess. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.



