BEGIN {
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = ("../lib", "lib");
    }
}

use lib 't';

local ($^W) = 1; #use warnings;
use strict;

use Test::More;

eval "use Test::Spelling;" ;
plan skip_all => "Test::Spelling required for testing POD spellings" 
    if $@;


set_spell_cmd('aspell list');
add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__DATA__
CPAN
STDIN
STDOUT
AutoClose
MultiStream
BlockSize
Gailly
InputLength
getHeaderInfo
getline
loup
FCOMMENT
FEXTRA
FHCRC
FLG
FNAME
FTEXT
ISIZE
XFL
ParseExtra
anyinflate
TODO
OO
rawinflate
RFC's
seekable
newStream
metadata
TextFlag
SubFields
HeaderCRC
globmap
wildcard
ExtraFlags
ExtraSubFields
Oberhumer
LZO
Xaver
gzcat
gzdopen
gzstream
RawMode
ExtraField
AppendOutput
deflateSetDictionary
MemLevel
Bufsize
ConsumeInput
conformant
rawdeflate



FileGlobs
fileglobs
globmaps
ID's
BufSize

Initialises
initialised
initialise
initialises

rb
wb

CRC
crc
inflateSync
uncompression
zlib
adler
deflateParams
WindowBits
deflateInit
inflateInit
gzflush
gzread
gzreadline

filenames
uncompresses
checksum
checksums
maximize
subfield
subfields
practice

OPTIMIZATION
Optimize

behaviour
