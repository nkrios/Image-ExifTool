#------------------------------------------------------------------------------
# File:         Nikon.pm
#
# Description:  Definitions for Nikon EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#               05/17/2004 - P. Harvey Added information from Joseph Heled
#               09/21/2004 - P. Harvey Changed tag 2 to ISOUsed & added PrintConv
#               12/01/2004 - P. Harvey Added default PRINT_CONV
#               12/06/2004 - P. Harvey Added SceneMode
#               01/01/2005 - P. Harvey Decode preview image and preview IFD
#               03/35/2005 - T. Christiansen additions
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Joseph Heled private communication (tests with D70)
#               3) Thomas Walter private communication (tests with Coolpix 5400)
#               4) http://www.cybercom.net/~dcoffin/dcraw/
#               5) Brian Ristuccia private communication (tests with D70)
#               6) Danek Duvall private communication (tests with D70)
#               7) Tom Christiansen private communication (tchrist@perl.com)
#               8) Robert Rottmerhusen private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Nikon;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.20';

%Image::ExifTool::Nikon::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRINT_CONV => 'Image::ExifTool::Nikon::FormatString($val)',
    0x0001 => { #2
        # the format differs for different models.  for D70, this is a string '0210',
        # but for the E775 it is binary: "\x00\x01\x00\x00"
        Name => 'FileSystemVersion',
        Writable => 'undef',
        # convert to string if binary
        ValueConv => '$_=$val; /^[\x00-\x09]/ and $_=join("",unpack("CCCC",$_)); $_',
        ValueConvInv => '$val',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_',
        PrintConvInv => '$_=$val;s/\.//;"0$_"',
    },
    # 0x0001 - unknown. Always 0210 for D70. Might be a version number? (ref 2)
    0x0002 => {
        # this is the ISO actually used by the camera
        # (may be different than ISO setting if auto)
        Name => 'ISO',
        Description => 'ISO Speed',
        Writable => 'int16u',
        Priority => 0,  # the EXIF ISO is more reliable
        Count => 2,
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    0x0003 => 'ColorMode',
    0x0004 => 'Quality',
    0x0005 => 'WhiteBalance',
    0x0006 => 'Sharpness',
    0x0007 => 'FocusMode',
    0x0008 => 'FlashSetting',
    # FlashType shows 'Built-in,TTL' when builtin flash fires,
    # and 'Optional,TTL' when external flash is used (ref 2)
    0x0009 => 'FlashType', #2
    0x000b => { #2
        Name => 'WhiteBalanceFineTune',
        Writable => 'int16u',
    },
    0x000c => 'ColorBalance1',
    # 0x000e last 3 bytes '010c00', first byte changes from shot to shot.
    0x000f => 'ISOSelection', #2
    0x0010 => {
        Name => 'DataDump',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0011 => {
        Name => 'NikonPreview',
        Groups => { 1 => 'NikonPreview', 2 => 'Image' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewImage',
            Start => '$val',
        },
    },
    0x0012 => { #2
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Format => 'int32s',
        # just the top byte, signed
        PrintConv => 'use integer;$val>>=24;no integer;sprintf("%.1f",$val/6)',
    },
    # D70 - another ISO tag
    0x0013 => { #2
        Name => 'ISOSetting',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    # D70 Image boundary?? top x,y bot-right x,y
    0x0016 => 'ImageBoundary', #2
    0x0018 => { #5
        Name => 'FlashExposureBracketValue',
        Format => 'int32s',
        # just the top byte, signed
        PrintConv => 'sprintf("%.1f",($val >> 24)/6)',
    },
    0x0019 => { #5
        Name => 'ExposureBracketValue',
        Format => 'rational32s',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0080 => 'ImageAdjustment',
    0x0081 => 'ToneComp', #2
    0x0082 => 'AuxiliaryLens',
    0x0083 => {
        Name => 'LensType',
        Writable => 'int8u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        PrintConv => q[$_ = $val ? Image::ExifTool::Exif::DecodeBits($val,
            {
                0 => 'MF',
                1 => 'D',
                2 => 'G',
                3 => 'VR',
            }) : 'AF';
            # remove commas and change "D G" to just "G"
            s/,//g; s/\bD G\b/G/; $_
        ],
        PrintConvInv => q[
            my $bits = 0;
            $bits |= 0x01 if $val =~ /\bMF\b/i;
            $bits |= 0x02 if $val =~ /\bD\b/i;
            $bits |= 0x06 if $val =~ /\bG\b/i;
            $bits |= 0x08 if $val =~ /\bVR\b/i;
            return $bits;
        ],
    },
    0x0084 => { #2
        Name => "Lens",
        Writable => 'rational32u',
        Count => 4,
        # short focal, long focal, aperture at short focal, aperture at long focal
        PrintConv => q{
            my ($a,$b,$c,$d) = split /\s+/, $val;
            ($a==$b ? $a : "$a-$b") . "mm f/" . ($c==$d ? $c : "$c-$d")
        },
        PrintConvInv => '$_=$val; tr/a-z\///d; s/(^|\s)([0-9.]+)(?=\s|$)/$1$2-$2/g; s/-/ /g; $_',
    },
    0x0085 => {
        Name => 'ManualFocusDistance',
        Writable => 'rational32u',
    },
    0x0086 => {
        Name => 'DigitalZoom',
        Writable => 'rational32u',
    },
    0x0087 => { #5
        Name => 'FlashMode',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Did Not Fire',
            8 => 'Fired, Commander Mode',
            9 => 'Fired, TTL Mode',
        },
    },
    0x0088 => {
        Name => 'AFPoint',
        Format => 'int32u',  # override format since int32u is more sensible
        Writable => 'int32u',
        Flags => 'PrintHex',
        PrintConv => {
            0x0000 => 'Center',
            0x0100 => 'Top',
            0x0200 => 'Bottom',
            0x0300 => 'Left',
            0x0400 => 'Right',

            # D70 (ref 2)
            0x0000001 => 'Single Area, Center',
            0x0010002 => 'Single Area, Top',
            0x0020004 => 'Single Area, Bottom',
            0x0030008 => 'Single Area, Left',
            0x0040010 => 'Single Area, Right',

            0x1000001 => 'Dynamic Area, Center',
            0x1010002 => 'Dynamic Area, Top',
            0x1020004 => 'Dynamic Area, Bottom',
            0x1030008 => 'Dynamic Area, Left',
            0x1040010 => 'Dynamic Area, Right',

            0x2000001 => 'Closest Subject, Center',
            0x2010002 => 'Closest Subject, Top',
            0x2020004 => 'Closest Subject, Bottom',
            0x2030008 => 'Closest Subject, Left',
            0x2040010 => 'Closest Subject, Right',
        },
    },
    0x0089 => { #5
        Name => 'ShootingMode',
        Writable => 'int16u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        # The (new?) bit 5 seriously complicates our life here: after firmwareB's
        # 1.03, bit 5 turns on when you ask for BUT DO NOT USE the long-range
        # noise reduction feature, probably because even not using it, it still
        # slows down your drive operation to 50% (1.5fps max not 3fps).  But no
        # longer does !$val alone indicate single-frame operation. - TC
        PrintConv => q[
            $_ = '';
            unless ($val & 0x87) {
                return 'Single-Frame' unless $val;
                $_ = 'Single-Frame, ';
            }
            return $_ . Image::ExifTool::Exif::DecodeBits($val,
            {
                0 => 'Continuous',
                1 => 'Delay',
                2 => 'PC Control',
                4 => 'Exposure Bracketing',
                5 => 'Unused LE-NR Slowdown',
                6 => 'White-Balance Bracketing',
                7 => 'IR Control',
            });
        ],
    },
    0x008b => { #8
        Name => 'LensFStops',
        ValueConv => 'my ($a,$b,$c)=unpack("C3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => 'my $a=int($val*12+0.5);$a<256 ? pack("C4",$a,1,12,0) : undef',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
        Writable => 'undef',
        Count => 4,
    },
    0x008c => {
        Name => 'NEFCurve1',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x008d => 'ColorHue' , #2
    # SceneMode takes on the following values: PORTRAIT, PARTY/INDOOR, NIGHT PORTRAIT,
    # BEACH/SNOW, LANDSCAPE, SUNSET, NIGHT SCENE, MUSEUM, FIREWORKS, CLOSE UP, COPY,
    # BACK LIGHT, PANORAMA ASSIST, SPORT, DAWN/DUSK
    0x008f => 'SceneMode', #2
    # LightSource shows 3 values COLORED SPEEDLIGHT NATURAL.
    # (SPEEDLIGHT when flash goes. Have no idea about difference between other two.)
    0x0090 => 'LightSource', #2
    0x0092 => { #2
        Name => 'HueAdjustment',
        Writable => 'int16s',
    },
    0x0094 => 'Saturation',
    0x0095 => 'NoiseReduction',
    0x0096 => {
        Name => 'NEFCurve2',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0097 => [ #4
        {
            Condition => '$self->{CameraModel} =~ /NIKON D70/',
            Name => 'ColorBalanceD70',
            Writable => 0,
            # D70:  at file offset 'tag-value + base + 20', 4 16 bits numbers,
            # v[0]/v[1] , v[2]/v[3] are the red/blue multipliers.
            SubDirectory => {
                Start => '$valuePtr + 20',
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceD70',
            },
        },
        {
            Condition => '$self->{CameraModel} =~ /NIKON D2H/',
            Name => 'ColorBalanceD2H',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 10',
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceD2H',
            },
        },
        {
            Condition => '$self->{CameraModel} =~ /NIKON D100/',
            Name => 'ColorBalanceD100',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 72',
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceD100',
            },
        },
        {
            Name => 'ColorBalanceUnknown',
            Writable => 0,
        },
    ],
    # D70 guessing here
    0x0099 => { #2
        Name => 'NEFThumbnailSize',
        Writable => 'int16u',
        Count => 2,
    },
    # 0x009a unknown shows '7.8 7.8' on all my shots (ref 2)
    0x00a0 => 'SerialNumber', #2
    0x00a7 => { # Number of shots taken by camera so far??? (ref 2)
        Name => 'ShutterCount',
        Writable => 'int32u',
    },
    0x00a9 => 'ImageOptimization', #2
    0x00aa => 'Saturation', #2
    0x00ab => 'VariProgram', #2
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    # 0x0e01 I don't know what this is, but in D70 NEF files produced by Nikon
    # Capture, the data for this tag extends 4 bytes past the end of the maker notes.
    # Very odd.  I hope these 4 bytes aren't useful because they will get lost by any
    # utility that just copies the maker notes - PH
    # 0x0e0e is in D70 Nikon Capture files (not out-of-the-camera D70 files) - PH
    0x0e0e => { #PH
        Name => 'NikonCaptureOffsets',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::NikonCaptureOffsets',
            Validate => '$val =~ /^0100/',
            Start => '$valuePtr + 4',
        },
    },
);

# ref PH
%Image::ExifTool::Nikon::NikonCaptureOffsets = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonCaptureOffsets,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'IFD0_Offset',
    2 => 'PreviewIFD_Offset',
    3 => 'SubIFD_Offset',
);

%Image::ExifTool::Nikon::ColorBalanceD70 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'rational16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
    1 => {
        Name => 'BlueBalance',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::Nikon::ColorBalanceD2H = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'rational16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
    1 => {
        Name => 'BlueBalance',
        ValueConv => '$val ? 1/$val : 0',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::Nikon::ColorBalanceD100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
    1 => {
        Name => 'BlueBalance',
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::Nikon::MakerNotesB = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0003 => {
        Name => 'Quality',
        Description => 'Image Quality',
    },
    0x0004 => 'ColorMode',
    0x0005 => 'ImageAdjustment',
    0x0006 => 'CCDSensitivity',
    0x0007 => 'WhiteBalance',
    0x0008 => 'Focus',
    0x000A => 'DigitalZoom',
    0x000B => 'Converter',
);

# these are standard EXIF tags, but they are duplicated here so we
# can change some names to extract the Nikon preview separately
%Image::ExifTool::Nikon::PreviewImage = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'NikonPreview', 2 => 'Image'},
    0x103 => {
        Name => 'Compression',
        PrintConv => \%Image::ExifTool::Exif::compression,
    },
    0x11a => 'XResolution',
    0x11b => 'YResolution',
    0x128 => {
        Name => 'ResolutionUnit',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    0x201 => {
        Name => 'PreviewImageStart',
        Flags => [ 'IsOffset', 'Permanent' ],
        OffsetPair => 0x202, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'NikonPreview',
        Protected => 2,
    },
    0x202 => {
        Name => 'PreviewImageLength',
        Flags => 'Permanent' ,
        OffsetPair => 0x201, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'NikonPreview',
        Protected => 2,
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
    },
);

# Nikon composite tags
%Image::ExifTool::Nikon::Composite = (
    GROUPS => { 2 => 'Camera' },
    LensSpec => {
        Description => 'Lens',
        Require => {
            0 => 'Nikon:Lens',
            1 => 'Nikon:LensType',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '"$valPrint[0] $valPrint[1]"',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::Nikon::Composite);


#------------------------------------------------------------------------------
# process Nikon IFD
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
# Notes: This isn't a normal IFD, but is close...
sub ProcessNikonCaptureOffsets($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart};
    my $dirLen = $dirInfo->{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $success = 0;
    return 0 unless $dirLen > 2;
    my $count = Get16u($dataPt, $dirStart);
    return 0 unless $count and $count * 12 + 2 <= $dirLen;
    my $index;
    for ($index=0; $index<$count; ++$index) {
        my $pos = $dirStart + 12 * $index + 2;
        my $tagID = Get32u($dataPt, $pos);
        my $value = Get32u($dataPt, $pos + 4);
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
        if ($verbose) {
            $exifTool->VerboseInfo($tagID, $tagInfo,
                'Table'  => $tagTablePtr,
                'Index'  => $index,
                'Value'  => $value,
                'DataPt' => $dataPt,
                'Size'   => 12,
                'Start'  => $pos,
            );
        }
        next unless $tagInfo;
        $exifTool->FoundTag($tagInfo, $value);
        $success = 1;
    }
    return $success;
}

#------------------------------------------------------------------------------
# Clean up formatting of string values
# Inputs: 0) string value
# Returns: formatted string value
# - removes trailing spaces and changes case to something more sensible
sub FormatString($)
{
    my $str = shift;
    # limit string length (can be very long for some unknown tags)
    if (length($str) > 60) {
        $str = substr($str,0,55) . "[...]";
    } else {
        $str =~ s/\s+$//;   # remove trailing white space and null terminator
        # Don't change case of hyphenated strings (like AF-S) or non-words (no vowels)
        unless ($str =~ /-/ or $str !~ /[AEIOUY]/) {
            # change all letters but the first to lower case
            $str =~ s/([A-Z]{1})([A-Z]+)/$1\L$2/g;
        }
    }
    return $str;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::Nikon - Definitions for Nikon EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Nikon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html

=item http://www.cybercom.net/~dcoffin/dcraw/

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joseph Heled, Thomas Walter, Brian Ristuccia, Danek Duvall, Tom
Christiansen and Robert Rottmerhusen for their help figuring out some Nikon
tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
