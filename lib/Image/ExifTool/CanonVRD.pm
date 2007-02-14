#------------------------------------------------------------------------------
# File:         CanonVRD.pm
#
# Description:  Read/write Canon VRD information
#
# Revisions:    10/30/2006 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::CanonVRD;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

sub ProcessCanonVRD($$);

my $debug;  # set this to 1 for offsets relative to binary data start

my %noYes = ( 0 => 'No', 1 => 'Yes' );

# main tag table IPTC-format records in CanonVRD trailer
%Image::ExifTool::CanonVRD::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        Canon Digital Photo Professional writes VRD (Virtual? Recipe Data)
        information as a trailer record to JPEG, CRW and CR2 images, or as a
        stand-alone VRD file.  The tags listed below represent information found in
        this record.  The complete VRD data record may be extracted separately as a
        binary data block using the Extra 'CanonVRD' tag, but this is not done
        unless specified explicitly.
    },
#
# RAW image adjustment
#
    0x002 => {
        Name => 'VRDVersion',
        Format => 'int16u',
        Writable => 0,
        PrintConv => 'sprintf("%.2f", $val / 100)',
    },
    # 0x006 related somehow to RGB levels
    0x008 => {
        Name => 'WBAdjRGBLevels',
        Format => 'int16u[3]',
    },
    0x018 => {
        Name => 'WhiteBalanceAdj',
        Format => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Tungsten',
            4 => 'Fluorescent',
            5 => 'Flash',
            8 => 'Shade',
            9 => 'Kelvin',
            30 => 'Manual (Click)',
            31 => 'Shot Settings',
        },
    },
    0x01a => {
        Name => 'WBAdjColorTemp',
        Format => 'int16u',
    },
    # 0x01c similar to 0x006
    # 0x01e similar to 0x008
    0x024 => {
        Name => 'WBFineTuneActive',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x028 => {
        Name => 'WBFineTuneSaturation',
        Format => 'int16u',
    },
    0x02c => {
        Name => 'WBFineTuneTone',
        Format => 'int16u',
    },
    0x02e => {
        Name => 'RawColorAdj',
        Format => 'int16u',
        PrintConv => {
            0 => 'Shot Settings',
            1 => 'Faithful',
            2 => 'Custom',
        },
    },
    0x030 => {
        Name => 'RawCustomSaturation',
        Format => 'int32s',
    },
    0x034 => {
        Name => 'RawCustomTone',
        Format => 'int32s',
    },
    0x038 => {
        Name => 'RawBrightnessAdj',
        Format => 'int32s',
        ValueConv => '$val / 6000',
        ValueConvInv => 'int($val * 6000 + ($val < 0 ? -0.5 : 0.5))',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    0x03c => {
        Name => 'ToneCurveProperty',
        Format => 'int16u',
        PrintConv => {
            0 => 'Shot Settings',
            1 => 'Linear',
            2 => 'Custom 1',
            3 => 'Custom 2',
            4 => 'Custom 3',
            5 => 'Custom 4',
            6 => 'Custom 5',
        },
    },
    # 0x040 usually "10 9 2"
    0x07a => {
        Name => 'DynamicRangeMin',
        Format => 'int16u',
    },
    0x07c => {
        Name => 'DynamicRangeMax',
        Format => 'int16u',
    },
    # 0x0c6 usually "10 9 2"
#
# RGB image adjustment
#
    0x110 => {
        Name => 'ToneCurveActive',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x114 => {
        Name => 'BrightnessAdj',
        Format => 'int8s',
    },
    0x115 => {
        Name => 'ContrastAdj',
        Format => 'int8s',
    },
    0x116 => {
        Name => 'SaturationAdj',
        Format => 'int16s',
    },
    0x11e => {
        Name => 'ColorToneAdj',
        Notes => 'in degrees, so -1 is the same as 359',
        Format => 'int32s',
    },
    0x160 => {
        Name => 'RedCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x19a => {
        Name => 'GreenCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x1d4 => {
        Name => 'BlueCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x18a => {
        Name => 'RedCurveLimits',
        Notes => '4 numbers: input and output highlight and shadow points',
        Format => 'int16u[4]',
    },
    0x1c4 => {
        Name => 'GreenCurveLimits',
        Format => 'int16u[4]',
    },
    0x1fe => {
        Name => 'BlueCurveLimits',
        Format => 'int16u[4]',
    },
    0x20e => {
        Name => 'RGBCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x238 => {
        Name => 'RGBCurveLimits',
        Format => 'int16u[4]',
    },
    0x244 => {
        Name => 'CropActive',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x246 => {
        Name => 'CropLeft',
        Notes => 'crop coordinates in original unrotated image',
        Format => 'int16u',
    },
    0x248 => {
        Name => 'CropTop',
        Format => 'int16u',
    },
    0x24a => {
        Name => 'CropWidth',
        Format => 'int16u',
    },
    0x24c => {
        Name => 'CropHeight',
        Format => 'int16u',
    },
    0x260 => {
        Name => 'CropAspectRatio',
        Format => 'int16u',
        PrintConv => {
            0 => 'Free',
            1 => '3:2',
            2 => '2:3',
            3 => '4:3',
            4 => '3:4',
            5 => 'A-size Landscape',
            6 => 'A-size Portrait',
            7 => 'Letter-size Landscape',
            8 => 'Letter-size Portrait',
            9 => '4:5',
            10 => '5:4',
            11 => '1:1',
        },
    },
    0x262 => {
        Name => 'ConstrainedCropWidth',
        Format => 'float',
        PrintConv => 'sprintf("%.7g",$val)',
        PrintConvInv => '$val',
    },
    0x266 => {
        Name => 'ConstrainedCropHeight',
        Format => 'float',
        PrintConv => 'sprintf("%.7g",$val)',
        PrintConvInv => '$val',
    },
    0x26a => {
        Name => 'CheckMark',
        Format => 'int16u',
        PrintConv => {
            0 => 'Clear',
            1 => 1,
            2 => 2,
            3 => 3,
        },
    },
    0x26e => {
        Name => 'Rotation',
        Format => 'int16u',
        PrintConv => {
            0 => 0,
            1 => 90,
            2 => 180,
            3 => 270,
        },
    },
    0x270 => {
        Name => 'WorkColorSpace',
        Format => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
            2 => 'Wide Gamut RGB',
            3 => 'Apple RGB',
            4 => 'ColorMatch RGB',
        },
    },
    # (VRD 1.00 edit data ends here -- 0x272 bytes long)
    0x27a => {
        Name => 'PictureStyle',
        Format => 'int16u',
        PrintConv => {
            0 => 'Standard',
            1 => 'Portrait',
            2 => 'Landscape',
            3 => 'Neutral',
            4 => 'Faithful',
            5 => 'Monochrome',
        },
    },
    0x290 => {
        Name => 'RawColorToneAdj',
        Format => 'int16s',
    },
    0x292 => {
        Name => 'RawSaturationAdj',
        Format => 'int16s',
    },
    0x294 => {
        Name => 'RawContrastAdj',
        Format => 'int16s',
    },
    0x296 => {
        Name => 'RawLinear',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x298 => {
        Name => 'RawSharpnessAdj',
        Format => 'int16s',
    },
    0x29a => {
        Name => 'RawHighlightPoint',
        Format => 'int16s',
    },
    0x29c => {
        Name => 'RawShadowPoint',
        Format => 'int16s',
    },
    0x2ea => {
        Name => 'MonochromeFilterEffect',
        Format => 'int16s',
        PrintConv => {
            -2 => 'None',
            -1 => 'Yellow',
            0 => 'Orange',
            1 => 'Red',
            2 => 'Green',
        },
    },
    0x2ec => {
        Name => 'MonochromeToningEffect',
        Format => 'int16s',
        PrintConv => {
            -2 => 'None',
            -1 => 'Sepia',
            0 => 'Blue',
            1 => 'Purple',
            2 => 'Green',
        },
    },
    0x2ee => {
        Name => 'MonochromeContrast',
        Format => 'int16s',
    },
    0x2f0 => {
        Name => 'MonochromeLinear',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x2f2 => {
        Name => 'MonochromeSharpness',
        Format => 'int16s',
    },
    # (VRD 2.00 edit data is 0x328 bytes)
);

#------------------------------------------------------------------------------
# Tone curve print conversion
sub ToneCurvePrint($)
{
    my $val = shift;
    my @vals = split ' ', $val;
    return $val unless @vals == 21;
    my $n = shift @vals;
    return $val unless $n >= 2 and $n <= 10;
    $val = '';
    while ($n--) {
        $val and $val .= ' ';
        $val .= '(' . shift(@vals) . ',' . shift(@vals) . ')';
    }
    return $val;
}

#------------------------------------------------------------------------------
# Inverse print conversion for tone curve
sub ToneCurvePrintInv($)
{
    my $val = shift;
    my @vals = ($val =~ /\((\d+),(\d+)\)/g);
    return undef unless @vals >= 4 and @vals <= 20 and not @vals & 0x01;
    unshift @vals, scalar(@vals) / 2;
    while (@vals < 21) { push @vals, 0 }
    return join(' ',@vals);
}

#------------------------------------------------------------------------------
# Read/write Canon VRD file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a Canon VRD file, 0 otherwise, -1 on write error
sub ProcessVRD($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    $raf->Read($buff, 0x1c) == 0x1c   or return 0;
    $buff =~ /^CANON OPTIONAL DATA\0/ or return 0;
    $exifTool->SetFileType();
    $$dirInfo{DirName} = 'CanonVRD';    # set directory name for verbose output
    my $result = ProcessCanonVRD($exifTool, $dirInfo);
    return $result if $result < 0;
    $result or $exifTool->Warn('Format error in VRD file');
    return 1;
}

#------------------------------------------------------------------------------
# Read/write CanonVRD information
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this file didn't contain CanonVRD information
# - updates DataPos to point to start of CanonVRD information
# - updates DirLen to trailer length
sub ProcessCanonVRD($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $offset = $$dirInfo{Offset} || 0;
    my $outfile = $$dirInfo{OutFile};
    my $verbose = $exifTool->Options('Verbose');
    my $out = $exifTool->Options('TextOut');
    my ($buff, $footer, $header, $recLen, $err);

    # read and validate the trailer footer
    $raf->Seek(-64-$offset, 2)    or return 0;
    $raf->Read($footer, 64) == 64 or return 0;
    $footer =~ /^CANON OPTIONAL DATA\0(.{4})/s or return 0;
    my $size = unpack('N', $1);

    # read and validate the header too
    # (header is 0x1c bytes and footer is 0x40 bytes)
    unless ($size > 12 and ($size & 0x80000000) == 0 and
            $raf->Seek(-$size-0x5c, 1) and
            $raf->Read($header, 0x1c) == 0x1c and
            $header =~ /^CANON OPTIONAL DATA\0/ and
            $raf->Read($buff, $size) == $size)
    {
        $exifTool->Warn('Bad CanonVRD trailer');
        return 0;
    }
    # extract binary VRD data block if requested
    if ($exifTool->{REQ_TAG_LOOKUP}->{canonvrd}) {
        $exifTool->FoundTag('CanonVRD', $header . $buff . $footer);
    }
    # set variables returned in dirInfo hash
    $$dirInfo{DataPos} = $raf->Tell() - $size - 0x1c;
    $$dirInfo{DirLen} = $size + 0x5c;

    # validate VRD record and get length of edit data
    SetByteOrder('MM');
    my $pos = 0x08;     # position of first record length word
    my $editLen = 0;
    for (;;) {
        if ($pos + 4 > $size) {
            last if $pos == $size;  # all done if we arrived at end
            $recLen = $size;        # mark as invalid
        } else {
            $recLen = Get32u(\$buff, $pos);
        }
        if ($pos + $recLen + 4 > $size) {
            $exifTool->Warn('Possibly corrupt CanonVRD data');
            last;
        }
        $editLen or $editLen = $recLen;
        $pos += $recLen + 4;
    }

    # prepare for reading/writing CanonVRD binary data
    my $tagTablePtr = GetTagTable('Image::ExifTool::CanonVRD::Main');
    my $editData = substr($buff, 0x0c, $editLen);
    my %dirInfo = (
        DataPt => \$editData,
        DataPos => $debug ? 0 : $$dirInfo{DataPos} + length($header) + 0x0c,
        DirStart => 0,
        DirLen => $editLen,
    );
    if (not $outfile) {
        # read CanonVRD information
        if ($debug) {
            Image::ExifTool::HexDump(\$editData);
        } else {
            $exifTool->DumpTrailer($dirInfo) if $verbose or $exifTool->{HTML_DUMP};
        }
        $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
    } elsif ($exifTool->{DEL_GROUP}->{CanonVRD}) {
        # delete CanonVRD information
        if ($exifTool->{FILE_TYPE} eq 'VRD') {
            $exifTool->Error("Can't delete all CanonVRD information from a VRD file");
            return 1;
        }
        $verbose and printf $out "  Deleting CanonVRD trailer\n";
        $verbose = 0;   # no more verbose messages after this
        ++$exifTool->{CHANGED};
    } else {
        # rewrite CanonVRD information
        $verbose and print $out "  Rewriting CanonVRD\n";
        my $newVal = $exifTool->WriteDirectory(\%dirInfo, $tagTablePtr);
        substr($buff, 0x0c, $editLen) = $newVal if $newVal;
        Write($outfile, $header, $buff, $footer) or $err = 1;
    }
    return $err ? -1 : 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::CanonVRD - Read/Write Canon VRD information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write VRD (Virtual?) Recipe Data information as written by the Canon Digital
Photo Professional software.  This information is written to VRD files, and
as a trailer in JPEG, CRW and CR2 images.

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/CanonVRD Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

