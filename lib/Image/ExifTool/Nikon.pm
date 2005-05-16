#------------------------------------------------------------------------------
# File:         Nikon.pm
#
# Description:  Definitions for Nikon EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#               05/17/2004 - P. Harvey Added information from Joseph Heled
#               09/21/2004 - P. Harvey Changed tag 2 to ISOUsed & added PrintConv
#               12/01/2004 - P. Harvey Added default PRINT_CONV
#               12/06/2004 - P. Harvey Added SceneMode
#               01/01/2005 - P. Harvey Decode preview image and preview IFD
#               03/35/2005 - T. Christiansen additions
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Joseph Heled private communication (tests with D70)
#               3) Thomas Walter private communication (tests with Coolpix 5400)
#               4) http://www.cybercom.net/~dcoffin/dcraw/
#               5) Brian Ristuccia private communication (tests with D70)
#               6) Danek Duvall private communication (tests with D70)
#               7) Tom Christiansen private communication (tchrist@perl.com)
#               8) Robert Rottmerhusen private communication
#               9) http://members.aol.com/khancock/pilot/nbuddy/
#------------------------------------------------------------------------------

package Image::ExifTool::Nikon;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.22';

%Image::ExifTool::Nikon::Main = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikon,
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRINT_CONV => 'Image::ExifTool::Nikon::FormatString($val)',
    0x0001 => { #2
        # the format differs for different models.  for D70, this is a string '0210',
        # but for the E775 it is binary: "\x00\x01\x00\x00"
        Name => 'FileSystemVersion',
        Writable => 'undef',
        # convert to string if binary
        ValueConv => '$_=$val; /^[\x00-\x09]/ and $_=join("",unpack("CCCC",$_)); $_',
        ValueConvInv => '$val',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_',
        PrintConvInv => '$_=$val;s/\.//;"0$_"',
    },
    # 0x0001 - unknown. Always 0210 for D70. Might be a version number? (ref 2)
    0x0002 => {
        # this is the ISO actually used by the camera
        # (may be different than ISO setting if auto)
        Name => 'ISO',
        Description => 'ISO Speed',
        Writable => 'int16u',
        Priority => 0,  # the EXIF ISO is more reliable
        Count => 2,
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    0x0003 => 'ColorMode',
    0x0004 => 'Quality',
    0x0005 => 'WhiteBalance',
    0x0006 => 'Sharpness',
    0x0007 => 'FocusMode',
    0x0008 => 'FlashSetting',
    # FlashType shows 'Built-in,TTL' when builtin flash fires,
    # and 'Optional,TTL' when external flash is used (ref 2)
    0x0009 => 'FlashType', #2
    0x000b => { #2
        Name => 'WhiteBalanceFineTune',
        Writable => 'int16u',
    },
    0x000c => 'ColorBalance1',
    # 0x000e last 3 bytes '010c00', first byte changes from shot to shot.
    0x000f => 'ISOSelection', #2
    0x0010 => {
        Name => 'DataDump',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0011 => {
        Name => 'NikonPreview',
        Groups => { 1 => 'NikonPreview', 2 => 'Image' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewImage',
            Start => '$val',
        },
    },
    0x0012 => { #2
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Format => 'int32s',
        # just the top byte, signed
        PrintConv => 'use integer;$val>>=24;no integer;sprintf("%.1f",$val/6)',
    },
    # D70 - another ISO tag
    0x0013 => { #2
        Name => 'ISOSetting',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    # D70 Image boundary?? top x,y bot-right x,y
    0x0016 => 'ImageBoundary', #2
    0x0018 => { #5
        Name => 'FlashExposureBracketValue',
        Format => 'int32s',
        # just the top byte, signed
        PrintConv => 'sprintf("%.1f",($val >> 24)/6)',
    },
    0x0019 => { #5
        Name => 'ExposureBracketValue',
        Format => 'rational32s',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x001d => { #4
        Name => 'SerialNumber',
        Writable => 0,
        Notes => 'Not writable because this value is used as a key to decrypt other information',
        ValueConv => '$self->{NikonInfo}->{SerialNumber} = $val',
        ValueConvInv => '$val',
    },
    0x0080 => 'ImageAdjustment',
    0x0081 => 'ToneComp', #2
    0x0082 => 'AuxiliaryLens',
    0x0083 => {
        Name => 'LensType',
        Writable => 'int8u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        PrintConv => q[$_ = $val ? Image::ExifTool::Exif::DecodeBits($val,
            {
                0 => 'MF',
                1 => 'D',
                2 => 'G',
                3 => 'VR',
            }) : 'AF';
            # remove commas and change "D G" to just "G"
            s/,//g; s/\bD G\b/G/; $_
        ],
        PrintConvInv => q[
            my $bits = 0;
            $bits |= 0x01 if $val =~ /\bMF\b/i;
            $bits |= 0x02 if $val =~ /\bD\b/i;
            $bits |= 0x06 if $val =~ /\bG\b/i;
            $bits |= 0x08 if $val =~ /\bVR\b/i;
            return $bits;
        ],
    },
    0x0084 => { #2
        Name => "Lens",
        Writable => 'rational32u',
        Count => 4,
        # short focal, long focal, aperture at short focal, aperture at long focal
        PrintConv => q{
            my ($a,$b,$c,$d) = split /\s+/, $val;
            ($a==$b ? $a : "$a-$b") . "mm f/" . ($c==$d ? $c : "$c-$d")
        },
        PrintConvInv => '$_=$val; tr/a-z\///d; s/(^|\s)([0-9.]+)(?=\s|$)/$1$2-$2/g; s/-/ /g; $_',
    },
    0x0085 => {
        Name => 'ManualFocusDistance',
        Writable => 'rational32u',
    },
    0x0086 => {
        Name => 'DigitalZoom',
        Writable => 'rational32u',
    },
    0x0087 => { #5
        Name => 'FlashMode',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Did Not Fire',
            8 => 'Fired, Commander Mode',
            9 => 'Fired, TTL Mode',
        },
    },
    0x0088 => {
        Name => 'AFPoint',
        Format => 'int32u',  # override format since int32u is more sensible
        Writable => 'int32u',
        Flags => 'PrintHex',
        PrintConv => {
            0x0000 => 'Center',
            0x0100 => 'Top',
            0x0200 => 'Bottom',
            0x0300 => 'Left',
            0x0400 => 'Right',

            # D70 (ref 2)
            0x0000001 => 'Single Area, Center',
            0x0010002 => 'Single Area, Top',
            0x0020004 => 'Single Area, Bottom',
            0x0030008 => 'Single Area, Left',
            0x0040010 => 'Single Area, Right',

            0x1000001 => 'Dynamic Area, Center',
            0x1010002 => 'Dynamic Area, Top',
            0x1020004 => 'Dynamic Area, Bottom',
            0x1030008 => 'Dynamic Area, Left',
            0x1040010 => 'Dynamic Area, Right',

            0x2000001 => 'Closest Subject, Center',
            0x2010002 => 'Closest Subject, Top',
            0x2020004 => 'Closest Subject, Bottom',
            0x2030008 => 'Closest Subject, Left',
            0x2040010 => 'Closest Subject, Right',
        },
    },
    0x0089 => { #5
        Name => 'ShootingMode',
        Writable => 'int16u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        # The (new?) bit 5 seriously complicates our life here: after firmwareB's
        # 1.03, bit 5 turns on when you ask for BUT DO NOT USE the long-range
        # noise reduction feature, probably because even not using it, it still
        # slows down your drive operation to 50% (1.5fps max not 3fps).  But no
        # longer does !$val alone indicate single-frame operation. - TC
        PrintConv => q[
            $_ = '';
            unless ($val & 0x87) {
                return 'Single-Frame' unless $val;
                $_ = 'Single-Frame, ';
            }
            return $_ . Image::ExifTool::Exif::DecodeBits($val,
            {
                0 => 'Continuous',
                1 => 'Delay',
                2 => 'PC Control',
                4 => 'Exposure Bracketing',
                5 => 'Unused LE-NR Slowdown',
                6 => 'White-Balance Bracketing',
                7 => 'IR Control',
            });
        ],
    },
    0x008b => { #8
        Name => 'LensFStops',
        ValueConv => 'my ($a,$b,$c)=unpack("C3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => 'my $a=int($val*12+0.5);$a<256 ? pack("C4",$a,1,12,0) : undef',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
        Writable => 'undef',
        Count => 4,
    },
    0x008c => {
        Name => 'NEFCurve1',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x008d => 'ColorHue' , #2
    # SceneMode takes on the following values: PORTRAIT, PARTY/INDOOR, NIGHT PORTRAIT,
    # BEACH/SNOW, LANDSCAPE, SUNSET, NIGHT SCENE, MUSEUM, FIREWORKS, CLOSE UP, COPY,
    # BACK LIGHT, PANORAMA ASSIST, SPORT, DAWN/DUSK
    0x008f => 'SceneMode', #2
    # LightSource shows 3 values COLORED SPEEDLIGHT NATURAL.
    # (SPEEDLIGHT when flash goes. Have no idea about difference between other two.)
    0x0090 => 'LightSource', #2
    0x0092 => { #2
        Name => 'HueAdjustment',
        Writable => 'int16s',
    },
    0x0094 => 'Saturation',
    0x0095 => 'NoiseReduction',
    0x0096 => {
        Name => 'NEFCurve2',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x0097 => [ #4
        {
            Condition => '$$valPt =~ /^0100/', # (D100)
            Name => 'ColorBalance0100',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 72',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance0100',
            },
        },
        {
            Condition => '$$valPt =~ /^0102/', # (D2H)
            Name => 'ColorBalance0102',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 10',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance0102',
            },
        },
        {
            Condition => '$$valPt =~ /^0103/', # (D70)
            Name => 'ColorBalance0103',
            Writable => 0,
            # D70:  at file offset 'tag-value + base + 20', 4 16 bits numbers,
            # v[0]/v[1] , v[2]/v[3] are the red/blue multipliers.
            SubDirectory => {
                Start => '$valuePtr + 20',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance0103',
            },
        },
        {
            Name => 'ColorBalanceUnknown',
            Writable => 0,
        },
    ],
    0x0098 => [
        { #8
            Condition => '$$valPt =~ /^0101/',
            Name => 'LensData0101',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData',
            },
        },
        # note: his information is encrypted if the version is 02xx
        { #8
            Condition => '$$valPt =~ /^0201/',
            Name => 'LensData0201',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
            },
        },
        {
            Name => 'LensDataUnknown',
        },
    ],
    # D70 guessing here
    0x0099 => { #2
        Name => 'NEFThumbnailSize',
        Writable => 'int16u',
        Count => 2,
    },
    # 0x009a unknown shows '7.8 7.8' on all my shots (ref 2)
    0x00a0 => 'SerialNumber', #2
    0x00a7 => { # Number of shots taken by camera so far (ref 2)
        Name => 'ShutterCount',
        Writable => 0,
        Notes => 'Not writable because this value is used as a key to decrypt other information',
        ValueConv => '$self->{NikonInfo}->{ShutterCount} = $val',
        ValueConvInv => '$val',
    },
    0x00a9 => 'ImageOptimization', #2
    0x00aa => 'Saturation', #2
    0x00ab => 'VariProgram', #2
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    # 0x0e01 I don't know what this is, but in D70 NEF files produced by Nikon
    # Capture, the data for this tag extends 4 bytes past the end of the maker notes.
    # Very odd.  I hope these 4 bytes aren't useful because they will get lost by any
    # utility that just copies the maker notes - PH
    # 0x0e0e is in D70 Nikon Capture files (not out-of-the-camera D70 files) - PH
    0x0e0e => { #PH
        Name => 'NikonCaptureOffsets',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::NikonCaptureOffsets',
            Validate => '$val =~ /^0100/',
            Start => '$valuePtr + 4',
        },
    },
);

# ref PH
%Image::ExifTool::Nikon::NikonCaptureOffsets = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonCaptureOffsets,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'IFD0_Offset',
    2 => 'PreviewIFD_Offset',
    3 => 'SubIFD_Offset',
);

%Image::ExifTool::Nikon::ColorBalance0100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
    1 => {
        Name => 'BlueBalance',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::Nikon::ColorBalance0102 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'rational16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
    1 => {
        Name => 'BlueBalance',
        ValueConv => '$val!=0 ? 1/$val : 0',
        ValueConvInv => '$val!=0 ? 1/$val : 0',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::Nikon::ColorBalance0103 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'rational16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
    1 => {
        Name => 'BlueBalance',
        PrintConv => 'sprintf("%.5f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::Nikon::MakerNotesB = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0003 => {
        Name => 'Quality',
        Description => 'Image Quality',
    },
    0x0004 => 'ColorMode',
    0x0005 => 'ImageAdjustment',
    0x0006 => 'CCDSensitivity',
    0x0007 => 'WhiteBalance',
    0x0008 => 'Focus',
    0x000A => 'DigitalZoom',
    0x000B => 'Converter',
);

# these are standard EXIF tags, but they are duplicated here so we
# can change some names to extract the Nikon preview separately
%Image::ExifTool::Nikon::PreviewImage = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'NikonPreview', 2 => 'Image'},
    0x103 => {
        Name => 'Compression',
        PrintConv => \%Image::ExifTool::Exif::compression,
        Priority => 0,
    },
    0x11a => {
        Name => 'XResolution',
        Priority => 0,
    },
    0x11b => {
        Name => 'YResolution',
        Priority => 0,
    },
    0x128 => {
        Name => 'ResolutionUnit',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
        Priority => 0,
    },
    0x201 => {
        Name => 'PreviewImageStart',
        Flags => [ 'IsOffset', 'Permanent' ],
        OffsetPair => 0x202, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'NikonPreview',
        Protected => 2,
    },
    0x202 => {
        Name => 'PreviewImageLength',
        Flags => 'Permanent' ,
        OffsetPair => 0x201, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'NikonPreview',
        Protected => 2,
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
        Priority => 0,
    },
);

# these are duplicated enough times to make it worthwhile to define them centrally
my %nikonApertureConversions = (
    ValueConv => '2**($val/24)',
    ValueConvInv => '$val>0 ? 24*log($val)/log(2) : 0',
    PrintConv => 'sprintf("%.1f",$val)',
    PrintConvInv => '$val',
);
my %nikonFocalConversions = (
    ValueConv => '5 * 2**($val/24)',
    ValueConvInv => '$val>0 ? 24*log($val/5)/log(2) : 0',
    PrintConv => 'sprintf("%.1fmm",$val)',
    PrintConvInv => '$val=~s/\s*mm$//;$val',
);

# Nikon lens data (note: needs decrypting if LensDataVersion is 0201)
%Image::ExifTool::Nikon::LensData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => q{
Nikon encrypts the LensData information below if LensDataVersion is 0201,
but  the decryption algorithm is known so the information can be extracted.
It isn't yet writable, however, because the encryption adds complications
which make writing more difficult.
    },
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'undef[4]',
    },
    0x05 => { #8
        Name => 'AFAperture',
        %nikonApertureConversions,
    },
    0x08 => 'FocusPosition', #8
    0x09 => { #8/9
        Name => 'FocusDistance',
        ValueConv => '10**($val/40)', # in cm
        ValueConvInv => '$val>0 ? 40*log($val)/log(10) : 0',
        PrintConv => 'sprintf("%.2f m",$val / 100)',
        PrintConvInv => '$val=~s/\s.*//; $val * 100',
    },
    0x0a => { #8/9
        Name => 'FocalLength',
        Priority => 0,
        %nikonFocalConversions,
    },
    0x0b => { #8
        Name => 'LensID',
        PrintConv => {
            2 => 'Unknown Nikkor or Sigma non D-type',
            7 => 'Nikkor AF 28-85/3.5-4.5',
            8 => 'Nikkor AF 35-105/3.5-4.5',
            9 => 'Nikkor AF 24/2.8',
            11 => 'Nikkor AF 180/2.8 IF-ED',
            15 => 'Nikkor AF 50/1.8',
            15 => 'Nikkor AF 50/1.8',
            16 => 'Nikkor AF 300/4 IF-ED',
            19 => 'Nikkor AF 24-50/3.3-4.5',
            20 => 'Nikkor AF 80-200/2.8 ED',
            27 => 'Nikkor AF 75-300/4.5-5.6',
            28 => 'Nikkor AF 20/2.8',
            29 => 'Nikkor AF 35-70/3.3-4.5 N',
            30 => 'Nikkor AF 60/2.8 Micro',
            34 => 'Nikkor AF 70-210/4-5.6 D',
            38 => 'Unkown Nikkor or Sigma D-type',
            42 => 'Nikkor AF 28/1.4 D',
            44 => 'Nikkor AF 105/2 D DC-Nikkor',
            45 => 'Nikkor AF 200/4 D IF-ED Micro',
            47 => 'Nikkor AF 28-70/3.5-4.5 D',
            47 => 'Nikkor AF 20-35/2.8 D IF',
            49 => 'Nikkor AF 60/2.8 D Micro',
            50 => 'Nikkor AF 105/2.8 D Micro',
            51 => 'Nikkor AF 18/2.8 D',
            52 => 'Unknown Nikkor or Tameron',
            54 => 'Nikkor AF 24/2.8 D',
            55 => 'Nikkor AF 20/2.8 D',
            56 => 'Nikkor AF 85/1.8 D',
            59 => 'Nikkor AF 35-70/2.8 D',
            66 => 'Nikkor AF 35/2 D',
            67 => 'Nikkor AF 50/1.4 D',
            69 => 'Nikkor AF 35-80/4-5.6 D',
            72 => 'Nikkor AF-S 300/2.8 D IF-ED',
            74 => 'Nikkor AF 85/1.4 D IF',
            76 => 'Nikkor AF 24-120/3.5-5.6 D IF',
            77 => 'Nikkor AF 28-200/3.5-5.6 D IF',
            78 => 'Nikkor AF 135/2 D DC-Nikkor',
            83 => 'Nikkor AF 80-200/2.8 D ED N',
            84 => 'Nikkor AF 70-180/4.5-5.6 D ED Micro',
            86 => 'Nikkor AF 70-300/4-5.6 D ED',
            93 => 'Nikkor AF-S 28-70/2.8 D IF-ED',
            94 => 'Nikkor AF-S 80-200/2.8 D IF-ED',
            99 => 'Nikkor AF-S 17-35/2.8 D IF-ED',
            101 => 'Nikkor AF 80-400/4.5-5.6 D ED VR',
            102 => 'Nikkor AF 18-35/3.5-4.5 D IF-ED',
            103 => 'Nikkor AF 24-85/2.8-4 D IF',
            104 => 'Nikkor AF 28-80/3.3-5.6 G',
            105 => 'Nikkor AF 70-300/4-5.6 G',
            106 => 'Nikkor AF-S 300/4 D IF-ED',
            109 => 'Nikkor AF-S 300/2.8 D IF-ED II',
            110 => 'Nikkor AF-S 400/2.8 D IF-ED II',
            112 => 'Nikkor AF-S 600/4 D IF-ED',
            114 => 'Nikkor 45mm F/2.8',
            116 => 'Nikkor AF-S 24-85/3.5-4.5 G IF-ED',
            118 => 'Nikkor AF 50/1.8 D',
            119 => 'Nikkor AF-S 70-200/2.8 G IF-ED VR',
            120 => 'Nikkor AF-S 24-120/3.5-5.6 G IF-ED VR',
            121 => 'Nikkor AF 28-200/3.5-5.6 G IF-ED',
            122 => 'Nikkor AF-S 12-24/4 G IF-ED DX',
            123 => 'Nikkor AF-S 200-400/4 G IF-ED VR',
            125 => 'Nikkor AF-S 17-55/2.8 G IF-ED DX',
            127 => 'Nikkor AF-S 18-70/3.5-4.5 G IF-ED DX',
            128 => 'Nikkor AF 10.5/2.8 G ED DX Fisheye',
            129 => 'Nikkor AF-S 200/2 G IF-ED VR',
            130 => 'Nikkor AF-S 300/2.8 G IF-ED VR',
            137 => 'Nikkor 55-200mm F/4-5.6G',
            140 => 'Nikkor 18-55mm F/3.5-5.6G',
        },
    },
    0x0c => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x0d => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x0e => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x0f => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x10 => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x11 => 'MCUVersion', #8
    0x12 => { #8
        Name => 'EffectiveMaxAperture',
        %nikonApertureConversions,
    },
);

# Nikon composite tags
%Image::ExifTool::Nikon::Composite = (
    GROUPS => { 2 => 'Camera' },
    LensSpec => {
        Description => 'Lens',
        Require => {
            0 => 'Nikon:Lens',
            1 => 'Nikon:LensType',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '"$valPrint[0] $valPrint[1]"',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::Nikon::Composite);


#------------------------------------------------------------------------------
# Clean up formatting of string values
# Inputs: 0) string value
# Returns: formatted string value
# - removes trailing spaces and changes case to something more sensible
sub FormatString($)
{
    my $str = shift;
    # limit string length (can be very long for some unknown tags)
    if (length($str) > 60) {
        $str = substr($str,0,55) . "[...]";
    } else {
        $str =~ s/\s+$//;   # remove trailing white space and null terminator
        # Don't change case of hyphenated strings (like AF-S) or non-words (no vowels)
        unless ($str =~ /-/ or $str !~ /[AEIOUY]/) {
            # change all letters but the first to lower case
            $str =~ s/([A-Z]{1})([A-Z]+)/$1\L$2/g;
        }
    }
    return $str;
}

#------------------------------------------------------------------------------
# decoding tables from ref 4
my @xlat = (
  [ 0xc1,0xbf,0x6d,0x0d,0x59,0xc5,0x13,0x9d,0x83,0x61,0x6b,0x4f,0xc7,0x7f,0x3d,0x3d,
    0x53,0x59,0xe3,0xc7,0xe9,0x2f,0x95,0xa7,0x95,0x1f,0xdf,0x7f,0x2b,0x29,0xc7,0x0d,
    0xdf,0x07,0xef,0x71,0x89,0x3d,0x13,0x3d,0x3b,0x13,0xfb,0x0d,0x89,0xc1,0x65,0x1f,
    0xb3,0x0d,0x6b,0x29,0xe3,0xfb,0xef,0xa3,0x6b,0x47,0x7f,0x95,0x35,0xa7,0x47,0x4f,
    0xc7,0xf1,0x59,0x95,0x35,0x11,0x29,0x61,0xf1,0x3d,0xb3,0x2b,0x0d,0x43,0x89,0xc1,
    0x9d,0x9d,0x89,0x65,0xf1,0xe9,0xdf,0xbf,0x3d,0x7f,0x53,0x97,0xe5,0xe9,0x95,0x17,
    0x1d,0x3d,0x8b,0xfb,0xc7,0xe3,0x67,0xa7,0x07,0xf1,0x71,0xa7,0x53,0xb5,0x29,0x89,
    0xe5,0x2b,0xa7,0x17,0x29,0xe9,0x4f,0xc5,0x65,0x6d,0x6b,0xef,0x0d,0x89,0x49,0x2f,
    0xb3,0x43,0x53,0x65,0x1d,0x49,0xa3,0x13,0x89,0x59,0xef,0x6b,0xef,0x65,0x1d,0x0b,
    0x59,0x13,0xe3,0x4f,0x9d,0xb3,0x29,0x43,0x2b,0x07,0x1d,0x95,0x59,0x59,0x47,0xfb,
    0xe5,0xe9,0x61,0x47,0x2f,0x35,0x7f,0x17,0x7f,0xef,0x7f,0x95,0x95,0x71,0xd3,0xa3,
    0x0b,0x71,0xa3,0xad,0x0b,0x3b,0xb5,0xfb,0xa3,0xbf,0x4f,0x83,0x1d,0xad,0xe9,0x2f,
    0x71,0x65,0xa3,0xe5,0x07,0x35,0x3d,0x0d,0xb5,0xe9,0xe5,0x47,0x3b,0x9d,0xef,0x35,
    0xa3,0xbf,0xb3,0xdf,0x53,0xd3,0x97,0x53,0x49,0x71,0x07,0x35,0x61,0x71,0x2f,0x43,
    0x2f,0x11,0xdf,0x17,0x97,0xfb,0x95,0x3b,0x7f,0x6b,0xd3,0x25,0xbf,0xad,0xc7,0xc5,
    0xc5,0xb5,0x8b,0xef,0x2f,0xd3,0x07,0x6b,0x25,0x49,0x95,0x25,0x49,0x6d,0x71,0xc7 ],
  [ 0xa7,0xbc,0xc9,0xad,0x91,0xdf,0x85,0xe5,0xd4,0x78,0xd5,0x17,0x46,0x7c,0x29,0x4c,
    0x4d,0x03,0xe9,0x25,0x68,0x11,0x86,0xb3,0xbd,0xf7,0x6f,0x61,0x22,0xa2,0x26,0x34,
    0x2a,0xbe,0x1e,0x46,0x14,0x68,0x9d,0x44,0x18,0xc2,0x40,0xf4,0x7e,0x5f,0x1b,0xad,
    0x0b,0x94,0xb6,0x67,0xb4,0x0b,0xe1,0xea,0x95,0x9c,0x66,0xdc,0xe7,0x5d,0x6c,0x05,
    0xda,0xd5,0xdf,0x7a,0xef,0xf6,0xdb,0x1f,0x82,0x4c,0xc0,0x68,0x47,0xa1,0xbd,0xee,
    0x39,0x50,0x56,0x4a,0xdd,0xdf,0xa5,0xf8,0xc6,0xda,0xca,0x90,0xca,0x01,0x42,0x9d,
    0x8b,0x0c,0x73,0x43,0x75,0x05,0x94,0xde,0x24,0xb3,0x80,0x34,0xe5,0x2c,0xdc,0x9b,
    0x3f,0xca,0x33,0x45,0xd0,0xdb,0x5f,0xf5,0x52,0xc3,0x21,0xda,0xe2,0x22,0x72,0x6b,
    0x3e,0xd0,0x5b,0xa8,0x87,0x8c,0x06,0x5d,0x0f,0xdd,0x09,0x19,0x93,0xd0,0xb9,0xfc,
    0x8b,0x0f,0x84,0x60,0x33,0x1c,0x9b,0x45,0xf1,0xf0,0xa3,0x94,0x3a,0x12,0x77,0x33,
    0x4d,0x44,0x78,0x28,0x3c,0x9e,0xfd,0x65,0x57,0x16,0x94,0x6b,0xfb,0x59,0xd0,0xc8,
    0x22,0x36,0xdb,0xd2,0x63,0x98,0x43,0xa1,0x04,0x87,0x86,0xf7,0xa6,0x26,0xbb,0xd6,
    0x59,0x4d,0xbf,0x6a,0x2e,0xaa,0x2b,0xef,0xe6,0x78,0xb6,0x4e,0xe0,0x2f,0xdc,0x7c,
    0xbe,0x57,0x19,0x32,0x7e,0x2a,0xd0,0xb8,0xba,0x29,0x00,0x3c,0x52,0x7d,0xa8,0x49,
    0x3b,0x2d,0xeb,0x25,0x49,0xfa,0xa3,0xaa,0x39,0xa7,0xc5,0xa7,0x50,0x11,0x36,0xfb,
    0xc6,0x67,0x4a,0xf5,0xa5,0x12,0x65,0x7e,0xb0,0xdf,0xaf,0x4e,0xb3,0x61,0x7f,0x2f ]
);

# decrypt Nikon data block (ref 4)
# Inputs: 0) reference to data block, 1) serial number key, 2) shutter count key
#         4) optional start offset (default 0)
#         5) optional number of bytes to decode (default to the end of the data)
# Returns: Decrypted data block
sub DecryptNikonData($$$;$$)
{
    my ($dataPt, $serial, $count, $start, $len) = @_;
    $start or $start = 0;
    my $end = $len ? $start + $len : length($$dataPt);
    my $i;
    my $key = 0;
    for ($i=0; $i<4; ++$i) {
        $key ^= ($count >> ($i*8)) & 0xff;
    }
    my $ci = $xlat[0][$serial & 0xff];
    my $cj = $xlat[1][$key];
    my $ck = 0x60;
    my @data = unpack('C*',$$dataPt);
    for ($i=$start; $i<$end; ++$i) {
        $cj = ($cj + $ci * $ck) & 0xff;
        $ck = ($ck + 1) & 0xff;
        $data[$i] ^= $cj;
    }
    return pack('C*',@data);
}

#------------------------------------------------------------------------------
# process Nikon IFD
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
# Notes: This isn't a normal IFD, but is close...
sub ProcessNikonCaptureOffsets($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart};
    my $dirLen = $dirInfo->{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $success = 0;
    return 0 unless $dirLen > 2;
    my $count = Get16u($dataPt, $dirStart);
    return 0 unless $count and $count * 12 + 2 <= $dirLen;
    my $index;
    for ($index=0; $index<$count; ++$index) {
        my $pos = $dirStart + 12 * $index + 2;
        my $tagID = Get32u($dataPt, $pos);
        my $value = Get32u($dataPt, $pos + 4);
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
        if ($verbose) {
            $exifTool->VerboseInfo($tagID, $tagInfo,
                'Table'  => $tagTablePtr,
                'Index'  => $index,
                'Value'  => $value,
                'DataPt' => $dataPt,
                'Size'   => 12,
                'Start'  => $pos,
            );
        }
        next unless $tagInfo;
        $exifTool->FoundTag($tagInfo, $value);
        $success = 1;
    }
    return $success;
}

#------------------------------------------------------------------------------
# process Nikon Encrypted data block
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
sub ProcessNikonEncrypted($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    # get the encrypted directory data
    my $buff = substr(${$$dirInfo{DataPt}}, $$dirInfo{DirStart}, $$dirInfo{DirLen});
    # save it until we have enough information to decrypt it later
    push @{$exifTool->{NikonInfo}->{Encrypted}}, [ $tagTablePtr, $buff ];
    return 1;
}

#------------------------------------------------------------------------------
# Process Nikon Makernotes directory
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table for this directory
#         2) Reference to directory information hash
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessNikon($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $verbose = $exifTool->Options('Verbose');
    my $nikonInfo = $exifTool->{NikonInfo} = { };
    my @encrypted;  # list to save encrypted data
    $$nikonInfo{Encrypted} = \@encrypted;
    my $rtnVal = Image::ExifTool::Exif::ProcessExif($exifTool, $tagTablePtr, $dirInfo);
    # process any encrypted information we found
    my $encryptedDir;
    if (@encrypted) {
        my $serial = $exifTool->{NikonInfo}->{SerialNumber} || 0;
        my $count = $exifTool->{NikonInfo}->{ShutterCount};
        unless (defined $count) {
            $exifTool->Warn("Can't decrypt Nikon information (no ShutterCount key)");
            undef @encrypted;
        }
        foreach $encryptedDir (@encrypted) {
            my ($subTablePtr, $data) = @$encryptedDir;
            $data = DecryptNikonData(\$data, $serial, $count, 4);
            my %subdirInfo = (
                DataPt   => \$data,
                DirStart => 0,
                DirLen   => length($data),
            );
            # process the decrypted information
            $exifTool->ProcessBinaryData($subTablePtr, \%subdirInfo);
        }
    }
    delete $exifTool->{NikonInfo};
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Nikon - Definitions for Nikon EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Nikon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://members.aol.com/khancock/pilot/nbuddy/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joseph Heled, Thomas Walter, Brian Ristuccia, Danek Duvall, Tom
Christiansen and Robert Rottmerhusen for their help figuring out some Nikon
tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
