#------------------------------------------------------------------------------
# File:         Kodak.pm
#
# Description:  Definitions for Kodak EXIF Maker Notes
#
# Revisions:    03/28/2005  - P. Harvey Created
#
# References:   1) http://search.cpan.org/dist/Image-MetaData-JPEG/
#------------------------------------------------------------------------------

package Image::ExifTool::Kodak;

use strict;
use vars qw($VERSION);

$VERSION = '1.01';

my %offOn = ( 0 => 'Off', 1 => 'On' );

%Image::ExifTool::Kodak::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => "\nThese tags used by a number of CX, DC, DX and LS models.\n",
    WRITABLE => 1,
    FIRST_ENTRY => 8,
    0x00 => {
        Name => 'KodakModel',
        Format => 'string[8]',
    },
    0x09 => {
        Name => 'Compression',
        PrintConv => { #PH
            1 => 'Normal',
            2 => 'High',
        },
    },
    0x0a => {
        Name => 'BurstMode',
        PrintConv => \%offOn, #PH
    },
    0x0b => {
        Name => 'MacroMode',
        PrintConv => \%offOn, #PH
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
        ValueConv => 'sprintf("%2d:%.2d:%.2d.%.2d",split(/\s+/, $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x18 => { #?
        Name => 'BurstMode2',
        Format => 'int16u',
        Unknown => 1,
    },
    0x1b => {
        Name => 'ShutterMode',
        PrintConv => { #PH
            0 => 'Auto?',
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
        Name => 'Aperture',
        Format => 'int16u',
        Priority => 0,
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x20 => { #?
        Name => 'KodakExposure',
        Description => 'Shutter Speed',
        Format => 'int32u',
        Unknown => 1,
    },
    0x24 => {
        Name => 'ExposureBias',
        Format => 'int16s',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x26 => { #?
        Name => 'VariousModes',
        Format => 'int16u',
        Unknown => 1,
    },
    0x28 => { #?
        Name => 'Distance1',
        Format => 'int32u',
        Unknown => 1,
    },
    0x2c => { #?
        Name => 'Distance2',
        Format => 'int32u',
        Unknown => 1,
    },
    0x30 => { #?
        Name => 'Distance3',
        Format => 'int32u',
        Unknown => 1,
    },
    0x34 => { #?
        Name => 'Distance4',
        Format => 'int32u',
        Unknown => 1,
    },
    0x38 => 'FocusMode',
    0x3a => { #?
        Name => 'VariousModes2',
        Format => 'int16u',
        Unknown => 1,
    },
    0x3c => {
        Name => 'PanoramaMode',
        Format => 'int16u',
    },
    0x3e => {
        Name => 'SubjectDistance',
        Format => 'int16u',
    },
    0x40 => {
        Name => 'WhiteBalance',
        Priority => 0,
        PrintConv => { #PH
            0 => 'Auto',
            1 => 'Daylight?',
            2 => 'Tungsten?',
            3 => 'Fluorescent?',
        },
    },
    0x5c => {
        Name => 'FlashMode',
        PrintConv => { #PH
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
            3 => 'Red-Eye',
        },
    },
    0x5d => 'FlashFired',
    0x5e => {
        Name => 'ISOSetting',
        Format => 'int16u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/^\d+$/ ? $val : 0',
    },
    0x60 => {
        Name => 'ISOUsed',
        Format => 'int16u',
    },
    0x62 => {
        Name => 'TotalZoomFactor',
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
        Name => 'ColorMode', # Color, b&w, sepia
        Format => 'int16u',
        # values are 32,64 and ?
    },
    0x68 => {
        Name => 'DigitalZoomFactor',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x6b => {
        Name => 'Sharpness',
        Format => 'int8s',
        PrintConv => { #PH
           -1 => 'Soft',
            0 => 'Normal',
            1 => 'Sharp',
        },
    },
);

%Image::ExifTool::Kodak::Type2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => "\nThese tags used by the DC265 and DC290.\n",
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
);

%Image::ExifTool::Kodak::Type3 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => "\nThese tags used by the DC280, DC3400 and DC5000.\n",
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
        ValueConv => 'sprintf("%2d:%.2d:%.2d.%.2d",split(/\s+/, $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
);

%Image::ExifTool::Kodak::Type4 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => "\nThese tags used by the DC200.\n",
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
    NOTES => "\nThese tags used by the CX4200.\n",
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x1a => { #PH
        Name => 'WhiteBalance',
        Flags => 'PrintHex',
        PrintConv => {
            1 => 'Daylight',
            2 => 'Flash',
            3 => 'Tungsten',
        },
    },
    0x1e => { #PH
        Name => 'ISOUsed',
        Format => 'int16u',
    },
    0x20 => { #PH
        Name => 'TotalZoomFactor',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x22 => { #PH
        Name => 'DigitalZoomFactor',
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
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    0x2b => { #PH
        Name => 'Macro',
        PrintConv => {
            0 => 'On',
            1 => 'Off',
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

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
