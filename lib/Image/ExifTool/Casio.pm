#------------------------------------------------------------------------------
# File:         Casio.pm
#
# Description:  Definitions for Casio EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#               09/10/2004 - P. Harvey Added MakerNote2 (thanks to Joachim Loehr)
#------------------------------------------------------------------------------

package Image::ExifTool::Casio;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

%Image::ExifTool::Casio::MakerNote1 = (
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0x0001 => {
        Name => 'RecordingMode' ,
        PrintConv => {
            1 => 'SingleShutter',
            2 => 'Panorama',
            3 => 'Night scene',
            4 => 'Portrait',
            5 => 'Landscape',
        },
    },
    0x0002 => { 
        Name => 'Quality',
        Description => 'Image Quality',
        PrintConv => { 1 => 'Economy', 2 => 'Normal', 3 => 'Fine' },
    },
    0x0003 => { 
        Name => 'FocusMode',
        PrintConv => {
            2 => 'Macro',
            3 => 'Auto',
            4 => 'Manual',
            5 => 'Infinity',
        },
    },
    0x0004 => { 
        Name => 'FlashMode',
        PrintConv => { 1 => 'Auto', 2 => 'On', 3 => 'Off', 4 => 'Red-eye reduction' },
    },
    0x0005 => { 
        Name => 'FlashIntensity',
        PrintConv => { 11 => 'Weak', 13 => 'Normal', 15 => 'Strong' },
    },
    0x0006 => 'ObjectDistance',
    0x0007 => { 
        Name => 'WhiteBalance', 
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
        PrintConv => { 65536 => 'Off', 65537 => '2X' },
    },
    0x000b => { 
        Name => 'Sharpness', 
        PrintConv => { 0 => 'Normal', 1 => 'Soft', 2 => 'Hard' },
    },
    0x000c => { 
        Name => 'Contrast', 
        PrintConv => { 0 => 'Normal', 1 => 'Low', 2 => 'High' },
    },
    0x000d => { 
        Name => 'Saturation', 
        PrintConv => { 0 => 'Normal', 1 => 'Low', 2 => 'High' },
    },
    0x0014 => { 
        Name => 'CCDSensitivity',
        PrintConv => {
            64  => 'Normal',
            125 => '+1.0',
            250 => '+2.0',
            244 => '+3.0',
            80  => 'Normal',
            100 => 'High',
        },
    },
);

%Image::ExifTool::Casio::MakerNote2 = (
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
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
        ValueConv => '$val + 10',
        Groups => { 2 => 'Image' },
    },
    0x0008 => { 
        Name => 'QualityMode',
        PrintConv => {
           0 => 'Economy',
           1 => 'Normal',
           2 => 'Fine',
        },
    },
    0x0009 => { 
        Name => 'CasioImageSize',
        Groups => { 2 => 'Image' },
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
        PrintConv => {
           0 => 'Normal',
           1 => 'Macro',
        },
    },
    0x0014 => { 
        Name => 'ISOSetting',
        Description => 'ISO',
        PrintConv => { 
           3 => 50,
           4 => 64,
           6 => 100,
           9 => 200,
        },
    },
    0x0019 => { 
        Name => 'WhiteBalance',
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
        Description => 'Focal Length (mm)',
    },
    0x001f => { 
        Name => 'Saturation',
        PrintConv => {
           0 => '-1',
           1 => 'Normal',
           2 => '+1',
        },
    },
    0x0020 => { 
        Name => 'Contrast',
        PrintConv => {
           0 => '-1',
           1 => 'Normal',
           2 => '+1',
        },
    },
    0x0021 => { 
        Name => 'Sharpness',
        PrintConv => {
           0 => '-1',
           1 => 'Normal',
           2 => '+1',
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
    #0x2000 => { 
    #    Name => 'CasioPreviewThumbnail',
    #},
    0x2011 => { 
        Name => 'WhiteBalanceBias',
    },
    0x2012 => { 
        Name => 'WhiteBalance',
        PrintConv => {
           12 => 'Flash',
           0 => 'Manual',
           1 => 'Auto?',
           4 => 'Flash?',
        },
    },
    0x2022 => { 
        Name => 'ObjectDistance',
        PrintConv => 'sprintf("%.3f m",$val/1000)',
    },
    0x2034 => { 
        Name => 'FlashDistance',
    },
    0x3000 => { 
        Name => 'RecordMode',
        PrintConv => { 2 => 'Normal' },
    },
    0x3001 => { 
        Name => 'SelfTimer',
        PrintConv => { 1 => 'Off' },
    },
    0x3002 => { 
        Name => 'Quality',
        PrintConv => { 
           1 => 'Economic',
           2 => 'Normal',
           3 => 'Fine',
        },
    },
    0x3003 => { 
        Name => 'FocusMode',
        PrintConv => { 
           0 => 'Manual?',
           1 => 'Fixation?',
           3 => 'Single-Area Auto Focus',
           6 => 'Multi-Area Auto Focus',
        },
    },
    0x3006 => { 
        Name => 'TimeZone',
    },
    0x3007 => { 
        Name => 'BestshotMode',
        PrintConv => { 
           0 => 'Off',
           1 => 'On?',
        },
    },
    0x3014 => { 
        Name => 'CCDISOSensitivity',
        Description => 'CCD ISO Sensitivity',
    },
    0x3015 => { 
        Name => 'ColorMode',
        PrintConv => { 0 => 'Off' },
    },
    0x3016 => { 
        Name => 'Enhancement',
        PrintConv => { 0 => 'Off' },
    },
    0x3017 => { 
        Name => 'Filter',
        PrintConv => { 0 => 'Off' },
    },
);

1;  # end
