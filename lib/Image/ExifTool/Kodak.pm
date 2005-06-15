#------------------------------------------------------------------------------
# File:         Kodak.pm
#
# Description:  Definitions for Kodak EXIF Maker Notes
#
# Revisions:    03/28/2005  - P. Harvey Created
#
# References:   1) http://search.cpan.org/dist/Image-MetaData-JPEG/
#
# Notes:        There really isn't much public information about Kodak formats. 
#               The only source I could find was Image::MetaData::JPEG, which
#               didn't provide information about decoding the tag values.  So
#               this module represents a lot of work downloading sample images
#               (about 100MB worth!), and testing with my daughter's CX4200.
#------------------------------------------------------------------------------

package Image::ExifTool::Kodak;

use strict;
use vars qw($VERSION);

$VERSION = '1.02';


%Image::ExifTool::Kodak::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => q{
The table below contains the most common set of Kodak tags.  The following
Kodak camera models have been tested and found to use these tags:  CX6330,
CX7330, CX7430, CX7530, DC4800, DC4900, DX3500, DX3600, DX3900, DX4330,
DX4530, DX4900, DX6340, DX6440, DX6490, DX7440, DX7590, DX7630, LS420,
LS443, LS743 and LS753.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 8,
    0x00 => {
        Name => 'KodakModel',
        Format => 'string[8]',
    },
    0x09 => {
        Name => 'Quality',
        PrintConv => { #PH
            1 => 'Fine',
            2 => 'Normal',
        },
    },
    0x0a => {
        Name => 'BurstMode',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x0c => {
        Name => 'KodakImageWidth',
        Format => 'int16u',
    },
    0x0e => {
        Name => 'KodakImageHeight',
        Format => 'int16u',
    },
    0x10 => {
        Name => 'Date',
        Format => 'undef[4]',
        ValueConv => 'sprintf("%.4d:%.2d:%.2d",Get16u(\$val,0),unpack("x2C2",$val))',
        ValueConvInv => 'my @v=split /:/, $val;Set16u($v[0]) . pack("C2",$v[1],$v[2])',
    },
    0x14 => {
        Name => 'Time',
        Format => 'int8u[4]',
        ValueConv => 'sprintf("%2d:%.2d:%.2d.%.2d",split(" ", $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x18 => {
        Name => 'BurstMode2',
        Format => 'int16u',
        Unknown => 1, # not sure about this tag (or other 'Unknown' tags)
    },
    0x1b => {
        Name => 'ShutterMode',
        PrintConv => { #PH
            0 => 'Auto',
            8 => 'Aperture Priority',
            32 => 'Manual?',
        },
    },
    0x1c => {
        Name => 'MeteringMode',
        PrintConv => { #PH
            0 => 'Multi-pattern',
            1 => 'Center-Weighted',
            2 => 'Spot',
        },
    },
    0x1d => 'SequenceNumber',
    0x1e => {
        Name => 'FNumber',
        Description => 'Aperture',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x20 => {
        Name => 'ExposureTime',
        Description => 'Shutter Speed',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x24 => {
        Name => 'ExposureCompensation',
        Format => 'int16s',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => 'eval $val',
    },
    0x26 => {
        Name => 'VariousModes',
        Format => 'int16u',
        Unknown => 1,
    },
    0x28 => {
        Name => 'Distance1',
        Format => 'int32u',
        Unknown => 1,
    },
    0x2c => {
        Name => 'Distance2',
        Format => 'int32u',
        Unknown => 1,
    },
    0x30 => {
        Name => 'Distance3',
        Format => 'int32u',
        Unknown => 1,
    },
    0x34 => {
        Name => 'Distance4',
        Format => 'int32u',
        Unknown => 1,
    },
    0x38 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Normal',
            2 => 'Macro',
        },
    },
    0x3a => {
        Name => 'VariousModes2',
        Format => 'int16u',
        Unknown => 1,
    },
    0x3c => {
        Name => 'PanoramaMode',
        Format => 'int16u',
        Unknown => 1,
    },
    0x3e => {
        Name => 'SubjectDistance',
        Format => 'int16u',
        Unknown => 1,
    },
    0x40 => {
        Name => 'WhiteBalance',
        Priority => 0,
        PrintConv => { #PH
            0 => 'Auto',
            1 => 'Flash?',
            2 => 'Tungsten',
            3 => 'Daylight',
        },
    },
    0x5c => {
        Name => 'FlashMode',
        Flags => 'PrintHex',
        # various models express this number differently
        PrintConv => { #PH
            0x00 => 'Auto',
            0x01 => 'Fill Flash',
            0x02 => 'Off',
            0x03 => 'Red-Eye',
            0x10 => 'Fill Flash',
            0x20 => 'Off',
            0x40 => 'Red-Eye?',
        },
    },
    0x5d => {
        Name => 'FlashFired',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x5e => {
        Name => 'ISOSetting',
        Format => 'int16u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/^\d+$/ ? $val : 0',
    },
    0x60 => {
        Name => 'ISO',
        Description => 'ISO Speed',
        Format => 'int16u',
    },
    0x62 => {
        Name => 'TotalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x64 => {
        Name => 'DateTimeStamp',
        Format => 'int16u',
        PrintConv => '$val ? "Mode $val" : "Off"',
        PrintConvInv => '$val=~tr/0-9//dc; $val ? $val : 0',
    },
    0x66 => {
        Name => 'ColorMode',
        Format => 'int16u',
        Flags => 'PrintHex',
        # various models express this number differently
        PrintConv => { #PH
            0x01 => 'B&W',
            0x02 => 'Sepia',
            0x03 => 'B&W Yellow Filter',
            0x04 => 'B&W Red Filter',
            0x20 => 'Saturated Color',
            0x40 => 'Neutral Color',
            0x100 => 'Saturated Color',
            0x200 => 'Neutral Color',
            0x2000 => 'B&W',
            0x4000 => 'Sepia',
        },
    },
    0x68 => {
        Name => 'DigitalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x6b => {
        Name => 'Sharpness',
        Format => 'int8s',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
);

%Image::ExifTool::Kodak::Type2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'These tags are used by the DC265 and DC290.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x08 => { #PH
        Name => 'KodakMaker',
        Format => 'string[32]',
    },
    0x28 => { #PH
        Name => 'KodakModel',
        Format => 'string[32]',
    },
    0x6c => { #PH
        Name => 'KodakImageWidth',
        Format => 'int32u',
    },
    0x70 => { #PH
        Name => 'KodakImageHeight',
        Format => 'int32u',
    },
);

%Image::ExifTool::Kodak::Type3 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'These tags are used by the DC280, DC3400 and DC5000.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x0c => { #PH
        Name => 'Date',
        Format => 'undef[4]',
        ValueConv => 'sprintf("%.4d:%.2d:%.2d",Get16u(\$val,0),unpack("x2C2",$val))',
        ValueConvInv => 'my @v=split /:/, $val;Set16u($v[0]) . pack("C2",$v[1],$v[2])',
    },
    0x10 => { #PH
        Name => 'Time',
        Format => 'int8u[4]',
        ValueConv => 'sprintf("%2d:%.2d:%.2d.%.2d",split(" ", $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x1e => { #PH
        Name => 'AnalogZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x37 => { #PH
        Name => 'Sharpness',
        Format => 'int8s',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0x38 => { #PH
        Name => 'ExposureTime',
        Description => 'Shutter Speed',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x3c => { #PH
        Name => 'FNumber',
        Description => 'Aperture',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x4e => { #PH
        Name => 'ISO',
        Description => 'ISO Speed',
        Format => 'int16u',
    },
);

%Image::ExifTool::Kodak::Type4 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'These tags are used by the DC200 and DC215.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x20 => { #PH
        Name => 'OriginalFileName',
        Format => 'string[12]',
    },
);

%Image::ExifTool::Kodak::Type5 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'These tags are used by the CX4200, CX4230 and CX6200.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x14 => { #PH
        Name => 'ExposureTime',
        Description => 'Shutter Speed',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x1a => { #PH
        Name => 'WhiteBalance',
        PrintConv => {
            1 => 'Daylight',
            2 => 'Flash',
            3 => 'Tungsten',
        },
    },
    0x1c => { #PH
        Name => 'FNumber',
        Description => 'Aperture',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x1e => { #PH
        Name => 'ISO',
        Description => 'ISO Speed',
        Format => 'int16u',
    },
    0x20 => { #PH
        Name => 'OpticalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x22 => { #PH
        Name => 'DigitalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',    
    },
    0x27 => { #PH
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
            3 => 'Red-Eye',
        },
    },
    0x2a => { #PH
        Name => 'ImageRotated',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x2b => { #PH
        Name => 'Macro',
        PrintConv => { 0 => 'On', 1 => 'Off' },
    },
);

%Image::ExifTool::Kodak::Type6 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'These tags are used by the DX3215 and DX3700.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x10 => { #PH
        Name => 'ExposureTime',
        Description => 'Shutter Speed',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x14 => { #PH
        Name => 'ISOSetting',
        Format => 'int32u',
        Unknown => 1,
    },
    0x18 => { #PH
        Name => 'FNumber',
        Description => 'Aperture',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x1a => { #PH
        Name => 'ISO',
        Description => 'ISO Speed',
        Format => 'int16u',
    },
    0x1c => { #PH
        Name => 'OpticalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x1e => { #PH
        Name => 'DigitalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x22 => { #PH
        Name => 'Flash',
        Format => 'int16u',
        PrintConv => {
            0 => 'No Flash',
            1 => 'Fired',
        },
    },
);

%Image::ExifTool::Kodak::Unknown = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Kodak - Definitions for Kodak EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Kodak maker notes EXIF meta information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<Image::MetaData::JPEG|Image::MetaData::JPEG>

=item (...plus lots of testing with my daughter's CX4200!)

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Kodak Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
