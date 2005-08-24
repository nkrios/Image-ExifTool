#------------------------------------------------------------------------------
# File:         Pentax.pm
#
# Description:  Definitions for Pentax/Asahi EXIF Maker Notes
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/10/2004 - P. Harvey Completely re-done
#               02/16/2004 - W. Smith Updated (see ref 3)
#               11/10/2004 - P. Harvey Added support for Asahi cameras
#               01/10/2005 - P. Harvey Added NikonLens with values from ref 4
#               03/30/2005 - P. Harvey Added new tags from ref 5
#
# References:   1) Image::MakerNotes::Pentax
#               2) http://johnst.org/sw/exiftags/ (Asahi cameras)
#               3) Wayne Smith private communication (tests with Optio 550)
#               4) http://kobe1995.jp/~kaz/astro/istD.html
#               5) John Francis private communication (tests with ist-D/ist-DS)
#               6) http://www.cybercom.net/~dcoffin/dcraw/
#               7) Douglas O'Brien private communication (tests with *istD)
#               8) Denis Bourez private communication
#
# Notes:        See POD documentation at the bottom of this file
#------------------------------------------------------------------------------

package Image::ExifTool::Pentax;

use strict;
use vars qw($VERSION);
use Image::ExifTool::MakerNotes;

$VERSION = '1.22';

# Pentax city codes - PH (from Optio WP)
my %pentaxCities = (
    0 => 'Pago Pago',
    1 => 'Honolulu',
    2 => 'Anchorage',
    3 => 'Vancouver',
    4 => 'San Fransisco',
    5 => 'Los Angeles',
    6 => 'Calgary',
    7 => 'Denver',
    8 => 'Mexico City',
    9 => 'Chicago',
    10 => 'Miami',
    11 => 'Toronto',
    12 => 'New York',
    13 => 'Santiago',
    14 => 'Caracus',
    15 => 'Halifax',
    16 => 'Buenos Aires',
    17 => 'Sao Paulo',
    18 => 'Rio de Janeiro',
    19 => 'Madrid',
    20 => 'London',
    21 => 'Paris',
    22 => 'Milan',
    23 => 'Rome',
    24 => 'Berlin',
    25 => 'Johannesburg',
    26 => 'Istanbul',
    27 => 'Cairo',
    28 => 'Jerusalem',
    29 => 'Moscow',
    30 => 'Jeddah',
    31 => 'Tehran',
    32 => 'Dubai',
    33 => 'Karachi',
    34 => 'Kabul',
    35 => 'Male',
    36 => 'Delhi',
    37 => 'Colombo',
    38 => 'Kathmandu',
    39 => 'Dacca',
    40 => 'Yangon',
    41 => 'Bangkok',
    42 => 'Kuala Lumpur',
    43 => 'Vientiane',
    44 => 'Singapore',
    45 => 'Phnom Penh',
    46 => 'Ho Chi Minh',
    47 => 'Jakarta',
    48 => 'Hong Kong',
    49 => 'Perth',
    50 => 'Beijing',
    51 => 'Shanghai',
    52 => 'Manila',
    53 => 'Taipei',
    54 => 'Seoul',
    55 => 'Adelaide',
    56 => 'Tokyo',
    57 => 'Guam',
    58 => 'Sydney',
    59 => 'Noumea',
    60 => 'Wellington',
    61 => 'Auckland',
    62 => 'Lima',
    63 => 'Dakar',
    64 => 'Algiers',
    65 => 'Helsinki',
    66 => 'Athens',
    67 => 'Nairobi',
    68 => 'Amsterdam',
    69 => 'Stockholm',
);

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
        Protected => 2,
    },
    0x0004 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        Protected => 2,
        OffsetPair => 0x0003, # point to associated byte count
        DataTag => 'PreviewImage',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
    },
    0x0006 => { #5
        # Note: Year is int16u in MM byte ordering regardless of EXIF byte order
        Name => 'Date',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'length($val)==4 ? sprintf("%.4d:%.2d:%.2d",unpack("nC2",$val)) : "Unknown ($val)"',
        ValueConvInv => 'my @v=split /:/, $val;pack("nC2",$v[0],$v[1],$v[2])',
    },
    0x0007 => { #5
        Name => 'Time',
        Writable => 'undef',
        Count => 3,
        ValueConv => 'length($val)>=3 ? sprintf("%.2d:%.2d:%.2d",unpack("C3",$val)) : "Unknown ($val)"',
        ValueConvInv => 'pack("C3",split(/:/,$val))',
    },
    0x0008 => {
        Name => 'Quality',
        Description => 'Image Quality',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Good',
            1 => 'Better',
            2 => 'Best',
            3 => 'TIFF', #5
            4 => 'RAW', #5
        },
    },
    0x0009 => { #3
        Name => 'PentaxImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        PrintConv => {
            0 => '640x480',
            1 => 'Full', #PH - this can mean 2048x1536 or 2240x1680 or ... ?
            2 => '1024x768',
            3 => '1280x960', #PH (Optio WP)
            4 => '1600x1200',
            5 => '2048x1536',
            8 => '2560x1920', #PH (Optio WP)
            19 => '320x240', #PH (Optio WP)
            21 => '2592x1944',
            22 => '2304x1728', #2
            '32 2' => '960x640', #7
            '33 2' => '1152x768', #7
            '34 2' => '1536x1024', #7
            '35 1' => '2400x1600', #7
            '36 0' => '3008x2008',  #PH
        },
    },
    0x000b => { #3
        Name => 'PictureMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Program', #PH
            5 => 'Portrait',
            6 => 'Landscape',
            8 => 'Sport', #PH
            9 => 'Night Scene',
            11 => 'Soft', #PH
            12 => 'Surf & Snow',
            13 => 'Sunset',
            14 => 'Autumn',
            15 => 'Flower',
            17 => 'Fireworks',
            18 => 'Text',
            19 => 'Panorama', #PH
            30 => 'Self Portrait', #PH
            37 => 'Museum', #PH
            38 => 'Food', #PH
            40 => 'Green Mode', #PH
            49 => 'Light Pet', #PH
            50 => 'Dark Pet', #PH
            51 => 'Medium Pet', #PH
            53 => 'Underwater', #PH
            54 => 'Candlelight', #PH
            55 => 'Natural Skin Tone', #PH
            56 => 'Synchro Sound Record', #PH
        },
    },
    0x000c => { #PH
        Name => 'FlashMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'Auto, Did not fire',
            0x001 => 'Off',
            0x003 => 'Auto, Did not fire, Red-eye reduction',
            0x100 => 'Auto, Fired',
            0x102 => 'On',
            0x103 => 'Auto, Fired, Red-eye reduction',
            0x104 => 'On, Red-eye reduction',
            0x108 => 'On, Soft',
        },
    },
    0x000d => [
        {
            Condition => '$self->{CameraMake} =~ /^PENTAX/',
            Name => 'FocusMode',
            Notes => 'Pentax models',
            Writable => 'int16u',
            PrintConv => { #PH
                0 => 'Normal',
                1 => 'Macro',
                2 => 'Infinity',
                3 => 'Manual',
                5 => 'Pan Focus',
            },
        },
        {
            Name => 'FocusMode',
            Writable => 'int16u',
            Notes => 'Asahi models',
            PrintConv => { #2
                0 => 'Normal',
                1 => 'Macro (1)',
                2 => 'Macro (2)',
                3 => 'Infinity',
            },
        },
    ],
    0x000f => { #PH
        Name => 'AutoAFPoint',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0xffff => 'None',
            1 => 'Top-left',
            2 => 'Top-center',
            3 => 'Top-right',
            4 => 'Left',
            5 => 'Center',
            6 => 'Right',
            7 => 'Bottom-left',
            8 => 'Bottom-center',
            9 => 'Bottom-right',
        },
    },
    0x0010 => { #PH
        Name => 'FocusPosition',
        Writable => 'int16u',
        Notes => 'Related to focus distance but effected by focal length',
    },
    0x0012 => { #PH
        Name => 'ExposureTime',
        Description => 'Shutter Speed',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val * 1e-5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x0013 => { #PH
        Name => 'FNumber',
        Description => 'Aperture',
        Writable => 'int16u',
        Priority => 0,
        ValueConv => '$val * 0.1',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    # ISO Tag - Entries confirmed by W. Smith 12 FEB 04
    0x0014 => {
        Name => 'ISO',
        Description => 'ISO Speed',
        Writable => 'int16u',
        Priority => 0,
        PrintConv => {
            3 => 50, #(NC=Not Confirmed)
            4 => 64,
            5 => 80, #(NC)
            6 => 100,
            7 => 125, #PH
            8 => 160, #PH
            9 => 200,
            10 => 250, #(NC)
            11 => 320, #(NC)
            12 => 400,
            13 => 500, #(NC)
            14 => 640, #(NC)
            15 => 800,
            16 => 1000, #(NC)
            17 => 1250, #(NC)
            18 => 1600, #(NC)
            21 => 3200, #(NC)
            50 => 50, #PH
            100 => 100, #PH
            200 => 200, #PH
            400 => 400, #PH
            800 => 800, #PH
            1600 => 1600, #PH
            3200 => 3200, #PH
        },
    },
    # 0x0015 - Related to measured EV? ranges from -2 to 6 if interpreted as signed int (PH)
    0x0016 => { #PH
        Name => 'ExposureCompensation',
        Writable => 'int16u',
        ValueConv => '($val - 50) * 0.1',
        ValueConvInv => 'int($val * 10 + 50.5)',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
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
    0x001a => { #5
        Name => 'WhiteBalanceMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto (Daylight?)',
            2 => 'Auto (Shade?)',
            3 => 'Auto (Flash?)',
            4 => 'Auto (Tungsten?)',
            0xffff => 'User-Selected',
            0xfffe => 'Preset (Fireworks?)', #PH
        },
    },
    0x001b => { #6
        Name => 'BlueBalance',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x001c => { #6
        Name => 'RedBalance',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    # Would be nice if there was a general way to determine units for FocalLength.
    # Optio 550 uses .1mm while *istD, Optio S and Optio WP use .01 - PH
    0x001d => [
        {
            Condition => '$self->{CameraModel} =~ /(\*ist D|Optio [A-Z])/',
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
        Notes => 'Pentax models',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Low', #PH
            1 => 'Normal', #PH
            2 => 'High', #PH
            3 => 'Med Low', #2
            4 => 'Med High', #2
            # the *istD has pairs of values - PH
            '0 0' => 'Low',
            '1 0' => 'Normal',
            '2 0' => 'High',
        },
    },
    0x0020 => {
        Name => 'Contrast',
        Notes => 'Pentax models',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Low', #PH
            1 => 'Normal', #PH
            2 => 'High', #PH
            3 => 'Med Low', #2
            4 => 'Med High', #2
            # the *istD has pairs of values - PH
            '0 0' => 'Low',
            '1 0' => 'Normal',
            '2 0' => 'High',
        },
    },
    0x0021 => {
        Name => 'Sharpness',
        Notes => 'Pentax models',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Soft', #PH
            1 => 'Normal', #PH
            2 => 'Hard', #PH
            3 => 'Med Soft', #2
            4 => 'Med Hard', #2
            # the *istD has pairs of values - PH
            '0 0' => 'Soft',
            '1 0' => 'Normal',
            '2 0' => 'Hard',
        },
    },
    0x0022 => { #PH
        Name => 'WorldTimeLocation',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Hometown',
            1 => 'Destination',
        },
    },
    0x0023 => { #PH
        Name => 'HometownCity',
        Writable => 'int16u',
        PrintConv => \%pentaxCities,
    },
    0x0024 => { #PH
        Name => 'DestinationCity',
        Writable => 'int16u',
        PrintConv => \%pentaxCities,
    },
    0x0025 => { #PH
        Name => 'HometownDST',
        Writable => 'int16u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x0026 => { #PH
        Name => 'DestinationDST',
        Writable => 'int16u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    # 0x0027 - could be a 5-byte string software version number for the Optio 550,
    #          but the offsets are wacky so it is hard to tell (PH)
    0x0029 => { #5
        Name => 'FrameNumber',
        Writable => 'int32u',
    },
    # 0x0032 - normally 4 zero bytes, but "\x02\0\0\0" for a cropped pic (PH)
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
        PrintConv => {  #4
            '1 0' => 'K,M Lens',
            '2 0' => 'A Series Lens', #7 (from smc PENTAX-A 400mmF5.6)
            '3 0' => 'SIGMA',
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
            '3 36' => 'SIGMA 20mm F1.8 EX DG ASPHERICAL RF',
            '3 38' => 'smc PENTAX-F*300mmF4.5ED[IF]',
            '3 39' => 'smc PENTAX-F*600mmF4ED[IF]',
            '3 40' => 'smc PENTAX-F MACRO 100mmF2.8',
            '3 41' => 'smc PENTAX-F MACRO 50mmF2.8',
            '3 44' => 'SIGMA 18-50mm F3.5-5.6 DC',
            '3 46' => 'SIGMA APO 70-200mm F2.8 EX',
            '3 50' => 'smc PENTAX-FA 28-70mmF4AL',
            '3 51' => 'SIGMA 28mm F1.8 EX DG ASPHERICAL MACRO',
            '3 52' => 'smc PENTAX-FA 28-200mmF3.8-5.6AL[IF]',
            '3 53' => 'smc PENTAX-FA 28-80mmF3.5-5.6AL',
            '3 253' => 'smc PENTAX-DA 14mmF2.8ED[IF]',
            '3 254' => 'smc PENTAX-DA 16-45mmF4ED AL',
            '3 255' => 'SIGMA 18-200mm F3.5-6.3 DC', #8
            '4 1' => 'smc PENTAX-FA SOFT 28mmF2.8',
            '4 2' => 'smc PENTAX-FA 80-320mmF4.5-5.6',
            '4 3' => 'smc PENTAX-FA 43mmF1.9 Limited',
            '4 6' => 'smc PENTAX-FA 35-80mmF4-5.6',
            '4 15' => 'smc PENTAX-FA 28-105mmF4-5.6[IF]',
            '4 19' => 'TAMRON SP AF90mm F/2.8',
            '4 20' => 'smc PENTAX-FA 28-80mmF3.5-5.6',
            '4 23' => 'smc PENTAX-FA 20-35mmF4AL',
            '4 24' => 'smc PENTAX-FA 77mmF1.8 Limited',
            '4 26' => 'smc PENTAX-FA MACRO 100mmF3.5',
            '4 28' => 'smc PENTAX-FA 35mmF2AL',
            '4 34' => 'smc PENTAX-FA 24-90mmF3.5-4.5AL[IF]',
            '4 35' => 'smc PENTAX-FA 100-300mmF4.7-5.8',
            '4 38' => 'smc PENTAX-FA 28-105mmF3.2-4.5AL[IF]',
            '4 39' => 'smc PENTAX-FA 31mmF1.8AL Limited',
            '4 41' => 'TAMRON AF28-200mm Super Zoom F/3.8-5.6 Aspherical XR [IF] MACRO (A03)',
            '4 43' => 'smc PENTAX-FA 28-90mmF3.5-5.6',
            '4 44' => 'smc PENTAX-FA J 75-300mmF4.5-5.8AL',
            '4 45' => 'TAMRON 28-300mm F3.5-6.3 Ultra zoom XR',
            '4 46' => 'smc PENTAX-FA J 28-80mm F3.5-5.6AL',
            '4 47' => 'smc PENTAX-FA J 18-35mmF4-5.6AL',
            '4 49' => 'TAMRON SP AF28-75mm F/2.8 XR Di (A09)',
            '4 250' => 'smc PENTAX-DA 50-200mm f/4-5.6 ED', #8
            '4 252' => 'smc PENTAX-DA 18-55mmF3.5-5.6 AL', #8
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
        },
    },
    # 0x0041 - increments for each cropped pic (PH)
    0x0200 => {
        Name => 'BlackPoint', #5
        Writable => 'int16u',
        Count => 4,
    },
    0x0201 => {
        Name => 'WhitePoint', #5
        Writable => 'int16u',
        Count => 4,
    },
    0x03fe => { #PH
        Name => 'DataDump',
        Writable => 0,
        PrintConv => '\$val',
    },
    0x0402 => { #5
        Name => 'ToneCurve',
        PrintConv => '\$val',
    },
    0x0403 => { #5
        Name => 'ToneCurves',
        PrintConv => '\$val',
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x1000 => {
        Name => 'HometownCityCode', #PH
        Writable => 'undef',
        Count => 4,
    },
    0x1001 => {
        Name => 'DestinationCityCode', #PH(NC)
        Writable => 'undef',
        Count => 4,
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

I couldn't find a good source for Pentax maker notes information, but I've
managed to discover a fair bit of information by analyzing sample pictures
from the Optio 330, Optio 550, Optio S, *istD, *istDs, and through tests
with my own Optio WP, and with help provided by other ExifTool users (see
L<ACKNOWLEDGEMENTS>).

The Pentax maker notes are stored in standard EXIF format, but the offsets
used for some of their cameras are wacky.  The Optio 330 gives the offset
relative to the offset of the tag in the directory, the Optio WP uses a base
offset in the middle of nowhere, and the Optio 550 uses different (and
totally illogical) bases for different menu entries.  Very weird.  (It
wouldn't surprise me if Pentax can't read their own maker notes!)  Luckily,
there are only a few entries in the maker notes which are large enough to
require offsets, so this doesn't effect much useful information.  ExifTool
attempts to make sense of this fiasco by making an assumption about where
the information should be stored to deduce the correct offsets.

=head1 REFERENCES

=over 4

=item L<Image::MakerNotes::Pentax|Image::MakerNotes::Pentax>

=item L<http://johnst.org/sw/exiftags/> (Asahi models)

=item L<http://kobe1995.jp/~kaz/astro/istD.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item (...plus lots of testing with my Optio WP!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Wayne Smith, John Francis and Douglas O'Brien for help figuring
out some Pentax tags.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Pentax Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::Info(3pm)|Image::Info>

=cut
