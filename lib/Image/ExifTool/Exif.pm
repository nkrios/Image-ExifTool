#------------------------------------------------------------------------------
# File:         Exif.pm
#
# Description:  Definitions for EXIF tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/06/2004 - P. Harvey Moved processing functions from ExifTool
#               03/19/2004 - P. Harvey Check PreviewImage for validity
#               11/11/2004 - P. Harvey Split off maker notes into MakerNotes.pm
#               12/13/2004 - P. Harvey Added AUTOLOAD to load write routines
#
# References:   1) http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf
#               2) http://www.adobe.com/products/dng/pdfs/dng_spec.pdf
#               3) http://www.awaresystems.be/imaging/tiff/tifftags.html
#               4) http://www.remotesensing.org/libtiff/TIFFTechNote2.html
#               5) http://www.asmail.be/msg0054681802.html
#               6) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               7) http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf
#               8) http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;
use vars qw($VERSION $AUTOLOAD @formatSize @formatName %formatNumber
            %lightSource %compression %photometricInterpretation %orientation);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::MakerNotes;

$VERSION = '1.46';

sub ProcessExif($$$);
sub WriteExif($$$);
sub CheckExif($$$);
sub RebuildMakerNotes($$$);
sub Rationalize($;$);

# byte sizes for the various EXIF format types below
@formatSize = (0,1,1,2,4,8,1,1,2,4,8,4,8);

@formatName = (
    'err','int8u','string','int16u',
    'int32u','rational32u','int8s','undef',
    'int16s','int32s','rational32s','float',
    'double'
);

# hash to look up EXIF format numbers by name
# (format types are all lower case)
%formatNumber = (
    'int8u'         => 1,   # BYTE
    'string'        => 2,   # ASCII
    'binary'        => 2,   # (binary is the same as string in Perl)
    'int16u'        => 3,   # SHORT
    'int32u'        => 4,   # LONG
    'rational32u'   => 5,   # RATIONAL
    'int8s'         => 6,   # SBYTE
    'undef'         => 7,   # UNDEFINED
    'int16s'        => 8,   # SSHORT
    'int32s'        => 9,   # SLONG
    'rational32s'   => 10,  # SRATIONAL
    'float'         => 11,  # FLOAT
    'double'        => 12,  # DOUBLE
);

# EXIF LightSource PrintConv values
%lightSource = (
    1 => 'Daylight',
    2 => 'Fluorescent',
    3 => 'Tungsten',
    4 => 'Flash',
    9 => 'Fine Weather',
    10 => 'Cloudy',
    11 => 'Shade',
    12 => 'Daylight Fluorescent',
    13 => 'Day White Fluorescent',
    14 => 'Cool White Fluorescent',
    15 => 'White Fluorescent',
    17 => 'Standard Light A',
    18 => 'Standard Light B',
    19 => 'Standard Light C',
    20 => 'D55',
    21 => 'D65',
    22 => 'D75',
    23 => 'D50',
    24 => 'ISO Studio Tungsten',
    255 => 'Other',
);

%compression = (
    1 => 'Uncompressed',
    2 => 'CCITT 1D',
    3 => 'T4/Group 3 Fax',
    4 => 'T6/Group 4 Fax',
    5 => 'LZW',
    6 => 'JPEG (old-style)', #3
    7 => 'JPEG', #4
    8 => 'Adobe Deflate', #3
    9 => 'JBIG B&W', #3
    10 => 'JBIG Color', #3
    32766 => 'Next', #3
    32771 => 'CCIRLEW', #3
    32773 => 'PackBits',
    32809 => 'Thunderscan', #3
    32895 => 'IT8CTPAD', #3
    32896 => 'IT8LW', #3
    32897 => 'IT8MP', #3
    32898 => 'IT8BL', #3
    32908 => 'PixarFilm', #3
    32909 => 'PixarLog', #3
    32946 => 'Deflate', #3
    32947 => 'DCS', #3
    34661 => 'JBIG', #3
    34676 => 'SGILog', #3
    34677 => 'SGILog24', #3
    34712 => 'JPEG 2000', #3
    34713 => 'Nikon NEF Compressed',
);

%photometricInterpretation = (
    0 => 'WhiteIsZero',
    1 => 'BlackIsZero',
    2 => 'RGB',
    3 => 'RGB Palette',
    4 => 'Transparency Mask',
    5 => 'CMYK',
    6 => 'YCbCr',
    8 => 'CIELab',
    9 => 'ICCLab', #3
    10 => 'ITULab', #3
    32803 => 'Color Filter Array', #2
    32844 => 'Pixar LogL', #3
    32845 => 'Pixar LogLuv', #3
    34892 => 'Linear Raw', #2
);

%orientation = (
    1 => 'Horizontal (normal)',
    2 => 'Mirror horizontal',
    3 => 'Rotate 180',
    4 => 'Mirror vertical',
    5 => 'Mirror horizontal and rotate 90 CCW',
    6 => 'Rotate 90 CW',
    7 => 'Mirror horizontal and rotate 90 CW',
    8 => 'Rotate 90 CCW',
);


# main EXIF tag table
%Image::ExifTool::Exif::Main = (
    GROUPS => { 0 => 'EXIF', 1 => 'IFD0', 2 => 'Image'},
    WRITE_PROC => \&WriteExif,
    0x1 => {
        Name => 'InteropIndex',
        Description => 'Interoperability Index',
    },
    0x2 => {
        Name => 'InteropVersion',
        Description => 'Interoperability Version',
    },
    0xfe => {
        Name => 'SubfileType',
        PrintConv => q[$val ? Image::ExifTool::Exif::DecodeBits($val,
            {
                0 => 'Reduced-resolution image',
                1 => 'Single page of multi-page image',
                2 => 'Transparency mask',
            }
        ) : 'Full-resolution Image' ],
    },
    0xff => {
        Name => 'OldSubfileType',
        PrintConv => {
            1 => 'Full-resolution image',
            2 => 'Reduced-resolution image',
            3 => 'Single page of multi-page image',
        },
    },
    0x100 => {
        Name => 'ImageWidth',
        # even though Group 1 is set dynamically we need to register IFD1 once
        # so it will show up in the group lists
        Groups => { 1 => 'IFD1' },
        # set Priority to zero so the value found in the first IFD (IFD0) doesn't
        # get overwritten by subsequent IFD's (same for ImageHeight below)
        Priority => 0,
    },
    0x101 => {
        Name => 'ImageHeight',
        Priority => 0,
    },
    0x102 => 'BitsPerSample',
    0x103 => {
        Name => 'Compression',
        PrintConv => \%compression,
    },
    0x106 => {
        Name => 'PhotometricInterpretation',
        PrintConv => \%photometricInterpretation,
    },
    0x107 => {
        Name => 'Thresholding',
        PrintConv => {
            1 => 'No dithering or halftoning',
            2 => 'Ordered dither or halftone',
            3 => 'Randomized dither',
        },
    },
    0x108 => 'CellWidth',
    0x109 => 'CellLength',
    0x10a => {
        Name => 'FillOrder',
        PrintConv => {
            1 => 'Normal',
            2 => 'Reversed',
        },
    },
    0x10d => 'DocumentName',
    0x10e => 'ImageDescription',
    0x10f => {
        Name => 'Make',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraMake',
        # save this value as an ExifTool member variable
        ValueConv => '$self->{CameraMake} = $val',
    },
    0x110 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraModel',
        # save this value as an ExifTool member variable
        ValueConv => '$self->{CameraModel} = $val',
    },
    0x111 => {
        Name => 'StripOffsets',
        Flags => 'IsOffset',
        OffsetPair => 0x117,  # point to associated byte counts
    },
    0x112 => {
        Name => 'Orientation',
        PrintConv => \%orientation,
    },
    0x115 => 'SamplesPerPixel',
    0x116 => 'RowsPerStrip',
    0x117 => {
        Name => 'StripByteCounts',
        OffsetPair => 0x111,   # point to associated offset
    },
    0x118 => 'MinSampleValue',
    0x119 => 'MaxSampleValue',
    0x11a => 'XResolution',
    0x11b => 'YResolution',
    0x11c => {
        Name => 'PlanarConfiguration',
        PrintConv => {
            1 => 'Chunky',
            2 => 'Planar',
        },
    },
    0x11d => 'PageName',
    0x11e => 'XPosition',
    0x11f => 'YPosition',
    0x120 => {
        Name => 'FreeOffsets',
        Flags => 'IsOffset',
        OffsetPair => 0x121,
    },
    0x121 => {
        Name => 'FreeByteCounts',
        OffsetPair => 0x120,
    },
    0x122 => {
        Name => 'GrayResponseUnit',
        PrintConv => { #3
            1 => 0.1,
            2 => 0.001,
            3 => 0.0001,
            4 => 0.00001,
            5 => 0.000001,
        },
    },
    0x123 => {
        Name => 'GrayResponseCurve',
        PrintConv => '\$val',
    },
    0x124 => {
        Name => 'T4Options',
        PrintConv => q[Image::ExifTool::Exif::DecodeBits($val, {
            0 => '2-Dimensional encoding',
            1 => 'Uncompressed',
            2 => 'Fill bits added',
        } )], #3
    },
    0x125 => {
        Name => 'T6Options',
        PrintConv => q[Image::ExifTool::Exif::DecodeBits($val, {
            1 => 'Uncompressed',
        } )], #3
    },
    0x128 => {
        Name => 'ResolutionUnit',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    0x129 => 'PageNumber',
    0x12d => {
        Name => 'TransferFunction',
        PrintConv => '\$val',
    },
    0x131 => 'Software',
    0x132 => {
        Name => 'ModifyDate',
        Description => 'Date/Time Of Last Modification',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x13b => {
        Name => 'Artist',
        Groups => { 2 => 'Author' },
    },
    0x13c => 'HostComputer',
    0x13d => {
        Name => 'Predictor',
        PrintConv => {
            1 => 'None',
            2 => 'Horizontal differencing',
        },
    },
    0x13e => {
        Name => 'WhitePoint',
        Groups => { 2 => 'Camera' },
    },
    0x13f => 'PrimaryChromaticities',
    0x140 => {
        Name => 'ColorMap',
        Format => 'binary',
        PrintConv => '\$val',
    },
    0x141 => 'HalftoneHints',
    0x142 => 'TileWidth',
    0x143 => 'TileLength',
    0x144 => {
        Name => 'TileOffsets',
        Flags => 'IsOffset',
        OffsetPair => 0x145,
        PrintConv => '\$val',
    },
    0x145 => {
        Name => 'TileByteCounts',
        OffsetPair => 0x144,
        PrintConv => '\$val',
    },
    0x146 => 'BadFaxLines', #3
    0x147 => { #3
        Name => 'CleanFaxData',
        PrintConv => {
            0 => 'Clean',
            1 => 'Regenerated',
            2 => 'Unclean',
        },
    },
    0x148 => 'ConsecutiveBadFaxLines', #3
    0x14a => {
        Name => 'SubIFD',
        Groups => { 1 => 'SubIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            Start => '$val',
            MaxSubdirs => 2,
        },
    },
    0x14c => {
        Name => 'InkSet',
        PrintConv => { #3
            1 => 'CMYK',
            2 => 'Not CMYK',
        },
    },
    0x14d => 'InkNames', #3
    0x14e => 'NumberofInks', #3
    0x150 => 'DotRange',
    0x151 => 'TargetPrinter',
    0x152 => 'ExtraSamples',
    0x153 => {
        Name => 'SampleFormat',
        PrintConv => {
            1 => 'Unsigned integer',
            2 => "Two's complement signed integer",
            3 => 'IEEE floating point',
            4 => 'Undefined',
            5 => 'Complex integer', #3
            6 => 'IEEE floating point', #3
        },
    },
    0x154 => 'SMinSampleValue',
    0x155 => 'SMaxSampleValue',
    0x156 => 'TransferRange',
    0x157 => 'ClipPath', #3
    0x158 => 'XClipPathUnits', #3
    0x159 => 'YClipPathUnits', #3
    0x15a => { #3
        Name => 'Indexed',
        PrintConv => { 0 => 'Not indexed', 1 => 'Indexed' },
    },
    0x15b => {
        Name => 'JPEGTables',
        PrintConv => '\$val',
    },
    0x15f => { #3
        Name => 'OPIProxy',
        PrintConv => {
            0 => 'Higher resolution image does not exist',
            1 => 'Higher resolution image exists',
        },
    },
    0x190 => { #3
        Name => 'GlobalParametersIFD',
        Groups => { 1 => 'GlobParamIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            Start => '$val',
        },
    },
    0x191 => { #3
        Name => 'ProfileType',
        PrintConv => { 0 => 'Unspecified', 1 => 'Group 3 FAX' },
    },
    0x192 => { #3
        Name => 'FaxProfile',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Minimal B&W lossless, S',
            2 => 'Extended B&W lossless, F',
            3 => 'Lossless JBIG B&W, J',
            4 => 'Lossy color and grayscale, C',
            5 => 'Lossless color and grayscale, L',
            6 => 'Mixed raster content, M',
        },
    },
    0x193 => { #3
        Name => 'CodingMethods',
        PrintConv => q[Image::ExifTool::Exif::DecodeBits($val, {
            0 => 'Unspecified compression',
            1 => 'Modified Huffman',
            2 => 'Modified Read',
            3 => 'Modified MR',
            4 => 'JBIG',
            5 => 'Baseline JPEG',
            6 => 'JBIG color',
        } )],
    },
    0x194 => 'VersionYear', #3
    0x195 => 'ModeNumber', #3
    0x1b1 => 'Decode', #3
    0x1b2 => 'DefaultImageColor', #3
    0x200 => {
        Name => 'JPEGProc',
        PrintConv => {
            1 => 'Baseline',
            14 => 'Lossless',
        },
    },
    0x201 => [
        {
            Name => 'ThumbnailOffset',
            Condition => '$self->{DIR_NAME} eq "IFD1"',
            Flags => [ 'IsOffset', 'Protected' ],
            OffsetPair => 0x202,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD1',
        },
        {
            Name => 'PreviewImageStart',
            Condition => '$self->{DIR_NAME} eq "MakerNotes"',
            Flags => [ 'IsOffset', 'Protected' ],
            OffsetPair => 0x202,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
        },
        {
            Name => 'JpgFromRawStart',
            Condition => '$self->{DIR_NAME} eq "SubIFD"',
            Flags => [ 'IsOffset', 'Protected' ],
            OffsetPair => 0x202,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            # JpgFromRaw is in SubIFD of NEF files
            WriteCondition => '$self->{TIFF_TYPE} eq "NEF"',
        },
        {
            Name => 'JpgFromRawStart',
            Condition => '$self->{DIR_NAME} eq "IFD2"',
            Flags => [ 'IsOffset', 'Protected' ],
            OffsetPair => 0x202,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'IFD2',
            # JpgFromRaw is in IFD2 of PEF files
            WriteCondition => '$self->{TIFF_TYPE} eq "PEF"',
        },
        {
            Name => 'OtherImageStart',
            OffsetPair => 0x202,
        },
    ],
    0x202 => [
        {
            Name => 'ThumbnailLength',
            Condition => '$self->{DIR_NAME} eq "IFD1"',
            Flags => 'Protected',
            OffsetPair => 0x201,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD1',
        },
        {
            Name => 'PreviewImageLength',
            Condition => '$self->{DIR_NAME} eq "MakerNotes"',
            Flags => 'Protected',
            OffsetPair => 0x201,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
        },
        {
            Name => 'JpgFromRawLength',
            Condition => '$self->{DIR_NAME} eq "SubIFD"',
            Flags => 'Protected',
            OffsetPair => 0x201,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            WriteCondition => '$self->{TIFF_TYPE} eq "NEF"',
        },
        {
            Name => 'JpgFromRawLength',
            Condition => '$self->{DIR_NAME} eq "IFD2"',
            Flags => 'Protected',
            OffsetPair => 0x201,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'IFD2',
            WriteCondition => '$self->{TIFF_TYPE} eq "PEF"',
        },
        {
            Name => 'OtherImageLength',
            OffsetPair => 0x201,
        },
    ],
    0x203 => 'JPEGRestartInterval',
    0x205 => 'JPEGLosslessPredictors',
    0x206 => 'JPEGPointTransforms',
    0x207 => 'JPEGQTables',
    0x208 => 'JPEGDCTables',
    0x209 => 'JPEGACTables',
    0x211 => 'YCbCrCoefficients',
    0x212 => {
        Name => 'YCbCrSubSampling',
        PrintConv => {
            '1 1' => 'YCbCr4:4:4', #PH
            '2 1' => 'YCbCr4:2:2', #6
            '2 2' => 'YCbCr4:2:0', #6
            '4 1' => 'YCbCr4:1:1', #6
            '4 2' => 'YCbCr4:1:0', #PH
            '1 2' => 'YCbCr4:4:0', #PH
        },
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
    },
    0x214 => 'ReferenceBlackWhite',
    0x22f => 'StripRowCounts',
    0x2bc => {
        Name => 'ApplicationNotes',
        # this could be an XMP block
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    0x1000 => 'RelatedImageFileFormat',
    0x1001 => 'RelatedImageWidth',
    0x1002 => 'RelatedImageLength',
    0x800d => 'ImageID',
    0x80a4 => 'WangAnnotation',
    0x827d => 'Model2',
    0x828d => 'CFARepeatPatternDim',
    0x828e => 'CFAPattern2',
    0x828f => {
        Name => 'BatteryLevel',
        Groups => { 2 => 'Camera' },
    },
    0x8298 => {
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
    },
    0x829a => {
        Name => 'ExposureTime',
        Description => 'Shutter Speed',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x829d => {
        Name => 'FNumber',
        Description => 'Aperture',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x830e => 'PixelScale',
    0x83bb => {
        Name => 'IPTC-NAA',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x8474 => 'IntergraphPacketData', #3
    0x847f => 'IntergraphFlagRegisters', #3
    0x8480 => 'IntergraphMatrix',
    0x8482 => {
        Name => 'ModelTiePoint',
        Groups => { 2 => 'Location' },
    },
    0x8568 => {
        Name => 'IPTC-NAA2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
            DirName => 'IPTC2',     # change name because this isn't the IPTC we want to write
        },
    },
    0x85d8 => {
        Name => 'ModelTransform',
        Groups => { 2 => 'Location' },
    },
    0x8649 => {
        Name => 'PhotoshopSettings',
        Format => 'binary',
        PrintConv => '\$val',
    },
    0x8769 => {
        Name => 'ExifOffset',
        Groups => { 1 => 'ExifIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            Start => '$val',
        },
    },
    0x8773 => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0x87ac => 'ImageLayer',
    0x87af => {
        Name => 'GeoTiffDirectory',
        Format => 'binary',
        PrintConv => '\$val',
    },
    0x87b0 => {
        Name => 'GeoTiffDoubleParams',
        Format => 'binary',
        PrintConv => '\$val',
    },
    0x87b1 => {
        Name => 'GeoTiffAsciiParams',
        PrintConv => '\$val',
    },
    0x8822 => {
        Name => 'ExposureProgram',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'Manual',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Creative (Slow speed)',
            6 => 'Action (High speed)',
            7 => 'Portrait',
            8 => 'Landscape',
        },
    },
    0x8824 => {
        Name => 'SpectralSensitivity',
        Groups => { 2 => 'Camera' },
    },
    0x8825 => {
        Name => 'GPSInfo',
        Groups => { 1 => 'GPS' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::GPS::Main',
            Start => '$val',
        },
    },
    0x8827 => {
        Name => 'ISO',
        Description => 'ISO Speed',
    },
    0x8828 => {
        Name => 'Opto-ElectricConvFactor',
    },
    0x8829 => 'Interlace',
    0x882a => 'TimeZoneOffset',
    0x882b => 'SelfTimerMode',
    0x9000 => 'ExifVersion',
    0x9003 => {
        Name => 'DateTimeOriginal',
        Description => 'Shooting Date/Time',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x9004 => {
        Name => 'CreateDate',
        Description => 'Date/Time Of Digitization',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x9101 => {
        Name => 'ComponentsConfiguration',
        PrintConv => '$_=$val;s/\0.*//;tr/\x01-\x06/YbrRGB/;s/b/Cb/g;s/r/Cr/g;$_',
    },
    0x9102 => 'CompressedBitsPerPixel',
    0x9201 => {
        Name => 'ShutterSpeedValue',
        ValueConv => 'abs($val)<100 ? 1/(2**$val) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x9202 => {
        Name => 'ApertureValue',
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x9203 => {
        Name => 'BrightnessValue',
    },
    0x9204 => {
        Name => 'ExposureCompensation',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x9205 => {
        Name => 'MaxApertureValue',
        Groups => { 2 => 'Camera' },
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x9206 => {
        Name => 'SubjectDistance',
        Groups => { 2 => 'Camera' },
        PrintConv => '"$val m"',
    },
    0x9207 => {
        Name => 'MeteringMode',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'Average',
            2 => 'Center-weighted average',
            3 => 'Spot',
            4 => 'Multi-spot',
            5 => 'Multi-segment',
            6 => 'Partial',
            255 => 'Other',
        },
    },
    0x9208 => {
        Name => 'LightSource',
        Groups => { 2 => 'Camera' },
        PrintConv => \%lightSource,
    },
    0x9209 => {
        Name => 'Flash',
        Groups => { 2 => 'Camera' },
        Flags => 'PrintHex',
        PrintConv => {
            0x00 => 'No Flash',
            0x01 => 'Fired',
            0x05 => 'Fired, Return not detected',
            0x07 => 'Fired, Return detected',
            0x09 => 'On',
            0x0d => 'On, Return not detected',
            0x0f => 'On, Return detected',
            0x10 => 'Off',
            0x18 => 'Auto, Did not fire',
            0x19 => 'Auto, Fired',
            0x1d => 'Auto, Fired, Return not detected',
            0x1f => 'Auto, Fired, Return detected',
            0x20 => 'No flash function',
            0x41 => 'Fired, Red-eye reduction',
            0x45 => 'Fired, Red-eye reduction, Return not detected',
            0x47 => 'Fired, Red-eye reduction, Return detected',
            0x49 => 'On, Red-eye reduction',
            0x4d => 'On, Red-eye reduction, Return not detected',
            0x4f => 'On, Red-eye reduction, Return detected',
            0x59 => 'Auto, Fired, Red-eye reduction',
            0x5d => 'Auto, Fired, Red-eye reduction, Return not detected',
            0x5f => 'Auto, Fired, Red-eye reduction, Return detected',
        },
    },
    0x920a => {
        Name => 'FocalLength',
        Groups => { 2 => 'Camera' },
        PrintConv => 'sprintf("%.1fmm",$val)',
    },
    # Note: tags 0x920b-0x9217 are duplicates of 0xa20b-0xa217
    # (The TIFF standard uses 0xa2xx, but you'll find both in images)
    0x920b => {
        Name => 'FlashEnergy',
        Groups => { 2 => 'Camera' },
    },
    0x920c => 'SpatialFrequencyResponse',
    0x920d => 'Noise',
    0x920e => 'FocalPlaneXResolution',
    0x920f => 'FocalPlaneYResolution',
    0x9210 => {
        Name => 'FocalPlaneResolutionUnit',
        Groups => { 2 => 'Camera' },
        ValueConv => {
            1 => '25.4',
            2 => '25.4',
            3 => '10',
            4 => '1',
            5 => '0.001',
        },
        PrintConv => {
            25.4 => 'inches',
            10 => 'cm',
            1 => 'mm',
            0.001 => 'um',
        },
    },
    0x9211 => 'ImageNumber',
    0x9212 => 'SecurityClassification',
    0x9213 => 'ImageHistory',
    0x9214 => {
        Name => 'SubjectLocation',
        Groups => { 2 => 'Camera' },
    },
    0x9215 => 'ExposureIndex',
    0x9216 => 'TIFF-EPStandardID',
    0x9217 => {
        Name => 'SensingMethod',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'Not defined',
            2 => 'One-chip color area',
            3 => 'Two-chip color area',
            4 => 'Three-chip color area',
            5 => 'Color sequential area',
            7 => 'Trilinear',
            8 => 'Color sequential linear',
        },
    },
    0x9213 => 'ImageHistory',
    # handle maker notes as a conditional list
    0x927c => \@Image::ExifTool::MakerNotes::Main,
    0x9286 => {
        Name => 'UserComment',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
    },
    0x9290 => {
        Name => 'SubSecTime',
        Groups => { 2 => 'Time' },
    },
    0x9291 => {
        Name => 'SubSecTimeOriginal',
        Groups => { 2 => 'Time' },
    },
    0x9292 => {
        Name => 'SubSecTimeDigitized',
        Groups => { 2 => 'Time' },
    },
    0x935c => 'ImageSourceData', #3
    0x9c9b => {
        Name => 'XPTitle',
        Format => 'undef',
        ValueConv => '$self->Unicode2Byte($val,"II")',
    },
    0x9c9c => {
        Name => 'XPComment',
        Format => 'undef',
        ValueConv => '$self->Unicode2Byte($val,"II")',
    },
    0x9c9d => {
        Name => 'XPAuthor',
        Groups => { 2 => 'Author' },
        Format => 'undef',
        ValueConv => '$self->Unicode2Byte($val,"II")',
    },
    0x9c9e => {
        Name => 'XPKeywords',
        Format => 'undef',
        ValueConv => '$self->Unicode2Byte($val,"II")',
    },
    0x9c9f => {
        Name => 'XPSubject',
        Format => 'undef',
        ValueConv => '$self->Unicode2Byte($val,"II")',
    },
    0xa000 => 'FlashpixVersion',
    0xa001 => {
        Name => 'ColorSpace',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
        },
    },
    0xa002 => 'ExifImageWidth',
    0xa003 => 'ExifImageLength',
    0xa004 => 'RelatedSoundFile',
    0xa005 => {
        Name => 'InteropOffset',
        Groups => { 1 => 'InteropIFD' },
        Flags => 'SubIFD',
        Description => 'Interoperability Offset',
        SubDirectory => {
            Start => '$val',
        },
    },
    0xa20b => {
        Name => 'FlashEnergy',
        Groups => { 2 => 'Camera' },
    },
    0xa20c => 'SpatialFrequencyResponse',
    0xa20d => 'Noise',
    0xa20e => 'FocalPlaneXResolution',
    0xa20f => 'FocalPlaneYResolution',
    0xa210 => {
        Name => 'FocalPlaneResolutionUnit',
        Groups => { 2 => 'Camera' },
        ValueConv => {
            1 => '25.4',
            2 => '25.4',
            3 => '10',
            4 => '1',
            5 => '0.001',
        },
        PrintConv => {
            25.4 => 'inches',
            10 => 'cm',
            1 => 'mm',
            0.001 => 'um',
        },
    },
    0xa211 => 'ImageNumber',
    0xa212 => 'SecurityClassification',
    0xa213 => 'ImageHistory',
    0xa214 => {
        Name => 'SubjectLocation',
        Groups => { 2 => 'Camera' },
    },
    0xa215 => 'ExposureIndex',
    0xa216 => 'TIFF-EPStandardID',
    0xa217 => {
        Name => 'SensingMethod',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'Not defined',
            2 => 'One-chip color area',
            3 => 'Two-chip color area',
            4 => 'Three-chip color area',
            5 => 'Color sequential area',
            7 => 'Trilinear',
            8 => 'Color sequential linear',
        },
    },
    0xa300 => {
        Name => 'FileSource',
        PrintConv => {
            3 => 'Digital Camera',
            # handle the case where Sigma incorrectly gives this tag a count of 4
            "\3\0\0\0" => 'Sigma Digital Camera',
        },
    },
    0xa301 => {
        Name => 'SceneType',
        PrintConv => {
            1 => 'Directly photographed',
        },
    },
    0xa302 => {
        Name => 'CFAPattern',
        PrintConv => 'Image::ExifTool::Exif::PrintCFAPattern($val)',
    },
    0xa401 => {
        Name => 'CustomRendered',
        PrintConv => {
            0 => 'Normal',
            1 => 'Custom',
        },
    },
    0xa402 => {
        Name => 'ExposureMode',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
            2 => 'Auto bracket',
        },
    },
    0xa403 => {
        Name => 'WhiteBalance',
        Groups => { 2 => 'Camera' },
        # set Priority to zero to keep this WhiteBalance from overriding the
        # MakerNotes WhiteBalance, since the MakerNotes WhiteBalance and is more
        # accurate and contains more information (if it exists)
        Priority => 0,
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0xa404 => {
        Name => 'DigitalZoomRatio',
        Groups => { 2 => 'Camera' },
    },
    0xa405 => {
        Name => 'FocalLengthIn35mmFormat',
        Groups => { 2 => 'Camera' },
    },
    0xa406 => {
        Name => 'SceneCaptureType',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Standard',
            1 => 'Landscape',
            2 => 'Portrait',
            3 => 'Night',
        },
    },
    0xa407 => {
        Name => 'GainControl',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'None',
            1 => 'Low gain up',
            2 => 'High gain up',
            3 => 'Low gain down',
            4 => 'High gain down',
        },
    },
    0xa408 => {
        Name => 'Contrast',
        Groups => { 2 => 'Camera' },
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
    },
    0xa409 => {
        Name => 'Saturation',
        Groups => { 2 => 'Camera' },
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
    },
    0xa40a => {
        Name => 'Sharpness',
        Groups => { 2 => 'Camera' },
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
    },
    0xa40b => {
        Name => 'DeviceSettingDescription',
        Groups => { 2 => 'Camera' },
    },
    0xa40c => {
        Name => 'SubjectDistanceRange',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'Macro',
            2 => 'Close',
            3 => 'Distant',
        },
    },
    0xa420 => 'ImageUniqueID',
    0xa480 => 'GDALMetadata', #3
    0xa481 => 'GDALNoData', #3
    # 0xc350 thru 0xc41a plus 0xc46c,0xc46e are Kodak APP13 tags (ref 8)
    0xc350 => 'FilmProductCode',
    0xc351 => 'ImageSourceEK',
    0xc352 => 'CaptureConditionsPAR',
    0xc353 => {
        Name => 'CameraOwner',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
    },
    0xc354 => {
        Name => 'SerialNumber',
        Groups => { 2 => 'Camera' },
    },
    0xc355 => 'UserSelectGroupTitle',
    0xc356 => 'DealerIDNumber',
    0xc357 => 'CaptureDeviceFID',
    0xc358 => 'EnvelopeNumber',
    0xc359 => 'FrameNumber',
    0xc35a => 'FilmCategory',
    0xc35b => 'FilmGencode',
    0xc35c => 'ModelAndVersion',
    0xc35d => 'FilmSize',
    0xc35e => 'SBA_RGBShifts',
    0xc35f => 'SBAInputImageColorspace',
    0xc360 => 'SBAInputImageBitDepth',
    0xc361 => 'SBAExposureRecord',
    0xc362 => 'UserAdjSBA_RGBShifts',
    0xc363 => 'ImageRotationStatus',
    0xc364 => 'RollGuidElements',
    0xc365 => 'MetadataNumber',
    0xc366 => 'EditTagArray',
    0xc367 => 'Magnification',
    0xc36c => 'NativeXResolution',
    0xc36d => 'NativeYResolution',
    0xc36e => {
        Name => 'KodakEffectsIFD',
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SpecialEffects',
            Start => '$val',
        },
    },
    0xc36f => {
        Name => 'KodakBordersIFD',
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Borders',
            Start => '$val',
        },
    },
    0xc37a => 'NativeResolutionUnit',
    0xc418 => 'SourceImageDirectory',
    0xc419 => 'SourceImageFileName',
    0xc41a => 'SourceImageVolumeName',
    # (end Kodak APP3 tags)
    0xc427 => 'OceScanjobDesc', #3
    0xc428 => 'OceApplicationSelector', #3
    0xc429 => 'OceIDNumber', #3
    0xc42a => 'OceImageLogic', #3
    0xc44f => 'Annotations', #7
    0xc46c => 'PrintQuality', #8 (Kodak APP3)
    0xc46e => 'ImagePrintStatus', #8 (Kodak APP3)
    0xc4a5 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0xc612 => 'DNGVersion', #2
    0xc613 => 'DNGBackwardVersion', #2
    0xc614 => 'UniqueCameraModel', #2
    0xc615 => { #2
        Name => 'LocalizedCameraModel',
        Format => 'string',
        PrintConv => '$self->Printable($val)',
    },
    0xc616 => 'CFAPlaneColor', #2
    0xc617 => { #2
        Name => 'CFALayout',
        PrintConv => {
            1 => 'Rectangular',
            2 => 'Even columns offset down 1/2 row',
            3 => 'Even columns offset up 1/2 row',
            4 => 'Even rows offset right 1/2 column',
            5 => 'Even rows offset left 1/2 column',
        },
    },
    0xc618 => { #2
        Name => 'LinearizationTable',
        PrintConv => '\$val',
    },
    0xc619 => 'BlackLevelRepeatDim', #2
    0xc61a => 'BlackLevel', #2
    0xc61b => 'BlackLevelDeltaH', #2
    0xc61c => 'BlackLevelDeltaV', #2
    0xc61d => 'WhiteLevel', #2
    0xc61e => 'DefaultScale', #2
    0xc61f => 'DefaultCropOrigin', #2
    0xc620 => 'DefaultCropSize', #2
    0xc621 => 'ColorMatrix1', #2
    0xc622 => 'ColorMatrix2', #2
    0xc623 => 'CameraCalibration1', #2
    0xc624 => 'CameraCalibration2', #2
    0xc625 => 'ReductionMatrix1', #2
    0xc626 => 'ReductionMatrix2', #2
    0xc627 => 'AnalogBalance', #2
    0xc628 => 'AsShotNeutral', #2
    0xc629 => 'AsShotWhiteXY', #2
    0xc62a => 'BaselineExposure', #2
    0xc62b => 'BaselineNoise', #2
    0xc62c => 'BaselineSharpness', #2
    0xc62d => 'BayerGreenSplit', #2
    0xc62e => 'LinearResponseLimit', #2
    0xc62f => { #2
        Name => 'DNGCameraSerialNumber',
        Groups => { 2 => 'Camera' },
    },
    0xc630 => { #2
        Name => 'DNGLensInfo',
        Groups => { 2 => 'Camera' },
        PrintConv => '$_=$val;s/(\S+) (\S+) (\S+) (\S+)/$1-$2mm f\/$3-$4/;$_',
    },
    0xc631 => 'ChromaBlurRadius', #2
    0xc632 => 'AntiAliasStrength', #2
    0xc633 => 'ShadowScale', #DNG forum at http://www.adobe.com/support/forums/main.html
    0xc634 => 'DNGPrivateData', #2
    0xc635 => { #2
        Name => 'MakerNoteSafety',
        PrintConv => {
            0 => 'Unsafe',
            1 => 'Safe',
        },
    },
    0xc65a => { #2
        Name => 'CalibrationIlluminant1',
        PrintConv => \%lightSource,
    },
    0xc65b => { #2
        Name => 'CalibrationIlluminant2',
        PrintConv => \%lightSource,
    },
    0xc65c => 'BestQualityScale', #3 (incorrect in ref 2)
    0xc660 => 'AliasLayerMetadata', #3

    # tags in the range 0xfde8-0xfe58 have been observed in PS7 files
    # generated from RAW images.  They are all strings with the
    # tag name at the start of the string.  To accomodate these types
    # of tags, all tags with values above 0xf000 are handled specially
    # by ProcessExif().
);

# Kodak Sub-IFD's (ref 8) - (put them here for convenience)
%Image::ExifTool::Kodak::SpecialEffects = (
    GROUPS => { 0 => 'EXIF', 1 => 'KodakEffectsIFD', 2 => 'Image'},
    0 => 'DigitalEffectsVersion',
    1 => {
        Name => 'DigitalEffectsName',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
    },
    2 => 'DigitalEffectsType',
);
%Image::ExifTool::Kodak::Borders = (
    GROUPS => { 0 => 'EXIF', 1 => 'KodakBordersIFD', 2 => 'Image'},
    0 => 'BordersVersion',
    1 => {
        Name => 'BorderName',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
    },
    2 => 'BorderID',
    3 => 'BorderLocation',
    4 => 'BorderType',
    8 => 'WatermarkType',
);

# the Composite tags are evaluated last, and are used
# to calculate values based on the other tags
# (the main script looks for the special 'Composite' hash)
%Image::ExifTool::Exif::Composite = (
    GROUPS => { 2 => 'Image' },
    ImageSize => {
        Require => {
            0 => 'ImageWidth',
            1 => 'ImageHeight',
        },
        ValueConv => '"$val[0]x$val[1]"',
    },
    # pick the best shutter speed value
    ShutterSpeed => {
        Desire => {
            0 => 'ExposureTime',
            1 => 'ShutterSpeedValue',
            2 => 'BulbDuration',
        },
        ValueConv => '$val[2] ? $val[2] : (defined($val[0]) ? $val[0] : $val[1])',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    Aperture => {
        Desire => {
            0 => 'FNumber',
            1 => 'ApertureValue',
        },
        ValueConv => '$val[0] ? $val[0] : $val[1]',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    FocalLength35efl => {
        Description => 'Focal Length',
        Groups => { 2 => 'Camera' },
        Require => {
            0 => 'FocalLength',
        },
        Desire => {
            1 => 'ScaleFactor35efl',
        },
        ValueConv => '$val[0] * ($val[1] ? $val[1] : 1)',
        PrintConv => '$val[1] ? sprintf("%.1fmm (35mm equivalent: %.1fmm)", $val[0], $val) : sprintf("%.1fmm", $val)',
    },
    ScaleFactor35efl => {
        Description => 'Scale Factor To 35mm Equivalent',
        Groups => { 2 => 'Camera' },
        Desire => {
            0 => 'FocalLength',
            1 => 'FocalLengthIn35mmFormat',
            2 => 'FocalPlaneResolutionUnit',
            3 => 'FocalPlaneXResolution',
            4 => 'FocalPlaneYResolution',
            5 => 'CanonImageWidthAsShot',
            6 => 'CanonImageHeightAsShot',
            7 => 'ExifImageWidth',
            8 => 'ExifImageLength',
            9 => 'ImageWidth',
           10 => 'ImageHeight',
        },
        ValueConv => 'Image::ExifTool::Exif::CalcScaleFactor35efl(@val)',
        PrintConv => 'sprintf("%.1f", $val)',
    },
    ThumbnailImage => {
        Writable => 1,
        Require => {
            0 => 'ThumbnailOffset',
            1 => 'ThumbnailLength',
        },
        # retrieve the thumbnail from our EXIF data
        ValueConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"ThumbnailImage",$dataPt)',
        ValueConvInv => '$val',
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
    PreviewImage => {
        Writable => 1,
        Require => {
            0 => 'PreviewImageStart',
            1 => 'PreviewImageLength',
        },
        ValueConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"PreviewImage")',
        ValueConvInv => '$val',
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
    JpgFromRaw => {
        Writable => 1,
        Require => {
            0 => 'JpgFromRawStart',
            1 => 'JpgFromRawLength',
        },
        ValueConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"JpgFromRaw")',
        ValueConvInv => '$val',
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
    PreviewImageSize => {
        Require => {
            0 => 'PreviewImageWidth',
            1 => 'PreviewImageHeight',
        },
        ValueConv => '"$val[0]x$val[1]"',
    },
    ProcessGeoTiff => {
        Require => {
            0 => 'GeoTiffDirectory',
        },
        Desire => {
            1 => 'GeoTiffDoubleParams',
            2 => 'GeoTiffAsciiParams',
        },
        ValueConv => q{
            my $tagTable = GetTagTable("Image::ExifTool::GeoTiff::Main");
            Image::ExifTool::GeoTiff::ProcessGeoTiff($self, $tagTable, \$val[0], \$val[1], \$val[2]);
            unless ($self->Options('Verbose')) {
                # this is duplicate information so delete it unless verbose
                $self->DeleteTag('GeoTiffDirectory');
                $self->DeleteTag('GeoTiffDoubleParams');
                $self->DeleteTag('GeoTiffAsciiParams');
            }
            return undef;       # don't generate a tag value
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::Exif::Composite);


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Calculate scale factor for 35mm effective focal length
# Inputs: 0) Focal length
#         1) Focal length in 35mm format
#         2) focal plane resolution units (in mm)
#         3/4) Focal plane X/Y resolution
#         5/6,7/8...) Image width/height in order of precidence (first valid pair is used)
# Returns: 35mm conversion factor (or undefined if it can't be calculated)
sub CalcScaleFactor35efl
{
    my $focal = shift;
    my $foc35 = shift;

    return $foc35 / $focal if $focal and $foc35;

    my $units = shift || return undef;
    my $x_res = shift || return undef;
    my $y_res = shift || return undef;
    my ($w, $h);
    for (;;) {
        @_ < 2 and return undef;
        $w = shift;
        $h = shift;
        last if $w and $h;
    }
    # calculate focal plane size in mm
    $w *= $units / $x_res;
    $h *= $units / $y_res;
    return sqrt(36*36+24*24) / sqrt($w*$w+$h*$h);
}

#------------------------------------------------------------------------------
# Convert exposure compensation fraction
sub ConvertFraction($)
{
    my $val = shift;
    my $str;
    if (defined $val) {
        $val *= 1.00001;    # avoid round-off errors
        if (not $val) {
            $str = '0';
        } elsif (int($val)/$val > 0.999) {
            $str = sprintf("%+d", int($val));
        } elsif ((int($val*2))/($val*2) > 0.999) {
            $str = sprintf("%+d/2", int($val * 2));
        } elsif ((int($val*3))/($val*3) > 0.999) {
            $str = sprintf("%+d/3", int($val * 3));
        } else {
            $str = sprintf("%.3g", $val);
        }
    }
    return $str;
}

#------------------------------------------------------------------------------
# Convert EXIF text to something readable
# Inputs: 0) ExifTool object reference, 1) EXIF text
# Returns: UTF8 or Latin text
sub ConvertExifText($$)
{
    my ($exifTool, $val) = @_;
    return $val if length($val) < 8;
    my $id = substr($val, 0, 8);
    my $str = substr($val, 8);
    if ($id eq "UNICODE\0") {
        # convert from unicode
        $str = $exifTool->Unicode2Byte($str);
    } else {
        # assume everything else is ASCII (Don't convert JIS... yet)
        $str =~ s/\0.*//;   # truncate at null terminator
    }
    return $str;
}

#------------------------------------------------------------------------------
# Print parameter value (with sign, or 'Normal' for zero)
sub PrintParameter($) {
    my $val = shift;
    if ($val > 0) {
        if ($val > 0xfff0) {    # a negative value in disguise?
            $val = $val - 0x10000;
        } else {
            $val = "+$val";
        }
    } elsif ($val == 0) {
        $val = 'Normal';
    }
    return $val;
}

#------------------------------------------------------------------------------
# Print exposure time as a fraction
sub PrintExposureTime($)
{
    my $secs = shift;
    if ($secs < 0.25001 and $secs > 0) {
        return sprintf("1/%d",int(0.5 + 1/$secs));
    }
    $_ = sprintf("%.1f",$secs);
    s/\.0$//;
    return $_;
}

#------------------------------------------------------------------------------
# Print CFA Pattern
sub PrintCFAPattern($)
{
    my $val = shift;
    return '<truncated data>' unless length $val > 4;
    my ($nx, $ny) = (Get16u(\$val, 0), Get16u(\$val, 2));
    return '<zero pattern size>' unless $nx and $ny;
    my $end = 4 + $nx * $ny;
    if ($end > length $val) {
        # try swapping byte order (I have seen this order different than in EXIF)
        ($nx, $ny) = unpack('n2',pack('v2',$nx,$ny));
        $end = 4 + $nx * $ny;
        return '<invalid pattern size>' if $end > length $val;
    }
    my @cfaColor = ('Red','Green','Blue','Cyan','Magenta','Yellow','White');
    my ($pos, $rtnVal) = (4, '[');
    for (;;) {
        $rtnVal .= $cfaColor[Get8u(\$val,$pos)] || 'Unknown';
        last if ++$pos >= $end;
        ($pos - 4) % $ny and $rtnVal .= ',', next;
        $rtnVal .= '][';
    }
    return $rtnVal . ']';
}

#------------------------------------------------------------------------------
# translate date into standard EXIF format
# Inputs: 0) date
# Returns: date in format '2003:10:22'
# - bad formats recognized: '2003-10-22','2003/10/22','2003 10 22','20031022'
# - removes null terminator if it exists
sub ExifDate($)
{
    my $date = shift;
    $date =~ tr/ -\//:/;    # use ':' (not ' ', '-' or '/') as a separator
    $date =~ s/\0$//;       # remove any null terminator
    # add separators if they don't exist
    $date =~ s/^(\d{4})(\d{2})(\d{2})$/$1:$2:$3/;
    return $date;
}

#------------------------------------------------------------------------------
# translate time into standard EXIF format
# Inputs: 0) time
# Returns: time in format '10:30:55'
# - bad formats recognized: '10 30 55', '103055', '103055'
# - removes null terminator if it exists
# - leaves time zone intact if specified (ie. '10:30:55+05:00')
sub ExifTime($)
{
    my $time = shift;
    $time =~ tr/ /:/;   # use ':' (not ' ') as a separator
    $time =~ s/\0$//;   # remove any null terminator
    # add separators if they don't exist
    $time =~ s/^(\d{2})(\d{2})(\d{2})/$1:$2:$3/;
    $time =~ s/([+-]\d{2})(\d{2})\s*$/$1:$2/;   # to timezone too
    return $time;
}

#------------------------------------------------------------------------------
# Decode bit mask
# Inputs: 0) value to decode,
#         1) Reference to hash for decoding
sub DecodeBits($$)
{
    my $bits = shift;
    my $lookup = shift;
    my $outStr = '';
    my $i;
    for ($i=0; $i<32; ++$i) {
        next unless $bits & (1 << $i);
        $outStr .= ', ' if $outStr;
        if ($$lookup{$i}) {
            $outStr .= $$lookup{$i};
        } else {
            $outStr .= "[$i]";
        }
    }
    return $outStr || '(none)';
}

#------------------------------------------------------------------------------
# extract image from file
# Inputs: 0) ExifTool object reference, 1) data offset, 2) data length
#         3) [optional] tag name, 4) Optional data pointer
# Returns: Image if specifically requested or "Binary data" message
#          Returns undef if there was an error loading the image
sub ExtractImage($$$$;$)
{
    my ($exifTool, $offset, $len, $tag, $dataPt) = @_;

    my $image;

    if ($dataPt and $offset+$len < length($$dataPt)) {
        $image = substr($$dataPt, $offset, $len);
    } else {
        $image = $exifTool->ExtractBinary($offset, $len, $tag);
        if (defined $image) {
            # make sure this is a good image if we loaded it
            unless ($image =~ /^(Binary data|\xff\xd8)/ or
                    $exifTool->Options('IgnoreMinorErrors'))
            {
                $tag = 'PreviewImage' unless $tag;
                $exifTool->Warn("$tag is not a valid image");
                return undef;
            }
        }
    }
    return $image;
}

#------------------------------------------------------------------------------
# Process EXIF directory
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table for this directory
#         2) Reference to directory information hash
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessExif($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $dataPos = $dirInfo->{DataPos} || 0;
    my $dataLen = $dirInfo->{DataLen};
    my $dirStart = $dirInfo->{DirStart} || 0;
    my $dirLen = $dirInfo->{DirLen} || $dataLen - $dirStart;
    my $base = $dirInfo->{Base} || 0;
    my $raf = $dirInfo->{RAF};
    my $success = 1;
    my $verbose = $exifTool->Options('Verbose');
    my ($tagKey, $warnOutside);

    if ($dirInfo->{Nesting} > 4) {
        $exifTool->Warn('EXIF nesting level too deep');
        return 0;
    }
    if ($dirInfo->{DirName} eq 'EXIF') {
        $dirInfo->{DirName} = 'IFD0';
    } elsif ($dirInfo->{DirName} eq 'MakerNotes') {
        $warnOutside = 1;
    }
    # read IFD from file if necessary
    if ($dirStart < 0 or $dirStart > $dataLen-2) {
        $success = 0;
        if ($raf) {
            # read the count of entries in this IFD
            my $offset = $dirStart + $dataPos;
            my ($buff, $buf2);
            if ($raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2) {
                my $len = 12 * Get16u(\$buff,0);
                # also read next IFD pointer if reading multiple IFD's
                $len += 4 if $dirInfo->{Multi};
                if ($raf->Read($buf2, $len) == $len) {
                    $buff .= $buf2;
                    # make copy of dirInfo since we're going to modify it
                    my %newDirInfo = %$dirInfo;
                    $dirInfo = \%newDirInfo;
                    # update directory parameters for the newly loaded IFD
                    $dataPt = $dirInfo->{DataPt} = \$buff;
                    $dataPos = $dirInfo->{DataPos} = $offset;
                    $dataLen = $dirInfo->{DataLen} = $len + 2;
                    $dirStart = $dirInfo->{DirStart} = 0;
                    $success = 1;
                }
            }
        }
        unless ($success) {
            $exifTool->Warn("Bad $$dirInfo{DirName} directory");
            return 0;
        }
    }

    my $numEntries = Get16u($dataPt, $dirStart);

    $verbose and $exifTool->VerboseDir($dirInfo->{DirName}, $numEntries);
    my $dirEnd = $dirStart + 2 + 12 * $numEntries;
    my $bytesFromEnd = $dataLen - $dirEnd;
    if ($bytesFromEnd < 4) {
        unless ($bytesFromEnd==2 or $bytesFromEnd==0) {
            $exifTool->Warn(sprintf"Illegal $$dirInfo{DirName} directory size (0x%x entries)",$numEntries);
            return 0;
        }
    }

    # loop through all entries in an EXIF directory (IFD)
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        my $format = Get16u($dataPt, $entry+2);
        my $count = Get32u($dataPt, $entry+4);
        if ($format < 1 or $format > 12) {
            # warn unless the IFD was just padded with zeros
            $format and $exifTool->Warn("Bad EXIF directory entry format ($format)");
            return 0 unless $index; # no success if this is our first entry
            last;   # stop now because this IFD could be corrupt
        }
        my $size = $count * $formatSize[$format];
        my $valueDataPt = $dataPt;
        my $valueDataPos = $dataPos;
        my $valueDataLen = $dataLen;
        my $valuePtr = $entry + 8;      # pointer to value within $$dataPt
        if ($size > 4) {
            my $didRead;
            $valuePtr = Get32u($dataPt, $valuePtr) - $dataPos;
            if ($valuePtr < 0 or $valuePtr+$size > $dataLen) {
                # get value by seeking in file if we are allowed
                if ($raf) {
                    if ($raf->Seek($base + $valuePtr + $dataPos,0)) {
                        my $buff;
                        if ($raf->Read($buff,$size) == $size) {
                            $valueDataPt = \$buff;
                            $valueDataPos = $valuePtr + $dataPos;
                            $valueDataLen = $size;
                            $valuePtr = 0;
                        }
                    }
                }
                if ($valuePtr) {
                    my $tagStr = sprintf("0x%x",$tagID);
                    $exifTool->Warn("Bad EXIF directory pointer value for tag $tagStr");
                    next;
                }
                $didRead = 1;
            }
            if ($warnOutside and ($didRead or $valuePtr < $dirStart or
                $valuePtr+$size > $dirStart+$dirLen))
            {
                $exifTool->{MAKER_NOTE_WARN} = 1;
                undef $warnOutside;
            }
        }
        my $formatStr = $formatName[$format];   # get name of this format
        # treat single unknown byte as int8u
        $formatStr = 'int8u' if $format == 7 and $count == 1;

        my $val;
        if ($tagID > 0xf000 and not $$tagTablePtr{$tagID}
            and $tagTablePtr eq \%Image::ExifTool::Exif::Main)
        {
            # handle special case of Photoshop RAW tags (0xfde8-0xfe58)
            # --> generate tags from the value if possible
            $val = ReadValue($valueDataPt,$valuePtr,$formatStr,$count,$size);
            if (defined $val and $val =~ /(.*): (.*)/) {
                my $desc = $1;
                $val = $2;
                my $tag = $desc;
                $tag =~ s/'s//; # remove 's (so "Owner's Name" becomes "OwnerName")
                $tag =~ tr/a-zA-Z0-9_//cd; # remove unknown characters
                if ($tag) {
                    my $tagInfo = {
                        Name => $tag,
                        Description => $desc,
                        ValueConv => '$_=$val;s/.*: //;$_', # remove descr
                    };
                    Image::ExifTool::AddTagToTable($tagTablePtr, $tagID, $tagInfo);
                }
            }
        }
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
        next unless $tagInfo or $verbose;
        # override EXIF format if specified
        if ($tagInfo) {
            if ($$tagInfo{Format}) {
                $formatStr = $$tagInfo{Format};
                # must adjust number of items for new format size
                my $newNum = $formatNumber{$$tagInfo{Format}};
                if ($newNum) {
                    $format = $newNum;
                    $count = $size / $formatSize[$format];
                }
            }
        } else {
            next unless $verbose;
        }
        # convert according to specified format
        $val = ReadValue($valueDataPt,$valuePtr,$formatStr,$count,$size);

        if ($verbose) {
            $exifTool->VerboseInfo($tagID, $tagInfo,
                Table  => $tagTablePtr,
                Index  => $index,
                Value  => $val,
                DataPt => $valueDataPt,
                Size   => $size,
                Start  => $valuePtr,
                Format => $formatName[$format],
                Count  => $count,
            );
            next unless $tagInfo;
        }
#..............................................................................
# Handle SubDirectory tag types
#
        my $subdir = $$tagInfo{SubDirectory};
        if ($subdir) {
            my $tagStr = $$tagInfo{Name};
            my @values;
            if ($$subdir{MaxSubdirs}) {
                @values = split /\s+/, $val;
                # limit the number of subdirectories we parse
                pop @values while @values > $$subdir{MaxSubdirs};
                $val = shift @values;
            }
            # loop through all sub-directories specified by this tag
            my $newTagTable;
            for (;;) {
                my $subdirBase = $base;
                my $subdirDataPt = $valueDataPt;
                my $subdirDataPos = $valueDataPos;
                my $subdirDataLen = $valueDataLen;
                my $subdirStart = $valuePtr;
                if (defined $$subdir{Start}) {
                    # set local $valuePtr relative to file $base for eval
                    my $valuePtr = $subdirStart + $subdirDataPos;
                    #### eval Start ($valuePtr, $val)
                    $subdirStart = eval($$subdir{Start});
                    # convert back to relative to $subdirDataPt
                    $subdirStart -= $subdirDataPos;
                }
                # this is a pain, but some maker notes are always a specific
                # byte order, regardless of the byte order of the file
                my $oldByteOrder = GetByteOrder();
                my $newByteOrder = $$subdir{ByteOrder};
                if ($newByteOrder) {
                    if ($newByteOrder =~ /^Little/i) {
                        $newByteOrder = 'II';
                    } elsif ($newByteOrder =~ /^Big/i) {
                        $newByteOrder = 'MM';
                    } elsif ($$subdir{OffsetPt}) {
                        warn "Can't have variable byte ordering for SubDirectories using OffsetPt\n";
                        last;
                    } else {
                        # attempt to determine the byte ordering by checking
                        # at the number of directory entries.  This is an int16u
                        # that should be a reasonable value.
                        my $num = Image::ExifTool::Get16u($subdirDataPt, $subdirStart);
                        if ($num & 0xff00 and ($num>>8) > ($num&0xff)) {
                            # This looks wrong, we shouldn't have this many entries
                            my %otherOrder = ( II=>'MM', MM=>'II' );
                            $newByteOrder = $otherOrder{$oldByteOrder};
                        } else {
                            $newByteOrder = $oldByteOrder;
                        }
                    }
                } else {
                    $newByteOrder = $oldByteOrder;
                }
                # set base offset if necessary
                if ($$subdir{Base}) {
                    # calculate subdirectory start relative to $base for eval
                    my $start = $subdirStart + $subdirDataPos;
                    #### eval Base ($start)
                    $subdirBase = eval($$subdir{Base}) + $base;
                }
                # add offset to the start of the directory if necessary
                if ($$subdir{OffsetPt}) {
                    SetByteOrder($newByteOrder);
                    #### eval OffsetPt ($valuePtr)
                    $subdirStart += Get32u($dataPt, eval $$subdir{OffsetPt});
                    SetByteOrder($oldByteOrder);
                }
                if ($subdirStart < 0 or $subdirStart + 2 > $subdirDataLen) {
                    # convert $subdirStart back to a file offset
                    $subdirStart += $subdirDataPos;
                    my $dirOK;
                    if ($raf) {
                        # read the directory from the file
                        if ($raf->Seek($subdirStart + $base,0)) {
                            my $buff;
                            if ($raf->Read($buff,2) == 2) {
                                # get no. dir entries
                                my $size = 12 * Get16u(\$buff, 0);
                                # read dir
                                my $buf2;
                                if ($raf->Read($buf2,$size) == $size) {
                                    # set up variables to process new subdir data
                                    $buff .= $buf2;
                                    $subdirDataPt = \$buff;
                                    $subdirDataPos = $subdirStart;
                                    $subdirDataLen = $size + 2;
                                    $subdirStart = 0;
                                    $dirOK = 1;
                                }
                            }
                        }
                    }
                    unless ($dirOK) {
                        my $msg = "Bad $tagStr SubDirectory start";
                        if ($verbose) {
                            if ($subdirStart < 0) {
                                $msg .= " (directory start $subdirStart is before EXIF start)";
                            } else {
                                my $end = $subdirStart + $size;
                                $msg .= " (directory end is $subdirStart but EXIF size is only $subdirDataLen)";
                            }
                        }
                        $exifTool->Warn($msg);
                        last;
                    }
                }
                if ($$subdir{TagTable}) {
                    $newTagTable = GetTagTable($$subdir{TagTable});
                    unless ($newTagTable) {
                        warn "Unknown tag table $$subdir{TagTable}\n";
                        last;
                    }
                } else {
                    $newTagTable = $tagTablePtr;    # use existing table
                }

                # must update subdirDataPos if $base changes for this subdirectory
                $subdirDataPos += $base - $subdirBase;

                # build information hash for new directory
                my %subdirInfo = (
                    Name     => $tagStr,
                    Base     => $subdirBase,
                    DataPt   => $subdirDataPt,
                    DataPos  => $subdirDataPos,
                    DataLen  => $subdirDataLen,
                    DirStart => $subdirStart,
                    DirLen   => $size,
                    Nesting  => $dirInfo->{Nesting} + 1,
                    RAF      => $raf,
                    Parent   => $dirInfo->{DirName},
                );
                # set directory IFD name from group name of family 1 in tag information if it exists
                $$tagInfo{Groups} and $subdirInfo{DirName} = $tagInfo->{Groups}->{1};

                SetByteOrder($newByteOrder);        # set byte order for this subdir
                # validate the subdirectory if necessary
                my $dirData = $subdirDataPt;    # set data pointer to be used in eval
                #### eval Validate ($val, $dirData, $subdirStart, $size)
                my $ok = 0;
                if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                    $exifTool->Warn("Invalid $tagStr data");
                } else {
                    # process the subdirectory
                    $ok = $exifTool->ProcessTagTable($newTagTable, \%subdirInfo, $$subdir{ProcessProc});
                }
                # print debugging information if there were errors
                if (not $ok and $verbose > 1 and $subdirStart != $valuePtr) {
                    $exifTool->VerboseInfo($tagID, $tagInfo,
                        Value  => $val,
                        DataPt => $subdirDataPt,
                        Size   => $subdirDataLen - $subdirStart,
                        Start  => $subdirStart,
                        Format => $formatStr,
                        Count  => $count,
                        Index  => $index,
                        Table  => $tagTablePtr,
                        Extra  => '(Bad SubDirectory data)',
                    );
                }
                SetByteOrder($oldByteOrder);    # restore original byte swapping

                @values or last;
                $val = shift @values;           # continue with next subdir
            }
            next unless $exifTool->Options('MakerNotes') and $$tagInfo{MakerNotes};
            if ($exifTool->{MAKER_NOTE_WARN}) {
                # this is a pain, but we must rebuild maker notes to include
                # all the value data if data was outside the maker notes
                my %makerDirInfo = (
                    Name     => $tagStr,
                    Base     => $base,
                    DataPt   => $valueDataPt,
                    DataPos  => $valueDataPos,
                    DataLen  => $valueDataLen,
                    DirStart => $valuePtr,
                    DirLen   => $size,
                    RAF      => $raf,
                    Parent   => $dirInfo->{DirName},
                    DirName  => 'MakerNotes',
                );
                my $val2 = RebuildMakerNotes($exifTool, $newTagTable, \%makerDirInfo);
                if (defined $val2) {
                    $val = $val2;
                    $verbose and $exifTool->Warn('Maker notes were not self-contained --> Rebuilt');
                } else {
                    $exifTool->Warn('Error rebuilding maker notes (may be corrupt)');
                }
            }
            $exifTool->{MAKER_NOTE_POS} = $valueDataPos + $valuePtr;
        }
 #..............................................................................
        # convert to absolute offsets if this tag is an offset
        if ($$tagInfo{IsOffset}) {
            my @vals = split(' ',$val);
            foreach $val (@vals) {
                $val += $base;
            }
            $val = join(' ', @vals);
        }
        # save the value of this tag
        $tagKey = $exifTool->FoundTag($tagInfo, $val);
        $exifTool->SetTagExtra($tagKey, $dirInfo->{DirName});
    }

    # scan for subsequent IFD's if specified
    if ($dirInfo->{Multi} and $bytesFromEnd >= 4) {
        my $offset = Get32u($dataPt, $dirEnd);
        if ($offset) {
            my $subdirStart = $offset - $dataPos;
            # use same directory information for trailing directory,
            # but change the start location and increment the nesting
            # to avoid recursively processing the same directory
            my %newDirInfo = %$dirInfo;
            ++$newDirInfo{Nesting};
            # increment IFD number if necessary
            if ($newDirInfo{DirName} =~ /^IFD(\d+)$/) {
                $newDirInfo{DirName} = 'IFD' . ($1 + 1);
            }
            $newDirInfo{DirStart} = $subdirStart;
            $exifTool->ProcessTagTable($tagTablePtr, \%newDirInfo) or $success = 0;
        }
    }
    return $success;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Exif - Definitions for EXIF meta information

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains main definitions required by Image::ExifTool to
interpret EXIF meta information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf

=item http://www.adobe.com/products/dng/pdfs/dng_spec.pdf

=item http://www.awaresystems.be/imaging/tiff/tifftags.html

=item http://www.remotesensing.org/libtiff/TIFFTechNote2.html

=item http://www.asmail.be/msg0054681802.html

=item http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html

=item http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf

=item http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
