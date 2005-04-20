#------------------------------------------------------------------------------
# File:         Canon.pm
#
# Description:  Definitions for Canon EXIF Maker notes
#
# Revisions:    11/25/03 - P. Harvey Created
#               12/03/03 - P. Harvey Figured out lots more tags and added
#                            CanonPictureInfo
#               02/17/04 - Michael Rommel Added IxusAFPoint
#               01/27/05 - P. Harvey Disable validation of CanonPictureInfo
#               01/30/05 - P. Harvey Added a few more tags from ref #4
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Michael Rommel private communication (tests with Digital Ixus)
#               3) Daniel Pittman private communication (tests with PowerShot S70)
#               4) http://www.wonderland.org/crw/
#               5) Juha Eskelinen private communication (tests with 20D)
#               6) Richard S. Smith private communication (tests with 20D)
#               7) Denny Priebe private communication (tests with 1D MkII)
#------------------------------------------------------------------------------

package Image::ExifTool::Canon;

use strict;
use vars qw($VERSION);

$VERSION = '1.13';

# Canon EXIF Maker Notes
%Image::ExifTool::Canon::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
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
    0x4 => {
        Name => 'CanonShotInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ShotInfo',
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
        Description => "Owner's Name",
    },
    0xa => {
        Name => 'CanonColorInfoD30',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ColorInfoD30',
        },
    },
    0xc => [   # square brackets for a conditional list
        {
            Condition => '$self->{CameraModel} =~ /\b(300D|350D|REBEL|10D|20D)/',
            Writable => 'int32u',
            Name => 'SerialNumber',
            Description => 'Camera Body No.',
            PrintConv => 'sprintf("%.10d",$val)',
            PrintConvInv => '$val',
        },
        {
            # serial number of 1D/1Ds/1D Mark II/1Ds Mark II is usually
            # displayed w/o leeding zeros (ref 7)
            Condition => '$self->{CameraModel} =~ /\b1D.*/',
            Writable => 'int32u',
            Name => 'SerialNumber',
            Description => 'Camera Body No.',
            PrintConv => 'sprintf("%d",$val)',
            PrintConvInv => '$val',
        },
        {
            # no condition (all other models)
            Name => 'SerialNumber',
            Writable => 'int32u',
            Description => 'Camera Body No.',
            PrintConv => 'sprintf("%x-%.5d",$val>>16,$val&0xffff)',
            PrintConvInv => '$val=~/(.*)-(\d+)/ ? (hex($1)<<16)+$2 : undef',
        },
    ],
    0xe => {
        Name => 'CanonFileLength',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
    },
    0xf => [
        {
            Condition => '$self->{CameraModel} =~ /\b10D/',
            Name => 'CanonCustomFunctions10D',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions10D',
            },
        },
        {
            Condition => '$self->{CameraModel} =~ /\b20D/',
            Name => 'CanonCustomFunctions20D',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions20D',
            },
        },
        {
            # assume everything else is a D30/D60
            Name => 'CanonCustomFunctionsD30',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
    ],
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
    0x90 => {
        Name => 'CanonCustomFunctions1D',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
        },
    },
    0x93 => {
        Name => 'CanonFileInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FileInfo',
        },
    },
    0xa0 => {
        Name => 'CanonColorInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ColorInfo',
        },
    },
    0xa9 => {
        Name => 'WhiteBalanceTable',
        SubDirectory => {
            # this offset is necessary because the table is interpreted as short rationals
            # (4 bytes long) but the first entry is 2 bytes into the table.
            Start => '$valuePtr + 2',
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart-2,$size)',
            TagTable => 'Image::ExifTool::Canon::WhiteBalance',
        },
    },
    0xae => {
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0xb6 => {
        Name => 'PreviewImageInfo',
        SubDirectory => {
            # Note: first word if this block is the total number of words, not bytes!
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size/2)',
            TagTable => 'Image::ExifTool::Canon::PreviewImageInfo',
        },
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
        Description => 'Image Quality',
        PrintConv => {
            2 => 'Normal',
            3 => 'Fine',
            4 => 'RAW',
            5 => 'Superfine',
        },
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
        },
    },
    10 => {
        Name => 'CanonImageSize',
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
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
            6 => 'Black & White',
            7 => 'Sepia',
            8 => 'Portrait',
            9 => 'Sports',
            10 => 'Macro',
            11 => 'Pan focus',
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'None',
            1 => 'x2',
            2 => 'x4',
            3 => 'Other',  # value obtained from 2*#37/#36
        },
    },
    13 => {
        Name => 'Contrast',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    14 => {
        Name => 'Saturation',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    15 => {
        Name => 'Sharpness',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    16 => {
        Name => 'CameraISO',
        PrintConv => {
            0 => 'Use shot ISO instead',
            15 => 'Auto',
            16 => '50',
            17 => '100',
            18 => '200',
            19 => '400',
        },
    },
    17 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Default', # older Ixus
            1 => 'Spot',
            3 => 'Evaluative',
            4 => 'Partial',
            5 => 'Center-weighted averaging',
        },
    },
    18 => {
        # this is always 2 for the 300D - PH
        Name => 'FocusType',
        PrintConv => {
            0 => 'Manual',
            1 => 'Auto (1)',
            2 => 'Auto (2)',
            3 => 'Macro Mode',
            7 => 'Infinity Mode',
            8 => 'Locked (Pan Mode)',
        },
    },
    19 => {
        Name => 'AFPoint',
        Flags => 'PrintHex',
        PrintConv => {
            0x3000 => 'None (MF)',
            0x3001 => 'Auto-selected',
            0x3002 => 'Right',
            0x3003 => 'Center',
            0x3004 => 'Left',
            0x4001 => 'Auto AF point selection',
            0x2005 => 'Manual AF point selection',
        },
    },
    20 => {
        Name => 'CanonExposureMode',
        PrintConv => {
            0 => 'Easy',
            1 => 'Program AE',
            2 => 'Shutter Speed Priority AE',
            3 => 'Aperture-Priority AE',
            4 => 'Manual',
            5 => 'Depth-of-field AE',
        },
    },
    22 => { #4
        Name => 'LensType',
        PrintConv => {
            1 => 'Canon EF 50mm f/1.8',
            2 => 'Canon EF 28mm f/2.8',
            4 => 'Sigma UC Zoom 35-135mm f/4-5.6',
            6 => 'Tokina AF193-2 19-35mm f/3.5-4.5',
            10 => 'Sigma 50mm f/2.8 EX / 28mm f/1.8',
            21 => 'Canon EF 80-200mm f/2.8L',
            26 => 'Cosina 100mm f/3.5 Macro AF',
            28 => 'Tamron AF Aspherical 28-200mm f/3.8-5.6',
            29 => 'Canon EF 50mm f/1.8 MkII',
            39 => 'Canon EF 75-300mm f/4-5.6',
            40 => 'Canon EF 28-80mm f/3.5-5.6',
            125 => 'Canon TS-E 24mm f/3.5L',
            131 => 'Sigma 17-35mm f2.8-4 EX Aspherical HSM',
            135 => 'Canon EF 200mm f/1.8L',
            136 => 'Canon EF 300mm f/2.8L',
            139 => 'Canon EF 400mm f/2.8L',
            141 => 'Canon EF 500mm f/4.5L',
            150 => 'Sigma 20mm EX f/1.8',
            151 => 'Canon EF 200mm f/2.8L USM',
            155 => 'Canon EF 85mm f/1.8 USM',
            156 => 'Canon EF 28-105mm f/3.5-4.5 USM',
            160 => 'Canon EF 20-35mm f/3.5-4.5 USM',
            161 => 'Canon EF 28-70mm f/2.8mm L USM / Sigma 24-70mm EX f/2.8',
            165 => 'Canon EF 70-200mm f/2.8 L',
            166 => 'Canon EF 70-200mm f/2.8 L + x1.4',
            167 => 'Canon EF 70-200mm f/2.8 L + x2',
            169 => 'Sigma 15-30mm f/3.5-4.5 EX DG Aspherical',
            173 => 'Sigma 180mm EX HSM Macro f/3.5',
            176 => 'Canon EF 24-85mm f/3.5-4.5 USM',
            178 => 'Canon EF 28-135mm f/3.5-5.6 IS',
            182 => 'Canon EF 100-400mm f/4.5-5.6 L IS + x2',
            183 => 'Canon EF 100-400mm f/4.5-5.6 L IS',
            190 => 'Canon EF 100mm f/2.8 Macro',
            197 => 'Canon EF 75-300mm f/4-5.6 IS',
            202 => 'Canon EF 28-80 f/3.5-5.6 USM IV',
            213 => 'Canon EF 90-300mm f/4.5-5.6',
            231 => 'Canon EF 17-40mm f/4L',
        },
    },
    23 => 'LongFocal',
    24 => 'ShortFocal',
    25 => 'FocalUnits',
    28 => {
        Name => 'FlashActivity',
        ValueConv => '$val==-1 ? undef() : $val',
        ValueConvInv => '$val',
    },
    29 => {
        Name => 'FlashBits',
        PrintConv => q[Image::ExifTool::Exif::DecodeBits($val,
            {
                3 => 'On',
                4 => 'FP sync enabled',
                7 => '2nd-curtain sync used',
                11 => 'FP sync used',
                13 => 'Internal flash',
                14 => 'External E-TTL',
            }
        )],
    },
    32 => {
        Name => 'FocusContinuous',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
        },
    },
    36 => 'ZoomedResolution',
    37 => 'ZoomedResolutionBase',
    42 => {
        Name => 'ColorTone',
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
    1 => {
        Name => 'FocalLength',
        # the EXIF FocalLength is more reliable, so set this priority to zero
        Priority => 0,
        PrintConv => '"${val}mm"',
        PrintConvInv => '$val=~s/mm//;$val',
    },
    2 => { #4
        Name => 'FocalPlaneXSize',
        # focal plane image dimensions in 1/1000 inch -- convert to mm
        ValueConv => '$val * 25.4 / 1000',
        ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
        PrintConv => 'sprintf("%.2fmm",$val)',
        PrintConvInv => '$val=~s/\s*mm.*//;$val',
    },
    3 => {
        Name => 'FocalPlaneYSize',
        ValueConv => '$val * 25.4 / 1000',
        ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
        PrintConv => 'sprintf("%.2fmm",$val)',
        PrintConvInv => '$val=~s/\s*mm.*//;$val',
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
    2 => {
        Name => 'ISO',
        Description => 'ISO Speed',
        # lookup tables can't predict new values, so calculate ISO instead - PH
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2))*100/32',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val*32/100)/log(2))',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
   # 4 => 'TargetAperture'; #2 ?
   # 5 => 'TargetExposureTime'; #2 ?
    6 => {
        Name => 'ExposureCompensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    7 => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Tungsten',
            4 => 'Fluorescent',
            5 => 'Flash',
            6 => 'Custom',
            7 => 'Black & White',
            8 => 'Shade',
            9 => 'Manual temperature',
            14 => 'Daylight Fluorescent', #3
            17 => 'Underwater', #3
        },
    },
    9 => {
        Name => 'SequenceNumber',
        Description => 'Shot Number In Continuous Burst',
    },
    # AF points for Ixus and IxusV cameras - 02/17/04 M. Rommel
    14 => { #2
        Name => 'IxusAFPoint',
        Flags => 'PrintHex',
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
            0 => 'Off',
            -1 => 'On',
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
        Description => 'Aperture',
        Priority => 0,
        # approximate big translation table by simple calculation - PH
        ValueConv => '$val ? exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2) : undef()',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    22 => [
        {
            Name => 'ExposureTime',
            Description => 'Shutter Speed',
            # encoding is different for 20D and 350D (darn!)
            Condition => '$self->{CameraModel} =~ /\b(20D|350D|REBEL XT)/',
            Priority => 0,
            # approximate big translation table by simple calculation - PH
            ValueConv => '$val ? exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))*1000/32 : undef()',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*32/1000)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'eval $val',
        },
        {
            Name => 'ExposureTime',
            Description => 'Shutter Speed',
            Priority => 0,
            # approximate big translation table by simple calculation - PH
            ValueConv => '$val ? exp(-Image::ExifTool::Canon::CanonEv($val)*log(2)) : undef()',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'eval $val',
        },
    ],
    24 => {
        Name => 'BulbDuration',
        Format => 'int32s',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    27 => {
        Name => 'AutoRotate',
        PrintConv => {
           -1 => 'Rotated by Software',
            0 => 'None',
            1 => 'Rotate 90',
            2 => 'Rotate 180',
            3 => 'Rotate 270',
        },
    },
    29 => {
        Name => 'Self-timer2',
        ValueConv => '$val >= 0 ? $val / 10 : undef()',
        ValueConvInv => '$val',
    },
);

# picture information (MakerNotes tag 0x12)
%Image::ExifTool::Canon::PictureInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    2 => 'CanonImageWidth',
    3 => 'CanonImageHeight',
    4 => 'CanonImageWidthAsShot',
    5 => 'CanonImageHeightAsShot',
    22 => {
        Name => 'AFPointsUsed',
        # this works for my Rebel -- bits 6-0 correspond to focus points 1-7 respectively - PH
        PrintConv => 'Image::ExifTool::Canon::PrintAFPoints($val)',
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
# this value is always 2
#    1 => {
#        Name => 'PreviewImageUnknown',
#    },
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
        Format => 'rational32s',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    8 => {
        Name => 'PreviewFocalPlaneYResolution',
        Format => 'rational32s',
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
            Condition => '$self->{CameraModel} =~ /\b20D/',
            Format => 'int32u',
            # Thanks to Juha Eskelinen for figuring this out:
            # this is an odd bit mapping -- it looks like the file number exists as a
            # 16-bit integer containing the high bits, followed by an 8-bit integer
            # with the low bits.  But it is more convenient to have this in a single
            # word, so some bit manipulations are necessary...
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
                return ($d << 6) + (($f & 0xff)<<16) + (($f >> 8) & 0x3f);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #7
            Name => 'ShutterCount',
            Condition => '$self->{CameraModel} =~ /\b1Ds? Mark II/',
            Format => 'int32u',
            ValueConv => '($val>>16)|(($val&0xffff)<<16)',
            ValueConvInv => '($val>>16)|(($val&0xffff)<<16)',
        },
        { #7
            Name => 'ShutterCount',
            Condition => '$self->{CameraModel} =~ /\b1DS?$/',
            Format => 'int32u',
        },
    ],
);

# color information (MakerNotes tag 0xa0)
%Image::ExifTool::Canon::ColorInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    9 => 'ColorTemperature', #6
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

# White balance information (MakerNotes tag 0xa9)
# these values are potentially useful to users of dcraw...
%Image::ExifTool::Canon::WhiteBalance = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    # Note: Don't make this table writable because the absolute values
    # of the numerator/denominators are crutial for generating the RAW
    # image, and they aren't preserved when written as a simple rational
    FORMAT => 'rational16u',
    FIRST_ENTRY => 0,
    PRINT_CONV => 'sprintf("%.5f",$val)',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # red,green1,green2,blue (ref 2)
    0 => 'RedBalanceAuto',
    1 => 'BlueBalanceAuto',
    2 => 'RedBalanceDaylight',
    3 => 'BlueBalanceDaylight',
    4 => 'RedBalanceCloudy',
    5 => 'BlueBalanceCloudy',
    6 => 'RedBalanceTungsten',
    7 => 'BlueBalanceTungsten',
    8 => 'RedBalanceFluorescent',
    9 => 'BlueBalanceFluorescent',
    10 => 'RedBalanceFlash',
    11 => 'BlueBalanceFlash',
    12 => 'RedBalanceCustom',
    13 => 'BlueBalanceCustom',
    14 => 'RedBalanceB&W',
    15 => 'BlueBalanceB&W',
    16 => 'RedBalanceShade',
    17 => 'BlueBalanceShade',
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
            2 => 'FocalUnits',
        },
        ValueConv => '$val[2] ? $val[0] / $val[2] : undef()',
        PrintConv => 'Image::ExifTool::Canon::PrintFocalRange(@val)',
    },
    Lens35efl => {
        Description => 'Lens',
        Require => {
            0 => 'ShortFocal',
            1 => 'LongFocal',
            2 => 'FocalUnits',
            4 => 'Lens',
        },
        Desire => {
            3 => 'ScaleFactor35efl',
        },
        ValueConv => '$val[4] * ($val[3] ? $val[3] : 1)',
        PrintConv => '$valPrint[4] . ($val[3] ? sprintf(" (35mm equivalent: %s)",Image::ExifTool::Canon::PrintFocalRange(@val)) : "")',
    },
    ShootingMode => {
        Require => {
            0 => 'CanonExposureMode',
            1 => 'EasyMode',
        },
        ValueConv => '$val[0] ? $val[0] : $val[1] + 10',
        PrintConv => '$val[0] ? $valPrint[0] : $valPrint[1]',
    },
    FlashType => {
        Require => {
            0 => 'FlashBits',
        },
        ValueConv => '$val[0] ? ($val[0]&(1<<14)? 1 : 0) : undef()',
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
        ValueConv => '$val[1] ? (($val[0]==3 or $val[0]==4 or $val[0]==6) ? 1 : 0) : undef()',
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
        ValueConv => '$val[1] ? $val[0] : undef()',
        PrintConv => '$valPrint[0]',
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
        ValueConv => '$val[1] ? (defined($val[0]) ? $val[0] : 0) : undef()',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::Canon::Composite);


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
    return 0 if $size < 46; # must be at least 46 bytes long
    my $w1 = Image::ExifTool::Get16u($dataPt, $offset + 4);
    my $h1 = Image::ExifTool::Get16u($dataPt, $offset + 6);
    my $w2 = Image::ExifTool::Get16u($dataPt, $offset + 8);
    my $h2 = Image::ExifTool::Get16u($dataPt, $offset + 10);
    return 0 unless $h1 and $w1 and $h2 and $w2;
    # validate by checking picture aspect ratio
    return 0 if $w1 eq $h1;
    my ($f1, $f2) = ($w1/$h1, $w2/$h2);
    return 1 if abs(1-$f1/$f2) < 0.01;
    return 1 if abs(1-$f1*$f2) < 0.01;
    return 0;
}

#------------------------------------------------------------------------------
# Print range of focal lengths
# Inputs: 0) short focal, 1) long focal, 2) focal units, 3) optional scaling factor
sub PrintFocalRange(@)
{
    my ($short, $long, $units, $scale) = @_;

    $scale and $units /= $scale;    # correct for 35efl scaling factor if given
    if ($short == $long) {
        return sprintf("%.1fmm", $short / $units);
    } else {
        return sprintf("%.1f - %.1fmm", $short / $units, $long / $units);
    }
}

#------------------------------------------------------------------------------
# Print auto focus points
# Inputs: 0) value to convert
sub PrintAFPoints($)
{
    my $val = shift;
    my @p;
    foreach (1..7) {
        $val&1<<(7-$_) and push(@p,$_);
    }
    return sprintf("%d (%s)",scalar @p,join(",",@p));
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
1;  # end

__END__

=head1 NAME

Image::ExifTool::Canon - Definitions for Canon EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Canon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html

=item http://www.wonderland.org/crw/

=item (...plus lots of testing with my own camera!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks Michael Rommel and Daniel Pittman for the information they provided
about the Digital Ixus and PowerShot S70 cameras, Juha Eskelinen for
figuring out the 20D FileNumber, and Denny Priebe for figuring out a couple
of 1D tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Canon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
