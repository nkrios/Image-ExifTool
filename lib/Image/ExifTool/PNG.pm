#------------------------------------------------------------------------------
# File:         PNG.pm
#
# Description:  Routines for reading and writing PNG, MNG and JNG images
#
# Revisions:    06/10/2005 - P. Harvey Created
#               06/23/2005 - P. Harvey Added MNG and JNG support
#               09/16/2005 - P. Harvey Added write support
#
# References:   1) http://www.libpng.org/pub/png/spec/1.2/
#               2) http://www.faqs.org/docs/png/
#               3) http://www.libpng.org/pub/mng/
#               4) http://www.libpng.org/pub/png/spec/register/
#
# Notes:        I haven't found a sample PNG image with a 'iTXt' chunk, so
#               this part of the code is still untested.
#
#               Writing meta information in PNG images is a pain in the butt
#               for a number of reasons:  One biggie is that you have to
#               decompress then decode the ASCII/hex profile information before
#               you can edit it, then you have to ASCII/hex-encode, recompress
#               and calculate a CRC before you can write it out again.  gaaaak.
#------------------------------------------------------------------------------

package Image::ExifTool::PNG;

use strict;
use vars qw($VERSION $AUTOLOAD);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

sub ProcessPNG_tEXt($$$);
sub ProcessPNG_iTXt($$$);
sub ProcessPNG_Compressed($$$);
sub CalculateCRC($;$$$);
sub HexEncode($);
sub AddChunks($$);

my $noCompressLib;

# look up for file type, header chunk and end chunk, based on file signature
my %pngLookup = (
    "\x89PNG\r\n\x1a\n" => ['PNG', 'IHDR', 'IEND' ],
    "\x8aMNG\r\n\x1a\n" => ['MNG', 'MHDR', 'MEND' ],
    "\x8bJNG\r\n\x1a\n" => ['JNG', 'JHDR', 'IEND' ],
);

# color type of current image
$Image::ExifTool::PNG::colorType = -1;

# PNG chunks
%Image::ExifTool::PNG::Main = (
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    GROUPS => { 2 => 'Image' },
    bKGD => {
        Name => 'BackgroundColor',
        ValueConv => 'join(" ",unpack(length($val) < 2 ? "C" : "n*", $val))',
    },
    cHRM => {
        Name => 'PrimaryChromaticities',
        Writable => 0,  # set to 0 as indication that we can't edit this information
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::PrimaryChromaticities' },
    },
    fRAc => {
        Name => 'FractalParameters',
        ValueConv => '\$val',
    },
    gAMA => {
        Name => 'Gamma',
        ValueConv => 'my $a=unpack("N",$val);$a ? int(1e9/$a+0.5)/1e4 : $val',
    },
    gIFg => {
        Name => 'GIFGraphicControlExtension',
        ValueConv => '\$val',
    },
    gIFt => {
        Name => 'GIFPlainTextExtension',
        ValueConv => '\$val',
    },
    gIFx => {
        Name => 'GIFApplicationExtension',
        ValueConv => '\$val',
    },
    hIST => {
        Name => 'PaletteHistogram',
        ValueConv => '\$val',
    },
    iCCP => {
        Name => 'ICC_Profile',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessPNG_Compressed,
        },
    },
#   IDAT
#   IEND
    IHDR => {
        Name => 'ImageHeader',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::ImageHeader' },
    },
    iTXt => {
        Name => 'InternationalText',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::TextualData',
            ProcessProc => \&ProcessPNG_iTXt,
        },
    },
    oFFs => {
        Name => 'ImageOffset',
        ValueConv => q{
            my @a = unpack("NNC",$val);
            $a[2] = ($a[2] ? "microns" : "pixels");
            return "$a[0], $a[1] ($a[2])";
        },
    },
    pCAL => {
        Name => 'PixelCalibration',
        ValueConv => '\$val',
    },
    pHYs => {
        Name => 'PhysicalPixel',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::PhysicalPixel' },
    },
    PLTE => {
        Name => 'Palette',
        ValueConv => 'length($val) <= 3 ? join(" ",unpack("C*",$val)) : \$val',
    },
    sBIT => {
        Name => 'SignificantBits',
        ValueConv => 'join(" ",unpack("C*",$val))',
    },
    sPLT => {
        Name => 'SuggestedPalette',
        ValueConv => '\$val',
        PrintConv => 'split("\0",$$val,1)', # extract palette name
    },
    sRGB => {
        Name => 'SRGBRendering',
        ValueConv => 'unpack("C",$val)',
        PrintConv => {
            0 => 'Perceptual',
            1 => 'Relative Colorimetric',
            2 => 'Saturation',
            3 => 'Absolute Colorimetric',
        },
    },
    tEXt => {
        Name => 'TextualData',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::TextualData' },
    },
    tIME => {
        Name => 'ModifyDate',
        Description => 'Date/Time Of Last Modification',
        Groups => { 2 => 'Time' },
        ValueConv => 'sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d", unpack("nC5", $val))',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    tRNS => {
        Name => 'Transparency',
        ValueConv => q{
            return \$val if length($val) > 6;
            join(" ",unpack($Image::ExifTool::PNG::colorType == 3 ? "C*" : "n*", $val));
        },
    },
    tXMP => {
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
    zTXt => {
        Name => 'CompressedText',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::TextualData',
            ProcessProc => \&ProcessPNG_Compressed,
        },
    },
);

# PNG IHDR chunk
%Image::ExifTool::PNG::ImageHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    4 => {
        Name => 'ImageHeight',
        Format => 'int32u',
    },
    8 => 'BitDepth',
    9 => {
        Name => 'ColorType',
        ValueConv => '$Image::ExifTool::PNG::colorType = $val',
        PrintConv => {
            0 => 'Grayscale',
            2 => 'RGB',
            3 => 'Palette',
            4 => 'Grayscale with Alpha',
            6 => 'RGB with Alpha',
        },
    },
    10 => {
        Name => 'Compression',
        PrintConv => { 0 => 'Deflate/Inflate' },
    },
    11 => {
        Name => 'Filter',
        PrintConv => { 0 => 'Adaptive' },
    },
    12 => {
        Name => 'Interlace',
        PrintConv => { 0 => 'Noninterlaced', 1 => 'Adam7 Interlace' },
    },
);

# PNG cHRM chunk
%Image::ExifTool::PNG::PrimaryChromaticities = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    0 => { Name => 'WhitePointX', ValueConv => '$val / 100000' },
    1 => { Name => 'WhitePointY', ValueConv => '$val / 100000' },
    2 => { Name => 'RedX',        ValueConv => '$val / 100000' },
    3 => { Name => 'RedY',        ValueConv => '$val / 100000' },
    4 => { Name => 'GreenX',      ValueConv => '$val / 100000' },
    5 => { Name => 'GreenY',      ValueConv => '$val / 100000' },
    6 => { Name => 'BlueX',       ValueConv => '$val / 100000' },
    7 => { Name => 'BlueY',       ValueConv => '$val / 100000' },
);

# PNG pHYs chunk
%Image::ExifTool::PNG::PhysicalPixel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'PixelsPerUnitX',
        Format => 'int32u',
    },
    4 => {
        Name => 'PixelsPerUnitY',
        Format => 'int32u',
    },
    8 => {
        Name => 'PixelUnits',
        PrintConv => { 0 => 'Unknown', 1 => 'Meter' },
    },
);

my %unreg = ( Notes => 'unregistered' );

# Tags for PNG tEXt zTXt and iTXt chunks
# (NOTE: ValueConv is set dynamically, so don't set it here!)
%Image::ExifTool::PNG::TextualData = (
    PROCESS_PROC => \&ProcessPNG_tEXt,
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    WRITABLE => 'string',
    PREFERRED => 1, # always add these tags when writing
    GROUPS => { 2 => 'Image' },
    NOTES => q{
The PNG TextualData format allows aribrary tag names to be used.  The tags
listed below are the only ones that can be written (unless new user-defined
tags are added via the configuration file), however ExifTool will extract
any other TextualData tags that are found.

The information for the TextualData tags may be stored as tEXt, zTXt or iTXt
chunks in the PNG image.  ExifTool will read and edit tags in their original
form, but only tEXt chunks are written when creating new tags (except for
the profiles which are written as zTXt if Compress::Zlib is available).

Some of the tags below are not registered as part of the PNG specification,
but are included here because they are generated by other software such as
ImageMagick.
    },
    Title       => { },
    Author      => { Groups => { 2 => 'Author' } },
    Description => { },
    Copyright   => { Groups => { 2 => 'Author' } },
   'Creation Time' => {
        Name => 'CreationTime',
        Groups => { 2 => 'Time' },
    },
    Software    => { },
    Disclaimer  => { },
    # change name to differentiate from ExifTool Warning
    Warning     => { Name => 'PNGWarning', },
    Source      => { },
    Comment     => { },
#
# The following tags are not part of the original PNG specification,
# but are written by ImageMagick and other software
#
    Artist      => { %unreg, Groups => { 2 => 'Author' } },
    Document    => { %unreg },
    Label       => { %unreg },
    Make        => { %unreg, Groups => { 2 => 'Camera' } },
    Model       => { %unreg, Groups => { 2 => 'Camera' } },
    TimeStamp   => { %unreg, Groups => { 2 => 'Time' } },
    URL         => { %unreg },
   'Raw profile type APP1' => [
        {
            # EXIF table must come first because we key on this in ProcessProfile()
            # (No condition because this is just for BuildTagLookup)
            Name => 'APP1_Profile',
            SubDirectory => {
                TagTable=>'Image::ExifTool::Exif::Main',
                ProcessProc => \&ProcessProfile,
            },
        },
        {
            Name => 'APP1_Profile',
            SubDirectory => {
                TagTable=>'Image::ExifTool::XMP::Main',
                ProcessProc => \&ProcessProfile,
            },
        },
    ],
   'Raw profile type exif' => {
        Name => 'EXIF_Profile',
        SubDirectory => {
            TagTable=>'Image::ExifTool::Exif::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type icc' => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type icm' => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type iptc' => {
        Name => 'IPTC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type xmp' => {
        Name => 'XMP_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
);

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Found a PNG tag -- extract info from subdirectory or decompress data if necessary
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table,
#         2) Tag ID, 3) Tag value, 4) [optional] compressed data flag:
#            0=not compressed, 1=unknown compression, 2-N=compression with type N-2
#         5) optional output buffer reference
sub FoundPNG($$$$;$$)
{
    my ($exifTool, $tagTablePtr, $tag, $val, $compressed, $outBuff) = @_;
    my $wasCompressed;
    return 0 unless defined $val;
#
# First, uncompress data if requested
#    
    my $verbose = $exifTool->Options('Verbose');
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag) ||
                  # (some software forgets to capitalize first letter)
                  $exifTool->GetTagInfo($tagTablePtr, ucfirst($tag));
    if ($compressed and $compressed > 1) {
        my $warn;
        if ($compressed == 2) { # Inflate/Deflate compression
            if (eval 'require Compress::Zlib') {
                my $v2;
                my $inflate = Compress::Zlib::inflateInit();
                $inflate and ($v2) = $inflate->inflate($val);
                if ($v2) {
                    $val = $v2;
                    $compressed = 0;
                    $wasCompressed = 1;
                } else {
                    $warn = "Error inflating $tag";
                }
            } elsif (not $noCompressLib) {
                $noCompressLib = 1;
                $warn = 'Install Compress::Zlib to decode compressed binary data';
            }
        } else {
            $compressed -= 2;
            $warn = "Unknown compression method $compressed for $tag";
        }
        if ($compressed and $verbose and $tagInfo and $$tagInfo{SubDirectory}) {
            $exifTool->VerboseDir("Unable to decompress $$tagInfo{Name}", 0, length($val));
        }
        $warn and $exifTool->Warn($warn);
    }
#
# extract information from subdirectory if available
#
    if ($tagInfo) {
        my $processed;
        if ($$tagInfo{SubDirectory} and not $compressed) {
            my $len = length $val;
            if ($verbose and $exifTool->{INDENT} ne '  ') {
                if ($wasCompressed and $verbose > 2) {
                    my $name = $$tagInfo{Name};
                    $wasCompressed and $name = "Decompressed $name";
                    $exifTool->VerboseDir($name, 0, $len);
                    my %parms = ( Prefix => $exifTool->{INDENT} );
                    $parms{MaxLen} = 96 unless $verbose > 3;
                    Image::ExifTool::HexDump(\$val, undef, %parms);
                }
                # don't indent next directory (since it is really the same data)
                $exifTool->{INDENT} = substr($exifTool->{INDENT}, 0, -2);
            }
            my $subdir = $$tagInfo{SubDirectory};
            my $processProc = $$subdir{ProcessProc};
            # don't extract info if Writable flag is defined
            # (it is set to 0 for a subdir that we can't edit)
            return 1 if $outBuff and defined $$tagInfo{Writable};
            my %subdirInfo = (
                DataPt => \$val,
                DirStart => 0,
                DataLen => $len,
                DirLen => $len,
                DirName => $$tagInfo{Name},
                TagInfo => $tagInfo,
                OutBuff => $outBuff,
            );
            my $subTable = GetTagTable($$subdir{TagTable});
            # no need to re-decompress if already done
            undef $processProc if $wasCompressed and $processProc eq \&ProcessPNG_Compressed;
            $processed = $exifTool->ProcessDirectory(\%subdirInfo, $subTable, $processProc);
            $compressed = 1;    # pretend this is compressed since it is binary data
        }
        if ($outBuff) {
            my $writable = $tagInfo->{Writable};
            if ($writable or ($$tagTablePtr{WRITABLE} and
                not defined $writable and not $$tagInfo{SubDirectory}))
            {
                # write new value for this tag if necessary
                my ($isOverwriting, $newVal);
                if ($exifTool->{DEL_GROUP} and $exifTool->{DEL_GROUP}->{PNG}) {
                    $isOverwriting = 1;
                } else {
                    my $newValueHash = $exifTool->GetNewValueHash($tagInfo);
                    $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash, $val);
                    $newVal = Image::ExifTool::GetNewValues($newValueHash);
                }
                if ($isOverwriting) {
                    $$outBuff =  (defined $newVal) ? $newVal : '';
                    ++$exifTool->{CHANGED};
                    if ($verbose > 1) {
                        print "    - $$tagInfo{Name} = '$val'\n";
                        print "    + $$tagInfo{Name} = '$newVal'\n" if defined $newVal;
                    }
                }
            }
            if ($$outBuff and $wasCompressed) {
                # re-compress the output data
                my $deflate;
                if (eval 'require Compress::Zlib') {
                    my $deflate = Compress::Zlib::deflateInit();
                    if ($deflate) {
                        $$outBuff = $deflate->deflate($$outBuff);
                        $$outBuff .= $deflate->flush() if defined $$outBuff;
                    } else {
                        undef $$outBuff;
                    }
                }
                $$outBuff or $exifTool->Warn("Error compressing $$tagInfo{Name} -- unchanged");
            }
            return 1;
        }
        return 1 if $processed;
    } else {
        my $name;
        ($name = $tag) =~ s/\s+(.)/\u$1/g;   # remove white space from tag name
        $tagInfo = { Name => $name };
        # make unknown profiles binary data type
        $$tagInfo{ValueConv} = '\$val' if $tag =~ /^Raw profile type /;
        Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
#
# store this tag information
#
    if ($verbose) {
        # temporarily remove subdirectory so it isn't printed in verbose information
        # since we aren't decoding it anyway;
        my $subdir = $$tagInfo{SubDirectory};
        delete $$tagInfo{SubDirectory};
        $exifTool->VerboseInfo($tag, $tagInfo,
            Table  => $tagTablePtr,
            DataPt => \$val,
        );
        $$tagInfo{SubDirectory} = $subdir if $subdir;
    }
    # set the ValueConv dynamically depending on whether this is binary or not
    my $delValueConv;
    if ($compressed and not defined $$tagInfo{ValueConv}) {
        $$tagInfo{ValueConv} = '\$val';
        $delValueConv = 1;
    }
    $exifTool->FoundTag($tagInfo, $val);
    delete $$tagInfo{ValueConv} if $delValueConv;
    return 1;
}

#------------------------------------------------------------------------------
# Process encoded PNG profile information
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
sub ProcessProfile($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $tagInfo = $$dirInfo{TagInfo};
    my $outBuff = $$dirInfo{OutBuff};

    # ImageMagick 5.3.6 writes profiles with the following headers:
    # "\nICC Profile\n", "\nIPTC profile\n", "\n\xaa\x01{generic prof\n"
    # and "\ngeneric profile\n"
    return 0 unless $$dataPt =~ /^\n(.*?)\n\s*(\d+)\n(.*)/s;
    my ($profileType, $len) = ($1, $2);
    # data is encoded in hex, so change back to binary
    my $buff = pack('H*', join('',split(' ',$3)));
    my $actualLen = length $buff;
    if ($len ne $actualLen) {
        $exifTool->Warn("$$tagInfo{Name} is wrong size (should be $len bytes but is $actualLen)");
        $len = $actualLen;
    }
    my $verbose = $exifTool->Options('Verbose');
    if ($verbose) {
        if ($verbose > 2) {
            $exifTool->VerboseDir("Decoded $$tagInfo{Name}", 0, $len);
            my %parms = ( Prefix => $exifTool->{INDENT} );
            $parms{MaxLen} = 96 unless $verbose > 3;
            Image::ExifTool::HexDump(\$buff, undef, %parms);
        }
        # don't indent next directory (since it is really the same data)
        $exifTool->{INDENT} = substr($exifTool->{INDENT}, 0, -2);
    }
    my %dirInfo = (
        Parent   => 'PNG',
        DataPt   => \$buff,
        DataLen  => $len,
        DirStart => 0,
        DirLen   => $len,
        Base     => 0,
        OutFile  => $outBuff,
    );
    my $processed = 0;
    my $oldChanged = $exifTool->{CHANGED};
    my $exifTable = GetTagTable('Image::ExifTool::Exif::Main');
    my $editDirs = $exifTool->{EDIT_DIRS};
    my $addDirs = $exifTool->{ADD_DIRS};
    if ($tagTablePtr ne $exifTable) {
        # process non-EXIF and non-APP1 profile as-is
        if ($outBuff) {
            # no need to rewrite this if not editing tags in this directory
            my $dir = $$tagInfo{Name};
            $dir =~ s/_Profile// unless $dir =~ /^ICC/;
            return 1 unless $$editDirs{$dir};
            delete $$addDirs{$dir};
            $$outBuff = $exifTool->WriteDirectory(\%dirInfo, $tagTablePtr);
        } else {
            $processed = $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
    } elsif ($buff =~ /^$Image::ExifTool::exifAPP1hdr/) {
        # APP1 EXIF information
        return 1 if $outBuff and not $$editDirs{IFD0};
        my $hdrLen = length($Image::ExifTool::exifAPP1hdr);
        $dirInfo{DirStart} += $hdrLen;
        $dirInfo{DirLen} -= $hdrLen;
        $processed = $exifTool->ProcessTIFF(\%dirInfo);
        if ($outBuff) {
            if ($$outBuff) {
                $$outBuff = $Image::ExifTool::exifAPP1hdr . $$outBuff if $$outBuff;
            } else {
                $$outBuff = '' if $processed;
            }
            delete $$addDirs{IFD0};
        }
    } elsif ($buff =~ /^$Image::ExifTool::xmpAPP1hdr/) {
        # APP1 XMP information
        my $hdrLen = length($Image::ExifTool::xmpAPP1hdr);
        my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
        $dirInfo{DirStart} += $hdrLen;
        $dirInfo{DirLen} -= $hdrLen;
        if ($outBuff) {
            return 1 unless $$editDirs{XMP};
            delete $$addDirs{XMP};
            $$outBuff = $exifTool->WriteDirectory(\%dirInfo, $tagTablePtr);
            $$outBuff and $$outBuff = $Image::ExifTool::xmpAPP1hdr . $$outBuff;
        } else {
            $processed = $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
    } elsif ($buff =~ /^(MM\0\x2a|II\x2a\0)/) {
        # TIFF information (haven't seen this, but what the heck...)
        return 1 if $outBuff and not $$editDirs{IFD0};
        $processed = $exifTool->ProcessTIFF(\%dirInfo);
        if ($outBuff) {
            if ($$outBuff) {
                $$outBuff = $Image::ExifTool::exifAPP1hdr . $$outBuff if $$outBuff;
            } else {
                $$outBuff = '' if $processed;
            }
            delete $$addDirs{IFD0};
        }
    } else {
        my $profName = $profileType;
        $profName =~ tr/\x00-\x1f\x7f-\xff/./;
        $exifTool->Warn("Unknown raw profile '$profName'");
    }
    if ($outBuff and $$outBuff) {
        if ($exifTool->{CHANGED} != $oldChanged) {
            my $hdr = sprintf("\n%s\n%8d\n", $profileType, length($$outBuff));
            # hex encode the data
            $$outBuff = $hdr . HexEncode($outBuff);
        } else {
            undef $$outBuff;
        }
    }
    return $processed;
}

#------------------------------------------------------------------------------
# Process PNG compressed zTXt or iCCP chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
sub ProcessPNG_Compressed($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my ($tag, $val) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return 0 unless defined $val;
    # set compressed to 2 + compression method to decompress the data
    my $compressed = 2 + unpack('C', $val);
    my $hdr = $tag . "\0" . substr($val, 0, 1);
    $val = substr($val, 1); # remove compression method byte
    # use the PNG chunk tag instead of the embedded tag name for iCCP chunks
    if ($$dirInfo{TagInfo} and $$dirInfo{TagInfo}->{Name} eq 'ICC_Profile') {
        $tag = 'iCCP';
        $tagTablePtr = \%Image::ExifTool::PNG::Main;
    }
    my $outBuff = $$dirInfo{OutBuff};
    my $rtnVal = FoundPNG($exifTool, $tagTablePtr, $tag, $val, $compressed, $outBuff);
    # add header back onto this chunk if we are writing
    $$outBuff = $hdr . $$outBuff if $outBuff and $$outBuff;
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Process PNG tEXt chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
sub ProcessPNG_tEXt($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my ($tag, $val) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    my $outBuff = $$dirInfo{OutBuff};
    my $rtnVal = FoundPNG($exifTool, $tagTablePtr, $tag, $val, undef, $outBuff);
    # add header back onto this chunk if we are writing
    if ($outBuff) {
        $$outBuff = $tag . "\0" . $$outBuff if $$outBuff;
        delete $exifTool->{ADD_PNG}->{ucfirst($tag)};
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Process PNG iTXt chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
sub ProcessPNG_iTXt($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my ($tag, $dat) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return 0 unless defined $dat and length($dat) >= 4;
    my ($compressed, $meth) = unpack('CC', $dat);
    my ($lang, $trans, $val) = split /\0/, substr($dat, 2), 3;
    # set compressed flag so we will decompress it in FoundPNG()
    $compressed and $compressed = 2 + $meth;
    my $outBuff = $$dirInfo{OutBuff};
    my $rtnVal = FoundPNG($exifTool, $tagTablePtr, $tag, $val, $compressed, $outBuff);
    if ($outBuff and $$outBuff) {
        $$outBuff = substr($dat, 0, 2) . "$lang\0$trans\0" . $$outBuff;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Extract meta information from a PNG image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PNG image
sub ProcessPNG($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $raf = $$dirInfo{RAF};
    my $datChunk = '';
    my $datCount = 0;
    my $datBytes = 0;
    my ($sig, $err, $ok);

    # check to be sure this is a valid PNG/MNG/JNG image
    return 0 unless $raf->Read($sig,8) == 8 and $pngLookup{$sig};
    if ($outfile) {
        Write($outfile, $sig) or $err = 1 if $outfile;
        # can only add tags in TextualData
        $exifTool->{ADD_PNG} = $exifTool->GetNewTagInfoHash(\%Image::ExifTool::PNG::TextualData);
        $exifTool->InitWriteDirs('JPEG');   # use same directories as JPEG
    }
    my ($fileType, $hdrChunk, $endChunk) = @{$pngLookup{$sig}};
    $exifTool->SetFileType($fileType);  # set the FileType tag
    SetByteOrder('MM'); # PNG files are big-endian
    my $tagTablePtr = GetTagTable('Image::ExifTool::PNG::Main');
    my $mngTablePtr;
    if ($fileType ne 'PNG') {
        $mngTablePtr = GetTagTable('Image::ExifTool::MNG::Main');
    }
    my $verbose = $exifTool->{OPTIONS}->{Verbose};
    my ($hbuf, $dbuf, $cbuf, $foundHdr);

    # process the PNG/MNG/JNG chunks
    undef $noCompressLib;
    for (;;) {
        $raf->Read($hbuf,8) == 8 or $exifTool->Warn("Truncated $fileType image"), last;
        my ($len, $chunk) = unpack('Na4',$hbuf);
        $len > 0x7fffffff and $exifTool->Warn("Invalid $fileType box size"), last;
        if ($verbose) {
            # don't dump image data chunks in verbose mode (only give count instead)
            if ($datCount and $chunk ne $datChunk) {
                my $s = $datCount > 1 ? 's' : '';
                print "$fileType $datChunk ($datCount chunk$s, total $datBytes bytes)\n";
                $datCount = $datBytes = 0;
                $datChunk = '';
            }
            if ($chunk =~ /^(IDAT|JDAT|JDAA)$/) {
                $datChunk = $chunk;
                $datCount++;
                $datBytes += $len;
            }
        }
        # add any new chunks immediately before the IEND chunk
        if ($outfile and $chunk eq 'IEND') {
            AddChunks($exifTool, $outfile) or $err = 1;
        }
        if ($chunk eq $endChunk) {
            if ($outfile) {
                # copy over the rest of the file if necessary
                Write($outfile, $hbuf) or $err = 1;
                while ($raf->Read($hbuf, 65536)) {
                    Write($outfile, $hbuf) or $err = 1;
                }
            }
            $verbose and print "$fileType $chunk (end of image)\n";
            $ok = 1;
            last;
        }
        # read chunk data and CRC
        unless ($raf->Read($dbuf,$len)==$len and $raf->Read($cbuf, 4)==4) {
            $exifTool->Warn("Corrupted $fileType image");
            last;
        }
        unless ($foundHdr) {
            if ($chunk eq $hdrChunk) {
                $foundHdr = 1;
            } else {
                $exifTool->Warn("$fileType image did not start with $hdrChunk");
                last;
            }
        }
        if ($verbose) {
            # check CRC when in verbose mode (since we don't care about speed)
            my $crc = CalculateCRC(\$hbuf, undef, 4);
            $crc = CalculateCRC(\$dbuf, $crc);
            unless ($crc == unpack('N',$cbuf)) {
                $exifTool->Warn("Bad CRC for $chunk chunk");
            }
            if ($datChunk) {
                Write($outfile, $hbuf, $dbuf, $cbuf) or $err = 1 if $outfile;
                next;
            }
            print "$fileType $chunk ($len bytes):\n";
            if ($verbose > 2) {
                my %dumpParms;
                $dumpParms{MaxLen} = 96 if $verbose <= 4;
                Image::ExifTool::HexDump(\$dbuf, undef, %dumpParms);
            }
        }
        # only extract information from chunks in our tables
        my ($theBuff, $outBuff);
        $outBuff = \$theBuff if $outfile;
        if ($$tagTablePtr{$chunk}) {
            FoundPNG($exifTool, $tagTablePtr, $chunk, $dbuf, undef, $outBuff);
        } elsif ($mngTablePtr and $$mngTablePtr{$chunk}) {
            FoundPNG($exifTool, $mngTablePtr, $chunk, $dbuf, undef, $outBuff);
        }
        if ($outfile) {
            if ($theBuff) {
                $hbuf = pack('Na4',length($theBuff), $chunk);
                $dbuf = $theBuff;
                my $crc = CalculateCRC(\$hbuf, undef, 4);
                $crc = CalculateCRC(\$dbuf, $crc);
                $cbuf = pack('N', $crc);
            } elsif (defined $theBuff) {
                next;   # empty if we deleted the information
            }
            Write($outfile, $hbuf, $dbuf, $cbuf) or $err = 1;
        }
    }
    return -1 if $outfile and ($err or not $ok);
    return 1;   # this was a valid PNG/MNG/JNG image
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PNG - Read and write PNG, MNG and JNG images

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read and
write PNG (Portable Network Graphics), MNG (Multi-image Network Graphics)
and JNG (JPEG Network Graphics) images.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.libpng.org/pub/png/spec/1.2/>

=item L<http://www.faqs.org/docs/png/>

=item L<http://www.libpng.org/pub/mng/>

=item L<http://www.libpng.org/pub/png/spec/register/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PNG Tags>,
L<Image::ExifTool::TagNames/MNG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

