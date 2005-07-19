#------------------------------------------------------------------------------
# File:         PNG.pm
#
# Description:  Routines for reading PNG, MNG and JNG images
#
# Revisions:    06/10/2005 - P. Harvey Created
#               06/23/2005 - P. Harvey Added MNG and JNG support
#
# References:   1) http://www.libpng.org/pub/png/spec/1.2/
#               2) http://www.faqs.org/docs/png/
#               3) http://www.libpng.org/pub/mng/
#
# Notes:        I haven't found a sample PNG image with a 'iTXt' chunk, so
#               this part of the code is still untested.
#------------------------------------------------------------------------------

package Image::ExifTool::PNG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.06';

sub ProcessPNG_tEXt($$$);
sub ProcessPNG_iTXt($$$);
sub ProcessPNG_Compressed($$$);

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
    GROUPS => { 2 => 'Image' },
    bKGD => {
        Name => 'BackgroundColor',
        ValueConv => 'join(" ",unpack(length($val) < 2 ? "C" : "n*", $val))',
    },
    cHRM => {
        Name => 'PrimaryChromaticities',
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
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessPNG_Compressed,
        },
    },
#   IDAT
#   IEND
    IHDR => {
        Name => 'ImageHeader',
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

# Tags for PNG tEXt zTXt and iTXt chunks
# (NOTE: ValueConv is set dynamically, so don't set it here!)
%Image::ExifTool::PNG::TextualData = (
    PROCESS_PROC => \&ProcessPNG_tEXt,
    GROUPS => { 2 => 'Image' },
    NOTES => q{
The PNG TextualData format allows aribrary tag names to be used.  Only the
standard tag names are listed below, however ExifTool will decode any tags
found in the image.
    },
    Title => 'Title',
    Author => {
        Name => 'Author',
        Groups => { 2 => 'Author' },
    },
    Description => 'Description',
    Copyright => 'Copyright',
   'Creation Time' => {
        Name => 'CreationTime',
        Groups => { 2 => 'Time' },
    },
    Software => 'Software',
    Disclaimer => 'Disclaimer',
    Warning => 'PNGWarning',    # change name to differentiate from ExifTool Warning
    Source => 'Source',
    Comment => 'Comment',
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
# Calculate CRC or update running CRC (ref 1)
# Inputs: 0) data reference, 1) running crc to update (undef intially)
#         2) data position (undef for 0), 3) data length (undef for all data),
# Returns: updated CRC
my @crcTable;
sub CalculateCRC($;$$$)
{
    my ($dataPt, $crc, $pos, $len) = @_;
    $crc = 0 unless defined $crc;
    $pos = 0 unless defined $pos;
    $len = length($$dataPt) - $pos unless defined $len;
    $crc ^= 0xffffffff;         # undo 1's complement
    # build lookup table unless done already
    unless (@crcTable) {
        my ($c, $n, $k);
        for ($n=0; $n<256; ++$n) {
            for ($k=0, $c=$n; $k<8; ++$k) {
                $c = ($c & 1) ? 0xedb88320 ^ ($c >> 1) : $c >> 1;
            }
            $crcTable[$n] = $c;
        }
    }
    # calculate the CRC
    foreach (unpack("x${pos}C$len", $$dataPt)) {
        $crc = $crcTable[($crc^$_) & 0xff] ^ ($crc >> 8);
    }
    return $crc ^ 0xffffffff;   # return 1's complement
}

#------------------------------------------------------------------------------
# Found a PNG tag -- extract info from subdirectory or decompress data if necessary
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table,
#         2) Tag ID, 3) Tag value, 4) [optional] compressed data flag:
#            0=not compressed, 1=unknown compression, 2-N=compression with type N-2
sub FoundPNG($$$$;$)
{
    my ($exifTool, $tagTablePtr, $tag, $val, $compressed) = @_;
    my $wasCompressed;
    return 0 unless defined $val;
#
# First, uncompress data if requested
#    
    my $verbose = $exifTool->Options('Verbose');
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
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
            my %subdirInfo = (
                DataPt => \$val,
                DirStart => 0,
                DataLen => $len,
                DirLen => $len,
                DirName => $$tagInfo{Name},
                TagInfo => $tagInfo,
            );
            my $subTable = GetTagTable($$subdir{TagTable});
            my $processProc = $$subdir{ProcessProc};
            # no need to re-decompress if already done
            undef $processProc if $wasCompressed and $processProc eq \&ProcessPNG_Compressed;
            my $ok = $exifTool->ProcessTagTable($subTable, \%subdirInfo, $processProc);
            return 1 if $ok;
            $compressed = 1;    # pretend this is compressed since it is binary data
        }
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
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessProfile($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $tagInfo = $$dirInfo{TagInfo};
    
    return 0 unless $$dataPt =~ /^\n(\S* ?profile)\n\s+(\d+)\n(.*)/s;
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
        Base     => 0,
        DataPt   => \$buff,
        DataLen  => $len,
        DirStart => 0,
        DirLen   => $len,
        Parent   => 'PNG',
    );
    my $processed = 0;
    my $exifTable = GetTagTable('Image::ExifTool::Exif::Main');
    if ($tagTablePtr ne $exifTable) {
        # process non-EXIF/APP1 tables as-is
        $processed = $exifTool->ProcessTagTable($tagTablePtr, \%dirInfo);
    } elsif ($buff =~ /^$Image::ExifTool::exifAPP1hdr/) {
        # APP1 EXIF information
        my $hdrLen = length($Image::ExifTool::exifAPP1hdr);
        $exifTool->{EXIF_DATA} = substr($buff, 6);
        $exifTool->{EXIF_POS} = 0;
        $processed = $exifTool->TiffInfo('PNG');
    } elsif ($buff =~ /^$Image::ExifTool::xmpAPP1hdr/) {
        # APP1 XMP information
        my $hdrLen = length($Image::ExifTool::xmpAPP1hdr);
        my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
        $dirInfo{DirStart} += $hdrLen;
        $dirInfo{DirLen} -= $hdrLen;
        $processed = $exifTool->ProcessTagTable($tagTablePtr, \%dirInfo);
    } elsif ($buff =~ /^(MM\0\x2a|II\x2a\0)/) {
        # TIFF information (haven't seen this, but what the heck...)
        $exifTool->{EXIF_DATA} = $buff;
        $exifTool->{EXIF_POS} = 0;
        $processed = $exifTool->TiffInfo('PNG');
    } else {
        $exifTool->Warn("Unknown raw $profileType");
    }
    return $processed;
}

#------------------------------------------------------------------------------
# Process PNG compressed zTXt or iCCP chunk
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessPNG_Compressed($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my ($tag, $val) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return 0 unless defined $val;
    # set compressed to 2 + compression method to decompress the data
    my $compressed = 2 + unpack('C', $val);
    $val = substr($val, 1); # remove compression method byte
    # use the PNG chunk tag instead of the embedded tag name for iCCP chunks
    if ($$dirInfo{TagInfo} and $dirInfo->{TagInfo}->{Name} eq 'ICC_Profile') {
        $tag = 'iCCP';
        $tagTablePtr = \%Image::ExifTool::PNG::Main;
    }
    return FoundPNG($exifTool, $tagTablePtr, $tag, $val, $compressed);
}

#------------------------------------------------------------------------------
# Process PNG tEXt chunk
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessPNG_tEXt($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my ($tag, $val) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return FoundPNG($exifTool, $tagTablePtr, $tag, $val);
}

#------------------------------------------------------------------------------
# Process PNG iTXt chunk
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessPNG_iTXt($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my ($tag, $dat) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return 0 unless defined $dat and length($dat) >= 4;
    my ($compressed, $meth) = unpack('CC', $dat);
    my ($lang, $trans, $val) = split /\0/, substr($dat, 2), 3;
    # set compressed flag so we will decompress it in FoundPNG()
    $compressed and $compressed = 2 + $meth;
    return FoundPNG($exifTool, $tagTablePtr, $tag, $val, $compressed);
}

#------------------------------------------------------------------------------
# PngInfo : extract meta information from a PNG image
# Inputs: 0) ExifTool object reference
# Returns: 1 on success, 0 if this wasn't a valid PNG image
sub PngInfo($)
{
    my $exifTool = shift;
    my $raf = $exifTool->{RAF};
    my $rtnVal = 0;
    my $sig;
    my $datChunk = '';
    my $datCount = 0;
    my $datBytes = 0;

    # check to be sure this is a valid PNG/MNG/JNG image
    return 0 unless $raf->Read($sig,8) == 8 and $pngLookup{$sig};
    my ($fileType, $hdrChunk, $endChunk) = @{$pngLookup{$sig}};
    $exifTool->SetFileType($fileType);  # set the FileType tag
    SetByteOrder('MM'); # PNG files are big-endian
    my %dirInfo = (
        RAF => $raf,
        DirName => $fileType,
    );
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
        if ($chunk eq $endChunk) {
            $verbose and print "$fileType $chunk (end of image)\n";
            last;
        }
        # read chunk data and CRC
        unless ($raf->Read($dbuf,$len)==$len and $raf->Read($cbuf, 4)==4) {
            $exifTool->Warn('Corrupted $fileType image');
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
            next if $datChunk;
            print "$fileType $chunk ($len bytes):\n";
            if ($verbose > 2) {
                my %dumpParms;
                $dumpParms{MaxLen} = 96 if $verbose <= 4;
                Image::ExifTool::HexDump(\$dbuf, undef, %dumpParms);
            }
        }
        # only extract information from chunks in our tables
        if ($$tagTablePtr{$chunk}) {
            FoundPNG($exifTool, $tagTablePtr, $chunk, $dbuf);
        } elsif ($mngTablePtr and $$mngTablePtr{$chunk}) {
            FoundPNG($exifTool, $mngTablePtr, $chunk, $dbuf);
        }
    }
    return 1;   # this was a valid PNG/MNG/JNG image
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PNG - Routines for reading PNG, MNG and JNG images

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read PNG
(Portable Network Graphics), MNG (Multi-image Network Graphics) and JNG
(JPEG Network Graphics) images.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.libpng.org/pub/png/spec/1.2/>

=item L<http://www.faqs.org/docs/png/>

=item L<http://www.libpng.org/pub/mng/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PNG Tags>,
L<Image::ExifTool::TagNames/MNG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

