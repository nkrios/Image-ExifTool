#------------------------------------------------------------------------------
# File:         Olympus.pm
#
# Description:  Definitions for Olympus/Epson EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#               11/11/2004 - P. Harvey Added Epson support
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) http://www.cybercom.net/~dcoffin/dcraw/
#               3) http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html
#               4) Markku HŠnninen private communication (tests with E-1)
#               5) RŽmi Guyomarch from http://forums.dpreview.com/forums/read.asp?forum=1022&message=12790396
#               6) Frank Ledwon private communication (tests with E/C-series cameras)
#               7) Michael Meissner private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Olympus;

use strict;
use vars qw($VERSION);

$VERSION = '1.17';

my %offOn = ( 0 => 'Off', 1 => 'On' );

%Image::ExifTool::Olympus::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
#
# Tags 0x0000 through 0x0103 are the same as Konica/Minolta cameras (ref 3)
#
    0x0000 => 'MakerNoteVersion',
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        Name => 'PreviewImageData',
        Writable => 0,
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 0,
        Protected => 2,
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 0,
        Protected => 2,
    },
    0x0100 => {
        Name => 'ThumbnailImage',
        Writable => 'undef',
        WriteCheck => '$self->CheckImage(\$val)',
        ValueConv => '\$val',
        ValueConvInv => '$val',
    },
    0x0101 => {
        Name => 'ColorMode',
        Writable => 'int16u',
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
        Writable => 'int16u',
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
        Writable => 'int16u',
        PrintConv => {
            0 => 'Raw',
            1 => 'Superfine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
#
# end Konica/Minolta tags
#
    0x0200 => {
        Name => 'SpecialMode',
        Notes => q{3 numbers: 1. Shooting mode: 0=Normal, 2=Fast, 3=Panorama;
                   2. Sequence Number; 3. Panorama Direction: 1=Left-Right,
                   2=Right-Left, 3=Bottom-Top, 4=Top-Bottom},
        Writable => 'int32u',
        Count => 3,
        PrintConv => q{ #3
            my @v = split /\s+/, $val;
            return $val unless @v >= 3;
            my @v0 = ('Normal','Unknown (1)','Fast','Panorama');
            my @v2 = ('(none)','Left to Right','Right to Left','Bottom to Top','Top to Bottom');
            $val = $v0[$v[0]] || "Unknown ($v[0])";
            $val .= ", Sequence: $v[1]";
            $val .= ', Panorama: ' . ($v2[$v[2]] || "Unknown ($v[2])");
            return $val;
        },
    },
    0x0201 => [
        {
            # for some reason, the values for the E-1/E-300 start at 1 instead of 0
            Condition => '$self->{CameraModel} =~ /^(E-1|E-300)/',
            Name => 'Quality',
            Description => 'Image Quality',
            Writable => 'int16u',
            PrintConv => { 1 => 'SQ', 2 => 'HQ', 3 => 'SHQ', 4 => 'RAW' },
        },
        {
            # all other models...
            Name => 'Quality',
            Description => 'Image Quality',
            Writable => 'int16u',
            # 6 = RAW for C5060WZ
            PrintConv => { 0 => 'SQ', 1 => 'HQ', 2 => 'SHQ', 6 => 'RAW' },
        },
    ],
    0x0202 => {
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Super Macro', #6
        },
    },
    0x0203 => { #6
        Name => 'BWMode',
        Description => 'Black & White Mode',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x0204 => {
        Name => 'DigitalZoom',
        Writable => 'rational32u',
        PrintConv => '$val=~/\./ or $val.=".0"; $val',
        PrintConvInv => '$val',
    },
    0x0205 => { #6
        Name => 'FocalPlaneDiagonal',
        Writable => 'rational32u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s+.*//;$val',
    },
    0x0207 => {
        Name => 'FirmwareVersion',
        Writable => 'string',
    },
    0x0208 => {
        Name => 'PictureInfo',
        Writable => 'string',
    },
    0x0209 => {
        Name => 'CameraID',
        Format => 'string', # this really should have been a string
    },
    0x020b => {
        Name => 'EpsonImageWidth', #PH
        Writable => 'int16u',
    },
    0x020c => {
        Name => 'EpsonImageHeight', #PH
        Writable => 'int16u',
    },
    0x020d => 'EpsonSoftware', #PH
    0x0300 => 'PreCaptureFrames', #6
    0x0302 => { #6
        Name => 'OneTouchWB',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (Preset)',
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
        Name => 'DataDump',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0f01 => { #6
        Name => 'DataDump2',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x1004 => {
        Name => 'FlashMode', #3
        Writable => 'int16u',
    },
    0x1005 => { #6
        Name => 'FlashDevice',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'Internal',
            4 => 'External',
            5 => 'Internal + External',
        },
    },
    0x1006 => 'Bracket', #3
    0x100b => 'FocusMode', #3
    0x100c => 'FocusDistance', #3
    0x100d => 'Zoom', #3
    0x100e => 'MacroFocus', #3
    0x100f => { #3
        Name => 'SharpnessFactor',
        Writable => 'int16u',
    },
    0x1011 => { #3
        Name => 'ColorMatrix',
        Writable => 'int16u',
        Count => 6,
    },
    0x1012 => { #3
        Name => 'BlackLevel',
        Writable => 'int16u',
        Count => 4,
    },
    0x1015 => 'WhiteBalance', #3
    0x1017 => { #2
        Name => 'RedBalance',
        Writable => 'int16u',
        Count => 2,
        ValueConv => '$val=~s/ .*//; $val / 256',
        ValueConvInv => '$val*=256;"$val 64"',
    },
    0x1018 => { #2
        Name => 'BlueBalance',
        Writable => 'int16u',
        Count => 2,
        ValueConv => '$val=~s/ .*//; $val / 256',
        ValueConvInv => '$val*=256;"$val 64"',
    },
    0x101a => 'SerialNumber', #3
    0x1023 => 'FlashBias', #3
    0x1029 => { #3
        Name => 'Contrast',
        Writable => 'int16u',
    },
    0x102a => { #3
        Name => 'SharpnessFactor',
        Writable => 'int16u',
    },
    0x102b => { #3
        Name => 'ColorControl',
        Writable => 'int16u',
        Count => 6,
    },
    0x102c => { #3
        Name => 'ValidBits',
        Writable => 'int16u',
        Count => 2,
    },
    0x102d => { #3
        Name => 'CoringFilter',
        Writable => 'int16u',
    },
    0x102e => { #PH
        Name => 'OlympusImageWidth',
        Writable => 'int32u',
    },
    0x102f => { #PH
        Name => 'OlympusImageHeight',
        Writable => 'int32u',
    },
    0x1034 => 'CompressionRatio', #3
    0x1035 => { #6
        Name => 'PreviewImageValid',
        Writable => 'int32u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x1036 => { #6
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x1037, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x1037 => { #6
        Name => 'PreviewImageLength',
        OffsetPair => 0x1036, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
# 
# Olympus really screwed up the format of the following subdirectories (for the
# E-1 and E-300 anyway). Not only is the subdirectory value data not included in
# the size, but also the count is 2 bytes short for the subdirectory itself
# (presumably the Olympus programmers forgot about the 2-byte entry count at the
# start of the subdirectory).  This mess is straightened out and these subdirs
# are written properly when ExifTool rewrites the file. - PH
# 
    0x2010 => { #PH
        Name => 'Equipment',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Equipment',
            ByteOrder => 'Unknown',
        },
    },
    0x2020 => { #PH
        Name => 'CameraSettings',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::CameraSettings',
            ByteOrder => 'Unknown',
        },
    },
    0x2030 => { #PH
        Name => 'RawDevelopment',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::RawDevelopment',
            ByteOrder => 'Unknown',
        },
    },
    0x2040 => { #PH
        Name => 'ImageProcessing',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::ImageProcessing',
            ByteOrder => 'Unknown',
        },
    },
    0x2050 => { #PH
        Name => 'FocusInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::FocusInfo',
            ByteOrder => 'Unknown',
        },
    },
);

# Subdir 1
%Image::ExifTool::Olympus::Equipment = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'EquipmentVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x100 => { #PH
        Name => 'FirmwareVersion2',
        Writable => 'string',
        Count => 6,
    },
    0x101 => { #PH
        Name => 'SerialNumber',
        Writable => 'string',
        Count => 32,
        PrintConv => '$val=~s/\s+$//;$val',
        PrintConvInv => 'pack("A31",$val)', # pad with spaces to 31 chars
    },
    0x103 => { #6
        Name => 'FocalPlaneDiagonal',
        Writable => 'rational32u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s+.*//;$val',
    },
    0x104 => { #6
        Name => 'BodyFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=~s/\.//;hex($val)',
    },
    0x201 => { #6
        Name => 'Lens',
        Writable => 'int8u',
        Count => 6,
        Notes => '6 numbers: 1. Make, 2. Unknown, 3. Model, 4. Release, 5-6. Unknown',
        PrintConv => 'Image::ExifTool::Olympus::PrintLensInfo($val,"Lens")',
    },
    # apparently the first 3 digits of the lens s/n give the type (ref 4):
    # 010 = 50macro
    # 040 = EC-14
    # 050 = 14-54
    # 060 = 50-200
    # 080 = EX-25
    # 101 = FL-50
    0x202 => { #PH
        Name => 'LensSerialNumber',
        Writable => 'string',
        Count => 32,
        PrintConv => '$val=~s/\s+$//;$val',
        PrintConvInv => 'pack("A31",$val)', # pad with spaces to 31 chars
    },
    0x204 => { #6
        Name => 'LensFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=~s/\.//;hex($val)',
    },
    0x206 => { #5
        Name => 'MaxApertureAtMaxFocal',
        Writable => 'int16u',
        ValueConv => '$val ? sqrt(2)**($val/256) : 0',
        ValueConvInv => '$val>0 ? int(512*log($val)/log(2)+0.5) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x207 => { #PH
        Name => 'MinFocalLength',
        Writable => 'int16u',
    },
    0x208 => { #PH
        Name => 'MaxFocalLength',
        Writable => 'int16u',
    },
    0x301 => { #6
        Name => 'Extender',
        Writable => 'int8u',
        Count => 6,
        Notes => '6 numbers: 1. Make, 2. Unknown, 3. Model, 4. Release, 5-6. Unknown',
        PrintConv => 'Image::ExifTool::Olympus::PrintLensInfo($val,"Extender")',
    },
    0x302 => { #4
        Name => 'ExtenderSerialNumber',
        Writable => 'string',
        Count => 32,
    },
    0x304 => { #6
        Name => 'ExtenderFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=~s/\.//;hex($val)',
    },
    0x1000 => { #6
        Name => 'FlashType',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            2 => 'Simple E-System',
            3 => 'E-System',
        },
    },
    0x1001 => { #6
        Name => 'FlashModel',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'FL-20',
            2 => 'FL-50',
            3 => 'RF-11',
            4 => 'TF-22',
            5 => 'FL-36',
        },
    },
    0x1003 => { #4
        Name => 'FlashSerialNumber',
        Writable => 'string',
        Count => 32,
    },
    0x1004 => { #6
        Name => 'FlashFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=~s/\.//;hex($val)',
    },
);

# Subdir 2
%Image::ExifTool::Olympus::CameraSettings = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'CameraSettingsVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x100 => { #6
        Name => 'PreviewImageValid',
        Writable => 'int32u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x101 => { #PH
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x102,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x102 => { #PH
        Name => 'PreviewImageLength',
        OffsetPair => 0x101,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x200 => { #4
        Name => 'ExposureMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Manual',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Program AE',
        }
    },
    0x202 => { #PH/4
        Name => 'MeteringMode',
        Writable => 'int16u',
        PrintConv => {
            2 => 'Center Weighted',
            3 => 'Spot',
            5 => 'ESP',
        },
    },
    0x300 => { #6
        Name => 'MacroMode',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x301 => { #6
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Single AF',
            1 => 'Sequential shooting AF',
            2 => 'Continuous AF',
            3 => 'Multi AF',
            10 => 'MF',
        },
    },
    0x302 => { #6
        Name => 'FocusProcess',
        Writable => 'int16u',
        PrintConv => {
            0 => 'AF Not Used',
            1 => 'AF Used',
        },
    },
    0x303 => { #6
        Name => 'AFSearch',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Not Ready',
            1 => 'Ready',
        },
    },
    0x304 => { #PH/4
        Name => 'AFAreas',
        Format => 'int32u',
        Count => 64,
        PrintConv => 'Image::ExifTool::Olympus::PrintAFAreas($val)',
    },
    0x400 => { #6
        Name => 'FlashMode',
        Writable => 'int16u',
    },
    0x401 => { #6
        Name => 'FlashExposureCompensation',
        Writable => 'rational32s',
    },
    0x501 => { #PH/4
        Name => 'WhiteBalanceTemperature',
        Writable => 'int16u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/^\d+$/ ? $val : 0',
    },
    0x502 => {  #PH/4
        Name => 'WhiteBalanceBracket',
        Writable => 'int16s',
    },
    0x503 => { #PH/4
        Name => 'CustomSaturation',
        Writable => 'int16s',
        Count => 3,
        Notes => '3 numbers: 1. CS Value, 2. Min, 3. Max',
        PrintConv => 'my ($a,$b,$c)=split /\s+/,$val; $a-=$b; $c-=$b; "CS$a (min CS0, max CS$c)"',
    },
    0x504 => { #PH/4
        Name => 'ModifiedSaturation',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'CM1 (Red Enhance)',
            2 => 'CM2 (Green Enhance)',
            3 => 'CM3 (Blue Enhance)',
            4 => 'CM4 (Skin Tones)',
        },
    },
    0x505 => { #PH/4
        Name => 'ContrastSetting',
        Writable => 'int16s',
        Count => 3,
        Notes => '3 numbers: 1. Contrast, 2. Min, 3. Max',
        PrintConv => 'my @v=split /\s+/,$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=$tr/-0-9 //dc;$val',
    },
    0x506 => { #PH/4
        Name => 'SharpnessSetting',
        Writable => 'int16s',
        Count => 3,
        Notes => '3 numbers: 1. Sharpness, 2. Min, 3. Max',
        PrintConv => 'my @v=split /\s+/,$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=$tr/-0-9 //dc;$val',
    },
    0x507 => { #PH/4
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => { #6
            0 => 'sRGB',
            1 => 'Adobe RGB',
            2 => 'Pro Photo RGB',
        },
    },
    0x509 => { #6
        Name => 'SceneMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Standard',
            7 => 'Sport',
            8 => 'Portrait',
            9 => 'Landscape+Portrait',
            10 => 'Landscape',
            11 => 'Night scene',
            17 => 'Night+Portrait',
            19 => 'Fireworks',
            20 => 'Sunset',
            22 => 'Macro',
            25 => 'Documents',
            26 => 'Museum',
            28 => 'Beach&Snow',
            30 => 'Candle',
            39 => 'High Key',
        },
    },
    0x50a => { #PH/4/6
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Noise Reduction On',
            2 => 'Noise Filter On',
            3 => 'Noise Reduction + Noise Filter On',
        },
    },
    0x50b => { #6
        Name => 'DistortionCorrection',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x50c => { #PH/4
        Name => 'ShadingCompensation',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x50d => { #PH/4
        Name => 'CompressionFactor',
        Writable => 'rational32u',
    },
    0x50f => { #6
        Name => 'Gradation',
        Writable => 'int16s',
        PrintConv => {
           -1 => 'Low Key',
            0 => 'Normal',
            1 => 'High Key',
        },
    },
    0x600 => { #PH/4
        Name => 'Sequence',
        Writable => 'int16u',
        Count => 2,
        Notes => '2 numbers: 1. Mode, 2. Sequence Number',
        PrintConv => q{
            my ($a,$b) = split /\s+/,$val;
            return 'Single Shot' unless $a;
            my %a = (
                1 => 'Continuous Shooting',
                2 => 'Exposure Bracketing',
                3 => 'White Balance Bracketing',
            );
            return ($a{$a} || "Unknown ($a)") . ', Shot ' . $b;
        },
    },
    0x603 => { #PH/4
        Name => 'ImageQuality2',
        Writable => 'int16u',
        PrintConv => {
            1 => 'SQ',
            2 => 'HQ',
            3 => 'SHQ',
            4 => 'RAW',
        },
    },
);

# Subdir 3
%Image::ExifTool::Olympus::RawDevelopment = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'RawDevVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x100 => { #6
        Name => 'RawDevExposureBiasValue',
        Writable => 'rational32s',
    },
    0x101 => { #6
        Name => 'RawDevWhiteBalanceValue',
        Writable => 'int16u',
    },
    0x102 => { #6
        Name => 'RawDevWBFineAdjustment',
        Writable => 'int16s',
    },
    0x103 => { #6
        Name => 'RawDevGrayPoint',
        Writable => 'int16u',
        Count => 3,
    },
    0x104 => { #6
        Name => 'RawDevSaturationEmphasis',
        Writable => 'int16s',
        Count => 3,
    },
    0x105 => { #6
        Name => 'RawDevMemoryColorEmphasis',
        Writable => 'int16u',
    },
    0x106 => { #6
        Name => 'RawDevContrastValue',
        Writable => 'int16s',
        Count => 3,
    },
    0x107 => { #6
        Name => 'RawDevSharpnessValue',
        Writable => 'int16s',
        Count => 3,
    },
    0x108 => { #6
        Name => 'RawDevColorSpace',
        Writable => 'int16u',
    },
    0x109 => { #6
        Name => 'RawDevEngine',
        Writable => 'int16u',
    },
    0x10A => { #6
        Name => 'RawDevNoiseReduction',
        Writable => 'int16u',
    },
    0x10B => { #6
        Name => 'RawDevEditStatus',
        Writable => 'int16u',
    },
    0x10C => { #6
        Name => 'RawDevSettings',
        Writable => 'int16u',
    },
);

# Subdir 4
%Image::ExifTool::Olympus::ImageProcessing = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'ImageProcessingVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x100 => { #6
        Name => 'RedBlueBias',
        Writable => 'int16u',
        Count => 2,
    },
    0x200 => { #6
        Name => 'ColorMatrix',
        Writable => 'int16u',
        Count => 9,
    },
    0x300 => { #PH/4
        Name => 'SmoothingParameter1',
        Writable => 'int16u',
    },
    0x310 => { #PH/4
        Name => 'SmoothingParameter2',
        Writable => 'int16u',
    },
    0x600 => { #PH/4
        Name => 'SmoothingThresholds',
        Writable => 'int16u',
        Count => 4,
    },
    0x610 => { #PH/4
        Name => 'SmoothingThreshold2',
        Writable => 'int16u',
    },
    0x611 => { #4/6
        Name => 'ValidBits',
        Writable => 'int16u',
        Count => 2,
    },
    0x614 => { #PH
        Name => 'OlympusImageWidth2',
        Writable => 'int32u',
    },
    0x615 => { #PH
        Name => 'OlympusImageHeight2',
        Writable => 'int32u',
    },
    0x1010 => { #PH/4
        Name => 'NoiseFilter2',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Noise Filter',
            2 => 'Noise Reduction',
        },
    },
    0x1012 => { #PH/4
        Name => 'ShadingCompensation2',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
);

# Subdir 5
%Image::ExifTool::Olympus::FocusInfo = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'FocusInfoVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x209 => { #PH/4
        Name => 'AutoFocus',
        Writable => 'int16u',
        PrintConv => \%offOn,
        Unknown => 1, #6
    },
    0x300 => { #6
        Name => 'ZoomPosition',
        Writable => 'int16u',
    },
    # 0x301 Related to inverse of focus distance
    0x305 => { #4
        Name => 'FocusDistance',
        # this rational value looks like it is in mm when the denominator is
        # 1 (E-1), and cm when denominator is 10 (E-300), so if we ignore the
        # denominator we are consistently in mm - PH
        Format => 'int32u',
        Count => 2,
        PrintConv => q{
            my ($a,$b) = split /\s+/,$val;
            return "inf" if $a == 0xffffffff;
            return $a / 1000 . ' m';
        },
        PrintConvInv => q{
            return '4294967295 1' if $val =~ /inf/i;
            $val =~ s/\s.*//;
            $val = int($val * 1000 + 0.5);
            return "$val 1";
        },
    },
    # 0x31a Continuous AF parameters?
    # 0x1200-0x1209 Flash information:
    0x1201 => { #6
        Name => 'ExternalFlash',
        Writable => 'int16u',
        Count => 2,
        PrintConv => {
            '0 0' => 'Off',
            '1 0' => 'On',
        },
    },
    0x1208 => { #6
        Name => 'InternalFlash',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    # 0x102a same as Subdir4-0x300
);

#------------------------------------------------------------------------------
# Print lens information (ref 6)
# Inputs: 0) Lens info (string of integers), 1) 'Lens' or 'Extender'
sub PrintLensInfo($$)
{
    my ($val, $type) = @_;
    my @info = split /\s+/, $val;
    return "Unknown ($val)" unless @info >= 4;
    return 'None' unless $info[2];
    my %make = (
        0 => 'Olympus',
        1 => 'Sigma',
    );
    my %model = (
        Lens => {
            0 => { # Olympus lenses
                1 => 'Zuiko Digital ED 50mm F2.0 Macro',
                2 => 'Zuiko Digital ED 150mm F2.0',
                3 => 'Zuiko Digital ED 300mm F2.8',
                5 => 'Zuiko Digital 14-54mm F2.8-3.5',
                6 => 'Zuiko Digital ED 50-200mm F2.8-3.5',
                7 => 'Zuiko Digital 11-22mm F2.8-3.5',
                21 => 'Zuiko Digital ED 7-14mm F4.0',
                24 => 'Zuiko Digital 14-45mm F3.5-5.6',
            },
            1 => { # Sigma lenses
                2 => '55-200mm F4.0-5.6 DC',
                3 => '18-125mm F3.5-5.6 DC',
                4 => '18-125mm F3.5-5.6', # (ref 7)
            },
        },
        Extender => {
            0 => { # Olympus extenders
                4 => 'Zuiko Digital EC-14 1.4x Teleconverter',
                8 => 'EX-25 Extension Tube',
            },
        },
    );
    my %release = (
        0 => '(production)',
        1 => '(pre-release)',
    );
    my $make = $make{$info[0]} || "Unknown Make ($info[0])";
    my $model = $model{$type}->{$info[0]}->{$info[2]} || "Unknown Model ($info[2])";
    my $rel = $release{$info[3]} || "Unknown Release ($info[3])";
    return "$make $model $rel";
}

#------------------------------------------------------------------------------
# Print AF points
# Inputs: 0) AF point data (string of integers)
# Notes: I'm just guessing that the 2nd and 4th bytes are the Y coordinates,
# and that more AF points will show up in the future (derived from E-1 images,
# and the E-1 uses just one of 3 possible AF points, all centered in Y) - PH
sub PrintAFAreas($)
{
    my $val = shift;
    my @points = split /\s+/, $val;
    my %afPointNames = (
        0x36794285 => 'Left',
        0x79798585 => 'Center',
        0xBD79C985 => 'Right',
    );
    $val = '';
    my $pt;
    foreach $pt (@points) {
        next unless $pt;
        $val and $val .= ', ';
        $afPointNames{$pt} and $val .= $afPointNames{$pt} . ' ';
        my @coords = unpack('C4',pack('N',$pt));
        $val .= "($coords[0],$coords[1])-($coords[2],$coords[3])";
    }
    $val or $val = 'none';
    return $val;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::Olympus - Definitions for Olympus/Epson maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Olympus or Epson maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Markku Hanninen, Remi Guyomarch, Frank Ledwon and Michael Meissner
for their help figuring out some Olympus tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Olympus Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
