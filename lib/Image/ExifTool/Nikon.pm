#------------------------------------------------------------------------------
# File:         Nikon.pm
#
# Description:  Nikon EXIF maker notes tags
#
# Revisions:    12/09/2003 - P. Harvey Created
#               05/17/2004 - P. Harvey Added information from Joseph Heled
#               09/21/2004 - P. Harvey Changed tag 2 to ISOUsed & added PrintConv
#               12/01/2004 - P. Harvey Added default PRINT_CONV
#               12/06/2004 - P. Harvey Added SceneMode
#               01/01/2005 - P. Harvey Decode preview image and preview IFD
#               03/35/2005 - T. Christiansen additions
#               05/10/2005 - P. Harvey Decode encrypted lens data
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
#              10) Werner Kober private communication (D2H, D2X, D100, D70, D200)
#              11) http://www.rottmerhusen.com/objektives/lensid/nikkor.html
#              12) http://libexif.sourceforge.net/internals/mnote-olympus-tag_8h-source.html
#------------------------------------------------------------------------------

package Image::ExifTool::Nikon;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.37';

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
        Name => 'FirmwareVersion',
        Writable => 'undef',
        Count => 4,
        # convert to string if binary
        ValueConv => '$_=$val; /^[\x00-\x09]/ and $_=join("",unpack("CCCC",$_)); $_',
        ValueConvInv => '$val',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_',
        PrintConvInv => '$_=$val;s/\.//;"0$_"',
    },
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
    0x0003 => { Name => 'ColorMode',    Writable => 'string' },
    0x0004 => { Name => 'Quality',      Writable => 'string' },
    0x0005 => { Name => 'WhiteBalance', Writable => 'string' },
    0x0006 => { Name => 'Sharpness',    Writable => 'string' },
    0x0007 => { Name => 'FocusMode',    Writable => 'string' },
    0x0008 => { Name => 'FlashSetting', Writable => 'string' },
    # FlashType shows 'Built-in,TTL' when builtin flash fires,
    # and 'Optional,TTL' when external flash is used (ref 2)
    0x0009 => { #2
        Name => 'FlashType',
        Writable => 'string',
        Count => 13,
    },
    0x000b => { Name => 'WhiteBalanceFineTune', Writable => 'int16u' }, #2
    0x000c => {
        Name => 'ColorBalance1',
        Writable => 'rational32u',
        Count => 4,
    },
    0x000e => {
        Name => 'ExposureDifference',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*12 + ($val>0 ? 0.5 : -0.5));
            return undef if $a<-128 or $a>127;
            return pack("c4",$a,1,12,0);
        },
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x000f => { Name => 'ISOSelection', Writable => 'string' }, #2
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
    0x0016 => { #2
        Name => 'ImageBoundary',
        Writable => 'int16u',
        Count => 4,
    },
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
        RawConv => '$self->{NikonInfo}->{SerialNumber} = $val',
    },
    0x0080 => { Name => 'ImageAdjustment',  Writable => 'string' },
    0x0081 => { Name => 'ToneComp',         Writable => 'string' }, #2
    0x0082 => { Name => 'AuxiliaryLens',    Writable => 'string' },
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
            $val =~ tr/,/./;    # in case locale is whacky
            my ($a,$b,$c,$d) = split ' ', $val;
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
    0x008d => { Name => 'ColorHue' ,        Writable => 'string' }, #2
    # SceneMode takes on the following values: PORTRAIT, PARTY/INDOOR, NIGHT PORTRAIT,
    # BEACH/SNOW, LANDSCAPE, SUNSET, NIGHT SCENE, MUSEUM, FIREWORKS, CLOSE UP, COPY,
    # BACK LIGHT, PANORAMA ASSIST, SPORT, DAWN/DUSK
    0x008f => { Name => 'SceneMode',        Writable => 'string' }, #2
    # LightSource shows 3 values COLORED SPEEDLIGHT NATURAL.
    # (SPEEDLIGHT when flash goes. Have no idea about difference between other two.)
    0x0090 => { Name => 'LightSource',      Writable => 'string' }, #2
    0x0092 => { #2
        Name => 'HueAdjustment',
        Writable => 'int16s',
    },
    0x0094 => { Name => 'Saturation',       Writable => 'int16s' },
    0x0095 => { Name => 'NoiseReduction',   Writable => 'string' },
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
                TagTable => 'Image::ExifTool::Nikon::ColorBalance1',
            },
        },
        {
            Condition => '$$valPt =~ /^0102/', # (D2H)
            Name => 'ColorBalance0102',
            Writable => 0,
            SubDirectory => {
                Start => '$valuePtr + 10',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
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
                TagTable => 'Image::ExifTool::Nikon::ColorBalance3',
            },
        },
        {
            Condition => '$$valPt =~ /^0205/', # (D50)
            Name => 'ColorBalance0205',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
                DecryptLen => 22, # 324 bytes encrypted, but don't need to decrypt it all
                DirOffset => 14,
            },
        },
        {
            Condition => '$$valPt =~ /^02/', # (0204=D2X,0206=D2Hs,0207=D200)
            Name => 'ColorBalance02',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 14, # 324 bytes encrypted, but don't need to decrypt it all
                DirOffset => 6,
            },
        },
        {
            Name => 'ColorBalanceUnknown',
            Writable => 0,
        },
    ],
    0x0098 => [
        { #8
            Condition => '$$valPt =~ /^0100/',
            Name => 'LensData0100',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData00',
            },
        },
        { #8
            Condition => '$$valPt =~ /^0101/',
            Name => 'LensData0101',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData01',
            },
        },
        # note: this information is encrypted if the version is 02xx
        { #8
            Condition => '$$valPt =~ /^0201/',
            Name => 'LensData0201',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData01',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        {
            Name => 'LensDataUnknown',
            Writable => 0,
        },
    ],
    # D70 guessing here
    0x0099 => { #2
        Name => 'NEFThumbnailSize',
        Writable => 'int16u',
        Count => 2,
    },
    0x009a => { #10
        Name => 'SensorPixelSize',
        Writable => 'rational32u',
        Count => 2,
        PrintConv => '$val=~s/ / x /;"$val um"',
        PrintConvInv => '$val=~tr/a-zA-Z/ /;$val',
    },
    0x00a0 => { Name => 'SerialNumber',     Writable => 'string' }, #2
    0x00a2 => { Name => 'ImageDataSize' }, # size of compressed image data plus EOI segment (ref 10)
    # the sum of 0xa5 and 0xa6 is equal to 0xa7 ShutterCount (D2X,D2Hs,D2H,D200, ref 10)
    0x00a7 => { # Number of shots taken by camera so far (ref 2)
        Name => 'ShutterCount',
        Writable => 0,
        Notes => 'Not writable because this value is used as a key to decrypt other information',
        RawConv => '$self->{NikonInfo}->{ShutterCount} = $val',
    },
    0x00a9 => { #2
        Name => 'ImageOptimization',
        Writable => 'string',
        Count => 16,
    },
    0x00aa => { Name => 'Saturation',       Writable => 'string' }, #2
    0x00ab => { Name => 'VariProgram',      Writable => 'string' }, #2
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
    # utility that blindly copies the maker notes (not ExifTool) - PH
    0x0e01 => {
        Name => 'NikonCaptureData',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::Main',
        },
    },
    0x0e09 => 'NikonCaptureVersion', #12
    # 0x0e0e is in D70 Nikon Capture files (not out-of-the-camera D70 files) - PH
    0x0e0e => { #PH
        Name => 'NikonCaptureOffsets',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::CaptureOffsets',
            Validate => '$val =~ /^0100/',
            Start => '$valuePtr + 4',
        },
    },
);

# ref PH
%Image::ExifTool::Nikon::CaptureOffsets = (
    PROCESS_PROC => \&ProcessNikonCaptureOffsets,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'IFD0_Offset',
    2 => 'PreviewIFD_Offset',
    3 => 'SubIFD_Offset',
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance1 = (
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

# ref 4
%Image::ExifTool::Nikon::ColorBalance2 = (
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

# ref 4
%Image::ExifTool::Nikon::ColorBalance3 = (
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

%Image::ExifTool::Nikon::Type2 = (
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
# nikon lens ID numbers (ref 8/11)
my %nikonLensIDs = (
    0 => 'Unknown Nikkor or Tokina',
    1 => 'AF Nikkor 50mm f/1.8',
    2 => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5 or Sigma non-D',
    3 => 'AF Zoom-Nikkor 70-210mm f/4 or Soligor',
    4 => 'AF Nikkor 28mm f/2.8',
    5 => 'AF Nikkor 50mm f/1.4',
    6 => 'AF Micro-Nikkor 55mm f/2.8 or Cosina',
    7 => 'AF Zoom-Nikkor 28-85mm f/3.5-4.5 or Tamron',
    8 => 'AF Zoom-Nikkor 35-105mm f/3.5-4.5',
    9 => 'AF Nikkor 24mm f/2.8',
    10 => 'AF Nikkor 300mm f/2.8 IF-ED',
    11 => 'AF Nikkor 180mm f/2.8 IF-ED or Tamron',
    13 => 'AF Zoom-Nikkor 35-135mm f/3.5-4.5',
    14 => 'AF Zoom-Nikkor 70-210mm f/4',
    15 => 'AF Nikkor 50mm f/1.8 N',
    16 => 'AF Nikkor 300mm f/4 IF-ED',
    17 => 'AF Zoom-Nikkor 35-70mm f/2.8',
    18 => 'AF Nikkor 70-210mm f/4-5.6',
    19 => 'AF Zoom-Nikkor 24-50mm f/3.3-4.5',
    20 => 'AF Zoom-Nikkor 80-200mm f/2.8 ED',
    21 => 'AF Nikkor 85mm f/1.8',
    23 => 'Nikkor 500mm f/4 P',
    24 => 'AF Zoom-Nikkor 35-135mm f/3.5-4.5 N',
    26 => 'AF Nikkor 35mm f/2',
    27 => 'AF Zoom-Nikkor 75-300mm f/4.5-5.6',
    28 => 'AF Nikkor 20mm f/2.8',
    29 => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5 N',
    30 => 'AF Micro-Nikkor 60mm f/2.8 or third party lens',
    32 => 'Unknown Nikkor or Tamron',
    36 => 'AF Zoom-Nikkor ED 80-200mm f/2.8D',
    37 => 'AF Zoom-Nikkor 35-70mm f/2.8D N',
    38 => 'Unknown Nikkor or Sigma D',
    39 => 'AF-I Nikkor 300mm f/2.8D IF-ED',
    42 => 'AF Nikkor 28mm f/1.4D',
    44 => 'AF DC-Nikkor 105mm f/2D',
    45 => 'AF Micro-Nikkor 200mm f/4D IF-ED',
    46 => 'AF Nikkor 70-210mm f/4-5.6D',
    47 => 'Unknown Nikkor or third party lens',
    49 => 'AF Micro-Nikkor 60mm f/2.8D',
    50 => 'AF Micro-Nikkor 105mm f/2.8D or Sigma Macro D',
    51 => 'AF Nikkor 18mm f/2.8D',
    52 => 'Unknown Nikkor or Tamron',
    54 => 'AF Nikkor 24mm f/2.8D',
    55 => 'AF Nikkor 20mm f/2.8D',
    56 => 'AF Nikkor 85mm f/1.8D',
    59 => 'AF Zoom-Nikkor 35-70mm f/2.8D N',
    61 => 'AF Zoom-Nikkor 35-80mm f/4-5.6D',
    62 => 'AF Nikkor 28mm f/2.8D',
    65 => 'AF Nikkor 180mm f/2.8D IF-ED',
    66 => 'AF Nikkor 35mm f/2D',
    67 => 'AF Nikkor 50mm f/1.4D',
    70 => 'AF Zoom-Nikkor 35-80mm f/4-5.6D N',
    72 => 'AF-S Nikkor 300mm f/2.8D IF-ED or Sigma HSM',
    74 => 'AF Nikkor 85mm f/1.4D IF',
    76 => 'AF Zoom-Nikkor 24-120mm f/3.5-5.6D IF',
    77 => 'AF Zoom-Nikkor 28-200mm f/3.5-5.6D IF or Tamron',
    78 => 'AF DC-Nikkor 135mm f/2D',
    79 => 'IX-Nikkor 24-70mm f/3.5-5.6',
    83 => 'AF Zoom-Nikkor 80-200mm f/2.8D ED',
    84 => 'AF Zoom-Micro Nikkor 70-180mm f/4.5-5.6D ED',
    86 => 'AF Zoom-Nikkor 70-300mm f/4-5.6D ED or Sigma D',
    89 => 'AF-S Nikkor 400mm f/2.8D IF-ED',
    90 => 'IX-Nikkor 30-60mm f/4-5.6',
    93 => 'AF-S Zoom-Nikkor 28-70mm f/2.8D IF-ED',
    94 => 'AF-S Zoom-Nikkor 80-200mm f/2.8D IF-ED',
    95 => 'AF Zoom-Nikkor 28-105mm f/3.5-4.5D IF',
    97 => 'AF Zoom-Nikkor 75-240mm f/4.5-5.6D',
    99 => 'AF-S Nikkor 17-35mm f/2.8D IF-ED',
    100 => 'PC Micro-Nikkor 85mm f/2.8D',
    101 => 'AF VR Zoom-Nikkor 80-400mm f/4.5-5.6D ED',
    102 => 'AF Zoom-Nikkor 18-35mm f/3.5-4.5D IF-ED',
    103 => 'AF Zoom-Nikkor 24-85mm f/2.8-4D IF',
    104 => 'AF Zoom-Nikkor 28-80mm f/3.3-5.6G',
    105 => 'AF Zoom-Nikkor 70-300mm f/4-5.6G',
    106 => 'AF-S Nikkor 300mm f/4D IF-ED',
    109 => 'AF-S Nikkor 300mm f/2.8D IF-ED II',
    110 => 'AF-S Nikkor 400mm f/2.8D IF-ED II',
    111 => 'AF-S Nikkor 500mm f/4D IF-ED',
    112 => 'AF-S Nikkor 600mm f/4D IF-ED',
    114 => 'Nikkor 45mm f/2.8 P',
    116 => 'AF-S Zoom-Nikkor 24-85mm f/3.5-4.5G IF-ED',
    117 => 'AF Zoom-Nikkor 28-100mm f/3.5-5.6G',
    118 => 'AF Nikkor 50mm f/1.8D',
    119 => 'AF-S VR Zoom-Nikkor 70-200mm f/2.8G IF-ED or Sigma OS',
    120 => 'AF-S VR Zoom-Nikkor 24-120mm f/3.5-5.6G IF-ED',
    121 => 'AF Zoom-Nikkor 28-200mm f/3.5-5.6G IF-ED',
    122 => 'AF-S DX Zoom-Nikkor 12-24mm f/4G IF-ED',
    123 => 'AF-S VR Zoom-Nikkor 200-400mm f/4G IF-ED',
    125 => 'AF-S DX Zoom-Nikkor 17-55mm f/2.8G IF-ED',
    127 => 'AF-S DX Zoom-Nikkor 18-70mm f/3.5-4.5G IF-ED',
    128 => 'AF DX Fisheye-Nikkor 10.5mm f/2.8G ED',
    129 => 'AF-S VR Nikkor 200mm f/2G IF-ED',
    130 => 'AF-S VR Nikkor 300mm f/2.8G IF-ED',
    137 => 'AF-S DX Zoom-Nikkor 55-200mm f/4-5.6G ED',
    139 => 'AF-S DX VR Zoom-Nikkor 18-200mm f/3.5-5.6G IF-ED',#8/10
    140 => 'AF-S DX Zoom-Nikkor 18-55mm f/3.5-5.6G ED',
);

# Version 100 Nikon lens data
%Image::ExifTool::Nikon::LensData00 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => 'This structure is used by the D100 and newer D1X models.',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'undef[4]',
    },
    0x06 => { #8
        Name => 'LensID',
        PrintConv => \%nikonLensIDs,
    },
    0x07 => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x08 => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x09 => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x0a => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x0b => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x0c => 'MCUVersion', #8
);

# Nikon lens data (note: needs decrypting if LensDataVersion is 0201)
%Image::ExifTool::Nikon::LensData01 = (
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
        ValueConv => '0.01 * 10**($val/40)', # in m
        ValueConvInv => '$val>0 ? 40*log($val*100)/log(10) : 0',
        PrintConv => '$val ? sprintf("%.2f m",$val) : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s.*//, $val',
    },
    0x0a => { #8/9
        Name => 'FocalLength',
        Priority => 0,
        %nikonFocalConversions,
    },
    0x0b => { #8
        Name => 'LensID',
        PrintConv => \%nikonLensIDs,
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
Image::ExifTool::AddCompositeTags('Image::ExifTool::Nikon::Composite');


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
sub Decrypt($$$;$$)
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
# process Nikon Encrypted data block
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub ProcessNikonEncrypted($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    # get the encrypted directory data
    my $buff = substr(${$$dirInfo{DataPt}}, $$dirInfo{DirStart}, $$dirInfo{DirLen});
    # save it until we have enough information to decrypt it later
    push @{$exifTool->{NikonInfo}->{Encrypted}}, [ $tagTablePtr, $buff, $$dirInfo{TagInfo}];
    if ($exifTool->Options('Verbose')) {
        my $indent = substr($exifTool->{INDENT}, 0, -2);
        $exifTool->VPrint(0, $indent, "[$dirInfo->{TagInfo}->{Name} directory to be decrypted later]\n");
    }
    return 1;
}

#------------------------------------------------------------------------------
# process Nikon Capture Offsets IFD (ref PH)
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
# Notes: This isn't a normal IFD, but is close...
sub ProcessNikonCaptureOffsets($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $success = 0;
    return 0 unless $dirLen > 2;
    my $count = Get16u($dataPt, $dirStart);
    return 0 unless $count and $count * 12 + 2 <= $dirLen;
    my $index;
    for ($index=0; $index<$count; ++$index) {
        my $pos = $dirStart + 12 * $index + 2;
        my $tagID = Get32u($dataPt, $pos);
        my $value = Get32u($dataPt, $pos + 4);
        $exifTool->HandleTag($tagTablePtr, $tagID, $value,
            Index  => $index,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => 12,
        ) and $success = 1;
    }
    return $success;
}

#------------------------------------------------------------------------------
# Process Nikon Makernotes directory
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessNikon($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $verbose = $exifTool->Options('Verbose');
    my $nikonInfo = $exifTool->{NikonInfo} = { };
    my @encrypted;  # list to save encrypted data
    $$nikonInfo{Encrypted} = \@encrypted;
    my $rtnVal = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
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
            my ($subTablePtr, $data, $tagInfo) = @$encryptedDir;
            my ($start, $len, $offset);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $start = $tagInfo->{SubDirectory}->{DecryptStart};
                $len = $tagInfo->{SubDirectory}->{DecryptLen};
                $offset = $tagInfo->{SubDirectory}->{DirOffset};
            }
            $start or $start = 0;
            if (defined $offset) {
                # offset, if specified, is releative to start of encrypted data
                $offset += $start;
            } else {
                $offset = 0;
            }
            my $maxLen = length($data) - $start;
            if ($len) {
                $len = $maxLen if $len > $maxLen;
            } else {
                $len = $maxLen;
            }
            # use fixed serial numbers if no good serial number found
            unless ($serial =~ /^\d+$/) {
                if ($exifTool->{CameraModel} =~ /\bD200$/) {
                    $serial = 0x60; # D200 (ref 10)
                } else {
                    $serial = 0x22; # D50 (ref 8)
                }
            }
            $data = Decrypt(\$data, $serial, $count, $start, $len);
            my %subdirInfo = (
                DataPt   => \$data,
                DirStart => $offset,
                DirLen   => length($data),
            );
            if ($verbose > 2) {
                $exifTool->VerboseDir("Decrypted $$tagInfo{Name}");
                my %parms = (
                    Prefix => $exifTool->{INDENT},
                    Out => $exifTool->Options('TextOut'),
                );
                $parms{MaxLen} = 96 unless $verbose > 3;
                Image::ExifTool::HexDump(\$data, undef, %parms);
            }
            # process the decrypted information
            $exifTool->ProcessBinaryData(\%subdirInfo, $subTablePtr);
        }
    }
    delete $exifTool->{NikonInfo};
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Nikon - Nikon EXIF maker notes tags

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

=item L<http://www.rottmerhusen.com/objektives/lensid/nikkor.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joseph Heled, Thomas Walter, Brian Ristuccia, Danek Duvall, Tom
Christiansen, Robert Rottmerhusen and Werner Kober for their help figuring
out some Nikon tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool::TagNames/NikonCapture Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
