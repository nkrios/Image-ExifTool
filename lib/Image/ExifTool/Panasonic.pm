#------------------------------------------------------------------------------
# File:         Panasonic.pm
#
# Description:  Definitions for Panasonic/Leica Maker Notes
#
# References:   1) http://www.compton.nu/panasonic.html (based on FZ10)
#               2) Derived from DMC-FZ3 samples from dpreview.com
#               3) http://johnst.org/sw/exiftags/
#
# Revisions:    11/10/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Panasonic;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

%Image::ExifTool::Panasonic::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x01 => {
        Name => 'ImageQuality',
        PrintConv => {
            2 => 'High',
            3 => 'Standard',
            6 => 'Very High', #3 (Leica)
            7 => 'Raw', #3 (Leica)
        },
    },
    0x02 => {
        Name => 'FirmwareVersion',
        Format => 'UChar',
        PrintConv => '$_=$val; s/ /\./g; $_',
    },
    0x03 => {
        Name => 'WhiteBalance',
        PrintConv => {
            1 => 'Auto',
            2 => 'Daylight',
            3 => 'Cloudy',
            4 => 'Halogen',
            5 => 'Manual',
            8 => 'Flash',
            10 => 'Black & White', #3 (Leica)
        },
    },
    0x07 => {
        Name => 'FocusMode',
        PrintConv => {
            1 => 'Auto',
            2 => 'Manual',
        },
    },
    0x0f => {
        Name => 'SpotMode',
        PrintConv => {
            '0 1'  => 'Spot Mode On',
            '0 16' => 'Spot Mode Off',
        },
    },
    0x1a => {
        Name => 'ImageStabilizer',
        PrintConv => {
            2 => 'On, Mode 1',
            3 => 'Off',
            4 => 'On, Mode 2',
        },
    },
    0x1c => {
        Name => 'MacroMode',
        PrintConv => { 1 => 'On', 2 => 'Off' },
    },
    0x1f => {
        Name => 'ShootingMode',
        PrintConv => {
            1  => 'Normal',
            2  => 'Portrait',
            3  => 'Scenery',
            4  => 'Sports',
            5  => 'Night Portrait',
            6  => 'Program',
            7  => 'Aperture Priority',
            8  => 'Shutter Priority',
            9  => 'Macro',
            11 => 'Manual',
            13 => 'Panning',
            18 => 'Fireworks',
            19 => 'Party',
            20 => 'Snow',
            21 => 'Night Scenery',
        },
    },
    0x20 => {
        Name => 'Audio',
        PrintConv => { 1 => 'Yes', 2 => 'No' },
    },
    0x21 => { #2
        Name => 'DataDump',
        PrintConv => '\$val',
    },
    0x23 => {
        Name => 'WhiteBalanceBias',
        Format => 'Short',
        ValueConv => '$val / 3',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x24 => {
        Name => 'FlashBias',
        Format => 'Short',
    },
    0x25 => 'SerialNumber', #2
    0x28 => {
        Name => 'ColorEffect',
        PrintConv => {
            1 => 'Off',
            2 => 'Warm',
            3 => 'Cool',
            4 => 'Black & White',
            5 => 'Sepia',
        },
    },
    # 0x29 => 'SubjectDistance?',
    0x2c => {
        Name => 'Contrast',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'High',
            #3 (Leica)
            0x100 => 'Low',
            0x110 => 'Standard',
            0x120 => 'High',
        },
    },
    0x2d => {
        Name => 'NoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
        },
    },
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Panasonic - Definitions for Panasonic/Leica maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Panasonic and Leica maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://www.compton.nu/panasonic.html

=item http://johnst.org/sw/exiftags/

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
