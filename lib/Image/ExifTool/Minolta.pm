#------------------------------------------------------------------------------
# File:         Minolta.pm
#
# Description:  Definitions for Minolta EXIF Maker Notes
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# Reference:    http://www.dalibor.cz/minolta/makernote.htm
#------------------------------------------------------------------------------

package Image::ExifTool::Minolta;

use strict;
use vars qw($VERSION);

$VERSION = '1.01';

%Image::ExifTool::Minolta::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0000 => 'MakerNoteVersion',
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            Start => '$valuePtr',
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        SubDirectory => {
            Start => '$valuePtr',
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0040 => 'CompressedImageSize',
    0x0081 => 'PreviewImageData',
    0x0088 => 'PreviewImageStart',
    0x0089 => 'PreviewImageLength',
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
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
        },
    },
    0x0f00 => 'MinoltaCameraSettings2',
);

%Image::ExifTool::Minolta::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'ULong',
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
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Tungsten',
            5 => 'Custom',
            7 => 'Fluorescent',
            8 => 'Fluorescent 2',
            11 => 'Custom 2',
            12 => 'Custom 3',
        },
    },
    4 => {
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => '2560x1920 (2048x1536)',
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
    },
    19 => {
        Name => 'FocusDistance',
        ValueConv => '$val / 1000',
        PrintConv => '$val ? "$val m" : "inf"',
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
    },
    22 => {
        Name => 'MinoltaTime',
        ValueConv => 'sprintf("%2d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
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
    },
    29 => {
        Name => 'ColorBalanceGreen',
        ValueConv => '$val / 256',
    },
    30 => {
        Name => 'ColorBalanceBlue',
        ValueConv => '$val / 256',
    },
    31 => {
        Name => 'Saturation',
        ValueConv => '$val - 3',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
    },
    32 => {
        Name => 'Contrast',
        ValueConv => '$val - 3',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
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
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    36 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => '100',
            1 => '200',
            2 => '400',
            3 => '800',
            4 => 'auto',
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

1;  # end
