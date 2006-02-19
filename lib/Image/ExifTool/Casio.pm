#------------------------------------------------------------------------------
# File:         Casio.pm
#
# Description:  Casio EXIF maker notes tags
#
# Revisions:    12/09/2003 - P. Harvey Created
#               09/10/2004 - P. Harvey Added MakerNote2 (thanks to Joachim Loehr)
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Joachim Loehr private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Casio;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.14';

%Image::ExifTool::Casio::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0001 => {
        Name => 'RecordingMode' ,
        Writable => 'int16u',
        PrintConv => {
            1 => 'Single Shutter',
            2 => 'Panorama',
            3 => 'Night Scene',
            4 => 'Portrait',
            5 => 'Landscape',
        },
    },
    0x0002 => {
        Name => 'Quality',
        Description => 'Image Quality',
        Writable => 'int16u',
        PrintConv => { 1 => 'Economy', 2 => 'Normal', 3 => 'Fine' },
    },
    0x0003 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            2 => 'Macro',
            3 => 'Auto',
            4 => 'Manual',
            5 => 'Infinity',
        },
    },
    0x0004 => {
        Name => 'FlashMode',
        Writable => 'int16u',
        PrintConv => { 1 => 'Auto', 2 => 'On', 3 => 'Off', 4 => 'Red-eye Reduction' },
    },
    0x0005 => {
        Name => 'FlashIntensity',
        Writable => 'int16u',
        PrintConv => { 11 => 'Weak', 13 => 'Normal', 15 => 'Strong' },
    },
    0x0006 => {
        Name => 'ObjectDistance',
        Writable => 'int32u',
    },
    0x0007 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto',
            2 => 'Tungsten',
            3 => 'Daylight',
            4 => 'Fluorescent',
            5 => 'Shade',
            129 => 'Manual',
        },
    },
    0x000a => {
        Name => 'DigitalZoom',
        Writable => 'int32u',
        PrintConv => { 65536 => 'Off', 65537 => '2X' },
    },
    0x000b => {
        Name => 'Sharpness',
        Writable => 'int16u',
        PrintConv => { 0 => 'Normal', 1 => 'Soft', 2 => 'Hard' },
    },
    0x000c => {
        Name => 'Contrast',
        Writable => 'int16u',
        PrintConv => { 0 => 'Normal', 1 => 'Low', 2 => 'High' },
    },
    0x000d => {
        Name => 'Saturation',
        Writable => 'int16u',
        PrintConv => { 0 => 'Normal', 1 => 'Low', 2 => 'High' },
    },
    0x0014 => {
        Name => 'CCDSensitivity',
        Writable => 'int16u',
        PrintConv => {
            64  => 'Normal',
            80  => 'Normal',
            100 => 'High',
            125 => '+1.0',
            250 => '+2.0',
            244 => '+3.0',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            # hack because QV-4000 uses a silly offset base here
            # (note this still won't get rewritten properly)
            Start => '$valuePtr + $entry + $dataPos',
        },
    },
);

# ref 2:
%Image::ExifTool::Casio::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0002 => {
        Name => 'PreviewImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    0x0003 => {
        Name => 'PreviewImageLength',
        Groups => { 2 => 'Image' },
        OffsetPair => 0x0004, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0004 => {
        Name => 'PreviewImageStart',
        Groups => { 2 => 'Image' },
        Flags => 'IsOffset',
        OffsetPair => 0x0003, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0008 => {
        Name => 'QualityMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Economy',
           1 => 'Normal',
           2 => 'Fine',
        },
    },
    0x0009 => {
        Name => 'CasioImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        PrintConv => {
            0 => '640x480',
            4 => '1600x1200',
            5 => '2048x1536',
            20 => '2288x1712',
            21 => '2592x1944',
            22 => '2304x1728',
            36 => '3008x2008',
        },
    },
    0x000d => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Normal',
           1 => 'Macro',
        },
    },
    0x0014 => {
        Name => 'ISO',
        Priority => 0,
        Writable => 'int16u',
        PrintConv => {
           3 => 50,
           4 => 64,
           6 => 100,
           9 => 200,
        },
    },
    0x0019 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Auto',
           1 => 'Daylight',
           2 => 'Shade',
           3 => 'Tungsten',
           4 => 'Fluorescent',
           5 => 'Manual',
        },
    },
    0x001d => {
        Name => 'FocalLength',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1fmm",$val)',
        PrintConvInv => '$val=~s/mm$//;$val',
    },
    0x001f => {
        Name => 'Saturation',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Low',
           1 => 'Normal',
           2 => 'High',
        },
    },
    0x0020 => {
        Name => 'Contrast',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Low',
           1 => 'Normal',
           2 => 'High',
        },
    },
    0x0021 => {
        Name => 'Sharpness',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Soft',
           1 => 'Normal',
           2 => 'Hard',
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
    0x2000 => {
        # this image data is also referenced by tags 3 and 4
        # (nasty that they double-reference the image!)
        %Image::ExifTool::previewImageTagInfo,
    },
    0x2011 => {
        Name => 'WhiteBalanceBias',
        Writable => 'int16u',
        Count => 2,
    },
    0x2012 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
           12 => 'Flash',
           0 => 'Manual',
           1 => 'Auto?',
           4 => 'Flash?',
        },
    },
    0x2022 => {
        Name => 'ObjectDistance',
        Writable => 'int32u',
        PrintConv => 'sprintf("%.3f m",$val/1000)',
    },
    0x2034 => {
        Name => 'FlashDistance',
        Writable => 'int16u',
    },
    0x3000 => {
        Name => 'RecordMode',
        Writable => 'int16u',
        PrintConv => { 2 => 'Normal' },
    },
    0x3001 => {
        Name => 'SelfTimer',
        Writable => 'int16u',
        PrintConv => { 1 => 'Off' },
    },
    0x3002 => {
        Name => 'Quality',
        Writable => 'int16u',
        PrintConv => {
           1 => 'Economic',
           2 => 'Normal',
           3 => 'Fine',
        },
    },
    0x3003 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Manual?',
           1 => 'Fixation?',
           3 => 'Single-Area Auto Focus',
           6 => 'Multi-Area Auto Focus',
        },
    },
    0x3006 => {
        Name => 'TimeZone',
        Writable => 'string',
    },
    0x3007 => {
        Name => 'BestshotMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Off',
           1 => 'On?',
        },
    },
    0x3014 => {
        Name => 'CCDISOSensitivity',
        Writable => 'int16u',
        Description => 'CCD ISO Sensitivity',
    },
    0x3015 => {
        Name => 'ColorMode',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off' },
    },
    0x3016 => {
        Name => 'Enhancement',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off' },
    },
    0x3017 => {
        Name => 'Filter',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off' },
    },
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Casio - Casio EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Casio maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joachim Loehr for adding support for the type 2 maker notes.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Casio Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
