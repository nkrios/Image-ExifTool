#------------------------------------------------------------------------------
# File:         Pentax.pm
#
# Description:  Definitions for Pentax EXIF Maker Notes
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/10/2004 - P. Harvey Completely re-done
#               02/16/2004 - W. Smith Updated (See specific tag comments)
#
# Notes:        I couldn't find a good source for Pentax maker notes information
#               so I've tried to figure out some of it myself based on sample
#               pictures from the Optio 550, Optio S and *istD.  So far, what I
#               have figured out isn't very complete, and some of it may be wrong.
#
#               While the pentax maker notes are stored in standard EXIF format,
#               the offsets used for some of the Optio cameras are wacky.  They
#               seem to give the offset relative to the offset of the tag in the
#               directory.  Very weird.  I'm just ignoring this peculiarity, but
#               it doesn't affect much except the PrintIM data since other data
#               is generally less than 4 bytes and therefore doesn't require a
#               pointer.
#------------------------------------------------------------------------------

package Image::ExifTool::Pentax;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

%Image::ExifTool::Pentax::Main = (
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0x0001 => {
        Name => 'PentaxMode',
        PrintConv => {
            0 => 'Auto',
            1 => 'Night-scene',
            2 => 'Manual',
        },
    },
    0x0002 => {
        Name => 'PreviewImageSize',
        Groups => { 2 => 'Image' },
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    0x0003 => {
        Name => 'PreviewImageLength',
        Groups => { 2 => 'Image' },
    },
    0x0004 => {
        Name => 'PreviewImageStart',
        Groups => { 2 => 'Image' },
        ValueConv => '$val + 12',
    },
    0x0008 => {
        Name => 'Quality',
        Description => 'Image Quality',
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
        PrintConv => {
            0 => '640x480',
            2 => '1024x768',
            4 => '1600x1200',
            5 => '2048x1536',
            21 => '2592x1944',
            '36 0' => '3008x2008',  # PH
        },
    },
    # Picture Mode Tag - W. Smith 12 FEB 04
    0x000b => {
        Name => 'PentaxPictureMode',
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
        Name => 'PentaxFocusMode',
    },
    # ISO Tag - Entries confirmed by W. Smith 12 FEB 04
    0x0014 => {
        Name => 'PentaxISO',
        PrintConv => {
            3 => 50,    # Not confirmed
            4 => 64,
            6 => 100,
            9 => 200,
            12 => 400,
            15 => 800,  # Not confirmed
            18 => 1600, # Not confirmed
            21 => 3200, # Not Confirmed
        },
    },
    # AE Metering Mode Tag - W. Smith 12 FEB 04
    0x0017 => {
        Name => 'PentaxAEMetering',
        PrintConv => {
            0 => 'Multi Segment',
            1 => 'Center Weighted',
            2 => 'Spot',
        },
    },
    # White Balance Tag - W. Smith 12 FEB 04
    0x0019 => {
        Name => 'PentaxWhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            4 => 'Tungsten',
            5 => 'Manual',
        },
    },
    # Would be nice if there was a general way to determine units for FocalLength.
    # Optio 550 uses .1mm while *istD uses .01 - PH
    0x001d => {
        Name => 'PentaxFocalLength',
        ValueConv => '$val * ($self->{CameraModel} =~ /\*ist D/ ? 0.01 : 0.1)',
    },
    # Digital Zoom Tag - W. Smith 12 FEB 04
    0x001e => {
        Name => 'PentaxZoom',
        ValueConv => '$val',
    },
    0x001f => {
        Name => 'PentaxSaturation',
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
        Name => 'PentaxContrast',
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
    0x0021 => {
        Name => 'PentaxSharpness',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
            # the *istD has pairs of values.  These are unverified - PH
            '0 0' => 'Normal',
            '1 0' => 'Soft',
            '2 0' => 'Hard',
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
