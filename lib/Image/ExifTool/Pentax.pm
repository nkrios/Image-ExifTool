#------------------------------------------------------------------------------
# File:         Pentax.pm
#
# Description:  Definitions for Pentax/Asahi EXIF Maker Notes
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/10/2004 - P. Harvey Completely re-done
#               02/16/2004 - W. Smith Updated (See specific tag comments)
#               11/10/2004 - P. Harvey Added support for Asahi cameras
#               01/10/2005 - P. Harvey Added NikonLens with values from ref 3.
#
# References:   1) Image::MakerNotes::Pentax
#               2) http://johnst.org/sw/exiftags/ (Asahi cameras)
#               3) http://kobe1995.jp/~kaz/astro/istD.html
#------------------------------------------------------------------------------

package Image::ExifTool::Pentax;

use strict;
use vars qw($VERSION);
use Image::ExifTool::MakerNotes;

$VERSION = '1.14';

%Image::ExifTool::Pentax::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0001 => {
        Name => 'PentaxMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Night-scene',
            2 => 'Manual',
        },
    },
    0x0002 => {
        Name => 'PreviewImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    0x0003 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0004, # point to associated offset
        DataTag => 'PreviewImage',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
        Protected => 1,
    },
    0x0004 => {
        Name => 'PreviewImageStart',
        Flags => [ 'IsOffset', 'Protected' ],
        OffsetPair => 0x0003, # point to associated byte count
        DataTag => 'PreviewImage',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
    },
    0x0008 => {
        Name => 'Quality',
        Description => 'Image Quality',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Good',
            1 => 'Better',
            2 => 'Best',
        },
    },
    # Recorded Pixels - W. Smith 16 FEB 04
    0x0009 => {
        Name => 'PentaxImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        PrintConv => {
            0 => '640x480',
            1 => 'Full', #PH - this can mean 2048x1536 or 2240x1680 or ... ?
            2 => '1024x768',
            4 => '1600x1200',
            5 => '2048x1536',
            21 => '2592x1944',
            22 => '2304x1728', #2
            '36 0' => '3008x2008',  #PH
        },
    },
    # Picture Mode Tag - W. Smith 12 FEB 04
    0x000b => {
        Name => 'PictureMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Not Selected',
            5 => 'Portrait',
            6 => 'Landscape',
            9 => 'Night Scene',
            12 => 'Surf & Snow',
            13 => 'Sunset',
            14 => 'Autumn',
            15 => 'Flower',
            17 => 'Fireworks',
            18 => 'Text',
        },
    },
    0x000d => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => { #2
            0 => 'Normal',
            1 => 'Macro (1)',
            2 => 'Macro (2)',
            3 => 'Infinity',
        },
    },
    # ISO Tag - Entries confirmed by W. Smith 12 FEB 04
    0x0014 => {
        Name => 'PentaxISO',
        Writable => 'int16u',
        PrintConv => {
            3 => 50,    # Not confirmed
            4 => 64,
            6 => 100,
            9 => 200,
            12 => 400,
            15 => 800,  # Not confirmed
            18 => 1600, # Not confirmed
            21 => 3200, # Not Confirmed
            50 => 50, #PH
            100 => 100, #PH
            200 => 200, #PH
            400 => 400, #PH
            800 => 800, #PH
            1600 => 1600, #PH
            3200 => 3200, #PH
        },
    },
    # AE Metering Mode Tag - W. Smith 12 FEB 04
    0x0017 => {
        Name => 'MeteringMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Multi Segment',
            1 => 'Center Weighted',
            2 => 'Spot',
        },
    },
    # White Balance Tag - W. Smith 12 FEB 04
    0x0019 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
        },
    },
    # Would be nice if there was a general way to determine units for FocalLength.
    # Optio 550 uses .1mm while *istD and Optio S use .01 - PH
    0x001d => [
        {
            Condition => '$self->{CameraModel} =~ /(\*ist D|Optio S)/',
            Name => 'FocalLength',
            Writable => 'int32u',
            ValueConv => '$val * 0.01',
            ValueConvInv => '$val / 0.01',
            PrintConv => 'sprintf("%.1fmm",$val)',
            PrintConvInv => '$val=~s/mm//;$val',
        },
        {
            Name => 'FocalLength',
            Writable => 'int32u',
            ValueConv => '$val * 0.1',
            ValueConvInv => '$val / 0.1',
            PrintConv => 'sprintf("%.1fmm",$val)',
            PrintConvInv => '$val=~s/mm//;$val',
        },
    ],
    # Digital Zoom Tag - W. Smith 12 FEB 04
    0x001e => {
        Name => 'DigitalZoom',
        Writable => 'int16u',
    },
    0x001f => {
        Name => 'Saturation',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
            # the *istD has pairs of values.  These are unverified - PH
            '0 0' => 'Normal',
            '1 0' => 'Low',
            '2 0' => 'High',
        },
    },
    0x0020 => {
        Name => 'Contrast',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
            3 => 'Medium Low', #2
            4 => 'Medium High', #2
            # the *istD has pairs of values.  These are unverified - PH
            '0 0' => 'Normal',
            '1 0' => 'Low',
            '2 0' => 'High',
        },
    },
    0x0021 => {
        Name => 'Sharpness',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
            3 => 'Medium Soft', #2
            4 => 'Medium Hard', #2
            # the *istD has pairs of values.  These are unverified - PH
            '0 0' => 'Normal',
            '1 0' => 'Soft',
            '2 0' => 'Hard',
        },
    },
    0x0039 => { #PH
        Name => 'RawImageSize',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/ /x/;$_',
    },
    0x003f => {     #PH
        Name => 'LensType',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {  #3
            '3 17' => 'smc PENTAX-FA SOFT 85mmF2.8',
            '3 18' => 'smc PENTAX-F 1.7X AF ADAPTER',
            '3 19' => 'smc PENTAX-F 24-50mmF4',
            '3 20' => 'smc PENTAX-F 35-80mmF4-5.6',
            '3 21' => 'smc PENTAX-F 80-200mmF4.7-5.6',
            '3 22' => 'smc PENTAX-F FISH-EYE17-28mmF3.5-4.5',
            '3 23' => 'smc PENTAX-F 100-300mmF4.5-5.6',
            '3 24' => 'smc PENTAX-F 35-135mmF3.5-4.5',
            '3 25' => 'smc PENTAX-F 35-105mmF4-5.6',
            '3 26' => 'smc PENTAX-F*250-600mmF5.6ED[IF]',
            '3 27' => 'smc PENTAX-F 28-80mmF3.5-4.5',
            '3 28' => 'smc PENTAX-F 35-70mmF3.5-4.5',
            '3 29' => 'PENTAX-F 28-80mmF3.5-4.5',
            '3 30' => 'PENTAX-F 70-200mmF4-5.6',
            '3 31' => 'smc PENTAX-F 70-210mmF4-5.6',
            '3 32' => 'smc PENTAX-F 50mmF1.4',
            '3 33' => 'smc PENTAX-F 50mmF1.7',
            '3 34' => 'smc PENTAX-F 135mmF2.8[IF]',
            '3 35' => 'smc PENTAX-F 28mmF2.8',
            '3 38' => 'smc PENTAX-F*300mmF4.5ED[IF]',
            '3 39' => 'smc PENTAX-F*600mmF4ED[IF]',
            '3 40' => 'smc PENTAX-F MACRO 100mmF2.8',
            '3 41' => 'smc PENTAX-F MACRO 50mmF2.8',
            '3 50' => 'smc PENTAX-FA 28-70mmF4AL',
            '3 52' => 'smc PENTAX-FA 28-200mmF3.8-5.6AL[IF]',
            '3 53' => 'smc PENTAX-FA 28-80mmF3.5-5.6AL',
            '4 1' => 'smc PENTAX-FA SOFT 28mmF2.8',
            '4 2' => 'smc PENTAX-FA 80-320mmF4.5-5.6',
            '4 3' => 'smc PENTAX-FA 43mmF1.9 Limited',
            '4 6' => 'smc PENTAX-FA 35-80mmF4-5.6',
            '4 15' => 'smc PENTAX-FA 28-105mmF4-5.6[IF]',
            '4 20' => 'smc PENTAX-FA 28-80mmF3.5-5.6',
            '4 23' => 'smc PENTAX-FA 20-35mmF4AL',
            '4 24' => 'smc PENTAX-FA 77mmF1.8 Limited',
            '4 26' => 'smc PENTAX-FA MACRO 100mmF3.5',
            '4 28' => 'smc PENTAX-FA 35mmF2AL',
            '4 34' => 'smc PENTAX-FA 24-90mmF3.5-4.5AL[IF]',
            '4 35' => 'smc PENTAX-FA 100-300mmF4.7-5.8',
            '4 38' => 'smc PENTAX-FA 28-105mmF3.2-4.5AL[IF]',
            '4 39' => 'smc PENTAX-FA 31mmF1.8AL Limited',
            '4 43' => 'smc PENTAX-FA 28-90mmF3.5-5.6',
            '4 44' => 'smc PENTAX-FA J 75-300mmF4.5-5.8AL',
            '4 46' => 'smc PENTAX-FA J 28-80mm F3.5-5.6AL',
            '4 47' => 'smc PENTAX-FA J 18-35mmF4-5.6AL',
            '4 253' => 'smc PENTAX-DA 14mmF2.8ED[IF]',
            '4 254' => 'smc PENTAX-DA 16-45mmF4ED AL',
            '5 1' => 'smc PENTAX-FA*24mmF2 AL[IF]',
            '5 2' => 'smc PENTAX-FA 28mmF2.8 AL',
            '5 3' => 'smc PENTAX-FA 50mmF1.7',
            '5 4' => 'smc PENTAX-FA 50mmF1.4',
            '5 5' => 'smc PENTAX-FA*600mmF4ED[IF]',
            '5 6' => 'smc PENTAX-FA*300mmF4.5ED[IF]',
            '5 7' => 'smc PENTAX-FA 135mmF2.8[IF]',
            '5 8' => 'smc PENTAX-FA MACRO 50mmF2.8',
            '5 9' => 'smc PENTAX-FA MACRO 100mmF2.8',
            '5 10' => 'smc PENTAX-FA*85mmF1.4[IF]',
            '5 11' => 'smc PENTAX-FA*200mmF2.8ED[IF]',
            '5 12' => 'smc PENTAX-FA 28-80mmF3.5-4.7',
            '5 13' => 'smc PENTAX-FA 70-200mmF4-5.6',
            '5 14' => 'smc PENTAX-FA* 250-600mmF5.6ED[IF]',
            '5 15' => 'smc PENTAX-FA 28-105mmF4-5.6',
            '5 16' => 'smc PENTAX-FA 100-300mmF4.5-5.6',
            '6 1' => 'smc PENTAX-FA*85mmF1.4[IF]',
            '6 2' => 'smc PENTAX-FA*200mmF2.8ED[IF]',
            '6 3' => 'smc PENTAX-FA*300mmF2.8ED[IF]',
            '6 4' => 'smc PENTAX-FA*28-70mmF2.8AL',
            '6 5' => 'smc PENTAX-FA*80-200mmF2.8ED[IF]',
            '6 6' => 'smc PENTAX-FA*28-70mmF2.8AL',
            '6 7' => 'smc PENTAX-FA*80-200mmF2.8ED[IF]',
            '6 8' => 'smc PENTAX-FA 28-70mmF4AL',
            '6 9' => 'smc PENTAX-FA 20mmF2.8',
            '6 10' => 'smc PENTAX-FA*400mmF5.6ED[IF]',
            '6 13' => 'smc PENTAX-FA*400mmF5.6ED[IF]',
            '6 14' => 'smc PENTAX-FA* MACRO 200mmF4ED[IF]',
            '1 0' => 'K,M Lens',
            '3 0' => 'SIGMA',
            '3 36' => 'SIGMA 20mm F1.8 EX DG ASPHERICAL RF',
            '3 51' => 'SIGMA 28mm F1.8 EX DG ASPHERICAL MACRO',
            '3 44' => 'SIGMA 18-50mm F3.5-5.6 DC',
            '3 46' => 'SIGMA APO 70-200mm F2.8 EX',
            '3 253' => 'smc PENTAX-DA 14mmF2.8ED[IF]',
            '3 254' => 'smc PENTAX-DA 16-45mmF4ED AL',
            '4 41' => 'TAMRON AF28-200mm Super Zoom F/3.8-5.6 Aspherical XR [IF] MACRO (A03)',
            '4 49' => 'TAMRON SP AF28-75mm F/2.8 XR Di (A09)',
            '4 19' => 'TAMRON SP AF90mm F/2.8',
            '4 45' => 'TAMRON 28-300mm F3.5-6.3 Ultra zoom XR',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
        },
    },
);

# These are from Image::MakerNotes::Pentax.pm, but they don't seem to work - PH
#    0x0003 => {
#        Name => 'Focus',
#        PrintConv => {
#            2 => 'Custom',
#            3 => 'Auto',
#        },
#    },
#    0x0004 => {
#        Name => 'Flash',
#        PrintConv => {
#            1 => 'Auto',
#            2 => 'On',
#            4 => 'Off',
#            6 => 'Red-eye reduction',
#        },
#    },
#    0x000a => 'Zoom',
#    0x0017 => {
#        Name => 'Color',
#        PrintConv => {
#            1 => 'Full',
#            2 => 'Black & White',
#            3 => 'Sepia',
#        },
#    },


1; # end

__END__

=head1 NAME

Image::ExifTool::Pentax - Definitions for Pentax/Asahi maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Pentax and Asahi maker notes in EXIF information.

=head1 NOTES

I couldn't find a good source for Pentax maker notes information so I've
tried to figure out some of it myself based on sample pictures from the
Optio 550, Optio S and *istD.  So far, what I have figured out isn't very
complete, and some of it may be wrong.

While the Pentax maker notes are stored in standard EXIF format, the offsets
used for some of the Optio cameras are wacky.  They seem to give the offset
relative to the offset of the tag in the directory.  Very weird.  I'm just
ignoring this peculiarity, but it doesn't affect much except the PrintIM
data since other data is generally less than 4 bytes and therefore doesn't
require a pointer.

=head1 REFERENCES

=over 4

=item Image::MakerNotes::Pentax

=item http://johnst.org/sw/exiftags/ (Asahi models)

=item http://kobe1995.jp/~kaz/astro/istD.html

=back

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>, L<Image::Info|Image::Info>

=cut
