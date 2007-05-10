#------------------------------------------------------------------------------
# File:         Canon.pm
#
# Description:  Canon EXIF maker notes tags
#
# Revisions:    11/25/03 - P. Harvey Created
#               12/03/03 - P. Harvey Figured out lots more tags and added
#                            CanonPictureInfo
#               02/17/04 - Michael Rommel Added IxusAFPoint
#               01/27/05 - P. Harvey Disable validation of CanonPictureInfo
#               01/30/05 - P. Harvey Added a few more tags (ref 4)
#               02/10/06 - P. Harvey Decode a lot of new tags (ref 12)
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Michael Rommel private communication (Digital Ixus)
#               3) Daniel Pittman private communication (PowerShot S70)
#               4) http://www.wonderland.org/crw/
#               5) Juha Eskelinen private communication (20D)
#               6) Richard S. Smith private communication (20D)
#               7) Denny Priebe private communication (1D MkII)
#               8) Irwin Poche private communication
#               9) Michael Tiemann private communication (1D MkII)
#              10) Volker Gering private communication (1D MkII)
#              11) "cip" private communication
#              12) Rainer Honle private communication (5D)
#              13) http://www.cybercom.net/~dcoffin/dcraw/
#              14) (bozi) http://www.cpanforum.com/threads/2476 and /2563
#              15) http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm and
#                  http://homepage3.nifty.com/kamisaka/makernote/CanonLens.htm (2006/07/04)
#              16) Emil Sit private communication (30D)
#              17) http://www.asahi-net.or.jp/~xp8t-ymzk/s10exif.htm
#              18) Samson Tai private communication (G7)
#              19) Warren Stockton private communication
#              20) Bogdan private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Canon;

use strict;
use vars qw($VERSION %canonModelID);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

sub WriteCanon($$$);

$VERSION = '1.69';

my %canonLensTypes = ( #4
    1 => 'Canon EF 50mm f/1.8',
    2 => 'Canon EF 28mm f/2.8',
    3 => 'Canon EF 135mm f/2.8 Soft', #15
    4 => 'Sigma UC Zoom 35-135mm f/4-5.6',
    6 => 'Sigma 18-125mm F3.5-5.6 DC IF ASP or Tokina AF193-2 19-35mm f/3.5-4.5',
    7 => 'Canon EF 100-300mm F5.6L', #15
    # 10 can be 3 different Sigma lenses:
    # Sigma 50mm f/2.8 EX or Sigma 28mm f/1.8
    # or Sigma 105mm f/2.8 Macro EX (ref 15)
    10 => 'Canon EF 50mm f/2.5 Macro or Sigma', #10/4/15
    11 => 'Canon EF 35mm f/2', #9
    13 => 'Canon EF 15mm f/2.8', #9
    21 => 'Canon EF 80-200mm f/2.8L',
    22 => 'Tokina AT-X280AF PRO 28-80mm F2.8 ASPHERICAL', #15
    # 26 can also be 2 Tamron lenses: (ref 15)
    # Tamron SP AF 90mm f/2.8 Di Macro or Tamron SP AF 180mm F3.5 Di Macro
    26 => 'Canon EF 100mm f/2.8 Macro or Cosina 100mm f/3.5 Macro AF or Tamron',
    # 28 can be: (ref 15)
    # - Tamron SP AF 28-105mm f/2.8 LD Aspherical IF
    # - Tamron SP AF 28-75mm F/2.8 XR Di LD Aspherical [ IF ] Macro
    28 => 'Tamron AF Aspherical 28-200mm f/3.8-5.6 or 28-75mm f/2.8 or 28-105mm f/2.8',#4/11/14/15
    29 => 'Canon EF 50mm f/1.8 MkII',
    31 => 'Tamron SP AF 300mm f/2.8 LD IF', #15
    32 => 'Canon EF 24mm f/2.8 or Sigma 15mm f/2.8 EX Fisheye', #10/11
    39 => 'Canon EF 75-300mm f/4-5.6',
    40 => 'Canon EF 28-80mm f/3.5-5.6',
    43 => 'Canon EF 28-105mm f/4-5.6', #10
    45 => 'Canon EF-S 18-55mm f/3.5-5.6', #PH
    124 => 'Canon MP-E 65mm f/2.8 1-5x Macro Photo', #9
    125 => 'Canon TS-E 24mm f/3.5L',
    126 => 'Canon TS-E 45mm f/2.8', #15
    127 => 'Canon TS-E 90mm f/2.8', #15
    130 => 'Canon EF 50mm f/1.0L', #10/15
    131 => 'Sigma 17-35mm f2.8-4 EX Aspherical HSM',
    134 => 'Canon EF 600mm f/4L IS', #15
    135 => 'Canon EF 200mm f/1.8L',
    136 => 'Canon EF 300mm f/2.8L',
    137 => 'Canon EF 85mm f/1.2L', #10
    139 => 'Canon EF 400mm f/2.8L',
    141 => 'Canon EF 500mm f/4.5L',
    142 => 'Canon EF 300mm f/2.8L IS', #15
    143 => 'Canon EF 500mm f/4L IS', #15
    149 => 'Canon EF 100mm f/2', #9
    # 150 can be: (ref 15)
    # Sigma 20mm EX F1.8/Sigma 30mm F1.4 DC HSM/Sigma 24mm F1.8 DG Macro EX
    150 => 'Canon EF 14mm f/2.8L or Sigma 20mm EX f/1.8', #10/4
    151 => 'Canon EF 200mm f/2.8L',
    # 152 can be: (ref 15)
    # Sigma 12-24mm F4.5-5.6 EX DG ASPHERICAL HSM or Sigma 14mm F2.8 EX Aspherical HSM
    152 => 'Sigma 10-20mm F4-5.6 or 12-24mm f/4.5-5.6 or 14mm f/2.8', #14/15
    153 => 'Canon EF 35-350mm f/3.5-5.6L or Tamron AF 28-300mm or Sigma Bigma', #PH/15
    155 => 'Canon EF 85mm f/1.8 USM',
    156 => 'Canon EF 28-105mm f/3.5-4.5 USM',
    160 => 'Canon EF 20-35mm f/3.5-4.5 USM',
    161 => 'Canon EF 28-70mm f/2.8L or Sigma 24-70mm EX f/2.8 or Tamron 90mm f/2.8',
    165 => 'Canon EF 70-200mm f/2.8 L',
    166 => 'Canon EF 70-200mm f/2.8 L + x1.4',
    167 => 'Canon EF 70-200mm f/2.8 L + x2',
    168 => 'Canon EF 28mm f/1.8 USM', #15
    169 => 'Canon EF17-35mm f/2.8L or Sigma 15-30mm f/3.5-4.5 EX DG Aspherical', #15/4
    170 => 'Canon EF 200mm f/2.8L II', #9
    # the following value is used by 2 different Sigma lenses (ref 14):
    # Sigma 180mm EX HSM Macro f/3.5 or Sigma APO Macro 150mm F3.5 EX DG IF HSM
    # 173 => 'Canon EF 180mm Macro f/3.5L or Sigma 180mm EX HSM Macro f/3.5', #9
    173 => 'Canon EF 180mm Macro f/3.5L or Sigma 180mm F3.5 or 150mm f/2.8 Macro',
    174 => 'Canon EF 135mm f/2L', #9
    176 => 'Canon EF 24-85mm f/3.5-4.5 USM',
    177 => 'Canon EF 300mm f/4L IS', #9
    178 => 'Canon EF 28-135mm f/3.5-5.6 IS',
    180 => 'Canon EF 35mm f/1.4L', #9
    181 => 'Canon EF 100-400mm f/4.5-5.6L IS + x1.4', #15
    182 => 'Canon EF 100-400mm f/4.5-5.6L IS + x2',
    183 => 'Canon EF 100-400mm f/4.5-5.6L IS',
    184 => 'Canon EF 400mm f/2.8L + x2', #15
    186 => 'Canon EF 70-200mm f/4L', #9
    190 => 'Canon EF 100mm f/2.8 Macro',
    191 => 'Canon EF 400mm f/4 DO IS', #9
    # 196 Canon 75-300mm F4? #15
    197 => 'Canon EF 75-300mm f/4-5.6 IS',
    198 => 'Canon EF 50mm f/1.4 USM', #9
    202 => 'Canon EF 28-80 f/3.5-5.6 USM IV',
    211 => 'Canon EF 28-200mm f/3.5-5.6', #15
    213 => 'Canon EF 90-300mm f/4.5-5.6',
    214 => 'Canon EF-S 18-55mm f/3.5-4.5 USM', #PH
    224 => 'Canon EF 70-200mm f/2.8L IS USM', #11
    225 => 'Canon EF 70-200mm f/2.8L IS USM + x1.4', #11
    226 => 'Canon EF 70-200mm f/2.8L IS USM + x2', #14
    229 => 'Canon EF 16-35mm f/2.8L', #PH
    230 => 'Canon EF 24-70mm f/2.8L', #9
    231 => 'Canon EF 17-40mm f/4L',
    232 => 'Canon EF 70-300mm f/4.5-5.6 DO IS USM', #15
    234 => 'Canon EF-S 17-85mm f4-5.6 IS USM', #19
    235 => 'Canon EF-S10-22mm F3.5-4.5 USM', #15
    236 => 'Canon EF-S60mm F2.8 Macro USM', #15
    237 => 'Canon EF 24-105mm f/4L IS', #15
    238 => 'Canon EF 70-300mm F4-5.6 IS USM', #15
    241 => 'Canon EF 50mm F1.2L USM', #15
    242 => 'Canon EF 70-200mm f/4L IS USM', #PH
);

# Canon model ID numbers (PH)
%canonModelID = (
    0x1010000 => 'PowerShot A30',
    0x1040000 => 'PowerShot S300 / Digital IXUS 300 / IXY Digital 300',
    0x1060000 => 'PowerShot A20',
    0x1080000 => 'PowerShot A10',
    0x1090000 => 'PowerShot S110 / Digital IXUS v / IXY Digital 200',
    0x1100000 => 'PowerShot G2',
    0x1110000 => 'PowerShot S40',
    0x1120000 => 'PowerShot S30',
    0x1130000 => 'PowerShot A40',
    0x1140000 => 'EOS D30',
    0x1150000 => 'PowerShot A100',
    0x1160000 => 'PowerShot S200 / Digital IXUS v2 / IXY Digital 200a',
    0x1170000 => 'PowerShot A200',
    0x1180000 => 'PowerShot S330 / Digital IXUS 330 / IXY Digital 300a',
    0x1190000 => 'PowerShot G3',
    0x1210000 => 'PowerShot S45',
    0x1230000 => 'PowerShot SD100 / Digital IXUS II / IXY Digital 30',
    0x1240000 => 'PowerShot S230 / Digital IXUS v3 / IXY Digital 320',
    0x1250000 => 'PowerShot A70',
    0x1260000 => 'PowerShot A60',
    0x1270000 => 'PowerShot S400 / Digital IXUS 400 / IXY Digital 400',
    0x1290000 => 'PowerShot G5',
    0x1300000 => 'PowerShot A300',
    0x1310000 => 'PowerShot S50',
    0x1340000 => 'PowerShot A80',
    0x1350000 => 'PowerShot SD10 / Digital IXUS i / IXY Digital L',
    0x1360000 => 'PowerShot S1 IS',
    0x1370000 => 'PowerShot Pro1',
    0x1380000 => 'PowerShot S70',
    0x1390000 => 'PowerShot S60',
    0x1400000 => 'PowerShot G6',
    0x1410000 => 'PowerShot S500 / Digital IXUS 500 / IXY Digital 500',
    0x1420000 => 'PowerShot A75',
    0x1440000 => 'PowerShot SD110 / Digital IXUS IIs / IXY Digital 30a',
    0x1450000 => 'PowerShot A400',
    0x1470000 => 'PowerShot A310',
    0x1490000 => 'PowerShot A85',
    0x1520000 => 'PowerShot S410 / Digital IXUS 430 / IXY Digital 450',
    0x1530000 => 'PowerShot A95',
    0x1540000 => 'PowerShot SD300 / Digital IXUS 40 / IXY Digital 50',
    0x1550000 => 'PowerShot SD200 / Digital IXUS 30 / IXY Digital 40',
    0x1560000 => 'PowerShot A520',
    0x1570000 => 'PowerShot A510',
    0x1590000 => 'PowerShot SD20 / Digital IXUS i5 / IXY Digital L2',
    0x1640000 => 'PowerShot S2 IS',
    0x1650000 => 'PowerShot SD430 / IXUS Wireless / IXY Wireless',
    0x1660000 => 'PowerShot SD500 / Digital IXUS 700 / IXY Digital 600',
    0x1668000 => 'EOS D60',
    0x1700000 => 'PowerShot SD30 / Digital IXUS i zoom / IXY Digital L3',
    0x1740000 => 'PowerShot A430',
    0x1750000 => 'PowerShot A410',
    0x1760000 => 'PowerShot S80',
    0x1780000 => 'PowerShot A620',
    0x1790000 => 'PowerShot A610',
    0x1800000 => 'PowerShot SD630 / Digital IXUS 65 / IXY Digital 80',
    0x1810000 => 'PowerShot SD450 / Digital IXUS 55 / IXY Digital 60',
    0x1820000 => 'PowerShot TX1',
    0x1870000 => 'PowerShot SD400 / Digital IXUS 50 / IXY Digital 55',
    0x1880000 => 'PowerShot A420',
    0x1890000 => 'PowerShot SD900 / Digital IXUS 900 Ti / IXY Digital 1000',
    0x1900000 => 'PowerShot SD550 / Digital IXUS 750 / IXY Digital 700',
    0x1920000 => 'PowerShot A700',
    0x1940000 => 'PowerShot SD700 IS / Digital IXUS 800 IS / IXY Digital 800 IS',
    0x1950000 => 'PowerShot S3 IS',
    0x1960000 => 'PowerShot A540',
    0x1970000 => 'PowerShot SD600 / Digital IXUS 60 / IXY Digital 70',
    0x1980000 => 'PowerShot G7',
    0x1990000 => 'PowerShot A530',
    0x2000000 => 'PowerShot SD800 IS / Digital IXUS 850 IS / IXY Digital 900 IS',
    0x2010000 => 'PowerShot SD40 / Digital IXUS i7 / IXY Digital L4',
    0x2020000 => 'PowerShot A710 IS',
    0x2030000 => 'PowerShot A640',
    0x2040000 => 'PowerShot A630',
    0x2090000 => 'PowerShot S5 IS',
    0x2100000 => 'PowerShot A460',
    0x2120000 => 'PowerShot SD850 IS / Digital IXUS 950 IS', #IXY?
    0x2130000 => 'PowerShot A570 IS',
    0x2140000 => 'PowerShot A560',
    0x2150000 => 'PowerShot SD750 / Digital IXUS 75 / IXY Digital 90',
    0x2160000 => 'PowerShot SD1000 / Digital IXUS 70 / IXY Digital 10',
    0x2180000 => 'PowerShot A550',
    0x2190000 => 'PowerShot A450',
    0x3010000 => 'PowerShot Pro90 IS',
    0x4040000 => 'PowerShot G1',
    0x6040000 => 'PowerShot S100 / Digital IXUS / IXY Digital',
    0x4007d675 => 'HV10',
    0x4007d777 => 'iVIS DC50',
    0x4007d778 => 'iVIS HV20',
    0x80000001 => 'EOS-1D',
    0x80000167 => 'EOS-1DS',
    0x80000168 => 'EOS 10D',
    0x80000169 => 'EOS-1D Mark III',
    0x80000170 => 'EOS Digital Rebel / 300D / Kiss Digital',
    0x80000174 => 'EOS-1D Mark II',
    0x80000175 => 'EOS 20D',
    0x80000188 => 'EOS-1Ds Mark II',
    0x80000189 => 'EOS Digital Rebel XT / 350D / Kiss Digital N',
    0x80000213 => 'EOS 5D',
    0x80000232 => 'EOS-1D Mark II N',
    0x80000234 => 'EOS 30D',
    0x80000236 => 'EOS Digital Rebel XTi / 400D / Kiss Digital X',
);

my %canonQuality = (
    1 => 'Economy',
    2 => 'Normal',
    3 => 'Fine',
    4 => 'RAW',
    5 => 'Superfine',
);
my %canonImageSize = (
    0 => 'Large',
    1 => 'Medium',
    2 => 'Small',
    5 => 'Medium 1', #PH
    6 => 'Medium 2', #PH
    7 => 'Medium 3', #PH
    8 => 'Postcard', #PH (SD200 1600x1200 with DateStamp option)
    9 => 'Widescreen', #PH (SD900 3648x2048)
);
my %canonWhiteBalance = (
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    4 => 'Fluorescent',
    5 => 'Flash',
    6 => 'Custom',
    7 => 'Black & White',
    8 => 'Shade',
    9 => 'Manual Temperature (Kelvin)',
    10 => 'PC Set1', #PH
    11 => 'PC Set2', #PH
    12 => 'PC Set3', #PH
    14 => 'Daylight Fluorescent', #3
    15 => 'Custom 1', #PH
    16 => 'Custom 2', #PH
    17 => 'Underwater', #3
);

# picture styles used by the 5D
# (styles 0x4X may be downloaded from Canon)
my %pictureStyles = ( #12
    0x00 => 'None', #PH
    0x01 => 'Standard', #PH guess (1D)
    0x02 => 'Set 1', #PH guess (1D)
    0x03 => 'Set 2', #PH guess (1D)
    0x04 => 'Set 3', #PH guess (1D)
    0x21 => 'User Def. 1',
    0x22 => 'User Def. 2',
    0x23 => 'User Def. 3',
    # "External" styles currently available from Canon are Nostalgia, Clear,
    # Twilight and Emerald.  The "User Def" styles change to these "External"
    # codes when these styles are installed in the camera
    0x41 => 'External 1',
    0x42 => 'External 2',
    0x43 => 'External 3',
    0x81 => 'Standard',
    0x82 => 'Portrait',
    0x83 => 'Landscape',
    0x84 => 'Neutral',
    0x85 => 'Faithful',
    0x86 => 'Monochrome',
);
my %userDefStyles = ( #12
    0x41 => 'Nostalgia',
    0x42 => 'Clear',
    0x43 => 'Twilight',
    0x81 => 'Standard',
    0x82 => 'Portrait',
    0x83 => 'Landscape',
    0x84 => 'Neutral',
    0x85 => 'Faithful',
    0x86 => 'Monochrome',
);

# ValueConv that makes long values binary type
my %longBin = (
    ValueConv => 'length($val) > 64 ? \$val : $val',
    ValueConvInv => '$val',
);

#------------------------------------------------------------------------------
# Canon EXIF Maker Notes
%Image::ExifTool::Canon::Main = (
    WRITE_PROC => \&WriteCanon,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x1 => {
        Name => 'CanonCameraSettings',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::CameraSettings',
        },
    },
    0x2 => {
        Name => 'CanonFocalLength',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::FocalLength',
        },
    },
    0x3 => {
        Name => 'CanonFlashInfo',
        Unknown => 1,
    },
    0x4 => {
        Name => 'CanonShotInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ShotInfo',
        },
    },
    0x5 => {
        Name => 'CanonPanorama',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Panorama',
        },
    },
    0x6 => {
        Name => 'CanonImageType',
        Writable => 'string',
    },
    0x7 => {
        Name => 'CanonFirmwareVersion',
        Writable => 'string',
    },
    0x8 => {
        Name => 'FileNumber',
        Writable => 'int32u',
        PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
        PrintConvInv => '$val=~s/-//g;$val',
    },
    0x9 => {
        Name => 'OwnerName',
        Writable => 'string',
    },
    0xa => {
        Name => 'ColorInfoD30',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ColorInfoD30',
        },
    },
    0xc => [   # square brackets for a conditional list
        {
            # D30
            Name => 'SerialNumber',
            Description => 'Camera Body No.',
            Condition => '$self->{CameraModel} =~ /EOS D30\b/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%x-%.5d",$val>>16,$val&0xffff)',
            PrintConvInv => '$val=~/(.*)-(\d+)/ ? (hex($1)<<16)+$2 : undef',
        },
        {
            # serial number of 1D/1Ds/1D Mark II/1Ds Mark II is usually
            # displayed w/o leeding zeros (ref 7) (1D uses 6 digits - PH)
            Name => 'SerialNumber',
            Description => 'Camera Body No.',
            Condition => '$self->{CameraModel} =~ /EOS-1D/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.6d",$val)',
            PrintConvInv => '$val',
        },
        {
            # all other models (D60,300D,350D,REBEL,10D,20D,etc)
            Name => 'SerialNumber',
            Description => 'Camera Body No.',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.10d",$val)',
            PrintConvInv => '$val',
        },
    ],
    0xd => [
        {
            Name => 'CanonCameraInfo',
            Condition => '$self->{CameraModel} =~ /\b(1D(?! Mark III)|5D)/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo',
            },
        },
        {
            Name => 'CanonCameraInfo1DmkIII',
            Condition => '$self->{CameraModel} =~ /\b1D Mark III/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIII',
            },
        },
    ],
    0xe => {
        Name => 'CanonFileLength',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
    },
    0xf => [
        {   # used by 1DmkII, 1DsMkII and 1DmkIIN
            Name => 'CustomFunctions1D',
            Condition => '$self->{CameraModel} =~ /EOS-1D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
            },
        },
        {
            Name => 'CustomFunctions5D',
            Condition => '$self->{CameraModel} =~ /EOS 5D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions5D',
            },
        },
        {
            Name => 'CustomFunctions10D',
            Condition => '$self->{CameraModel} =~ /EOS 10D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions10D',
            },
        },
        {
            Name => 'CustomFunctions20D',
            Condition => '$self->{CameraModel} =~ /EOS 20D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions20D',
            },
        },
        {
            Name => 'CustomFunctions30D',
            Condition => '$self->{CameraModel} =~ /EOS 30D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions30D',
            },
        },
        {
            Name => 'CustomFunctions350D',
            Condition => '$self->{CameraModel} =~ /\b(350D|REBEL XT|Kiss Digital N)\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions350D',
            },
        },
        {
            Name => 'CustomFunctions400D',
            Condition => '$self->{CameraModel} =~ /\b(400D|REBEL XTi|Kiss Digital X|K236)\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions400D',
            },
        },
        {
            Name => 'CustomFunctionsD30',
            Condition => '$self->{CameraModel} =~ /EOS D30\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsD60',
            Condition => '$self->{CameraModel} =~ /EOS D60\b/',
            SubDirectory => {
                # the stored size in the D60 apparently doesn't include the size word:
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size-2,$size)',
                # (D60 custom functions are basically the same as D30)
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsUnknown',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FuncsUnknown',
            },
        },
    ],
    0x10 => { #PH
        Name => 'CanonModelID',
        Writable => 'int32u',
        PrintHex => 1,
        SeparateTable => 1,
        PrintConv => \%canonModelID,
    },
    0x12 => {
        Name => 'CanonPictureInfo',
        SubDirectory => {
            # the first word seems to be always 7, not the size as in other blocks,
            # I've also seen 53 in a 1DMkII raw file, and 9 in 20D.  So I have to
            # handle validation differently for this block
            Validate => 'Image::ExifTool::Canon::ValidatePictureInfo($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::PictureInfo',
        },
    },
    0x15 => { #PH
        # display format for serial number
        Name => 'SerialNumberFormat',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x90000000 => 'Format 1',
            0xa0000000 => 'Format 2',
        },
    },
    # 0x19 => 'InteropFooter', # what is this for?
    # 0x1d => 'MicaRa', ???? #15
    0x1e => { #PH
        Name => 'FirmwareRevision',
        Writable => 'int32u',
        # as a hex number: 0xAVVVRR00, where (a bit of guessing here...)
        #  A = 'a' for alpha, 'b' for beta?
        #  V = version? (100,101 for normal releases, 100,110,120,130,170 for alpha/beta)
        #  R = revision? (01-07, except 00 for alpha/beta releases)
        PrintConv => q{
            my $rev = sprintf("%.8x", $val);
            my ($rel, $v1, $v2, $r1, $r2) = ($rev =~ /^(.)(.)(..)0?(.+)(..)$/);
            my %r = ( a => 'Alpha ', b => 'Beta ', '0' => '' );
            $rel = defined $r{$rel} ? $r{$rel} : "Unknown($rel) ";
            return "$rel$v1.$v2 rev $r1.$r2",
        },
        PrintConvInv => q{
            $_=$val; s/Alpha ?/a/i; s/Beta ?/b/i;
            s/Unknown ?\((.)\)/$1/i; s/ ?rev ?(.)\./0$1/; s/ ?rev ?//;
            tr/a-fA-F0-9//dc; return hex $_;
        },
    },
    0x83 => { #PH
        Name => 'OriginalDecisionData',
        Writable => 'int32u',
    },
    0x90 => {   # used by 1D and 1Ds
        Name => 'CustomFunctions1D',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
        },
    },
    0x91 => { #PH
        Name => 'PersonalFunctions',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::PersonalFuncs',
        },
    },
    0x92 => { #PH
        Name => 'PersonalFunctionValues',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::PersonalFuncValues',
        },
    },
    0x93 => {
        Name => 'CanonFileInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FileInfo',
        },
    },
    0x94 => { #PH
        # AF points for 1D (45 points in 5 rows)
        Name => 'AFPointsUsed1D',
        Notes => '5 rows: A1-7, B1-10, C1-11, D1-10, E1-7, center point is C6',
        PrintConv => 'Image::ExifTool::Canon::PrintAFPoints1D($val)',
    },
    0x95 => { #PH (observed in 5D sample image)
        Name => 'LensType',
        Writable => 'string',
    },
    0x96 => { #PH
        Name => 'InternalSerialNumber',
        Writable => 'string',
    },
    0x97 => { #PH
        Name => 'DustRemovalData',
        # some interesting stuff is stored in here, like LensType and InternalSerialNumber...
        Binary => 1,
    },
    0x99 => { #PH (EOS 1D Mark III)
        Name => 'CustomFunctions1DmkIII',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions1DmkIII',
        },
    },
    0xa0 => {
        Name => 'ProccessingInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Processing',
        },
    },
    0xa1 => { Name => 'ToneCurveTable', %longBin }, #PH
    0xa2 => { Name => 'SharpnessTable', %longBin }, #PH
    0xa3 => { Name => 'SharpnessFreqTable', %longBin }, #PH
    0xa4 => { Name => 'WhiteBalanceTable', %longBin }, #PH
    0xa9 => {
        Name => 'ColorBalance',
        SubDirectory => {
            # this offset is necessary because the table is interpreted as short rationals
            # (4 bytes long) but the first entry is 2 bytes into the table.
            Start => '$valuePtr + 2',
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart-2,$size+2)',
            TagTable => 'Image::ExifTool::Canon::ColorBalance',
        },
    },
    # 0xaa - looks like maybe measured color balance (inverse of RGGBLevels)? - PH
    0xae => {
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0xb0 => { #PH
        Name => 'CanonFlags',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Flags',
        },
    },
    0xb1 => { #PH
        Name => 'ModifiedInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ModifiedInfo',
        },
    },
    0xb2 => { Name => 'ToneCurveMatching', %longBin }, #PH
    0xb3 => { Name => 'WhiteBalanceMatching', %longBin }, #PH
    0xb4 => { #PH
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
    0xb6 => {
        Name => 'PreviewImageInfo',
        SubDirectory => {
            # Note: first word if this block is the total number of words, not bytes!
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size/2)',
            TagTable => 'Image::ExifTool::Canon::PreviewImageInfo',
        },
    },
    0xe0 => { #12
        Name => 'SensorInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::SensorInfo',
        },
    },
    0x4001 => [ #13
        {   # (int16u[582])
            Condition => '$self->{CameraModel} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Name => 'ColorBalance1',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorBalance1',
            },
        },
        {   # (int16u[653])
            Condition => '$self->{CameraModel} =~ /EOS-1Ds? Mark II$/',
            Name => 'ColorBalance2',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorBalance2',
            },
        },
        {   # (int16u[796])
            Condition => '$self->{CameraModel} =~ /\b(1D Mark II N|5D|30D|400D|REBEL XTi|Kiss Digital X|K236)\b/',
            Name => 'ColorBalance3',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorBalance3',
            },
        },
        {
            Name => 'ColorBalanceUnknown',
            %longBin,
        },
    ],
    0x4002 => { #PH
        # unknown data block in some JPEG and CR2 images
        # (5kB for most models, but 22kb for 5D and 30D)
        Name => 'UnknownBlock1',
        Format => 'undef',
        Flags => [ 'Unknown', 'Binary' ],
    },
    0x4003 => { #PH
        Name => 'ColorInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::ColorInfo',
        },
    },
    0x4005 => { #PH
        Name => 'UnknownBlock2',
        Notes => 'unknown 49kB block, not copied to JPEG images',
        # 'Drop' because not found in JPEG images (too large for APP1 anyway)
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x4008 => { #PH guess (1DmkIII)
        Name => 'BlackLevel',
        Unknown => 1,
    },
);

#..............................................................................
# Canon camera settings (MakerNotes tag 0x01)
# BinaryData (keys are indices into the int16s array)
%Image::ExifTool::Canon::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    DATAMEMBER => [ 25 ],   # FocalUnits necessary writing
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'MacroMode',
        PrintConv => {
            1 => 'Macro',
            2 => 'Normal',
        },
    },
    2 => {
        Name => 'Self-timer',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    3 => {
        Name => 'Quality',
        PrintConv => \%canonQuality,
    },
    4 => {
        Name => 'CanonFlashMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
            3 => 'Red-eye reduction',
            4 => 'Slow-sync',
            5 => 'Red-eye reduction (Auto)',
            6 => 'Red-eye reduction (On)',
            16 => 'External flash', # not set in D30 or 300D
        },
    },
    5 => {
        Name => 'ContinuousDrive',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            2 => 'Movie', #PH
            3 => 'Continuous, Speed Priority', #PH
            4 => 'Continuous, Low', #PH
            5 => 'Continuous, High', #PH
        },
    },
    7 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'One-shot AF',
            1 => 'AI Servo AF',
            2 => 'AI Focus AF',
            3 => 'Manual Focus',
            4 => 'Single',
            5 => 'Continuous',
            6 => 'Manual Focus',
           16 => 'Pan Focus', #PH
        },
    },
    9 => { #PH
        Name => 'RecordMode',
        PrintConv => {
            1 => 'JPEG',
            2 => 'CRW+THM', # (300D,etc)
            3 => 'AVI+THM', # (30D)
            4 => 'TIF', # +THM? (1Ds) (unconfirmed)
            5 => 'TIF+JPEG', # (1D) (unconfirmed)
            6 => 'CR2', # +THM? (1D,30D,350D)
            7 => 'CR2+JPEG', # (S30)
        },
    },
    10 => {
        Name => 'CanonImageSize',
        PrintConv => \%canonImageSize,
    },
    11 => {
        Name => 'EasyMode',
        PrintConv => {
            0 => 'Full auto',
            1 => 'Manual',
            2 => 'Landscape',
            3 => 'Fast shutter',
            4 => 'Slow shutter',
            5 => 'Night',
            6 => 'Gray Scale', #PH
            7 => 'Sepia',
            8 => 'Portrait',
            9 => 'Sports',
            10 => 'Macro',
            11 => 'Black & White', #PH
            12 => 'Pan focus',
            13 => 'Vivid', #PH
            14 => 'Neutral', #PH
            15 => 'Flash Off',  #8
            16 => 'Long Shutter', #PH
            17 => 'Super Macro', #PH
            18 => 'Foliage', #PH
            19 => 'Indoor', #PH
            20 => 'Fireworks', #PH
            21 => 'Beach', #PH
            22 => 'Underwater', #PH
            23 => 'Snow', #PH
            24 => 'Kids & Pets', #PH
            25 => 'Night Snapshot', #PH
            26 => 'Digital Macro', #PH
            27 => 'My Colors', #PH
            28 => 'Still Image', #15 (animation frame?)
            30 => 'Color Accent', #18
            31 => 'Color Swap', #18
            32 => 'Aquarium', #18
            33 => 'ISO 3200', #18
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'None',
            1 => '2x',
            2 => '4x',
            3 => 'Other',  # value obtained from 2*#37/#36
        },
    },
    13 => {
        Name => 'Contrast',
        RawConv => '$val == 0x7fff ? undef : $val',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    14 => {
        Name => 'Saturation',
        RawConv => '$val == 0x7fff ? undef : $val',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    15 => {
        Name => 'Sharpness',
        RawConv => '$val == 0x7fff ? undef : $val',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    16 => {
        Name => 'CameraISO',
        RawConv => '$val != 0x7fff ? $val : undef',
        ValueConv => 'Image::ExifTool::Canon::CameraISO($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CameraISO($val,1)',
    },
    17 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Default', # older Ixus
            1 => 'Spot',
            2 => 'Average', #PH
            3 => 'Evaluative',
            4 => 'Partial',
            5 => 'Center-weighted averaging',
        },
    },
    18 => {
        # this is always 2 for the 300D - PH
        Name => 'FocusRange',
        PrintConv => {
            0 => 'Manual',
            1 => 'Auto',
            2 => 'Not Known',
            3 => 'Macro',
            4 => 'Very Close', #PH
            5 => 'Close', #PH
            6 => 'Middle Range', #PH
            7 => 'Far Range',
            8 => 'Pan Focus',
            9 => 'Super Macro', #PH
            10=> 'Infinity', #PH
        },
    },
    19 => {
        Name => 'AFPoint',
        Flags => 'PrintHex',
        RawConv => '$val==0 ? undef : $val',
        PrintConv => {
            0x2005 => 'Manual AF point selection',
            0x3000 => 'None (MF)',
            0x3001 => 'Auto AF point selection',
            0x3002 => 'Right',
            0x3003 => 'Center',
            0x3004 => 'Left',
            0x4001 => 'Auto AF point selection',
            0x4002 => 'Top', #PH guess (A560/A570IS)
            0x4003 => 'Upper-left', #PH guess (A560/A570IS)
            0x4004 => 'Upper-right', #PH guess (A560/A570IS)
            0x4005 => 'Left', #PH guess (A560/A570IS)
            0x4006 => 'Center', #PH guess (A560/A570IS)
            0x4007 => 'Right', #PH guess (A560/A570IS)
            0x4008 => 'Lower-left', #PH guess (A560/A570IS)
            0x4009 => 'Lower-right', #PH guess (A560/A570IS)
            0x400a => 'Bottom', #PH guess (A560/A570IS)
        },
    },
    20 => {
        Name => 'CanonExposureMode',
        PrintConv => {
            0 => 'Easy',
            1 => 'Program AE',
            2 => 'Shutter speed priority AE',
            3 => 'Aperture-priority AE',
            4 => 'Manual',
            5 => 'Depth-of-field AE',
            6 => 'M-Dep', #PH
        },
    },
    22 => { #4
        Name => 'LensType',
        RawConv => '$val ? $val : undef', # don't use if value is zero
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    23 => {
        Name => 'LongFocal',
        Format => 'int16u',
        # this is a bit tricky, but we need the FocalUnits to convert this to mm
        RawConvInv => '$val * ($$self{FocalUnits} || 1)',
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    24 => {
        Name => 'ShortFocal',
        Format => 'int16u',
        RawConvInv => '$val * ($$self{FocalUnits} || 1)',
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    25 => {
        Name => 'FocalUnits',
        DataMember => 'FocalUnits',
        RawConv => '$$self{FocalUnits} = $val',
    },
    26 => { #9
        Name => 'MaxAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    27 => { #PH
        Name => 'MinAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    28 => {
        Name => 'FlashActivity',
        RawConv => '$val==-1 ? undef : $val',
    },
    29 => {
        Name => 'FlashBits',
        PrintConv => { BITMASK => {
            0 => 'Manual', #PH
            1 => 'TTL', #PH
            2 => 'A-TTL', #PH
            3 => 'E-TTL', #PH
            4 => 'FP sync enabled',
            7 => '2nd-curtain sync used',
            11 => 'FP sync used',
            13 => 'Built-in',
            14 => 'External',
        } },
    },
    32 => {
        Name => 'FocusContinuous',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
        },
    },
    33 => { #PH
        Name => 'AESetting',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Normal AE',
            1 => 'Exposure Compensation',
            2 => 'AE Lock',
            3 => 'AE Lock + Exposure Comp.',
            4 => 'No AE',
        },
    },
    34 => { #PH
        Name => 'ImageStabilization',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On, Shot Only', #15
        },
    },
    35 => { #PH
        Name => 'DisplayAperture',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    36 => 'ZoomSourceWidth', #PH
    37 => 'ZoomTargetWidth', #PH
    40 => { #PH
        Name => 'PhotoEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'Vivid',
            2 => 'Neutral',
            3 => 'Smooth',
            4 => 'Sepia',
            5 => 'B&W',
            6 => 'Custom',
            100 => 'My Color Data',
        },
    },
    42 => {
        Name => 'ColorTone',
        RawConv => '$val == 0x7fff ? undef : $val',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
);

# focal length information (MakerNotes tag 0x02)
%Image::ExifTool::Canon::FocalLength = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => { #9
        Name => 'FocalType',
        RawConv => '$val ? $val : undef', # don't use if value is zero
	    PrintConv => {
            1 => 'Fixed',
            2 => 'Zoom',
        },
    },
    1 => {
        Name => 'FocalLength',
        # the EXIF FocalLength is more reliable, so set this priority to zero
        Priority => 0,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        RawConvInv => q{
            my $focalUnits = $$self{FocalUnits};
            unless ($focalUnits) {
                $focalUnits = 1;
                # (this happens when writing FocalLength to CRW images)
                $self->Warn("FocalUnits not available for FocalLength conversion (1 assumed)");
            }
            return $val * $focalUnits;
        },
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    2 => { #4
        Name => 'FocalPlaneXSize',
        Notes => 'not valid for 1DmkIII',
        Condition => '$$self{CameraModel} !~ /1D Mark III/',
        # focal plane image dimensions in 1/1000 inch -- convert to mm
        RawConv => '$val < 40 ? undef : $val',  # must be reasonable
        ValueConv => '$val * 25.4 / 1000',
        ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
        PrintConv => 'sprintf("%.2fmm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    3 => {
        Name => 'FocalPlaneYSize',
        Notes => 'not valid for 1DmkIII',
        Condition => '$$self{CameraModel} !~ /1D Mark III/',
        RawConv => '$val < 40 ? undef : $val',  # must be reasonable
        ValueConv => '$val * 25.4 / 1000',
        ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
        PrintConv => 'sprintf("%.2fmm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
);

# Canon shot information (MakerNotes tag 0x04)
# BinaryData (keys are indices into the int16s array)
%Image::ExifTool::Canon::ShotInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'AutoISO',
        Notes => 'actual ISO used = BaseISO * AutoISO / 100',
        ValueConv => 'exp($val/32*log(2))*100',
        ValueConvInv => '32*log($val/100)/log(2)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    2 => {
        Name => 'BaseISO',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        ValueConv => 'exp($val/32*log(2))*100/32',
        ValueConvInv => '32*log($val*32/100)/log(2)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    3 => { #9/PH
        Name => 'MeasuredEV',
        Notes => q{
            this the Canon name for what should properly be called MeasuredLV, and is
            offset by about -5 EV from the calculated LV for most models
        },
        ValueConv => '$val / 32',
        ValueConvInv => '$val * 32',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    4 => { #2, 9
        Name => 'TargetAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    5 => { #2
        Name => 'TargetExposureTime',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    6 => {
        Name => 'ExposureCompensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    7 => {
        Name => 'WhiteBalance',
        PrintConv => \%canonWhiteBalance,
    },
    8 => { #PH
        Name => 'SlowShutter',
        PrintConv => {
            0 => 'Off',
            1 => 'Night Scene',
            2 => 'On',
            3 => 'None',
        },
    },
    9 => {
        Name => 'SequenceNumber',
        Description => 'Shot Number In Continuous Burst',
    },
    10 => { #PH/17
        Name => 'OpticalZoomCode',
        Groups => { 2 => 'Camera' },
        Notes => 'for many PowerShot models, a this is 0-6 for wide-tele zoom',
        # (for many models, 0-6 represent 0-100% zoom, but it is always 8 for
        #  EOS models, and I have seen values of 16,20,28,32 and 39 too...)
    },
    # 11 - (8 for all EOS samples, [0,8] for other models - PH)
    13 => { #PH
        Name => 'FlashGuideNumber',
        RawConv => '$val == -1 ? undef : $val',
        ValueConv => '$val / 32',
        ValueConvInv => '$val * 32',
    },
    # AF points for Ixus and IxusV cameras - 02/17/04 M. Rommel (also D30/D60 - PH)
    14 => { #2
        Name => 'AFPointsUsed2',
        Notes => 'used by D30, D60 and some PowerShot/Ixus models',
        Groups => { 2 => 'Camera' },
        Flags => 'PrintHex',
        RawConv => '$val==0 ? undef : $val',
        PrintConv => {
            0x3000 => 'None (MF)',
            0x3001 => 'Right',
            0x3002 => 'Center',
            0x3003 => 'Center+Right',
            0x3004 => 'Left',
            0x3005 => 'Left+Right',
            0x3006 => 'Left+Center',
            0x3007 => 'All',
        },
    },
    15 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    16 => {
        Name => 'AutoExposureBracketing',
        PrintConv => {
            -1 => 'On',
            0 => 'Off',
            1 => 'On (shot 1)',
            2 => 'On (shot 2)',
            3 => 'On (shot 3)',
        },
    },
    17 => {
        Name => 'AEBBracketValue',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    19 => {
        Name => 'FocusDistanceUpper',
        ValueConv => '$val * 0.01',
        ValueConvInv => '$val / 0.01',
    },
    20 => {
        Name => 'FocusDistanceLower',
        ValueConv => '$val * 0.01',
        ValueConvInv => '$val / 0.01',
    },
    21 => {
        Name => 'FNumber',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        # approximate big translation table by simple calculation - PH
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    22 => [
        {
            Name => 'ExposureTime',
            # encoding is different for 20D and 350D (darn!)
            # (but note that encoding is the same for TargetExposureTime - PH)
            Condition => '$self->{CameraModel} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Priority => 0,
            RawConv => '$val ? $val : undef',
            # approximate big translation table by simple calculation - PH
            ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))*1000/32',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*32/1000)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'eval $val',
        },
        {
            Name => 'ExposureTime',
            Priority => 0,
            RawConv => '$val ? $val : undef',
            # approximate big translation table by simple calculation - PH
            ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'eval $val',
        },
    ],
    24 => {
        Name => 'BulbDuration',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    # 25 - (usually 0, but 1 for 2s timer?, 19 for small AVI, 14 for large
    #       AVI, and -6 and -10 for shots 1 and 2 with stitch assist - PH)
    26 => { #15
        Name => 'CameraType',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            248 => 'EOS High-end',
            250 => 'Compact',
            252 => 'EOS Mid-range',
            255 => 'DV Camera', #PH
        },
    },
    27 => {
        Name => 'AutoRotate',
        PrintConv => {
           -1 => 'Rotated by Software',
            0 => 'None',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 180',
            3 => 'Rotate 270 CW',
        },
    },
    28 => { #15
        Name => 'NDFilter',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    29 => {
        Name => 'Self-timer2',
        RawConv => '$val >= 0 ? $val : undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
);

# Canon camera information for 1DmkIII (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfo1DmkIII = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x04 => { #9
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        Format => 'int8u',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        ValueConv => 'exp(4*log(2)*(1-Image::ExifTool::Canon::CanonEv($val-24)))',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(1-log($val)/(4*log(2)))+24',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
);

# Canon camera information (MakerNotes tag 0x0d)
# (ref 12 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Used by the 1D, 1DS, 1DmkII, 1DSmkII and 5D.',
    0x04 => { #9
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        Format => 'int8u',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        ValueConv => 'exp(4*log(2)*(1-Image::ExifTool::Canon::CanonEv($val-24)))',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(1-log($val)/(4*log(2)))+24',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x0a => { #9
        Name => 'FocalLength',
        Condition => '$self->{CameraModel} !~ /EOS 5D/', #PH
        Format => 'int8u',
        # the EXIF FocalLength is more reliable, so set this priority to zero
        Priority => 0,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    0x0d => { #9
        Name => 'LensType',
        Format => 'int8u',
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => \%canonLensTypes,
    },
    0x12 => { #9
        Name => 'ShortFocal',
        Format => 'int8u',
        Condition => '$self->{CameraModel} =~ /\b(1D|5D)/',
        Notes => '1D and 5D only',
        # the EXIF ShortFocal is more reliable, so set this priority to zero
        Priority => 0,
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    0x14 => { #9
        Name => 'LongFocal',
        Format => 'int8u',
        Condition => '$self->{CameraModel} =~ /\b(1D|5D)/',
        Notes => '1D and 5D only',
        # the EXIF LongFocal is more reliable, so set this priority to zero
        Priority => 0,
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    0x2d => { #9
        Name => 'FocalType',
        Format => 'int8u',
        Condition => '$self->{CameraModel} =~ /EOS-1Ds? Mark II/',
        Notes => '1DmkII and 1DSmkII only',
        Priority => 0,
        PrintConv => {
           0 => 'Fixed',
           2 => 'Zoom',
        },
    },
    0x38 => {
        Name => 'AFPointsUsed5D',
        Format => 'undef[2]',
        Condition => '$self->{CameraModel} =~ /EOS 5D/',
        Notes => 'bit definitions are for big-endian int16u',
        ValueConv => 'unpack("n",$val)',
        ValueConvInv => 'pack("n",$val)',
        PrintConv => { BITMASK => {
            0 => 'Center',
            1 => 'Top',
            2 => 'Bottom',
            3 => 'Upper-left',
            4 => 'Upper-right',
            5 => 'Lower-left',
            6 => 'Lower-right',
            7 => 'Left',
            8 => 'Right',
            9 => 'AI Servo1',
           10 => 'AI Servo2',
           11 => 'AI Servo3',
           12 => 'AI Servo4',
           13 => 'AI Servo5',
           14 => 'AI Servo6',
        } },
    },
    0x6c => {
        Name => 'PictureStyle',
        Format => 'int16u',
        Condition => '$self->{CameraModel} =~ /EOS(-1Ds? Mark II| 5D)$/',
        Notes => '1DmkII, 1DSmkII and 5D only',
        PrintHex => 1,
        PrintConv => \%pictureStyles,
    },
    0xa4 => { #PH (5D)
        Name => 'FirmwareRevision',
        Condition => '$self->{CameraModel} =~ /EOS 5D/',
        Notes => '5D only',
        Format => 'string[8]',
    },
    0xac => { #PH (5D)
        Name => 'ShortOwnerName',
        Format => 'string[16]',
        Condition => '$self->{CameraModel} =~ /EOS 5D/',
        Notes => '5D only',
    },
    0xd0 => {
        Name => 'ImageNumber',
        Groups => { 2 => 'Image' },
        Format => 'int16u',
        Condition => '$self->{CameraModel} =~ /EOS 5D/',
        Notes => '5D only',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0xe8 => {
        Name => 'ContrastStandard',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xe9 => {
        Name => 'ContrastPortrait',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xea => {
        Name => 'ContrastLandscape',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xeb => {
        Name => 'ContrastNeutral',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xec => {
        Name => 'ContrastFaithful',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xed => {
        Name => 'ContrastMonochrome',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xee => {
        Name => 'ContrastUserDef1',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xef => {
        Name => 'ContrastUserDef2',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xf0 => {
        Name => 'ContrastUserDef3',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    # sharpness values are 0-7
    0xf1 => 'SharpnessStandard',
    0xf2 => 'SharpnessPortrait',
    0xf3 => 'SharpnessLandscape',
    0xf4 => 'SharpnessNeutral',
    0xf5 => 'SharpnessFaithful',
    0xf6 => 'SharpnessMonochrome',
    0xf7 => 'SharpnessUserDef1',
    0xf8 => 'SharpnessUserDef2',
    0xf9 => 'SharpnessUserDef3',
    0xfa => 'SaturationStandard',
    0xfb => 'SaturationPortrait',
    0xfc => 'SaturationLandscape',
    0xfd => 'SaturationNeutral',
    0xfe => 'SaturationFaithful',
    0xff => {
        Name => 'FilterEffectMonochrome',
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
        },
    },
    0x100 => 'SaturationUserDef1',
    0x101 => 'SaturationUserDef2',
    0x102 => 'SaturationUserDef3',
    0x103 => 'ColorToneStandard',
    0x104 => 'ColorTonePortrait',
    0x105 => 'ColorToneLandscape',
    0x106 => 'ColorToneNeutral',
    0x107 => 'ColorToneFaithful',
    0x108 => {
        Name => 'ToningEffectMonochrome',
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
        },
    },
    0x109 => 'ColorToneUserDef1',
    0x10a => 'ColorToneUserDef2',
    0x10b => 'ColorToneUserDef3',
    0x10c => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => \%userDefStyles,
    },
    0x10e => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => \%userDefStyles,
    },
    0x110 => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => \%userDefStyles,
    },
    0x11c => {
        Name => 'TimeStamp',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$val',
    },
);

# Canon panorama information (MakerNotes tag 0x05)
%Image::ExifTool::Canon::Panorama = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    2 => 'PanoramaFrame',
    5 => {
        Name => 'PanoramaDirection',
        PrintConv => {
            0 => 'Left to Right',
            1 => 'Right to Left',
            2 => 'Bottom to Top',
            3 => 'Top to Bottom',
            4 => '2x2 Matrix (Clockwise)',
        },
     },
);

# picture information (MakerNotes tag 0x12)
%Image::ExifTool::Canon::PictureInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    DATAMEMBER => [ 1 ], # necessary to save NumAFPoints when writing
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'NumAFPoints',
        Groups => { 2 => 'Camera' },
        DataMember => 'NumAFPoints',
        RawConv => '$self->{NumAFPoints} = $val',
    },
    2 => 'CanonImageWidth',
    3 => 'CanonImageHeight',
    4 => 'CanonImageWidthAsShot',
    5 => 'CanonImageHeightAsShot',
    22 => [ #PH (300D)
        {
            Name => 'AFPointsUsed',
            Groups => { 2 => 'Camera' },
            # (older cameras with 7 AF points)
            Condition => q{
                $self->{NumAFPoints} == 7 and
                $self->{CameraModel} !~ /\b(350D|REBEL XT|Kiss Digital N)\b/
            },
            Notes => '10D and 300D',
            RawConv => '($val & 0xff00) == 0xff00 ? undef : $val',
            PrintConv => { BITMASK => {
                0 => 'Right',
                1 => 'Mid-right',
                2 => 'Bottom',
                3 => 'Center',
                4 => 'Top',
                5 => 'Mid-left',
                6 => 'Left',
            } },
        },
        { #20 (350D)
            Name => 'AFPointsUsed',
            Groups => { 2 => 'Camera' },
            # (newer cameras with 7 AF points)
            Condition => '$self->{NumAFPoints} == 7',
            Notes => '350D',
            RawConv => '($val & 0xff00) == 0xff00 ? undef : $val',
            PrintConv => { BITMASK => {
                0 => 'Bottom',
                1 => 'Left',
                2 => 'Mid-left',
                3 => 'Center',
                4 => 'Mid-right',
                5 => 'Right',
                6 => 'Top',
            } },
        },
    ],
    26 => { #12 (20D)
        Name => 'AFPointsUsed',
        Groups => { 2 => 'Camera' },
        # (cameras with 9 AF points)
        Condition => '$self->{NumAFPoints} == 9',
        Notes => '20D, 30D and 400D',
        PrintConv => { BITMASK => {
            0 => 'Top',
            1 => 'Upper-left',
            2 => 'Upper-right',
            3 => 'Left',
            4 => 'Center',
            5 => 'Right',
            6 => 'Lower-left',
            7 => 'Lower-right',
            8 => 'Bottom',
        } },
    },
);


# Preview image information (MakerNotes tag 0xb6)
# - The 300D writes a 1536x1024 preview image that is accessed
#   through this information - decoded by PH 12/14/03
%Image::ExifTool::Canon::PreviewImageInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 1,
    IS_OFFSET => [ 5 ],   # tag 5 is 'IsOffset'
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
# the size of the preview block in 2-byte increments
#    0 => {
#        Name => 'PreviewImageInfoWords',
#    },
    1 => {
        Name => 'PreviewQuality',
        PrintConv => \%canonQuality,
    },
    2 => {
        Name => 'PreviewImageLength',
        OffsetPair => 5,   # point to associated offset
        DataTag => 'PreviewImage',
        Protected => 2,
    },
    3 => 'PreviewImageWidth',
    4 => 'PreviewImageHeight',
    5 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 2,  # associated byte count tagID
        DataTag => 'PreviewImage',
        Protected => 2,
    },
    6 => {
        Name => 'PreviewFocalPlaneXResolution',
        Format => 'rational64s',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    8 => {
        Name => 'PreviewFocalPlaneYResolution',
        Format => 'rational64s',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
# the following 2 values look like they are really 4 shorts
# taking the values of 1,4,4 and 2 respectively - don't know what they are though
#    10 => {
#        Name => 'PreviewImageUnknown1',
#        PrintConv => 'sprintf("0x%x",$val)',
#    },
#    11 => {
#        Name => 'PreviewImageUnknown2',
#        PrintConv => 'sprintf("0x%x",$val)',
#    },
);

# Sensor information (MakerNotes tag 0xe0) (ref 12)
%Image::ExifTool::Canon::SensorInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # Note: Don't make these writable because it confuses Canon decoding software
    # if these are changed
    1 => 'SensorWidth',
    2 => 'SensorHeight',
    5 => 'SensorLeftBorder', #2
    6 => 'SensorTopBorder', #2
    7 => 'SensorRightBorder', #2
    8 => 'SensorBottomBorder', #2
);

# File number information (MakerNotes tag 0x93)
%Image::ExifTool::Canon::FileInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => [
        { #5
            Name => 'FileNumber',
            Condition => '$self->{CameraModel} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Format => 'int32u',
            # Thanks to Juha Eskelinen for figuring this out:
            # [this is an odd bit mapping -- it looks like the file number exists as
            # a 16-bit integer containing the high bits, followed by an 8-bit integer
            # with the low bits.  But it is more convenient to have this in a single
            # word, so some bit manipulations are necessary... - PH]
            # The bit pattern of the 32-bit word is:
            #   31....24 23....16 15.....8 7......0
            #   00000000 ffffffff DDDDDDDD ddFFFFFF
            #     0 = zero bits (not part of the file number?)
            #     f/F = low/high bits of file number
            #     d/D = low/high bits of directory number
            # The directory and file number are then converted into decimal
            # and separated by a '-' to give the file number used in the 20D
            ValueConv => '(($val&0xffc0)>>6)*10000+(($val>>16)&0xff)+(($val&0x3f)<<8)',
            ValueConvInv => q{
                my $d = int($val/10000);
                my $f = $val - $d * 10000;
                return (($d<<6) & 0xffc0) + (($f & 0xff)<<16) + (($f>>8) & 0x3f);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #16
            Name => 'FileNumber',
            Condition => '$self->{CameraModel} =~ /\b(30D|400D|REBEL XTi|Kiss Digital X|K236)\b/',
            Format => 'int32u',
            Notes => q{
                the location of the upper 4 bits of the directory number is a mystery for
                the EOS 30D, so the reported directory number will be incorrect for original
                images with a directory number of 164 or greater
            },
            # Thanks to Emil Sit for figuring this out:
            # [more insane bit maniplations like the 20D/350D above, but this time we
            # appear to have lost the upper 4 bits of the directory number (this was
            # verified through tests with directory numbers 100, 222, 801 and 999) - PH]
            # The bit pattern for the 30D is: (see 20D notes above for more information)
            #   31....24 23....16 15.....8 7......0
            #   00000000 ffff0000 ddddddFF FFFFFFFF
            # [NOTE: the 4 high order directory bits don't appear in this record, but
            # I have chosen to write them into bits 16-19 since these 4 zero bits look
            # very suspicious, and are a convenient place to store this information - PH]
            ValueConv  => q{
                my $d = ($val & 0xffc00) >> 10;
                # we know there are missing bits if directory number is < 100
                $d += 0x40 while $d < 100;  # (repair the damage as best we can)
                return $d*10000 + (($val&0x3ff)<<4) + (($val>>20)&0x0f);
            },
            ValueConvInv => q{
                my $d = int($val/10000);
                my $f = $val - $d * 10000;
                return ($d << 10) + (($f>>4)&0x3ff) + (($f&0x0f)<<20);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #7 (1Ds)
            Name => 'ShutterCount',
            Condition => 'GetByteOrder() eq "MM"',
            Format => 'int32u',
        },
        { #7 (1DmkII, 1DsMkII, 1DsMkIIN, 5D... + future models?)
            Name => 'ShutterCount',
            Condition => '$self->{CameraModel} !~ /\b(10D|300D|REBEL|Kiss)\b/',
            Format => 'int32u',
            ValueConv => '($val>>16)|(($val&0xffff)<<16)',
            ValueConvInv => '($val>>16)|(($val&0xffff)<<16)',
        },
    ],
    3 => { #PH
        Name => 'BracketMode',
        PrintConv => {
            0 => 'Off',
            1 => 'AEB',
            2 => 'FEB',
            3 => 'ISO',
            4 => 'WB',
        },
    },
    4 => 'BracketValue', #PH
    5 => 'BracketShotNumber', #PH
    6 => { #PH
        Name => 'RawJpgQuality',
        RawConv => '$val<=0 ? undef : $val',
        PrintConv => \%canonQuality,
    },
    7 => { #PH
        Name => 'RawJpgSize',
        RawConv => '$val<0 ? undef : $val',
        PrintConv => \%canonImageSize,
    },
    8 => { #PH
        Name => 'NoiseReduction',
        RawConv => '$val<0 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            # what do these modes mean?:
            1 => 'On (mode 1)',
            2 => 'On (mode 2)',
            3 => 'On (mode 3)', # (1DmkII,5D)
            4 => 'On (mode 4)', # (30D)
        },
    },
    9 => { #PH
        Name => 'WBBracketMode',
        PrintConv => {
            0 => 'Off',
            1 => 'On (shift AB)',
            2 => 'On (shift GM)',
        },
    },
    12 => 'WBBracketValueAB', #PH
    13 => 'WBBracketValueGM', #PH
    14 => { #PH
        Name => 'FilterEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
        },
    },
    15 => { #PH
        Name => 'ToningEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
        },
    },
);

# color information (MakerNotes tag 0xa0)
%Image::ExifTool::Canon::Processing = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'ToneCurve',
        PrintConv => {
            0 => 'Standard',
            1 => 'Manual',
            2 => 'Custom',
        },
    },
    2 => { #12
        Name => 'Sharpness',
        Notes => '1D and 5D only',
        Condition => '$self->{CameraModel} =~ /\b(1D|5D)/',
    },
    3 => { #PH
        Name => 'SharpnessFrequency',
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    4 => 'SensorRedLevel', #PH
    5 => 'SensorBlueLevel', #PH
    6 => 'WhiteBalanceRed', #PH
    7 => 'WhiteBalanceBlue', #PH
    8 => { #PH
        Name => 'WhiteBalance',
        RawConv => '$val < 0 ? undef : $val',
        PrintConv => \%canonWhiteBalance,
    },
    9 => 'ColorTemperature', #6
    10 => { #12
        Name => 'PictureStyle',
        PrintHex => 1,
        PrintConv => \%pictureStyles,
    },
    11 => { #PH
        Name => 'DigitalGain',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    12 => { #PH
        Name => 'WBShiftAB',
        Notes => 'positive is a shift toward red',
    },
    13 => { #PH
        Name => 'WBShiftGM',
        Notes => 'positive is a shift toward yellow/green',
    },
);

# D30 color information (MakerNotes tag 0x0a)
%Image::ExifTool::Canon::ColorInfoD30 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    9 => 'ColorTemperature',
    10 => 'ColorMatrix',
);

# Color balance information (MakerNotes tag 0xa9) (ref PH)
%Image::ExifTool::Canon::ColorBalance = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'This table is used by the 10D and 300D.',
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # red,green1,green2,blue (ref 2)
    0  => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16u[4]' },
    4  => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16u[4]' },
    8  => { Name => 'WB_RGGBLevelsShade',      Format => 'int16u[4]' },
    12 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16u[4]' },
    16 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16u[4]' },
    20 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16u[4]' },
    24 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16u[4]' },
    28 => { Name => 'WB_RGGBLevelsCustom',     Format => 'int16u[4]' },
    32 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16u[4]' },
);

# Color balance (MakerNotes tag 0x4001) (ref 12)
%Image::ExifTool::Canon::ColorBalance1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'This table is used by the 20D and 350D.',
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    25 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16u[4]' },
    29 => 'ColorTempAsShot',
    30 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16u[4]' },
    34 => 'ColorTempAuto',
    35 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16u[4]' },
    39 => 'ColorTempDaylight',
    40 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16u[4]' },
    44 => 'ColorTempShade',
    45 => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16u[4]' },
    49 => 'ColorTempCloudy',
    50 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16u[4]' },
    54 => 'ColorTempTungsten',
    55 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16u[4]' },
    59 => 'ColorTempFluorescent',
    60 => { Name => 'WB_RGGBLevelsFlash',       Format => 'int16u[4]' },
    64 => 'ColorTempFlash',
    65 => { Name => 'WB_RGGBLevelsCustom1',     Format => 'int16u[4]' },
    69 => 'ColorTempCustom1',
    70 => { Name => 'WB_RGGBLevelsCustom2',     Format => 'int16u[4]' },
    74 => 'ColorTempCustom2',
);

# Color balance (MakerNotes tag 0x4001) (ref 12)
%Image::ExifTool::Canon::ColorBalance2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'This table is used by the 1DmkII and 1DSmkII.',
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    24 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16u[4]' },
    28 => 'ColorTempAsShot',
    29 => { Name => 'WB_RGGBLevelsUnknown',     Format => 'int16u[4]', Unknown => 1 },
    33 => { Name => 'ColorTempUnknown', Unknown => 1 },
    34 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16u[4]' },
    38 => 'ColorTempAuto',
    39 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16u[4]' },
    43 => 'ColorTempDaylight',
    44 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16u[4]' },
    48 => 'ColorTempShade',
    49 => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16u[4]' },
    53 => 'ColorTempCloudy',
    54 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16u[4]' },
    58 => 'ColorTempTungsten',
    59 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16u[4]' },
    63 => 'ColorTempFluorescent',
    64 => { Name => 'WB_RGGBLevelsKelvin',      Format => 'int16u[4]' },
    68 => 'ColorTempKelvin',
    69 => { Name => 'WB_RGGBLevelsFlash',       Format => 'int16u[4]' },
    73 => 'ColorTempFlash',
    74 => { Name => 'WB_RGGBLevelsUnknown2',    Format => 'int16u[4]', Unknown => 1 },
    78 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    79 => { Name => 'WB_RGGBLevelsUnknown3',    Format => 'int16u[4]', Unknown => 1 },
    83 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    84 => { Name => 'WB_RGGBLevelsUnknown4',    Format => 'int16u[4]', Unknown => 1 },
    88 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    89 => { Name => 'WB_RGGBLevelsUnknown5',    Format => 'int16u[4]', Unknown => 1 },
    93 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    94 => { Name => 'WB_RGGBLevelsUnknown6',    Format => 'int16u[4]', Unknown => 1 },
    98 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    99 => { Name => 'WB_RGGBLevelsUnknown7',    Format => 'int16u[4]', Unknown => 1 },
    103 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    104 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16u[4]', Unknown => 1 },
    108 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    109 => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16u[4]', Unknown => 1 },
    113 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    114 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16u[4]', Unknown => 1 },
    118 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    119 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16u[4]', Unknown => 1 },
    123 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    124 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16u[4]', Unknown => 1 },
    128 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    129 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16u[4]', Unknown => 1 },
    133 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    134 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16u[4]', Unknown => 1 },
    138 => { Name => 'ColorTempUnknown14', Unknown => 1 },
    139 => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16u[4]', Unknown => 1 },
    143 => { Name => 'ColorTempUnknown15', Unknown => 1 },
    144 => { Name => 'WB_RGGBLevelsPC1',        Format => 'int16u[4]' },
    148 => 'ColorTempPC1',
    149 => { Name => 'WB_RGGBLevelsPC2',        Format => 'int16u[4]' },
    153 => 'ColorTempPC2',
    154 => { Name => 'WB_RGGBLevelsPC3',        Format => 'int16u[4]' },
    158 => 'ColorTempPC3',
    159 => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16u[4]', Unknown => 1 },
    163 => { Name => 'ColorTempUnknown16', Unknown => 1 },
);

# Color balance (MakerNotes tag 0x4001) (ref 12)
%Image::ExifTool::Canon::ColorBalance3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'This table is used by the 1DmkIIN, 5D, 30D and 400D.',
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    63 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16u[4]' },
    67 => 'ColorTempAsShot',
    68 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16u[4]' },
    72 => 'ColorTempAuto',
    # not sure exactly what 'Measured' values mean...
    73 => { Name => 'WB_RGGBLevelsMeasured',    Format => 'int16u[4]' },
    77 => 'ColorTempMeasured',
    78 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16u[4]' },
    82 => 'ColorTempDaylight',
    83 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16u[4]' },
    87 => 'ColorTempShade',
    88 => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16u[4]' },
    92 => 'ColorTempCloudy',
    93 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16u[4]' },
    97 => 'ColorTempTungsten',
    98 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16u[4]' },
    102 => 'ColorTempFluorescent',
    103 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16u[4]' },
    107 => 'ColorTempKelvin',
    108 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16u[4]' },
    112 => 'ColorTempFlash',
    113 => { Name => 'WB_RGGBLevelsPC1',        Format => 'int16u[4]' },
    117 => 'ColorTempPC1',
    118 => { Name => 'WB_RGGBLevelsPC2',        Format => 'int16u[4]' },
    122 => 'ColorTempPC2',
    123 => { Name => 'WB_RGGBLevelsPC3',        Format => 'int16u[4]' },
    127 => 'ColorTempPC3',
    128 => { Name => 'WB_RGGBLevelsCustom',     Format => 'int16u[4]' },
    132 => 'ColorTempCustom',
);

# Color information (MakerNotes tag 0x4003) (ref PH)
%Image::ExifTool::Canon::ColorInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Condition => '$self->{CameraMake} =~ /EOS-1D/',
        Name => 'Saturation',
    },
    2 => 'ColorHue',
    3 => {
        Name => 'ColorSpace',
        RawConv => '$val ? $val : undef', # ignore tag if zero
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
);

# Flags information (MakerNotes tag 0xb0) (ref PH)
%Image::ExifTool::Canon::Flags = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'ModifiedParamFlag',
);

# Modified information (MakerNotes tag 0xb1) (ref PH)
%Image::ExifTool::Canon::ModifiedInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'ModifiedToneCurve',
        PrintConv => {
            0 => 'Standard',
            1 => 'Manual',
            2 => 'Custom',
        },
    },
    2 => {
        Name => 'ModifiedSharpness',
        Notes => '1D and 5D only',
        Condition => '$self->{CameraModel} =~ /\b(1D|5D)/',
    },
    3 => {
        Name => 'ModifiedSharpnessFreq',
        PrintConv => {
            0 => 'n/a',
            1 => 'Smoothest',
            2 => 'Smooth',
            3 => 'Standard',
            4 => 'Sharp',
            5 => 'Sharpest',
        },
    },
    4 => 'ModifiedSensorRedLevel',
    5 => 'ModifiedSensorBlueLevel',
    6 => 'ModifiedWhiteBalanceRed',
    7 => 'ModifiedWhiteBalanceBlue',
    8 => {
        Name => 'ModifiedWhiteBalance',
        PrintConv => \%canonWhiteBalance,
    },
    9 => 'ModifiedColorTemp',
    10 => {
        Name => 'ModifiedPictureStyle',
        PrintHex => 1,
        PrintConv => \%pictureStyles,
    },
    11 => {
        Name => 'ModifiedDigitalGain',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
);

# canon composite tags
%Image::ExifTool::Canon::Composite = (
    GROUPS => { 2 => 'Camera' },
    DriveMode => {
        Require => {
            0 => 'ContinuousDrive',
            1 => 'Self-timer',
        },
        ValueConv => '$val[0] ? 0 : ($val[1] ? 1 : 2)',
        PrintConv => {
            0 => 'Continuous shooting',
            1 => 'Self-timer Operation',
            2 => 'Single-frame shooting',
        },
    },
    Lens => {
        Require => {
            0 => 'ShortFocal',
            1 => 'LongFocal',
        },
        ValueConv => '$val[0]',
        PrintConv => 'Image::ExifTool::Canon::PrintFocalRange(@val)',
    },
    Lens35efl => {
        Description => 'Lens',
        Require => {
            0 => 'ShortFocal',
            1 => 'LongFocal',
            3 => 'Lens',
        },
        Desire => {
            2 => 'ScaleFactor35efl',
        },
        ValueConv => '$val[3] * ($val[2] ? $val[2] : 1)',
        PrintConv => '$prt[3] . ($val[2] ? sprintf(" (35mm equivalent: %s)",Image::ExifTool::Canon::PrintFocalRange(@val)) : "")',
    },
    ShootingMode => {
        Require => {
            0 => 'CanonExposureMode',
            1 => 'EasyMode',
        },
        ValueConv => '$val[0] ? $val[0] : $val[1] + 10',
        PrintConv => '$val[0] ? $prt[0] : $prt[1]',
    },
    FlashType => {
        Require => {
            0 => 'FlashBits',
        },
        RawConv => '$val[0] ? $val : undef',
        ValueConv => '$val[0]&(1<<14)? 1 : 0',
        PrintConv => {
            0 => 'Built-In Flash',
            1 => 'External',
        },
    },
    RedEyeReduction => {
        Require => {
            0 => 'CanonFlashMode',
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => '($val[0]==3 or $val[0]==4 or $val[0]==6) ? 1 : 0',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    # fudge to display simple Flash On/Off for Canon cameras only
    FlashOn => {
        Description => 'Flash',
        Desire => {
            0 => 'FlashBits',
            1 => 'Flash',
        },
        ValueConv => 'Image::ExifTool::Canon::FlashOn(@val)',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    # same as FlashExposureComp, but undefined if no flash
    ConditionalFEC => {
        Description => 'Flash Exposure Compensation',
        Require => {
            0 => 'FlashExposureComp',
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => '$val[0]',
        PrintConv => '$prt[0]',
    },
    # hack to assume 1st curtain unless we see otherwise
    ShutterCurtainHack => {
        Description => 'Shutter Curtain Sync',
        Desire => {
            0 => 'ShutterCurtainSync',
        },
        Require => {
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => 'defined($val[0]) ? $val[0] : 0',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    WB_RGGBLevels => {
        Require => {
            0 => 'Canon:WhiteBalance',
        },
        Desire => {
            1 => 'WB_RGGBLevelsAsShot',
            # indices of the following entries correspond to Canon:WhiteBalance + 2
            2 => 'WB_RGGBLevelsAuto',
            3 => 'WB_RGGBLevelsDaylight',
            4 => 'WB_RGGBLevelsCloudy',
            5 => 'WB_RGGBLevelsTungsten',
            6 => 'WB_RGGBLevelsFluorescent',
            7 => 'WB_RGGBLevelsFlash',
            8 => 'WB_RGGBLevelsCustom',
           10 => 'WB_RGGBLevelsShade',
           11 => 'WB_RGGBLevelsKelvin',
        },
        ValueConv => '$val[1] ? $val[1] : $val[($val[0] || 0) + 2]',
    },
    ISO => {
        Priority => 0,  # let EXIF:ISO take priority
        Desire => {
            0 => 'Canon:CameraISO',
            1 => 'Canon:BaseISO',
            2 => 'Canon:AutoISO',
        },
        Notes => 'use CameraISO if numerical, otherwise calculate as BaseISO * AutoISO / 100',
        ValueConv => q{
            return $val[0] if $val[0] and $val[0] =~ /^\d+$/;
            return undef unless $val[1] and $val[2];
            return $val[1] * $val[2] / 100;
        },
        PrintConv => 'sprintf("%.0f",$val)',
    },
    DigitalZoom => {
        Require => {
            0 => 'Canon:ZoomSourceWidth',
            1 => 'Canon:ZoomTargetWidth',
            2 => 'Canon:DigitalZoom',
        },
        RawConv => q{
            return undef unless $val[2] == 3 and $val[0];
            return $val[1] / $val[0];
        },
        PrintConv => 'sprintf("%.2fx",$val)',
    }
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Canon');


#------------------------------------------------------------------------------
# Validate first word of Canon binary data
# Inputs: 0) data pointer, 1) offset, 2-N) list of valid values
# Returns: true if data value is the same
sub Validate($$@)
{
    my ($dataPt, $offset, @vals) = @_;
    # the first 16-bit value is the length of the data in bytes
    my $dataVal = Image::ExifTool::Get16u($dataPt, $offset);
    my $val;
    foreach $val (@vals) {
        return 1 if $val == $dataVal;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Validate CanonPictureInfo
# Inputs: 0) data pointer, 1) offset, 2) size
# Returns: true if data appears valid
sub ValidatePictureInfo($$$)
{
    my ($dataPt, $offset, $size) = @_;
    return 0 if $size < 24; # must be at least 24 bytes long (PowerShot Pro1)
    my $w1 = Image::ExifTool::Get16u($dataPt, $offset + 4);
    my $h1 = Image::ExifTool::Get16u($dataPt, $offset + 6);
    return 0 unless $h1 and $w1;
    my $f1 = $w1 / $h1;
    # check for normal aspect ratio
    return 1 if abs($f1 - 1.33) < 0.01 or abs($f1 - 1.67) < 0.01;
    # ZoomBrowser can modify this for rotated images (ref Joshua Bixby)
    return 1 if abs($f1 - 0.75) < 0.01 or abs($f1 - 0.60) < 0.01;
    my $w2 = Image::ExifTool::Get16u($dataPt, $offset + 8);
    my $h2 = Image::ExifTool::Get16u($dataPt, $offset + 10);
    return 0 unless $h2 and $w2;
    # compare aspect ratio with as-shot image dimensions
    # (the Powershot G6 as-shot height is wacky, hence the test above)
    return 0 if $w1 eq $h1;
    my $f2 = $w2 / $h2;
    return 1 if abs(1-$f1/$f2) < 0.01;
    return 1 if abs(1-$f1*$f2) < 0.01;
    return 0;
}

#------------------------------------------------------------------------------
# Convert the CameraISO value
# Inputs: 0) value, 1) set for inverse conversion
sub CameraISO($;$)
{
    my ($val, $inv) = @_;
    my $rtnVal;
    my %isoLookup = (
         0 => 'n/a',
        14 => 'Auto High', #PH (S3IS)
        15 => 'Auto',
        16 => 50,
        17 => 100,
        18 => 200,
        19 => 400,
        20 => 800, #PH
    );
    if ($inv) {
        $rtnVal = Image::ExifTool::ReverseLookup($val, \%isoLookup);
        if (not defined $rtnVal and Image::ExifTool::IsInt($val)) {
            $rtnVal = ($val & 0x3fff) | 0x4000;
        }
    } elsif ($val != 0x7fff) {
        if ($val & 0x4000) {
            $rtnVal = $val & 0x3fff;
        } else {
            $rtnVal = $isoLookup{$val} || "Unknown ($val)";
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Print range of focal lengths
# Inputs: 0) short focal, 1) long focal, 2) optional scaling factor
sub PrintFocalRange(@)
{
    my ($short, $long, $scale) = @_;

    $scale or $scale = 1;
    if ($short == $long) {
        return sprintf("%.1fmm", $short * $scale);
    } else {
        return sprintf("%.1f - %.1fmm", $short * $scale, $long * $scale);
    }
}

#------------------------------------------------------------------------------
# Print 1D AF points
# Inputs: 0) value to convert
# Focus point pattern:
#          A1  A2  A3  A4  A5  A6  A7
#    B1  B2  B3  B4  B5  B6  B7  B8  B9  B10
#  C1  C2  C3  C4  C5  C6  C7  C9  C9  C10  C11
#    D1  D2  D3  D4  D5  D6  D7  D8  D9  D10
#          E1  E2  E3  E4  E5  E6  E7
sub PrintAFPoints1D($)
{
    my $val = shift;
    return 'Unknown' unless length $val == 8;
    # these are the x/y positions of each bit in the AF point mask
    # (x is upper 3 bits / y is lower 5 bits)
    my @focusPts = (0,0,
              0x04,0x06,0x08,0x0a,0x0c,0x0e,0x10,         0,0,
      0x21,0x23,0x25,0x27,0x29,0x2b,0x2d,0x2f,0x31,0x33,
    0x40,0x42,0x44,0x46,0x48,0x4a,0x4c,0x4d,0x50,0x52,0x54,
      0x61,0x63,0x65,0x67,0x69,0x6b,0x6d,0x6f,0x71,0x73,  0,0,
              0x84,0x86,0x88,0x8a,0x8c,0x8e,0x90,   0,0,0,0,0
    );
    my $focus = unpack('C',$val);
    my @bits = split //, unpack('b*',substr($val,1));
    my @rows = split //, '  AAAAAAA  BBBBBBBBBBCCCCCCCCCCCDDDDDDDDDD  EEEEEEE     ';
    my ($focusing, $focusPt, @points);
    my $lastRow = '';
    my $col = 0;
    foreach $focusPt (@focusPts) {
        my $row = shift @rows;
        $col = ($row eq $lastRow) ? $col + 1 : 1;
        $lastRow = $row;
        $focusing = "$row$col" if $focus eq $focusPt;
        push @points, "$row$col" if shift @bits;
    }
    $focusing or $focusing = ($focus eq 0xff) ? 'Auto' : sprintf('Unknown (0x%.2x)',$focus);
    return "$focusing (" . join(',',@points) . ')';
}

#------------------------------------------------------------------------------
# Decide whether flash was on or off
sub FlashOn(@)
{
    my @val = @_;

    if (defined $val[0]) {
        return $val[0] ? 1 : 0;
    }
    if (defined $val[1]) {
        return $val[1]&0x07 ? 1 : 0;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Convert Canon hex-based EV (modulo 0x20) to real number
# Inputs: 0) value to convert
# ie) 0x00 -> 0
#     0x0c -> 0.33333
#     0x10 -> 0.5
#     0x14 -> 0.66666
#     0x20 -> 1   ...  etc
sub CanonEv($)
{
    my $val = shift;
    my $sign;
    # temporarily make the number positive
    if ($val < 0) {
        $val = -$val;
        $sign = -1;
    } else {
        $sign = 1;
    }
    my $frac = $val & 0x1f;
    $val -= $frac;      # remove fraction
    # Convert 1/3 and 2/3 codes
    if ($frac == 0x0c) {
        $frac = 0x20 / 3;
    } elsif ($frac == 0x14) {
        $frac = 0x40 / 3;
    }
    return $sign * ($val + $frac) / 0x20;
}

#------------------------------------------------------------------------------
# Convert number to Canon hex-based EV (modulo 0x20)
# Inputs: 0) number
# Returns: Canon EV code
sub CanonEvInv($)
{
    my $num = shift;
    my $sign;
    # temporarily make the number positive
    if ($num < 0) {
        $num = -$num;
        $sign = -1;
    } else {
        $sign = 1;
    }
    my $val = int($num);
    my $frac = $num - $val;
    if (abs($frac - 0.33) < 0.05) {
        $frac = 0x0c
    } elsif (abs($frac - 0.67) < 0.05) {
        $frac = 0x14;
    } else {
        $frac = int($frac * 0x20 + 0.5);
    }
    return $sign * ($val * 0x20 + $frac);
}

#------------------------------------------------------------------------------
# Write Canon maker notes
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table ref
# Returns: data block (may be empty if no Exif data) or undef on error
sub WriteCanon($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dirData = Image::ExifTool::Exif::WriteExif($exifTool, $dirInfo, $tagTablePtr);
    # add trailer which is written by some Canon models (it's a TIFF header)
    if (defined $dirData and length $dirData and $$dirInfo{Fixup}) {
        $dirData .= GetByteOrder() . Set16u(42) . Set32u(0);
        $dirInfo->{Fixup}->AddFixup(length($dirData) - 4);
    }
    return $dirData;
}

#------------------------------------------------------------------------------
1;  # end

__END__

=head1 NAME

Image::ExifTool::Canon - Canon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Canon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.wonderland.org/crw/>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm>

=item (...plus lots of testing with my 300D!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks Michael Rommel and Daniel Pittman for information they provided about
the Digital Ixus and PowerShot S70 cameras, Juha Eskelinen and Emil Sit for
figuring out the 20D and 30D FileNumber, Denny Priebe for figuring out a
couple of 1D tags, and Michael Tiemann and Rainer Honle for decoding a
number of new tags.  Also thanks to everyone who made contributions to the
LensType lookup list or the meanings of other tag values.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Canon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
