#------------------------------------------------------------------------------
# File:         Minolta.pm
#
# Description:  Minolta EXIF maker notes tags
#
# Revisions:    04/06/2004 - P. Harvey Created
#               09/09/2005 - P. Harvey Added ability to write MRW files
#
# References:   1) http://www.dalibor.cz/minolta/makernote.htm
#               2) Jay Al-Saadi private communication (testing with A2)
#               3) Shingo Noguchi, PhotoXP (http://www.daifukuya.com/photoxp/)
#               4) Niels Kristian Bech Jensen private communication
#               5) http://www.cybercom.net/~dcoffin/dcraw/
#               6) Pedro Corte-Real private communication
#               7) ExifTool forum post by bronek (http://www.cpanforum.com/posts/1118)
#               8) http://www.chauveau-central.net/mrw-format/
#               9) CPAN Forum post by 'geve'
#------------------------------------------------------------------------------

package Image::ExifTool::Minolta;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.23';

%Image::ExifTool::Minolta::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0000 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        # These camera settings are different for the DiMAGE X31
        Condition => '$self->{CameraModel} ne "DiMAGE X31"',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0004 => { #8
        Name => 'MinoltaCameraSettings7D',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings7D',
            ByteOrder => 'BigEndian',
        },
    },
    # it appears that image stabilization is on if this tag exists (ref 2),
    # but it is an 8kB binary data block!
    0x0018 => {
        Name => 'ImageStabilization',
        Condition => '$self->{CameraModel} =~ /^DiMAGE (A1|A2|X1)$/',
        Notes => q{
            a block of binary data which exists in DiMAGE A2 (and A1/X1?) images only if
            image stabilization is enabled
        },
        ValueConv => '"On"',
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        # preview image in TIFF format files
        %Image::ExifTool::previewImageTagInfo,
        Permanent => 1,     # don't add this to a file because it doesn't exist in JPEG images
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0101 => {
        Name => 'ColorMode',
        Priority => 0, # Other ColorMode is more reliable for A2
        Writable => 'int32u',
        PrintConv => {
            0 => 'Natural color',
            1 => 'Black & White',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
            13 => 'Natural sRGB',
            14 => 'Natural+ sRGB',
        },
    },
    0x0102 => {
        Name => 'MinoltaQuality',
        Writable => 'int32u',
        # PrintConv strings conform with Minolta reference manual (ref 4)
        # (note that Minolta calls an uncompressed TIFF image "Super fine")
        PrintConv => {
            0 => 'Raw',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    # (0x0103 is the same as 0x0102 above) -- this is true for some
    # cameras (A2/7Hi), but not others - PH
    0x0103 => [
        {
            Name => 'MinoltaQuality',
            Writable => 'int32u',
            Condition => '$self->{CameraModel} =~ /^DiMAGE (A2|7Hi)$/',
            Notes => 'quality for DiMAGE A2/7Hi',
            Priority => 0, # lower priority because this doesn't work for A200
            PrintConv => { #4
                0 => 'Raw',
                1 => 'Super Fine',
                2 => 'Fine',
                3 => 'Standard',
                4 => 'Economy',
                5 => 'Extra fine',
            },
        },
        { #PH
            Name => 'MinoltaImageSize',
            Writable => 'int32u',
            Condition => '$self->{CameraModel} !~ /^DiMAGE A200$/',
            Notes => 'image size for other models except A200',
            PrintConv => {
                1 => '1600x1200',
                2 => '1280x960',
                3 => '640x480',
                5 => '2560x1920',
                6 => '2272x1704',
                7 => '2048x1536',
            },
        },
    ],
    0x0107 => { #8
        Name => 'ImageStabilization',
        Writable => 'int32u',
        PrintConv => {
            1 => 'Off',
            5 => 'On',
        },
    },
    0x010a => {
        Name => 'ZoneMatching',
        Writable => 'int32u',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    0x010b => {
        Name => 'ColorTemperature',
        Writable => 'int32u',
    },
    0x010c => { #3 (Alpha 7)
        Name => 'LensID',
        Writable => 'int32u',
        PrintConv => {
            1 => 'AF80-200mm F2.8G',
            2 => 'AF28-70mm F2.8G',
            6 => 'AF24-85mm F3.5-4.5',
            7 => 'AF100-400mm F4.5-6.7(D)',
            11 => 'AF300mm F4G',
            12 => 'AF100mm F2.8 Soft',
            15 => 'AF400mm F4.5G',
            16 => 'AF17-35mm F3.5G',
            19 => 'AF35mm/1.4',
            20 => 'STF135mm F2.8[T4.5]',
            23 => 'AF200mm F4G Macro',
            24 => 'AF24-105mm F3.5-4.5(D) or SIGMA 18-50mm F2.8',
            25 => 'AF100-300mm F4.5-5.6(D)',
            27 => 'AF85mm F1.4G',
            28 => 'AF100mm F2.8 Macro(D)',
            29 => 'AF75-300mm F4.5-5.6(D)',
            30 => 'AF28-80mm F3.5-5.6(D)',
            31 => 'AF50mm F2.8 Macro(D) or AF50mm F3.5 Macro',
            32 => 'AF100-400mm F4.5-6.7(D) x1.5',
            33 => 'AF70-200mm F2.8G SSM',
            35 => 'AF85mm F1.4G(D) Limited',
            38 => 'AF17-35mm F2.8-4(D)',
            39 => 'AF28-75mm F2.8(D)',
            40 => 'AFDT18-70mm F3.5-5.6(D)', #6
            128 => 'TAMRON 18-200, 28-300 or 80-300mm F3.5-6.3',
            25501 => 'AF50mm F1.7', #7
            25521 => 'TOKINA 19-35mm F3.5-4.5 or TOKINA 28-70mm F2.8 AT-X', #3/7
            25541 => 'AF35-105mm F3.5-4.5',
            25551 => 'AF70-210mm F4 Macro or SIGMA 70-210mm F4-5.6 APO', #7/6
            25581 => 'AF24-50mm F4',
            25611 => 'SIGMA 70-300mm F4-5.6 or SIGMA 300mm F4 APO Macro', #3/7
            25621 => 'AF50mm F1.4 NEW',
            25631 => 'AF300mm F2.8G',
            25641 => 'AF50mm F2.8 Macro',
            25661 => 'AF24mm F2.8',
            25721 => 'AF500mm F8 Reflex',
            25781 => 'AF16mm F2.8 Fisheye or SIGMA 8mm F4 Fisheye',
            25791 => 'AF20mm F2.8',
            25811 => 'AF100mm F2.8 Macro(D), TAMRON 90mm F2.8 Macro or SIGMA 180mm F5.6 Macro',
            25858 => 'TAMRON 24-135mm F3.5-5.6',
            25891 => 'TOKINA 80-200mm F2.8',
            25921 => 'AF85mm F1.4G(D)',
            25931 => 'AF200mm F2.8G',
            25961 => 'AF28mm F2',
            25981 => 'AF100mm F2',
            26061 => 'AF100-300mm F4.5-5.6(D)',
            26081 => 'AF300mm F2.8G',
            26121 => 'AF200mm F2.8G(D)',
            26131 => 'AF50mm F1.7',
            26241 => 'AF35-80mm F4-5.6',
            45741 => 'AF200mm F2.8G x2 or TOKINA 300mm F2.8 x2',
        },
    },
    0x0114 => { #8
        Name => 'MinoltaCameraSettings5D',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings5D',
            ByteOrder => 'BigEndian',
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
    0x0f00 => {
        Name => 'MinoltaCameraSettings2',
        Writable => 0,
    },
);

%Image::ExifTool::Minolta::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0, # not as reliable as other tags
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    NOTES => q{
        There is some variability in CameraSettings information between different
        models (and sometimes even between different firmware versions), so this
        information may not be as reliable as it should be.  Because of this, tags
        in the following tables are set to lower priority to prevent them from
        superceeding the values of same-named tags in other locations when duplicate
        tags are disabled.
    },
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
        PrintConv => 'Image::ExifTool::Minolta::ConvertWhiteBalance($val)',
    },
    4 => {
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Full',
            1 => '1600x1200',
            2 => '1280x960',
            3 => '640x480',
            6 => '2080x1560', #PH (A2)
            7 => '2560x1920', #PH (A2)
            8 => '3264x2176', #PH (A2)
        },
    },
    5 => {
        Name => 'MinoltaQuality',
        PrintConv => { #4
            0 => 'Raw',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    6 => {
        Name => 'DriveMode',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            2 => 'Self-timer',
            4 => 'Bracketing',
            5 => 'Interval',
            6 => 'UHS continuous',
            7 => 'HS continuous',
        },
    },
    7 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center weighted',
            2 => 'Spot',
        },
    },
    8 => {
        Name => 'ISO',
        ValueConv => '2 ** (($val-48)/8) * 100',
        ValueConvInv => '48 + 8*log($val/100)/log(2)',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    9 => {
        Name => 'ExposureTime',
        ValueConv => '2 ** ((48-$val)/8)',
        ValueConvInv => '48 - 8*log($val)/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    10 => {
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
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
        ValueConvInv => '($val + 2) * 3',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
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
        ValueConvInv => '$val * 256',
        PrintConv => 'sprintf("%.1fmm",$val)',
        PrintConvInv => '$val=~s/mm$//;$val',
    },
    19 => {
        Name => 'FocusDistance',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '$val ? "$val m" : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s.*//, $val',
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
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'sprintf("%4d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    22 => {
        Name => 'MinoltaTime',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'sprintf("%.2d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    23 => {
        Name => 'MaxAperture',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
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
        ValueConvInv => '$val * 256',
    },
    29 => {
        Name => 'ColorBalanceGreen',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    30 => {
        Name => 'ColorBalanceBlue',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    31 => {
        Name => 'Saturation',
        ValueConv => '$val - ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    32 => {
        Name => 'Contrast',
        ValueConv => '$val - ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
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
        ValueConvInv => '$val * 3 + 6',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    36 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => 100,
            1 => 200,
            2 => 400,
            3 => 800,
            4 => 'Auto',
            5 => 64,
        },
    },
    37 => {
        Name => 'MinoltaModel',
        PrintConv => {
            0 => 'DiMAGE 7 or X31',
            1 => 'DiMAGE 5',
            2 => 'DiMAGE S304',
            3 => 'DiMAGE S404',
            4 => 'DiMAGE 7i',
            5 => 'DiMAGE 7Hi',
            6 => 'DiMAGE A1',
            7 => 'DiMAGE A2 or S414',
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
            1 => 'Black & White',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
        },
    },
    41 => {
        Name => 'ColorFilter',
        ValueConv => '$val - ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
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
        ValueConvInv => '($val + 6) * 8',
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
            0 => 'Exposure',
            1 => 'Contrast',
            2 => 'Saturation',
            3 => 'Filter',
        },
    },
    # 7Hi only:
    51 => {
        Name => 'ColorProfile',
        Condition => '$self->{CameraModel} eq "DiMAGE 7Hi"',
        Notes => 'DiMAGE 7Hi only',
        PrintConv => {
            0 => 'Not Embedded',
            1 => 'Embedded',
        },
    },
    # (the following may be entry 51 for other models?)
    52 => {
        Name => 'DataImprint',
        Condition => '$self->{CameraModel} eq "DiMAGE 7Hi"',
        Notes => 'DiMAGE 7Hi only',
        PrintConv => {
            0 => 'None',
            1 => 'YYYY/MM/DD',
            2 => 'MM/DD/HH:MM',
            3 => 'Text',
            4 => 'Text + ID#',
        },
    },
    63 => { #9
        Name => 'FlashMetering',
        PrintConv => {
            0 => 'ADI (Advanced Distance Integration)',
            1 => 'Pre-flash TTl', 
            2 => 'Manual flash control',
        },
    },
);

# Camera settings used by the 7D (ref 8)
%Image::ExifTool::Minolta::CameraSettings7D = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x00 => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture Priority',
            2 => 'Shutter Priority',
            3 => 'Manual',
            4 => 'Auto?',
            5 => 'Program-shift A',
            6 => 'Program-shift S',
        },
    },
    0x02 => { #PH
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    0x03 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'RAW',
            16 => 'Fine', #PH
            32 => 'Normal', #PH
            34 => 'RAW+JPEG',
            48 => 'Economy', #PH
        },
    },
    0x04 => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Cloudy',
            4 => 'Tungsten',
            5 => 'Fluorescent',
            0x100 => 'Kelvin',
            0x200 => 'Manual',
        },
    },
    0x0e => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Single-shot AF',
            1 => 'Continuous AF',
            3 => 'Automatic AF',
            4 => 'Manual',
        },
    },
    0x10 => {
        Name => 'AFPoints',
        PrintConv => { BITMASK => {
            0 => 'Center',
            1 => 'Top',
            2 => 'Top-Right',
            3 => 'Right',
            4 => 'Bottom-Right',
            5 => 'Bottom',
            6 => 'Bottom-Left',
            7 => 'Left',
            8 => 'Top-Left',
        } },
    },
    0x15 => {
        Name => 'Flash',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x1c => {
        Name => 'ISOSetting',
        PrintConv => {
            1 => 100,
            3 => 200,
            4 => 400,
            5 => 800,
            6 => 1600,
            7 => 3200,
        },
    },
    0x1e => {
        Name => 'ExposureCompensation',
        Format => 'int16s',
        ValueConv => '$val / 24',
        ValueConvInv => '$val * 24',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    0x25 => {
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'sRGB (Natural)',
            1 => 'sRGB (Natural+)',
            4 => 'Adobe RGB',
        },
    },
    0x26 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x27 => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x28 => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x2d => 'FreeMemoryCardImages',
    0x3f => {
        Format => 'int16s',
        Name => 'ColorTemperature',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x46 => {
        Name => 'Rotation',
        PrintConv => {
            72 => 'Horizontal (normal)',
            76 => 'Rotate 90 CW',
            82 => 'Rotate 270 CW',
        },
    },
    0x47 => {
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x48 => {
        Name => 'ExposureTime',
        ValueConv => '2 ** ((48-$val)/8)',
        ValueConvInv => '48 - 8*log($val)/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x4a => 'FreeMemoryCardImages',
    0x5e => {
        Name => 'ImageNumber',
        Notes => q{
            this information may appear at index 98 (0x62), depending on firmware
            version
        },
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x60 => {
        Name => 'NoiseReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x62 => {
        Name => 'ImageNumber2',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x71 => {
        Name => 'ImageStabilization',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x75 => {
        Name => 'ZoneMatchingOn',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# Camera settings used by the 5D (ref 8)
%Image::ExifTool::Minolta::CameraSettings5D = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x0a => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture Priority',
            2 => 'Shutter Priority',
            3 => 'Manual',
            4 => 'Auto?',
            4131 => 'Connected Copying?',
        },
    },
    0x0c => { #PH
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    0x0d => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'RAW',
            16 => 'Fine', #PH
            32 => 'Normal', #PH
            34 => 'RAW+JPEG',
            48 => 'Economy', #PH
        },
    },
    0x0e => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy?',
            3 => 'Shade?',
            4 => 'Tungsten',
            5 => 'Fluorescent',
            6 => 'Flash',
            0x100 => 'Kelvin',
            0x200 => 'Manual',
        },
    },
    # 0x0f=0x11 something to do with WB RGB levels as shot? (PH)
    # 0x12-0x17 RGB levels for other WB modes (with G missing)? (PH)
    0x1f => { #PH
        Name => 'Flash',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
        },
    },
    0x25 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center weighted',
            2 => 'Spot',
        },
    },
    0x26 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => 'Auto',
            1 => 100,
            3 => 200,
            4 => 400,
            5 => 800,
            6 => 1600,
            7 => 3200,
            8 => '200 (Zone Matching High)',
            10 => '80 (Zone Matching Low)',
        },
    },
    0x30 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x31 => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x32 => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x35 => { #PH
        Name => 'ExposureTime',
        ValueConv => '2 ** ((48-$val)/8)',
        ValueConvInv => '48 - 8*log($val)/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0x36 => { #PH
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x37 => 'FreeMemoryCardImages',
    # 0x38 definitely not related to exposure comp as in ref 8 (PH)
    0x49 => { #PH
        Name => 'ColorTemperature',
        Format => 'int16s',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x50 => {
        Name => 'Rotation',
        PrintConv => {
            72 => 'Horizontal (normal)',
            76 => 'Rotate 90 CW',
            82 => 'Rotate 270 CW',
        },
    },
    0x53 => {
        Name => 'ExposureCompensation',
        ValueConv => '$val / 100 - 3',
        ValueConvInv => '($val + 3) * 100',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    0x54 => 'FreeMemoryCardImages',
    # 0x66 maybe program mode or some setting like this? (PH)
    # 0x95 FlashStrength? (PH)
    # 0xa4 similar information to 0x27, except with different values
    0xae => {
        Name => 'ImageNumber',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0xb0 => {
        Name => 'NoiseReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xbd => {
        Name => 'ImageStabilization',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# basic Minolta white balance lookup
my %minoltaWhiteBalance = (
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    5 => 'Custom',
    7 => 'Fluorescent',
    8 => 'Fluorescent 2',
    11 => 'Custom 2',
    12 => 'Custom 3',
    # the following come from tests with the A2 (ref 2)
    0x0800000 => 'Auto',
    0x1800000 => 'Daylight',
    0x2800000 => 'Cloudy',
    0x3800000 => 'Tungsten',
    0x4800000 => 'Flash',
    0x5800000 => 'Fluorescent',
    0x6800000 => 'Shade',
    0x7800000 => 'Custom1',
    0x8800000 => 'Custom2',
    0x9800000 => 'Custom3',
);

#------------------------------------------------------------------------------
# PrintConv for Minolta white balance
sub ConvertWhiteBalance($)
{
    my $val = shift;
    my $printConv = $minoltaWhiteBalance{$val};
    unless (defined $printConv) {
        # the A2 values can be shifted by += 3 settings, where
        # each setting adds or subtracts 0x001000 (ref 2)
        my $type = ($val & 0xff000000) + 0x800000;
        if ($type and $printConv = $minoltaWhiteBalance{$type}) {
            $printConv .= sprintf("%+.8g", ($val - $type) / 0x10000);
        } else {
            $printConv = sprintf("Unknown (0x%x)", $val);
        }
    }
    return $printConv;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Minolta - Minolta EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Minolta and Konica-Minolta maker notes in EXIF information, and to read
and write Minolta RAW (MRW) images.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.dalibor.cz/minolta/makernote.htm>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Jay Al-Saadi, Niels Kristian Bech Jensen, Shingo Noguchi and Pedro
Corte-Real for the information they provided.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
