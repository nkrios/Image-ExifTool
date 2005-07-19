#------------------------------------------------------------------------------
# File:         PDF.pm
#
# Description:  Definitions for reading PDF files
#
# Revisions:    07/11/05 - P. Harvey Created
#
# References:   1) http://partners.adobe.com/public/developer/pdf/index_reference.html
#
# TO DO:        - verbose messages (and in PostScript!)
#------------------------------------------------------------------------------

package Image::ExifTool::PDF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
require Exporter;

$VERSION = '1.02';

sub ExtractObject($$;$$);
sub ProcessDict($$$$);
sub FetchObject($$$$);
sub ReadToNested($;$);

my %warnedOnce;     # hash of warnings we issued
my %streamObjs;     # hash of stream objects
my %fetched;        # dicts fetched in verbose mode (to avoid cyclical recursion)

# tags in main PDF directories
%Image::ExifTool::PDF::Main = (
    Root => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Root',
        },
    },
    Info => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Info',
        },
    },
);

# tags in PDF Root directory
%Image::ExifTool::PDF::Root = (
    Metadata => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Metadata',
        },
    },
    Pages => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Pages',
        },
    },
);

# tags in PDF Pages directory
%Image::ExifTool::PDF::Pages = (
    GROUPS => { 2 => 'Image' },
    Count => 'PageCount',
    Kids => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Kids',
        },
    },
);

# tags in PDF Kids directory
%Image::ExifTool::PDF::Kids = (
    PieceInfo => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::PieceInfo',
        },
    },
    Resources => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Resources',
        },
    },
);

# tags in PDF Resources directory
%Image::ExifTool::PDF::Resources = (
    ColorSpace => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::ColorSpace',
        },
    },
);

# tags in PDF ColorSpace directory
%Image::ExifTool::PDF::ColorSpace = (
    DefaultRGB => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::DefaultRGB',
        },
    },
);

# tags in PDF DefaultRGB directory
%Image::ExifTool::PDF::DefaultRGB = (
    ICCBased => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::ICCBased',
        },
    },
);

# tags in PDF ICCBased directory
%Image::ExifTool::PDF::ICCBased = (
    stream => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
);

# tags in PDF PieceInfo directory
%Image::ExifTool::PDF::PieceInfo = (
    AdobePhotoshop => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::AdobePhotoshop',
        },
    },
);

# tags in PDF AdobePhotoshop directory
%Image::ExifTool::PDF::AdobePhotoshop = (
    Private => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::Private',
        },
    },
);

# tags in PDF Private directory
%Image::ExifTool::PDF::Private = (
    ImageResources => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::PDF::ImageResources',
        },
    },
);

# tags in PDF ImageResources directory
%Image::ExifTool::PDF::ImageResources = (
    stream => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
        },
    },
);

# tags in PDF Info directory
%Image::ExifTool::PDF::Info = (
    GROUPS => { 2 => 'Image' },
    Title       => { },
    Author      => { Groups => { 2 => 'Author' } },
    Subject     => { },
    Keywords    => { List => 1 },  # this is a list of tokens
    Creator     => { },
    Producer    => { },
    CreationDate => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::PDF::ConvertPDFDate($self, $val)',
    },
    ModDate => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::PDF::ConvertPDFDate($self, $val)',
    },
    Trapped     => { },
);

# tags in PDF Metadata directory
%Image::ExifTool::PDF::Metadata = (
    GROUPS => { 2 => 'Image' },
    XML_stream => { # this is the stream for a Subtype /XML dictionary (not a real tag)
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
);

# unknown tags for use in verbose option
%Image::ExifTool::PDF::Unknown = (
    GROUPS => { 2 => 'Unknown' },
);

#------------------------------------------------------------------------------
# Issue one warning of each type
# Inputs: 0) ExifTool object reference, 1) warning
sub WarnOnce($$)
{
    my ($exifTool, $warn) = @_;
    unless ($warnedOnce{$warn}) {
        $warnedOnce{$warn} = 1;
        $exifTool->Warn($warn);
    }
}

#------------------------------------------------------------------------------
# Set PDF format error warning
# Inputs: 0) ExifTool object reference, 1) error string
# Returns: 1
sub PDFErr($$)
{
    my ($exifTool, $str) = @_;
    $exifTool->Warn("PDF format error ($str)");
    return 1;
}

#------------------------------------------------------------------------------
# Convert from PDF to EXIF-style date/time
# Inputs: 0) ExifTool object reference,
#         1) PDF date/time string (D:yyyymmddhhmmss+hh'mm')
# Returns: EXIF date string (yyyy:mm:dd hh:mm:ss+hh:mm)
sub ConvertPDFDate($$)
{
    my ($exifTool, $date) = @_;
    # remove optional 'D:' prefix
    $date =~ s/^D://;
    # fill in default values if necessary
    #              yyyymmddhhmmss
    my $default = '00000101000000';
    if (length $date < length $default) {
        $date .= substr($default, length $date);
    }
    $date =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(.*)/ or return $date;
    $date = "$1:$2:$3 $4:$5:$6";
    if ($7) {
        my @t = split /'/, $7;
        $date .= $t[0];
        $date .= ':' . ($t[1] || 0) if $t[0] ne 'Z';
    }
    return $exifTool->ConvertDateTime($date);
}

#------------------------------------------------------------------------------
# read to nested delimiter
# Inputs: 0) data reference, 1) optional raf reference
# Returns: data up to and including matching delimiter (or undef on error)
# - updates data reference with trailing data
# - unescapes characters in literal strings
sub ReadToNested($;$)
{
    my ($dataPt, $raf) = @_;
    # matching closing delimiters
    my %mate = (
        '<<' => '>>',
        '('  => ')',
        '['  => ']',
        '<'  => '>',
    );
    my @delim = ('');   # delimiter nesting list, deepest first
    pos($$dataPt) = 0;  # begin at start of data
    for (;;) {
        unless ($$dataPt =~ /(\\*)(\(|\)|<{1,2}|>{1,2}|\[|\]|%)/g) {
            # must read some more data
            my $buff;
            last unless $raf and $raf->ReadLine($buff);
            $$dataPt .= $buff;
            pos($$dataPt) = length($$dataPt) - length($buff);
            next;
        }
        # are we in a literal string?
        if ($delim[0] eq ')') {
            # ignore escaped delimiters (preceeded by odd number of \'s)
            next if length($1) & 0x01;
            # ignore all delimiters but unescaped braces
            next unless $2 eq '(' or $2 eq ')';
        } elsif ($2 eq '%') {
            # ignore the comment
            my $pos = pos($$dataPt);
            # remove everything from '%' up to but not including newline
            $$dataPt =~ s/%\G.*//;
            pos($$dataPt) = $pos - 1;
            next;
        }
        if ($mate{$2}) {
            # push the corresponding closing delimiter
            unshift @delim, $mate{$2};
            next;
        }
        unless ($2 eq $delim[0]) {
            # handle the case where we find a ">>>" and interpret it
            # as ">> >" instead of "> >>"
            next unless $2 eq '>>' and $delim[0] eq '>';
            pos($$dataPt) = pos($$dataPt) - 1;
        }
        my $delim = shift @delim;   # remove from nesting list
        next if $delim[0];          # keep going if we have more nested delimiters
        my $pos = pos($$dataPt);
        my $buff = substr($$dataPt, 0, $pos);
        $$dataPt = substr($$dataPt, $pos);
        return $buff;   # success!
    }
    return undef;   # didn't find matching delimiter
}

#------------------------------------------------------------------------------
# extract PDF object from combination of buffered data and file
# Inputs: 0) ExifTool object reference, 1) data reference,
#         2) optional raf reference, 3) optional xref table
# Returns: converted PDF object or undef on error
#          a) dictionary object --> hash reference
#          b) array object --> array reference
#          c) indirect reference --> scalar reference
#          d) string, name, integer, boolean, null --> scalar value
# - updates $$dataPt on return to contain unused data
# - creates two bogus entries ('stream' and 'tags') in dictionaries to represent
#   the stream data and a list of the tags (not including 'stream' and 'tags')
#   in their original order
sub ExtractObject($$;$$)
{
    my ($exifTool, $dataPt, $raf, $xref) = @_;
    my (@tags, $data, $objData);
    my $dict = { };
    my $delim;

    for (;;) {
        if ($$dataPt =~ /^\s*(<{1,2}|\[|\()/) {
            $delim = $1;
            $objData = ReadToNested($dataPt, $raf);
            return undef unless defined $objData;
            last;
        } elsif ($$dataPt =~ s{^\s*(\S[^[(/<>\s]*)\s*}{}) {
#
# extract boolean, numerical, string, name, null object or indirect reference
#
            $objData = $1;
            # look for an indirect reference
            if ($objData =~ /^\d+$/ and $$dataPt =~ s/^(\d+)\s+R//) {
                $objData .= "$1 R";
                $objData = \$objData;   # return scalar reference
            }
            return $objData;    # return simple scalar or scalar reference
        }
        $raf and $raf->ReadLine($data) or return undef;
        $$dataPt .= $data;
    }
#
# extract literal string
#
    if ($delim eq '(') {
        $objData = $1 if $objData =~ /.*?\((.*)\)/s;    # remove brackets
        # decode escape sequences in literal strings
        while ($objData =~ /\\(.)/sg) {
            my $n = pos($objData) - 2;
            my $c = $1;
            my $r;
            if ($c =~ /[0-7]/) {
                # get up to 2 more octal digits
                $c .= $1 if $objData =~ /\G([0-7]{1,2})/g;
                # convert octal escape code
                $r = chr(oct($c) & 0xff);
            } elsif ($c eq "\x0d") {
                # the string is continued if the line ends with '\'
                # (also remove "\x0d\x0a")
                $c .= $1 if $objData =~ /\G(\x0a)/g;
                $r = '';
            } elsif ($c eq "\x0a") {
                # (also remove "\x0a\x0d")
                $c .= $1 if $objData =~ /\G(\x0d)/g;
                $r = '';
            } else {
                # convert escaped characters
                ($r = $c) =~ tr/nrtbf/\n\r\t\b\f/;
            }
            substr($objData, $n, length($c)+1) = $r;
            # contine search after this character
            pos($objData) = $n + length($r);
        }
        return $objData;
#
# extract hex string
#
    } elsif ($delim eq '<') {
        # decode hex data
        $objData =~ tr/0-9A-Fa-f//dc;
        $objData .= '0' if length($objData) & 0x01; # (by the spec)
        return pack('H*', $objData);
#
# extract array
#
    } elsif ($delim eq '[') {
        $objData =~ /.*?\[(.*)\]/s or return;    # remove brackets
        my $data = $1;
        my @list;
        for (;;) {
            last unless $data =~ m{\s*(\S[^[(/<>\s]*)}sg;
            my $val = $1;
            if ($val =~ /^(<{1,2}|\[|\()/) {
                my $pos = pos($data) - length($val);
                # nested dict, array, literal string or hex string
                my $buff = substr($data, $pos);
                $val = ReadToNested(\$buff);
                last unless defined $val;
                pos($data) = $pos + length($val);
                $val = ExtractObject($exifTool, \$val);
            } elsif ($val =~ /^\d/) {
                my $pos = pos($data);
                if ($data =~ /\G\s+(\d+)\s+R/g) {
                    $val = \ "$val $1 R";   # make a reference
                } else {
                    pos($data) = $pos;
                }
            }
            push @list, $val;
        }
        return \@list;
    }
#
# extract dictionary
#
    # Note: entries are not necessarily separated by whitespace (doh!)
    # ie) "/Tag/Name", "/Tag(string)", "/Tag[array]", etc are legal!
    # Also, they may be separated by a comment (ie. "/Tag%comment\nValue"),
    # but comments have already been removed
    while ($objData =~ m{(\s*)/([^/[\]()<>{}\s]+)\s*(\S[^[(/<>\s]*)}sg) {
        my $tag = $2;
        my $val = $3;
        if ($val =~ /^(<{1,2}|\[|\()/) {
            # nested dict, array, literal string or hex string
            $objData = substr($objData, pos($objData)-length($val));
            $val = ReadToNested(\$objData, $raf);
            last unless defined $val;
            $val = ExtractObject($exifTool, \$val);
            pos($objData) = 0;
        } elsif ($val =~ /^\d/) {
            my $pos = pos($objData);
            if ($objData =~ /\G\s+(\d+)\s+R/g) {
                $val = \ "$val $1 R";   # make a reference
            } else {
                pos($objData) = $pos;
            }
        }
        if ($$dict{$tag}) {
            # duplicate dictionary entries are not allowed
            $exifTool->Warn("Duplicate $tag entry in dictionary (ignored)");
        } else {
            # save the entry
            push @tags, $tag;
            $$dict{$tag} = $val;
        }
    }
    return undef unless @tags;
    $$dict{tags} = \@tags;
    return $dict unless $raf;   # direct objects can not have streams
#
# extract the stream object
#
    # dictionary must specify stream Length
    my $length = $$dict{Length} or return $dict;
    if (ref $length) {
        $length = $$length;
        my $oldpos = $raf->Tell();
        # get the location of the object specifying the length
        return $dict unless $xref and $$xref{$length};
        my $offset = $$xref{$length};
        $raf->Seek($offset, 0) or $exifTool->Warn("Bad Length offset"), return $dict;
        # verify that we are reading the expected object
        $raf->ReadLine($data) or $exifTool->Warn("Error reading Length data"), return $dict;
        $length =~ s/R/obj/;
        unless ($data =~ /^$length/) {
            $exifTool->Warn("Length object ($length) not found at $offset");
            return $dict;
        }
        $raf->ReadLine($data) or $exifTool->Warn("Error reading stream Length"), return $dict;
        $data =~ /(\d+)/ or $exifTool->Warn("Stream length not found"), return $dict;
        $length = $1;
        $raf->Seek($oldpos, 0); # restore position to start of stream
    }
    # extract the trailing stream data
    for (;;) {
        # find the stream token
        if ($$dataPt =~ /(\S+)/) {
            last unless $1 eq 'stream';
            # read an extra line because it may contain our \x0a
            $$dataPt .= $data if $raf->ReadLine($data);
            # remove our stream header
            $$dataPt =~ s/^.*stream(\x0a|\x0d\x0a)//s;
            my $more = $length - length($$dataPt);
            if ($more > 0) {
                unless ($raf->Read($data, $more) == $more) {
                    $exifTool->Warn("Error reading stream data");
                    $$dataPt = '';
                    return $dict;
                }
                $$dict{stream} = $$dataPt . $data;
                $$dataPt = '';
            } elsif ($more < 0) {
                $$dict{stream} = substr($$dataPt, 0, $length);
                $$dataPt = substr($$dataPt, $length);
            } else {
                $$dict{stream} = $$dataPt;
                $$dataPt = '';
            }
            last;
        }
        $raf->ReadLine($data) or last;
        $$dataPt .= $data;
    }
    return $dict;
}

#------------------------------------------------------------------------------
# decode filtered stream
# Inputs: 0) ExifTool object reference, 1) dictionary reference
# Returns: true if stream has been decoded OK
sub DecodeStream($$)
{
    my ($exifTool, $dict) = @_;

    return 0 unless $$dict{stream}; # no stream to decode
    if ($$dict{Filter}) {
        if ($$dict{Filter} eq '/FlateDecode') {
            if (eval 'require Compress::Zlib') {
                my $inflate = Compress::Zlib::inflateInit();
                my ($buff, $stat);
                $inflate and ($buff, $stat) = $inflate->inflate($$dict{stream});
                if ($stat == 1) {
                    $$dict{stream} = $buff;
                    # move Filter to prevent double decoding
                    $$dict{oldFilter} = $$dict{Filter};
                    $$dict{Filter} = '';
                } else {
                    $exifTool->Warn("Error inflating stream");
                    return 0;
                }
            } else {
                WarnOnce($exifTool,'Install Compress::Zlib to decode filtered streams');
                return 0;
            }
#
# apply anti-predictor if necessary
#
            return 1 unless $$dict{DecodeParms};
            my $pre = $dict->{DecodeParms}->{Predictor};
            return 1 unless $pre and $pre != 1;
            if ($pre != 12) {
                # currently only support 'up' prediction
                WarnOnce($exifTool,"FlateDecode Predictor $pre not currently supported");
                return 0;
            }
            my $cols = $dict->{DecodeParms}->{Columns};
            unless ($cols) {
                # currently only support 'up' prediction
                WarnOnce($exifTool,"No Columns for decoding stream");
                return 0;
            }
            my @bytes = unpack('C*', $$dict{stream});
            my @pre = (0) x $cols;  # initialize predictor array
            my $buff = '';
            while (@bytes > $cols) {
                my $pngFilt = shift @bytes;
                unless ($pngFilt == 2) {
                    WarnOnce($exifTool, "Unsupported PNG filter $pngFilt");
                    return 0;
                }
                foreach (@pre) {
                    $_ = ($_ + shift(@bytes)) & 0xff;
                }
                $buff .= pack('C*', @pre);
            }
            $$dict{stream} = $buff;
        } else {
            WarnOnce($exifTool, "Unsupported Filter $$dict{Filter}");
            return 0;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# fetch indirect object from file (from inside a stream if required)
# Inputs: 0) ExifTool object reference, 1) object reference, 2) xref lookup,
# Returns: object data or undefined on error
sub FetchObject($$$$)
{
    my ($exifTool, $ref, $xref, $tag) = @_;
    my $offset = $$xref{$ref};
    unless ($offset) {
        $exifTool->Warn("Bad $tag reference");
        return undef;
    }
    my ($data, $obj);
    if ($offset =~ s/^I(\d+) //) {
        my $index = $1; # object index in stream
        my ($objNum) = split ' ', $ref; # save original object number
        $ref = $offset; # now a reference to the containing stream object
        my $obj = $streamObjs{$ref};
        unless ($obj) {
            # don't try to load the same object stream twice
            return undef if defined $obj;
            $streamObjs{$ref} = '';
            # load the parent object stream
            $obj = FetchObject($exifTool, $ref, $xref, $tag);
            # make sure it contains everything we need
            return undef unless defined $obj and ref($obj) eq 'HASH';
            return undef unless $$obj{First} and $$obj{N};
            return undef unless DecodeStream($exifTool, $obj);
            # add a special 'table' entry to this dictionary which contains
            # the list of object number/offset pairs from the stream header
            my $num = $$obj{N} * 2;
            my @table = split ' ', $$obj{stream}, $num;
            return undef unless @table == $num;
            # remove everything before first object in stream
            $$obj{stream} = substr($$obj{stream}, $$obj{First});
            $table[$num-1] =~ s/^(\d+).*/$1/;  # trim excess from last number
            $$obj{table} = \@table;
            # save the object stream so we don't have to re-load it later
            $streamObjs{$ref} = $obj;
        }
        # verify that we have the specified object
        my $i = 2 * $index;
        my $table = $$obj{table};
        unless ($index < $$obj{N} and $$table[$i] == $objNum) {
            $exifTool->Warn("Bad index for stream object $tag");
            return undef;
        }
        # extract the object at the specified index in the stream
        # (offsets in table are in sequential order, so we can subract from
        #  the next offset to get the object length)
        $offset = $$table[$i + 1];
        my $len = ($$table[$i + 3] || length($$obj{stream})) - $offset;
        $data = substr($$obj{stream}, $offset, $len);
        return ExtractObject($exifTool, \$data);
    }
    my $raf = $exifTool->{RAF};
    $raf->Seek($offset, 0) or $exifTool->Warn("Bad $tag offset"), return undef;
    # verify that we are reading the expected object
    $raf->ReadLine($data) or $exifTool->Warn("Error reading $tag data"), return undef;
    ($obj = $ref) =~ s/R/obj/;
    unless ($data =~ s/^$obj//) {
        $exifTool->Warn("$tag object ($obj) not found at $offset");
        return undef;
    }
    return ExtractObject($exifTool, \$data, $raf, $xref);
}

#------------------------------------------------------------------------------
# Process PDF dictionary extract tag values
# Inputs: 0) ExifTool object reference, 1) tag table reference
#         2) dictionary reference, 3) cross-reference table reference
sub ProcessDict($$$$)
{
    my ($exifTool, $tagTablePtr, $dict, $xref) = @_;
    my $verbose = $exifTool->Options('Verbose');
    my @tags = @{$$dict{tags}};
    my $index = 0;
#
# extract information for tags in table
#
    while (@tags) {
        my $tag = shift @tags;
        my $tagInfo;
        if ($$tagTablePtr{$tag}) {
            $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        }
        if ($verbose) {
            my $val = $$dict{$tag};
            my $extra;
            if (ref $val eq 'SCALAR') {
                $extra = ", indirect object ($$val)";
                if ($fetched{$$val}) {
                    $val = "ref($$val)";
                } else {
                    # handle 'Next' links at this level to avoid deep recursion
                    if ($tag eq 'Next' and @tags and $tags[0] ne 'Next') {
                        push @tags, $tag;
                        next;
                    }
                    $fetched{$$val} = 1;
                    $val = FetchObject($exifTool, $$val, $xref, $tag);
                    $val = '<err>' unless defined $val;
                }
            } else {
                $extra = ', direct object';
            }
            if (ref $val eq 'HASH') {
                # create bogus subdirectory to recurse into this dict
                $tagInfo or $tagInfo = {
                    Name => $tag,
                    SubDirectory => {
                        TagTable => 'Image::ExifTool::PDF::Unknown',
                    },
                };
            } elsif (ref $val eq 'ARRAY') {
                my @list = @$val;
                foreach (@list) {
                    $_ = "ref($$_)" if ref $_ eq 'SCALAR';
                }
                $val = '[' . join(',',@list) . ']';
            }
            $exifTool->VerboseInfo($tag, $tagInfo,
                Value => $val,
                Extra => $extra,
                Index => $index++
            );
        }
        next unless $tagInfo;
        unless ($$tagInfo{SubDirectory}) {
            if ($$tagInfo{List}) {
                # separate tokens in whitespace delimited lists
                my @values = split ' ', $$dict{$tag};
                my $val;
                foreach $val (@values) {
                    $exifTool->FoundTag($tagInfo, $val);
                }
            } else {
                # a tag value
                $exifTool->FoundTag($tagInfo, $$dict{$tag});
            }
            next;
        }
        # process the subdirectory
        my @subDicts;
        if (ref $$dict{$tag} eq 'ARRAY') {
            @subDicts = @{$$dict{$tag}};
        } else {
            @subDicts = ( $$dict{$tag} );
        }
        # loop through all values of this tag
        for (;;) {
            my $subDict = shift @subDicts or last;
            if (ref $subDict eq 'SCALAR') {
                # load dictionary via an indirect reference
                $subDict = FetchObject($exifTool, $$subDict, $xref, $tag);
                unless ($subDict) {
                    $exifTool->Warn("Error reading $tag object");
                    next;
                }
            }
            if (ref $subDict eq 'ARRAY') {
                # convert array of key/value pairs to a hash
                next if @$subDict < 2;
                my %hash = ( tags => [] );
                while (@$subDict >= 2) {
                    my $key = shift @$subDict;
                    $key =~ s/^\///;
                    push @{$hash{tags}}, $key;
                    $hash{$key} = shift @$subDict;
                }
                $subDict = \%hash;
            } elsif (ref $subDict ne 'HASH') {
                next;
            }
            my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            if ($tag eq 'Next' and not @tags) {
                # don't increase nesting level for 'Next' link
                # (or else we can recurse very deeply)
                $index = 0;
                $tagTablePtr = $subTablePtr;
                $dict = $subDict;
                push @tags, @{$$dict{tags}};
                $verbose and $exifTool->VerboseDir($tag, scalar(@tags));
            } else {
                if ($verbose) {
                    my $oldIndent = $exifTool->{INDENT};
                    my $oldDir = $exifTool->{DIR_NAME};
                    # don't increase indent level for Next links
                    $exifTool->{INDENT} .= '| ' unless $tag eq 'Next';
                    $exifTool->{DIR_NAME} = $tag;
                    $exifTool->VerboseDir($tag, scalar(@{$$subDict{tags}}));
                    ProcessDict($exifTool, $subTablePtr, $subDict, $xref);
                    $exifTool->{INDENT} = $oldIndent;
                    $exifTool->{DIR_NAME} = $oldDir;
                } else {
                    ProcessDict($exifTool, $subTablePtr, $subDict, $xref);
                }
            }
        }
    }
#
# extract information from stream object if it exists
#
    return unless $$dict{stream};
    my $tag = 'stream';
    # add Subtype (if it exists) to stream name and remove leading '/'
    ($tag = "$$dict{Subtype}_$tag") =~ s/^\/// if $$dict{Subtype};
    return unless $$tagTablePtr{$tag};
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
    # decode stream if necessary
    DecodeStream($exifTool, $dict) or return;
    # extract information from stream
    my %dirInfo = (
        DataPt => \$$dict{stream},
        DataLen => length $$dict{stream},
        DirStart => 0,
        DirLen => length $$dict{stream},
        Parent => 'PDF',
    );
    my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
    unless ($exifTool->ProcessTagTable($subTablePtr, \%dirInfo)) {
        $exifTool->Warn("Error processing $$tagInfo{Name} information");
    }
}

#------------------------------------------------------------------------------
# extract information from PDF file
# Inputs: 0) ExifTool object reference
# Returns: 0 if not a PDF file, 1 on success, otherwise a negative error number
sub ReadPDF($)
{
    my $exifTool = shift;
    my $raf = $exifTool->{RAF};
    my $verbose = $exifTool->Options('Verbose');
    my $data;
#
# validate PDF file
#
    $raf->Read($data, 4) == 4 or return 0;
    $data eq '%PDF' or return 0;
    $exifTool->SetFileType();   # set the FileType tag
    my $tagTablePtr = GetTagTable('Image::ExifTool::PDF::Main');
#
# read the xref tables referenced from startxref at the end of the file
#
    my @xrefOffsets;
    $raf->Seek(0, 2) or return -1;
    # the %%EOF must occur within the last 1024 bytes of the file (PDF spec, appendix H)
    my $len = $raf->Tell();
    $len = 1024 if $len > 1024;
    $raf->Seek(-$len, 2) or return -1;
    $raf->Read($data, $len) == $len or return -2;
    $data =~ /.*startxref(\x0d\x0a|\x0a\x0a|\x0d|\x0a)(\d+)\1%%EOF/s or return -3;
    $/ = $1;    # set input record separator
    push @xrefOffsets, $2;
    my (%xref, @mainDicts, %loaded);
    while (@xrefOffsets) {
        my $offset = shift @xrefOffsets;
        next if $loaded{$offset};   # avoid infinite recursion
        unless ($raf->Seek($offset, 0)) {
            %loaded or return -4;
            $exifTool->Warn('Bad offset for secondary xref table');
            next;
        }
        unless ($raf->ReadLine($data)) {
            %loaded or return -5;
            $exifTool->Warn('Bad offset for secondary xref table');
            next;
        }
        my $loadXRefStream;
        if ($data eq "xref$/") {
            # load xref table
            for (;;) {
                $raf->ReadLine($data) or return -5;
                last if $data eq "trailer$/";
                my ($start, $num) = $data =~ /(\d+)\s+(\d+)/;
                $num or return -3;
                my $i;
                for ($i=0; $i<$num; ++$i) {
                    $raf->Read($data, 20) == 20 or return -5;
                    $data =~ /^(\d{10}) (\d{5}) (f|n)/ or return -3;
                    next if $3 eq 'f';  # ignore free entries
                    # save the object offset keyed by its reference
                    my $ref = ($start + $i) . ' ' . int($2) . ' R';
                    $xref{$ref} = int($1);
                }
            }
            %xref or return -3;
            $data = '';
        } elsif ($data =~ s/^(\d+)\s+(\d+)\s+obj//) {
            # this is a PDF-1.5 cross-reference stream dictionary
            $loadXRefStream = 1;
        } else {
            %loaded or return -3;
            $exifTool->Warn('Invalid secondary xref table');
            next;
        }
        my $mainDict = ExtractObject($exifTool, \$data, $raf, \%xref);
        unless ($mainDict) {
            %loaded or return -7;
            $exifTool->Warn('Error loading secondary dictionary');
            next;
        }
        while ($loadXRefStream) {
            # decode and parse our XRef stream from PDF-1.5 file
            last unless $$mainDict{Type} eq '/XRef' and
                        DecodeStream($exifTool, $mainDict) and
                        $$mainDict{Size} and $$mainDict{W} and
                        @{$$mainDict{W}} > 2;
            # construct unpack string for xref entry
            my @index;
            if ($$mainDict{Index}) {
                @index = @{$$mainDict{Index}};
            } else {
                @index = ( 0, $$mainDict{Size} );
            }
            # validate the size of the xref stream
            # (I have had problems decoding this at times)
            # first count the number of expected entries
            my $num = 0;
            my $i;
            for ($i=1; $i<@index; $i+=2) {
                $num += $index[$i];
            }
            # then determine the size of each entry
            my $w = $$mainDict{W};
            my $size = 0;
            foreach (@$w) {
                $size += $_;
            }
            $offset = 0;
            # validate the stream length
            if (length($$mainDict{stream}) != $size * $num) {
                my $s = int(length($$mainDict{stream}) / $num);
                last if $s < $size;
                $offset = $s - $size;   # ignore leading bytes
                $size = $s;             # use actual size
            }
            $offset = 0;
            my $lastOffset = length($$mainDict{stream}) - $size;
            while (@index > 1) {
                my $start = shift @index;
                $num = shift @index;
                for ($i=0; $i<$num; ++$i) {
                    last if $offset > $lastOffset;
                    my @c = unpack("x$offset C$size", $$mainDict{stream});
                    $offset += $size;
                    # calculate values in table entry
                    # (can be 1, 2, 3, 4, etc.. bytes per value)
                    my (@t, $j, $k);
                    for ($j=0; $j<3; ++$j) {
                        # use default value if W entry is 0 (as per spec)
                        $$w[$j] or $t[$j] = ($j ? 1 : 0), next;
                        $t[$j] = shift(@c);
                        for ($k=1; $k < $$w[$j]; ++$k) {
                            $t[$j] = 256 * $t[$j] + shift(@c);
                        }
                    }
                    if ($t[0] == 1) {
                        # normal object reference: use "o g R" as hash ref
                        # (o = object number, g = generation number)
                        my $ref = ($start + $i) . " $t[2] R";
                        # xref is offset of object from start
                        $xref{$ref} = $t[1];
                    } elsif ($t[0] == 2) {
                        my $ref = ($start + $i) . ' 0 R';
                        # xref is object index and stream object reference
                        $xref{$ref} = "I$t[2] $t[1] 0 R";
                    }
                }
            }
            $loadXRefStream = 0;    # success!
        }
        if ($loadXRefStream) {
            %loaded or return -8;
            $exifTool->Warn('Invalid xref stream in secondary dictionary');
        }
        $loaded{$offset} = 1;
        # load XRef stream in hybrid file if it exists
        push @xrefOffsets, $$mainDict{XRefStm} if $$mainDict{XRefStm};
        return -9 if $$mainDict{Encrypt} and not @mainDicts and not $verbose;
        push @mainDicts, $mainDict;
        # load previous xref table if it exists
        push @xrefOffsets, $$mainDict{Prev} if $$mainDict{Prev};
    }
#
# extract the information beginning with each of the main dictionaries
#
    my $dict;
    foreach $dict (@mainDicts) {
        ProcessDict($exifTool, $tagTablePtr, $dict, \%xref);
    }
    return 1;
}

#------------------------------------------------------------------------------
# ReadPDF() warning strings for each error return value
my @pdfWarning = (
    'Error seeking in file',    # -1
    'Error reading file',       # -2
    'Invalid xref table',       # -3
    'Invalid xref offset',      # -4
    'Error reading xref table', # -5
    'Error reading trailer',    # -6
    'Error reading main dictionary', # -7
    'Invalid xref stream in main dictionary', # -8
    'Encrypted documents not currently supported', # -9
);

#------------------------------------------------------------------------------
# extract information from PDF file
# Inputs: 0) ExifTool object reference
# Returns: 1 if this was a valid PDF file
sub PdfInfo($)
{
    my $exifTool = shift;

    my $oldsep = $/;
    my $result = ReadPDF($exifTool);
    $/ = $oldsep;   # restore input record separator in case it was changed
    if ($result < 0) {
        $exifTool->Warn($pdfWarning[-1 - $result]);
        $result = 1;
    }
    # clean up and return
    undef %warnedOnce;
    undef %streamObjs;
    undef %fetched;
    return $result;
}

1; # end


__END__

=head1 NAME

Image::ExifTool::PDF - Definitions for reading PDF files

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This code reads meta information from PDF (Adobe Portable Document Format)
files.  It supports object streams introduced in PDF-1.5, but only with a
limited set of Filter and Predictor algorithms.

=head1 NOTES

Encrypted PDF documents are not currently supported.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://partners.adobe.com/public/developer/pdf/index_reference.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PDF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
