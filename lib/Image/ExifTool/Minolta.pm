#------------------------------------------------------------------------------
# File:         Minolta.pm
#
# Description:  Definitions for Minolta EXIF Maker Notes
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# References:   1) http://www.dalibor.cz/minolta/makernote.htm
#               2) Jay Al-Saadi private communication (testing with A2)
#------------------------------------------------------------------------------

package Image::ExifTool::Minolta;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.12';

%Image::ExifTool::Minolta::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0000 => 'MakerNoteVersion',
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    # it appears that image stabilization is on if this tag exists (ref 2),
    # but it is an 8kB binary data block!
    0x0018 => {
        Name => 'ImageStabilization',
        Writable => 0,
        ValueConv => '"On"',
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        Name => 'PreviewImageData',
        Writable => 0,
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0101 => {
        Name => 'ColorMode',
        PrintConv => {
            0 => 'Natural color',
            1 => 'Black&white',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
        },
    },
    0x0102 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'Raw',
            1 => 'Superfine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    # (0x0103 is the same as 0x0102 above)
    0x0103 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'Raw',
            1 => 'Superfine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x0f00 => {
        Name => 'MinoltaCameraSettings2',
        Writable => 0,
    },
);

%Image::ExifTool::Minolta::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    1 => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture priority',
            2 => 'Shutter priority',
            3 => 'Manual',
        },
    },
    2 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Fill flash',
            1 => 'Red-eye reduction',
            2 => 'Rear flash sync',
            3 => 'Wireless',
        },
    },
    3 => {
        Name => 'WhiteBalance',
        PrintConv => 'Image::ExifTool::Minolta::ConvertWhiteBalance($val)',
    },
    4 => {
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => '2560x1920 or 2048x1536',
            1 => '1600x1200',
            2 => '1280x960',
            3 => '640x480',
        },
    },
    5 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'Raw',
            1 => 'Superfine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    6 => {
        Name => 'DriveMode',
        PrintConv => {
            0 => 'single',
            1 => 'continuous',
            2 => 'self-timer',
            4 => 'bracketing',
            5 => 'interval',
            6 => 'UHS continuous',
            7 => 'HS continuous',
        },
    },
    7 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'multi-segment',
            1 => 'center weighted',
            2 => 'spot',
        },
    },
    8 => {
        Name => 'MinoltaISO',
        ValueConv => '2 ** (($val/8-1))*3.125',
        PrintConv => 'int($val)',
    },
    9 => {
        Name => 'MinoltaShutterSpeed',
        ValueConv => '2 ** ((48-$val)/8)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    10 => {
        Name => 'MinoltaAperture',
        ValueConv => '2 ** ($val/16 - 0.5)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    11 => {
        Name => 'MacroMode',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'Off',
            1 => 'Electronic magnification',
            2 => '2x',
        },
    },
    13 => {
        Name => 'ExposureCompensation',
        ValueConv => '$val/3 - 2',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        ValueConvInv => '($val + 2) * 3',
        PrintConvInv => 'eval $val',
    },
    14 => {
        Name => 'BracketStep',
        PrintConv => {
            0 => '1/3 EV',
            1 => '2/3 EV',
            2 => '1 EV',
        },
    },
    16 => 'IntervalLength',
    17 => 'IntervalNumber',
    18 => {
        Name => 'FocalLength',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
        PrintConv => 'sprintf("%.1fmm",$val)',
        PrintConvInv => '$val=~s/mm$//;$val',
    },
    19 => {
        Name => 'FocusDistance',
        ValueConv => '$val / 1000',
        PrintConv => '$val ? "$val m" : "inf"',
        ValueConvInv => '$val * 1000',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/ m$//, $val',
    },
    20 => {
        Name => 'FlashFired',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    21 => {
        Name => 'MinoltaDate',
        ValueConv => 'sprintf("%4d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    22 => {
        Name => 'MinoltaTime',
        ValueConv => 'sprintf("%2d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    23 => {
        Name => 'MaxAperture',
        ValueConv => '2 ** ($val/16 - 0.5)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    26 => {
        Name => 'FileNumberMemory',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    27 => 'LastFileNumber',
    28 => {
        Name => 'ColorBalanceRed',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    29 => {
        Name => 'ColorBalanceGreen',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    30 => {
        Name => 'ColorBalanceBlue',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    31 => {
        Name => 'Saturation',
        ValueConv => '$val - 3',
        ValueConvInv => '$val + 3',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    32 => {
        Name => 'Contrast',
        ValueConv => '$val - 3',
        ValueConvInv => '$val + 3',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    33 => {
        Name => 'Sharpness',
        PrintConv => {
            0 => 'Hard',
            1 => 'Normal',
            2 => 'Soft',
        },
    },
    34 => {
        Name => 'SubjectProgram',
        PrintConv => {
            0 => 'None',
            1 => 'Portrait',
            2 => 'Text',
            3 => 'Night portrait',
            4 => 'Sunset',
            5 => 'Sports action',
        },
    },
    35 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        ValueConv => '($val - 6) / 3',
        ValueConvInv => '$val * 3 + 6',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    36 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => '100',
            1 => '200',
            2 => '400',
            3 => '800',
            4 => 'auto',
            5 => '64',
        },
    },
    37 => {
        Name => 'MinoltaModel',
        PrintConv => {
            0 => 'DiMAGE 7',
            1 => 'DiMAGE 5',
            2 => 'DiMAGE S304',
            3 => 'DiMAGE S404',
            4 => 'DiMAGE 7i',
            5 => 'DiMAGE 7Hi',
            6 => 'DiMAGE A1',
            7 => 'DiMAGE A2', # also 'DiMAGE S414'?
        },
    },
    38 => {
        Name => 'IntervalMode',
        PrintConv => {
            0 => 'Still Image',
            1 => 'Time-lapse Movie',
        },
    },
    39 => {
        Name => 'FolderName',
        PrintConv => {
            0 => 'Standard Form',
            1 => 'Data Form',
        },
    },
    40 => {
        Name => 'ColorMode',
        PrintConv => {
            0 => 'Natural color',
            1 => 'Black&white',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
        },
    },
    41 => {
        Name => 'ColorFilter',
        ValueConv => '$val - 3',
        ValueConvInv => '$val + 3',
    },
    42 => 'BWFilter',
    43 => {
        Name => 'InternalFlash',
        PrintConv => {
            0 => 'No',
            1 => 'Fired',
        },
    },
    44 => {
        Name => 'Brightness',
        ValueConv => '$val/8 - 6',
        ValueConvInv => '($val + 6) * 8',
    },
    45 => 'SpotFocusPointX',
    46 => 'SpotFocusPointY',
    47 => {
        Name => 'WideFocusZone',
        PrintConv => {
            0 => 'No zone',
            1 => 'Center zone (horizontal orientation)',
            2 => 'Center zone (vertical orientation)',
            3 => 'Left zone',
            4 => 'Right zone',
        },
    },
    48 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },
    49 => {
        Name => 'FocusArea',
        PrintConv => {
            0 => 'Wide Focus (normal)',
            1 => 'Spot Focus',
        },
    },
    50 => {
        Name => 'DECPosition',
        PrintConv => {
            0 => 'exposure',
            1 => 'contrast',
            2 => 'saturation',
            3 => 'filter',
        },
    },
# D7Hi only:
#    51 => {
#        Name => 'ColorProfile',
#        PrintConv => {
#            0 => 'Not Embedded',
#            1 => 'Embedded',
#        },
#    },
# entry 52 for D7Hi:
#    51 => {
#        Name => 'DataImprint',
#        PrintConv => {
#            0 => 'none',
#            1 => 'yyyy/mm/dd',
#            2 => 'mm/dd/hr:min',
#            3 => 'text',
#            4 => 'text + id#',
#        },
#    },
);

# basic Minolta white balance lookup
my %minoltaWhiteBalance = (
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    5 => 'Custom',
    7 => 'Fluorescent',
    8 => 'Fluorescent 2',
    11 => 'Custom 2',
    12 => 'Custom 3',
    # the following come from tests with the A2 (ref 2)
    0x0800000 => 'Auto',
    0x1800000 => 'Daylight',
    0x2800000 => 'Cloudy',
    0x3800000 => 'Tungsten',
    0x4800000 => 'Flash',
    0x5800000 => 'Fluorescent',
    0x6800000 => 'Shade',
    0x7800000 => 'Custom1',
    0x8800000 => 'Custom2',
    0x9800000 => 'Custom3',
);

#------------------------------------------------------------------------------
# PrintConv for Minolta white balance
sub ConvertWhiteBalance($)
{
    my $val = shift;
    my $printConv = $minoltaWhiteBalance{$val};
    unless (defined $printConv) {
        # the A2 values can be shifted by += 3 settings, where
        # each setting adds or subtracts 0x001000 (ref 2)
        my $type = ($val & 0xff000000) + 0x800000;
        if ($type and $printConv = $minoltaWhiteBalance{$type}) {
            $printConv .= sprintf("%+.8g", ($val - $type) / 0x10000);
        } else {
            $printConv = sprintf("Unknown (0x%x)", $val);
        }
    }
    return $printConv;
}

#------------------------------------------------------------------------------
# get information from Minolta MRW file
# Inputs: 0) ExifTool object reference
#         1) RAF pointer
# Returns: 1 if this was a valid MRW file
sub MrwInfo($$)
{
    my ($exifTool, $raf) = @_;
    my $data;

    $raf->Read($data,4);
    $data eq "\0MRM" or return 0;

    return $exifTool->TiffInfo('MRW', $raf, 48);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Minolta - Definitions for Minolta EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Minolta and Konika-Minolta maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.dalibor.cz/minolta/makernote.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
