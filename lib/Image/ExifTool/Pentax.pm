#------------------------------------------------------------------------------
# File:         Pentax.pm
#
# Description:  Pentax/Asahi EXIF maker notes tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/10/2004 - P. Harvey Completely re-done
#               02/16/2004 - W. Smith Updated (see ref 3)
#               11/10/2004 - P. Harvey Added support for Asahi cameras
#               01/10/2005 - P. Harvey Added NikonLens with values from ref 4
#               03/30/2005 - P. Harvey Added new tags from ref 5
#               10/04/2005 - P. Harvey Added MOV tags
#
# References:   1) Image::MakerNotes::Pentax
#               2) http://johnst.org/sw/exiftags/ (Asahi cameras)
#               3) Wayne Smith private communication (Optio 550)
#               4) http://kobe1995.jp/~kaz/astro/istD.html
#               5) John Francis private communication (ist-D/ist-DS)
#               6) http://www.cybercom.net/~dcoffin/dcraw/
#               7) Douglas O'Brien private communication (*istD)
#               8) Denis Bourez private communication
#               9) Kazumichi Kawabata private communication
#              10) David Buret private communication (*istD)
#              11) http://forums.dpreview.com/forums/read.asp?forum=1036&message=17465929
#              12) Derby Chang private communication
#              13) http://homepage3.nifty.com/kamisaka/makernote/makernote_pentax.htm
#              14) Ger Vermeulen private communication (Optio S6)
#              15) Barney Garrett private communication (Samsung GX-1S)
#              16) Axel Kellner private communication (K10D)
#
# Notes:        See POD documentation at the bottom of this file
#------------------------------------------------------------------------------

package Image::ExifTool::Pentax;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.42';

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
    70 => 'Lisbon', #14
);

%Image::ExifTool::Pentax::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    0x0001 => {
        Name => 'PentaxMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Night Scene',
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
        IsOffset => 2,  # code to use original base
        Protected => 2,
        OffsetPair => 0x0003, # point to associated byte count
        DataTag => 'PreviewImage',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
    },
    0x0005 => { #13
        Name => 'PentaxModelID',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => { #PH
            0x0000d => 'Optio 330/430',
            0x12926 => 'Optio 230',
            0x12958 => 'Optio 330GS',
            0x12962 => 'Optio 450/550',
            0x1296c => 'Optio S',
            0x12994 => '*ist D',
            0x129b2 => 'Optio 33L',
            0x129bc => 'Optio 33LF',
            0x129c6 => 'Optio 33WR/43WR/555',
            0x129d5 => 'Optio S4',
            0x12a02 => 'Optio MX',
            0x12a0c => 'Optio S40',
            0x12a16 => 'Optio S4i',
            0x12a34 => 'Optio 30',
            0x12a52 => 'Optio S30',
            0x12a66 => 'Optio 750Z',
            0x12a70 => 'Optio SV',
            0x12a75 => 'Optio SVi',
            0x12a7a => 'Optio X',
            0x12a8e => 'Optio S5i',
            0x12a98 => 'Optio S50',
            0x12aa2 => '*ist DS',
            0x12ab6 => 'Optio MX4',
            0x12ac0 => 'Optio S5n',
            0x12aca => 'Optio WP',
            0x12afc => 'Optio S55',
            0x12b10 => 'Optio S5z',
            0x12b1a => '*ist DL',
            0x12b24 => 'Optio S60',
            0x12b2e => 'Optio S45',
            0x12b38 => 'Optio S6',
            0x12b4c => 'Optio WPi', #13
            0x12b56 => 'BenQ DC X600',
            0x12b60 => '*ist DS2',
            0x12b62 => 'Samsung GX-1S',
            0x12b6a => 'Optio A10',
            0x12b7e => '*ist DL2',
            0x12b80 => 'Samsung GX-1L',
            0x12b9c => 'K100D',
            0x12b9d => 'K110D',
            0x12bb0 => 'Optio T10',
            0x12be2 => 'Optio W10',
            0x12bf6 => 'Optio M10',
            0x12c1e => 'K10D',
            0x12c20 => 'Samsung GX10',
            0x12c28 => 'Optio S7',
            0x12c32 => 'Optio M20',
            0x12c3c => 'Optio W20',
            0x12c46 => 'Optio A20',
        },
    },
    0x0006 => { #5
        # Note: Year is int16u in MM byte ordering regardless of EXIF byte order
        Name => 'Date',
        Groups => { 2 => 'Time' },
        Writable => 'undef',
        Count => 4,
        Shift => 'Time',
        ValueConv => 'length($val)==4 ? sprintf("%.4d:%.2d:%.2d",unpack("nC2",$val)) : "Unknown ($val)"',
        ValueConvInv => 'my @v=split /:/, $val;pack("nC2",$v[0],$v[1],$v[2])',
    },
    0x0007 => { #5
        Name => 'Time',
        Groups => { 2 => 'Time' },
        Writable => 'undef',
        Count => 3,
        Shift => 'Time',
        ValueConv => 'length($val)>=3 ? sprintf("%.2d:%.2d:%.2d",unpack("C3",$val)) : "Unknown ($val)"',
        ValueConvInv => 'pack("C3",split(/:/,$val))',
    },
    0x0008 => {
        Name => 'Quality',
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
            8 => '2560x1920 or 2304x1728', #PH (Optio WP) or #14
            10 => '3264x2448', #13
            19 => '320x240', #PH (Optio WP)
            20 => '2288x1712', #13
            21 => '2592x1944',
            22 => '2304x1728 or 2592x1944', #2 or #14
            23 => '3056x2296', #13
            25 => '2816x2212 or 2816x2112', #13 or #14
            '0 0' => '2304x1728', #13
            '5 0' => '2048x1536', #13
            '8 0' => '2560x1920', #13
            '32 2' => '960x640', #7
            '33 2' => '1152x768', #7
            '34 2' => '1536x1024', #7
            '35 1' => '2400x1600', #7
            '36 0' => '3008x2008',  #PH
            '37 0' => '3008x2000', #13
        },
    },
    # 0x000a - (See note below)
    0x000b => { #3
        Name => 'PictureMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Program', #PH
            2 => 'Program AE', #13
            3 => 'Manual', #13
            5 => 'Portrait',
            6 => 'Landscape',
            8 => 'Sport', #PH
            9 => 'Night Scene',
            11 => 'Soft', #PH
            12 => 'Surf & Snow',
            13 => 'Sunset or Candlelight', #14 (Candlelight)
            14 => 'Autumn',
            15 => 'Macro',
            17 => 'Fireworks',
            18 => 'Text',
            19 => 'Panorama', #PH
            30 => 'Self Portrait', #PH
            31 => 'Illustrations', #13
            33 => 'Digital Filter', #13
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
            58 => 'Frame Composite', #14
            '0 0' => 'Auto', #13
            '0 2' => 'Program AE', #13
            '5 2' => 'Portrait', #13
            '6 2' => 'Landscape', #13
            '9 1' => 'Night Scene', #13
            '13 1' => 'Candlelight', #13
            '15 1' => 'Macro', #13
            '255 0' => 'Digital Filter?', #13
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
    0x000e => { #7
        Name => 'AFPointSelected',
        Writable => 'int16u',
        PrintConv => {
            0xffff => 'Auto',
            0xfffe => 'Fixed Center',
            1 => 'Upper-left',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Left',
            5 => 'Mid-left',
            6 => 'Center',
            7 => 'Mid-right',
            8 => 'Right',
            9 => 'Lower-left',
            10 => 'Bottom',
            11 => 'Lower-right',
        },
    },
    0x000f => { #PH
        Name => 'AutoAFPoint',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0xffff => 'None',
            0 => 'Multiple', #14
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
        Notes => 'related to focus distance but affected by focal length',
    },
    0x0012 => { #PH
        Name => 'ExposureTime',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val * 1e-5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x0013 => { #PH
        Name => 'FNumber',
        Writable => 'int16u',
        Priority => 0,
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    # ISO Tag - Entries confirmed by W. Smith 12 FEB 04
    0x0014 => {
        Name => 'ISO',
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
        ValueConv => '($val - 50) / 10',
        ValueConvInv => 'int($val * 10 + 50.5)',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    0x0017 => { #3
        Name => 'MeteringMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Multi Segment',
            1 => 'Center Weighted',
            2 => 'Spot',
        },
    },
    0x0018 => { #7/PH
        Name => 'ExposureBracketStep',
        Writable => 'int16',
        # don't apply conversion if this is 2 integers
        ValueConv => '$val=~/ / ? $val : $val / 3',
        ValueConvInv => '$val=~/ / ? $val : int($val * 3 + 0.5)',
        PrintConv => '$val=~/ / ? $val : sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0019 => { #3
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
            6 => 'DaylightFluorescent', #13
            7 => 'DaywhiteFluorescent', #13
            8 => 'WhiteFluorescent', #13
            9 => 'Flash', #13
            10 => 'Cloudy', #13
            65534 => 'Unknown', #13
            65535 => 'User Selected', #13
        },
    },
    0x001a => { #5
        Name => 'WhiteBalanceMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto (Daylight)',
            2 => 'Auto (Shade)',
            3 => 'Auto (Flash)',
            4 => 'Auto (Tungsten)',
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
    0x001d => [
        # Would be nice if there was a general way to determine units for FocalLength...
        {
            # Optio 30, 33WR, 43WR, 450, 550, 555, 750Z, X
            Name => 'FocalLength',
            Condition => '$self->{CameraModel} =~ /^PENTAX Optio (30|33WR|43WR|450|550|555|750Z|X)\b/',
            Writable => 'int32u',
            Priority => 0,
            ValueConv => '$val / 10',
            ValueConvInv => '$val * 10',
            PrintConv => 'sprintf("%.1fmm",$val)',
            PrintConvInv => '$val=~s/mm//;$val',
        },
        {
            # K100D, Optio 230, 330GS, 33L, 33LF, A10, M10, MX, MX4, S, S30,
            # S4, S4i, S5i, S5n, S5z, S6, S45, S50, S55, S60, SV, Svi, W10, WP,
            # *ist D, DL, DL2, DS, DS2
            # (Note: the Optio S6 seems to report the minimum focal length - PH)
            Name => 'FocalLength',
            Writable => 'int32u',
            Priority => 0,
            ValueConv => '$val / 100',
            ValueConvInv => '$val * 100',
            PrintConv => 'sprintf("%.1fmm",$val)',
            PrintConvInv => '$val=~s/mm//;$val',
        },
    ],
    0x001e => { #3
        Name => 'DigitalZoom',
        Writable => 'int16u',
        ValueConv => '$val / 100', #14
        ValueConvInv => '$val * 100', #14
    },
    0x001f => {
        Name => 'Saturation',
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
    # 0x002b - definitely exposure related somehow (PH)
    # 0x0032 - normally 4 zero bytes, but "\x02\0\0\0" for a cropped pic (PH)
    # and "\0\0\0\x04" for Digital filter (ref 13)
    # and "\x04\0\0\0" for Color filter (ref 13)
    0x0033 => { #PH (K110D/K100D)
        Name => 'PictureMode',
        Writable => 'int8u',
        Count => 3,
        PrintConv => {
            # Program dial modes
            '0 0 0'  => 'Program', # K110D
            '0 4 0'  => 'Standard', #13
            '0 5 0'  => 'Portrait', # K110D
            '0 6 0'  => 'Landscape', # K110D
            '0 7 0'  => 'Macro', # K110D
            '0 8 0'  => 'Sport', # K110D
            '0 9 0'  => 'Night Scene Portrait', # K110D
            '0 10 0' => 'No Flash', # K110D
            # SCN modes (menu-selected)
            '0 11 0' => 'Night Scene', # K100D
            '0 12 0' => 'Surf & Snow', # K100D
            '0 13 0' => 'Text', # K100D
            '0 14 0' => 'Sunset', # K100D
            '0 15 0' => 'Kids', # K100D
            '0 16 0' => 'Pet', # K100D
            '0 17 0' => 'Candlelight', # K100D
            '0 18 0' => 'Museum', # K100D
            # AUTO PICT modes (auto-selected)
            '1 4 0'  => 'Auto PICT (Standard)', #13
            '1 5 0'  => 'Auto PICT (Portrait)', #7 (K100D)
            '1 6 0'  => 'Auto PICT (Landscape)', # K110D
            '1 7 0'  => 'Auto PICT (Macro)', #13
            '1 8 0'  => 'Auto PICT (Sport)', #13
            # Manual dial modes
            '2 0 0'  => 'Program AE', #13
            '3 0 0'  => 'Green Mode', #16
            '4 0 0'  => 'Shutter Speed Priority', # K110D
            '5 0 0'  => 'Aperture Priority', # K110D
            '8 0 0'  => 'Manual', # K110D
            '9 0 0'  => 'Bulb', # K110D
            # *istD modes (ref 7)
            '2 0 1'  => 'Program AE', # 'User Program AE' according to ref 16
            '2 1 1'  => 'Hi-speed Program',
            '2 2 1'  => 'DOF Program',
            '2 3 1'  => 'MTF Program',
            '3 0 1'  => 'Green Mode',
            '4 0 1'  => 'Shutter Speed Priority',
            '5 0 1'  => 'Aperture Priority',
            '6 0 1'  => 'Program Tv Shift',
            '7 0 1'  => 'Program Av Shift',
            '8 0 1'  => 'Manual',
            '9 0 1'  => 'Bulb',
            '10 0 1' => 'Aperture Priority (Off-Auto-Aperture)',
            '11 0 1' => 'Manual (Off-Auto-Aperture)',
            '12 0 1' => 'Bulb (Off-Auto-Aperture)',
            # K10D modes (ref 16)
            '13 0 0' => 'Shutter & Aperture Priority AE',
            '13 0 1' => 'Shutter & Aperture Priority AE (1)', #PH guess
            '15 0 0' => 'Sensitivity Priority AE',
            '15 0 1' => 'Sensitivity Priority AE (1)',
            '16 0 0' => 'Flash X-Sync Speed AE',
            '16 0 1' => 'Flash X-Sync Speed AE (1)', #PH guess
        },
    },
    0x0034 => { #7/PH
        Name => 'DriveMode',
        Writable => 'int8u',
        Count => 4,
        PrintConv => {
            '0 0 0 0' => 'Single-frame',
            '1 0 0 0' => 'Continuous',
            '0 1 0 0' => 'Self-timer (12 sec)',
            '0 2 0 0' => 'Self-timer (2 sec)',
            '0 0 1 0' => 'Remote Control?', # needs validation
            '0 0 0 1' => 'Multiple Exposure',
        },
    },
    0x0037 => { #13
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
        },
    },
    0x0039 => { #PH
        Name => 'RawImageSize',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/ /x/;$_',
    },
    0x003c => { #7/PH
        Name => 'AFPointsUsed',
        # not writable because I'm not decoding these 4 bytes fully:
        # Nibble pattern: XSSSYUUU
        # X = unknown (AF focused flag?, 0 or 1)
        # SSS = selected AF point bitmask (0x000 or 0x7ff if unused)
        # Y = unknown (observed 0,6,7,b,e, always 0 if SSS is 0x000 or 0x7ff)
        # UUU = af points used
        Format => 'int32u',
        ValueConv => '$val & 0x7ff', # ignore other bits for now
        PrintConv => { BITMASK => {
            0 => 'Upper-left',
            1 => 'Top',
            2 => 'Upper-right',
            3 => 'Left',
            4 => 'Mid-left',
            5 => 'Center',
            6 => 'Mid-right',
            7 => 'Right',
            8 => 'Lower-left',
            9 => 'Bottom',
            10 => 'Lower-right',
        } },
    },
    0x003f => { #PH
        Name => 'LensType',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {  #4
            '1 0' => 'K,M Lens',
            '2 0' => 'A Series Lens', #7 (from smc PENTAX-A 400mm F5.6)
            '3 0' => 'SIGMA',
            '3 17' => 'smc PENTAX-FA SOFT 85mm F2.8',
            '3 18' => 'smc PENTAX-F 1.7X AF ADAPTER',
            '3 19' => 'smc PENTAX-F 24-50mm F4',
            '3 20' => 'smc PENTAX-F 35-80mm F4-5.6',
            '3 21' => 'smc PENTAX-F 80-200mm F4.7-5.6',
            '3 22' => 'smc PENTAX-F FISH-EYE 17-28mm F3.5-4.5',
            '3 23' => 'smc PENTAX-F 100-300mm F4.5-5.6',
            '3 24' => 'smc PENTAX-F 35-135mm F3.5-4.5',
            '3 25' => 'smc PENTAX-F 35-105mm F4-5.6 or SIGMA AF 28-300 F3.5-5.6 DL IF', #11 (sigma)
            # or '3 25' => 'Tokina 80-200mm F2.8 ATX-Pro', #12
            '3 26' => 'smc PENTAX-F* 250-600mm F5.6 ED[IF]',
            '3 27' => 'smc PENTAX-F 28-80mm F3.5-4.5',
            '3 28' => 'smc PENTAX-F 35-70mm F3.5-4.5',
            # or '3 28' => 'Tokina 19-35mm F3.5-4.5 AF', #12
            '3 29' => 'PENTAX-F 28-80mm F3.5-4.5 or SIGMA AF 18-125mm F3.5-5.6 DC', #11 (sigma)
            '3 30' => 'PENTAX-F 70-200mm F4-5.6',
            '3 31' => 'smc PENTAX-F 70-210mm F4-5.6',
            # or '3 31' => 'Tokina AF 730 75-300mm F4.5-5.6',
            '3 32' => 'smc PENTAX-F 50mm F1.4',
            '3 33' => 'smc PENTAX-F 50mm F1.7',
            '3 34' => 'smc PENTAX-F 135mm F2.8 [IF]',
            '3 35' => 'smc PENTAX-F 28mm F2.8',
            '3 36' => 'SIGMA 20mm F1.8 EX DG ASPHERICAL RF',
            '3 38' => 'smc PENTAX-F* 300mm F4.5 ED[IF]',
            '3 39' => 'smc PENTAX-F* 600mm F4 ED[IF]',
            '3 40' => 'smc PENTAX-F MACRO 100mm F2.8',
            '3 41' => 'smc PENTAX-F MACRO 50mm F2.8',
            '3 44' => 'SIGMA 18-50mm F3.5-5.6 DC, 12-24mm F4.5 EX DG or Tamron 35-90mm F4 AF', #4,12,12
            '3 46' => 'SIGMA APO 70-200mm F2.8 EX',
            '3 50' => 'smc PENTAX-FA 28-70mm F4 AL',
            '3 51' => 'SIGMA 28mm F1.8 EX DG ASPHERICAL MACRO',
            '3 52' => 'smc PENTAX-FA 28-200mm F3.8-5.6 AL[IF]',
            '3 53' => 'smc PENTAX-FA 28-80mm F3.5-5.6 AL',
            '3 247' => 'smc PENTAX-DA FISH-EYE 10-17mm F3.5-4.5 ED[IF]',
            '3 248' => 'smc PENTAX-DA 12-24mm F4 ED AL[IF]',
            '3 250' => 'smc PENTAX-DA 50-200mm F4-5.6 ED',
            '3 251' => 'smc PENTAX-DA 40mm F2.8 Limited',
            '3 252' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL',
            '3 253' => 'smc PENTAX-DA 14mm F2.8 ED[IF]',
            '3 254' => 'smc PENTAX-DA 16-45mm F4 ED AL',
            '3 255' => 'SIGMA',
            # '3 255' => 'SIGMA 18-200mm F3.5-6.3 DC', #8
            # '3 255' => 'SIGMA DL-II 35-80mm F4-5.6', #12
            # '3 255' => 'SIGMA DL Zoom 75-300mm F4-5.6', #12
            # '3 255' => 'SIGMA DF EX Aspherical 28-70mm F2.8', #12
            '4 1' => 'smc PENTAX-FA SOFT 28mm F2.8',
            '4 2' => 'smc PENTAX-FA 80-320mm F4.5-5.6',
            '4 3' => 'smc PENTAX-FA 43mm F1.9 Limited',
            '4 6' => 'smc PENTAX-FA 35-80mm F4-5.6',
            '4 15' => 'smc PENTAX-FA 28-105mm F4-5.6 [IF]',
            '4 16' => 'TAMRON AF 80-210mm F4-5.6 (178D)', #13
            '4 19' => 'TAMRON SP AF 90mm F2.8 (172E)',
            '4 20' => 'smc PENTAX-FA 28-80mm F3.5-5.6',
            '4 22' => 'TOKINA 28-80mm F3.5-5.6', #13
            '4 23' => 'smc PENTAX-FA 20-35mm F4 AL',
            '4 24' => 'smc PENTAX-FA 77mm F1.8 Limited',
            '4 25' => 'TAMRON SP AF 14mm F2.8', #13
            '4 26' => 'smc PENTAX-FA MACRO 100mm F3.5',
            '4 27' => 'TAMRON AF28-300mm F/3.5-6.3 LD Aspherical[IF]Macro (285D)',
            '4 28' => 'smc PENTAX-FA 35mm F2 AL',
            '4 34' => 'smc PENTAX-FA 24-90mm F3.5-4.5 AL[IF]',
            '4 35' => 'smc PENTAX-FA 100-300mm F4.7-5.8',
            '4 36' => 'TAMRON AF70-300mm F/4-5.6 LD MACRO (572D)',
            '4 37' => 'TAMRON SP AF 24-135mm F3.5-5.6 AD AL (190D)', #13
            '4 38' => 'smc PENTAX-FA 28-105mm F3.2-4.5 AL[IF]',
            '4 39' => 'smc PENTAX-FA 31mm F1.8AL Limited',
            '4 41' => 'TAMRON AF 28-200mm Super Zoom F3.8-5.6 Aspherical XR [IF] MACRO (A03)',
            '4 43' => 'smc PENTAX-FA 28-90mm F3.5-5.6',
            '4 44' => 'smc PENTAX-FA J 75-300mm F4.5-5.8 AL',
            '4 45' => 'TAMRON 28-300mm F3.5-6.3 Ultra zoom XR',
            '4 46' => 'smc PENTAX-FA J 28-80mm F3.5-5.6 AL',
            '4 47' => 'smc PENTAX-FA J 18-35mm F4-5.6 AL',
            '4 49' => 'TAMRON SP AF 28-75mm F2.8 XR Di (A09)',
            '4 51' => 'smc PENTAX-D FA 50mmF2.8 MACRO',
            '4 52' => 'smc PENTAX-D FA 100mmF2.8 MACRO',
            '4 244' => 'smc PENTAX-DA 21mm F3.2 AL Limited', #9
            '4 245' => 'Schneider D-XENON 50-200mm', #15
            '4 246' => 'Schneider D-XENON 18-55mm', #15
            '4 247' => 'smc PENTAX-DA 10-17mm F3.5-4.5 ED [IF] Fisheye zoom', #10
            '4 248' => 'smc PENTAX-DA 12-24mm F4 ED AL [IF]', #10
            '4 249' => 'TAMRON XR DiII 18-200mm F3.5-6.3 (A14)',
            '4 250' => 'smc PENTAX-DA 50-200mm F4-5.6 ED', #8
            '4 251' => 'smc PENTAX-DA 40mm F2.8 Limited', #9
            '4 252' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL', #8
            '4 253' => 'smc PENTAX-DA 14mm F2.8 ED[IF]',
            '4 254' => 'smc PENTAX-DA 16-45mm F4 ED AL',
            '5 1' => 'smc PENTAX-FA* 24mm F2 AL[IF]',
            '5 2' => 'smc PENTAX-FA 28mm F2.8 AL',
            '5 3' => 'smc PENTAX-FA 50mm F1.7',
            '5 4' => 'smc PENTAX-FA 50mm F1.4',
            '5 5' => 'smc PENTAX-FA* 600mm F4 ED[IF]',
            '5 6' => 'smc PENTAX-FA* 300mm F4.5 ED[IF]',
            '5 7' => 'smc PENTAX-FA 135mm F2.8 [IF]',
            '5 8' => 'smc PENTAX-FA MACRO 50mm F2.8',
            '5 9' => 'smc PENTAX-FA MACRO 100mm F2.8',
            '5 10' => 'smc PENTAX-FA* 85mm F1.4 [IF]',
            '5 11' => 'smc PENTAX-FA* 200mmF2.8 ED[IF]',
            '5 12' => 'smc PENTAX-FA 28-80mm F3.5-4.7',
            '5 13' => 'smc PENTAX-FA 70-200mm F4-5.6',
            '5 14' => 'smc PENTAX-FA* 250-600mm F5.6 ED[IF]',
            '5 15' => 'smc PENTAX-FA 28-105mm F4-5.6',
            '5 16' => 'smc PENTAX-FA 100-300mm F4.5-5.6',
            '6 1' => 'smc PENTAX-FA* 85mm F1.4[IF]',
            '6 2' => 'smc PENTAX-FA* 200mm F2.8 ED[IF]',
            '6 3' => 'smc PENTAX-FA* 300mm F2.8 ED[IF]',
            '6 4' => 'smc PENTAX-FA* 28-70mm F2.8 AL',
            '6 5' => 'smc PENTAX-FA* 80-200mm F2.8 ED[IF]',
            '6 6' => 'smc PENTAX-FA* 28-70mm F2.8 AL',
            '6 7' => 'smc PENTAX-FA* 80-200mm F2.8 ED[IF]',
            '6 8' => 'smc PENTAX-FA 28-70mm F4AL',
            '6 9' => 'smc PENTAX-FA 20mm F2.8',
            '6 10' => 'smc PENTAX-FA* 400mm F5.6 ED[IF]',
            '6 13' => 'smc PENTAX-FA* 400mm F5.6 ED[IF]',
            '6 14' => 'smc PENTAX-FA* MACRO 200mm F4 ED[IF]',
            '7 243' => 'smc PENTAX-DA 70mm F2.4 Limited', #PH (K10D)
            '7 244' => 'smc PENTAX-DA 16-45mm F4 ED AL', #PH (K10D)
        },
    },
    # 0x0041 - increments for each cropped pic (PH)
    # 0x0047 - increments every few pictures for unknown reason (PH)
    0x0049 => { #13
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    # 0x004f - PictureFinish ? (ref 13)
    0x0200 => { #5
        Name => 'BlackPoint',
        Writable => 'int16u',
        Count => 4,
    },
    0x0201 => { #5
        Name => 'WhitePoint',
        Writable => 'int16u',
        Count => 4,
    },
    # 0x0205 - Also stores PictureMode (PH)
    # 0x0207 - LensInformation ? (ref 13) - includes focus distance!
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
    0x1000 => { #PH
        Name => 'HometownCityCode',
        Writable => 'undef',
        Count => 4,
    },
    0x1001 => { #PH
        Name => 'DestinationCityCode',
        Writable => 'undef',
        Count => 4,
    },
    0x2000 => { #PH (Optio 330RS)
        Name => 'PreviewImageData',
        Binary => 1,
    },
);

# NOTE: These are from Image::MakerNotes::Pentax.pm, but they don't seem to work - PH
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

# tags in Pentax QuickTime videos (PH - tests with Optio WP)
# (note: very similar to information in Nikon videos)
%Image::ExifTool::Pentax::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is found in Pentax MOV video images.',
    0x00 => {
        Name => 'Make',
        Format => 'string[6]',
        PrintConv => 'ucfirst(lc($val))',
    },
    0x26 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x2a => {
        Name => 'FNumber',
        Format => 'int32u',
        ValueConv => '$val / 10',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x32 => {
        Name => 'ExposureCompensation',
        Format => 'int32s',
        ValueConv => '$val / 10',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x44 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
        },
    },
    0x48 => {
        Name => 'FocalLength',
        Writable => 'int32u',
        ValueConv => '$val / 10',
        PrintConv => 'sprintf("%.1fmm",$val)',
    },
    0xaf => {
        Name => 'ISO',
        Format => 'int16u',
    },
);


1; # end

__END__

=head1 NAME

Image::ExifTool::Pentax - Pentax/Asahi maker notes tags

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
require offsets, so this doesn't affect much useful information.  ExifTool
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
out some Pentax tags, and to Denis Bourez, Kazumichi Kawabata, David Buret
and Barney Garrett for adding to the LensType list.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Pentax Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::Info(3pm)|Image::Info>

=cut
