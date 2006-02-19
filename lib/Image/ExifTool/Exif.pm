#------------------------------------------------------------------------------
# File:         Exif.pm
#
# Description:  Read EXIF meta information
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/06/2004 - P. Harvey Moved processing functions from ExifTool
#               03/19/2004 - P. Harvey Check PreviewImage for validity
#               11/11/2004 - P. Harvey Split off maker notes into MakerNotes.pm
#               12/13/2004 - P. Harvey Added AUTOLOAD to load write routines
#
# References:   0) http://www.exif.org/Exif2-2.PDF
#               1) http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf
#               2) http://www.adobe.com/products/dng/pdfs/dng_spec.pdf
#               3) http://www.awaresystems.be/imaging/tiff/tifftags.html
#               4) http://www.remotesensing.org/libtiff/TIFFTechNote2.html
#               5) http://www.asmail.be/msg0054681802.html
#               6) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               7) http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf
#               8) http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html
#               9) http://hul.harvard.edu/jhove/tiff-tags.html
#              10) http://partners.adobe.com/public/developer/en/tiff/TIFFPM6.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;
use vars qw($VERSION $AUTOLOAD @formatSize @formatName %formatNumber
            %lightSource %compression %photometricInterpretation %orientation);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::MakerNotes;

$VERSION = '1.86';

sub ProcessExif($$$);
sub WriteExif($$$);
sub CheckExif($$$);
sub RebuildMakerNotes($$$);

# byte sizes for the various EXIF format types below
@formatSize = (0,1,1,2,4,8,1,1,2,4,8,4,8,4);

@formatName = (
    'err','int8u','string','int16u',
    'int32u','rational64u','int8s','undef',
    'int16s','int32s','rational64s','float',
    'double', 'ifd'
);

# hash to look up EXIF format numbers by name
# (format types are all lower case)
%formatNumber = (
    'int8u'         => 1,   # BYTE
    'string'        => 2,   # ASCII
    'int16u'        => 3,   # SHORT
    'int32u'        => 4,   # LONG
    'rational64u'   => 5,   # RATIONAL
    'int8s'         => 6,   # SBYTE
    'undef'         => 7,   # UNDEFINED
    'binary'        => 7,   # (treat binary data as undef)
    'int16s'        => 8,   # SSHORT
    'int32s'        => 9,   # SLONG
    'rational64s'   => 10,  # SRATIONAL
    'float'         => 11,  # FLOAT
    'double'        => 12,  # DOUBLE
    'ifd'           => 13,  # IFD (with int32u format)
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
    5 => 'Mirror horizontal and rotate 270 CW',
    6 => 'Rotate 90 CW',
    7 => 'Mirror horizontal and rotate 90 CW',
    8 => 'Rotate 270 CW',
);

# ValueConv that makes long values binary type
my %longBin = (
    ValueConv => 'length($val) > 64 ? \$val : $val',
    ValueConvInv => '$val',
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
        # set priority directory if this is the full resolution image
        RawConv => '$self->SetPriorityDir() if $val == 0; $val',
        PrintConv => {
            0 => 'Full-resolution Image',
            1 => 'Reduced-resolution image',
            2 => 'Single page of multi-page image',
            3 => 'Single page of multi-page reduced-resolution image',
            4 => 'Transparency mask',
            5 => 'Transparency mask of reduced-resolution image',
            6 => 'Transparency mask of multi-page image',
            7 => 'Transparency mask of reduced-resolution multi-page image',
        },
    },
    0xff => {
        Name => 'OldSubfileType',
        # set priority directory if this is the full resolution image
        RawConv => '$self->SetPriorityDir() if $val == 1; $val',
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
    0x102 => {
        Name => 'BitsPerSample',
        Priority => 0,
    },
    0x103 => {
        Name => 'Compression',
        PrintConv => \%compression,
        Priority => 0,
    },
    0x106 => {
        Name => 'PhotometricInterpretation',
        PrintConv => \%photometricInterpretation,
        Priority => 0,
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
    0x10e => {
        Name => 'ImageDescription',
        Priority => 0,
    },
    0x10f => {
        Name => 'Make',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraMake',
        # save this value as an ExifTool member variable
        RawConv => '$self->{CameraMake} = $val',
    },
    0x110 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraModel',
        # save this value as an ExifTool member variable
        RawConv => '$self->{CameraModel} = $val',
    },
    0x111 => [
        {
            Condition => q[
                ($self->{TIFF_TYPE} ne "CR2" or $self->{DIR_NAME} ne "IFD0") and
                ($self->{TIFF_TYPE} ne "DNG" or $self->{DIR_NAME} ne "SubIFD1")
            ],
            Name => 'StripOffsets',
            Flags => 'IsOffset',
            OffsetPair => 0x117,  # point to associated byte counts
            ValueConv => 'length($val) > 32 ? \$val : $val',
        },
        {
            Name => 'PreviewImageStart',
            Flags => 'IsOffset',
            OffsetPair => 0x117,
            Notes => 'PreviewImageStart in IFD0 of CR2 images and SubIFD1 of DNG images',
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
        },
    ],
    0x112 => {
        Name => 'Orientation',
        PrintConv => \%orientation,
        Priority => 0,  # so IFD1 doesn't take precedence
    },
    0x115 => {
        Name => 'SamplesPerPixel',
        Priority => 0,
    },
    0x116 => {
        Name => 'RowsPerStrip',
        Priority => 0,
    },
    0x117 => [
        {
            Condition => q[
                ($self->{TIFF_TYPE} ne "CR2" or $self->{DIR_NAME} ne "IFD0") and
                ($self->{TIFF_TYPE} ne "DNG" or $self->{DIR_NAME} ne "SubIFD1")
            ],
            Name => 'StripByteCounts',
            OffsetPair => 0x111,   # point to associated offset
            ValueConv => 'length($val) > 32 ? \$val : $val',
        },
        {
            Name => 'PreviewImageLength',
            OffsetPair => 0x111,
            Notes => 'PreviewImageLength in IFD0 of CR2 images and SubIFD1 of DNG images',
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
        },
    ],
    0x118 => 'MinSampleValue',
    0x119 => 'MaxSampleValue',
    0x11a => {
        Name => 'XResolution',
        Priority => 0,  # so IFD0 takes priority over IFD1
    },
    0x11b => {
        Name => 'YResolution',
        Priority => 0,
    },
    0x11c => {
        Name => 'PlanarConfiguration',
        PrintConv => {
            1 => 'Chunky',
            2 => 'Planar',
        },
        Priority => 0,
    },
    0x11d => 'PageName',
    0x11e => 'XPosition',
    0x11f => 'YPosition',
    0x120 => {
        Name => 'FreeOffsets',
        Flags => 'IsOffset',
        OffsetPair => 0x121,
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x121 => {
        Name => 'FreeByteCounts',
        OffsetPair => 0x120,
        ValueConv => 'length($val) > 32 ? \$val : $val',
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
        ValueConv => '\$val',
    },
    0x124 => {
        Name => 'T4Options',
        PrintConv => { BITMASK => {
            0 => '2-Dimensional encoding',
            1 => 'Uncompressed',
            2 => 'Fill bits added',
        } }, #3
    },
    0x125 => {
        Name => 'T6Options',
        PrintConv => { BITMASK => {
            1 => 'Uncompressed',
        } }, #3
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
    0x129 => 'PageNumber',
    0x12c => 'ColorResponseUnit', #9
    0x12d => {
        Name => 'TransferFunction',
        ValueConv => '\$val',
    },
    0x131 => {
        Name => 'Software',
    },
    0x132 => {
        Name => 'ModifyDate',
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
    0x13f => {
        Name => 'PrimaryChromaticities',
        Priority => 0,
    },
    0x140 => {
        Name => 'ColorMap',
        Format => 'binary',
        ValueConv => '\$val',
    },
    0x141 => 'HalftoneHints',
    0x142 => 'TileWidth',
    0x143 => 'TileLength',
    0x144 => {
        Name => 'TileOffsets',
        Flags => 'IsOffset',
        OffsetPair => 0x145,
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x145 => {
        Name => 'TileByteCounts',
        OffsetPair => 0x144,
        ValueConv => 'length($val) > 32 ? \$val : $val',
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
        ValueConv => '\$val',
    },
    0x15f => { #10
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
            DirName => 'GlobParamIFD',
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
        PrintConv => { BITMASK => {
            0 => 'Unspecified compression',
            1 => 'Modified Huffman',
            2 => 'Modified Read',
            3 => 'Modified MR',
            4 => 'JBIG',
            5 => 'Baseline JPEG',
            6 => 'JBIG color',
        } },
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
            Flags => 'IsOffset',
            OffsetPair => 0x202,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD1',
            Protected => 2,
        },
        {
            Name => 'PreviewImageStart',
            Condition => '$self->{DIR_NAME} eq "MakerNotes"',
            Flags => 'IsOffset',
            OffsetPair => 0x202,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
        },
        {
            Name => 'JpgFromRawStart',
            Condition => '$self->{DIR_NAME} eq "SubIFD"',
            Flags => 'IsOffset',
            OffsetPair => 0x202,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            # JpgFromRaw is in SubIFD of NEF files
            WriteCondition => '$self->{TIFF_TYPE} eq "NEF"',
            Protected => 2,
        },
        {
            Name => 'JpgFromRawStart',
            Condition => '$self->{DIR_NAME} eq "IFD2"',
            Flags => 'IsOffset',
            OffsetPair => 0x202,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'IFD2',
            # JpgFromRaw is in IFD2 of PEF files
            WriteCondition => '$self->{TIFF_TYPE} eq "PEF"',
            Protected => 2,
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
            OffsetPair => 0x201,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD1',
            Protected => 2,
        },
        {
            Name => 'PreviewImageLength',
            Condition => '$self->{DIR_NAME} eq "MakerNotes"',
            OffsetPair => 0x201,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
        },
        {
            Name => 'JpgFromRawLength',
            Condition => '$self->{DIR_NAME} eq "SubIFD"',
            OffsetPair => 0x201,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            WriteCondition => '$self->{TIFF_TYPE} eq "NEF"',
            Protected => 2,
        },
        {
            Name => 'JpgFromRawLength',
            Condition => '$self->{DIR_NAME} eq "IFD2"',
            OffsetPair => 0x201,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'IFD2',
            WriteCondition => '$self->{TIFF_TYPE} eq "PEF"',
            Protected => 2,
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
    0x211 => {
        Name => 'YCbCrCoefficients',
        Priority => 0,
    },
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
        Priority => 0,
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
        Priority => 0,
    },
    0x214 => {
        Name => 'ReferenceBlackWhite',
        Priority => 0,
    },
    0x22f => 'StripRowCounts',
    0x2bc => {
        Name => 'ApplicationNotes',
        # this could be an XMP block
        SubDirectory => {
            DirName => 'XMP',
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    0x1000 => 'RelatedImageFileFormat',
    0x1001 => 'RelatedImageWidth',
    0x1002 => 'RelatedImageLength',
    0x800d => 'ImageID', #10
    0x80a4 => 'WangAnnotation',
    0x80e3 => 'Matteing', #9
    0x80e4 => 'DataType', #9
    0x80e5 => 'ImageDepth', #9
    0x80e6 => 'TileDepth', #9
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
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x829d => {
        Name => 'FNumber',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x82a5 => { #3
        Name => 'MDFileTag',
        Notes => 'tags 0x82a5-0x82ac are used in Molecular Dynamics GEL files',
    },
    0x82a6 => 'MDScalePixel', #3
    0x82a7 => 'MDColorTable', #3
    0x82a8 => 'MDLabName', #3
    0x82a9 => 'MDSampleInfo', #3
    0x82aa => 'MDPrepDate', #3
    0x82ab => 'MDPrepTime', #3
    0x82ac => 'MDFileUnits', #3
    0x830e => 'PixelScale',
    0x83bb => {
        Name => 'IPTC-NAA',
        SubDirectory => {
            DirName => 'IPTC',
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x847e => 'IntergraphPacketData', #3
    0x847f => 'IntergraphFlagRegisters', #3
    0x8480 => 'IntergraphMatrix',
    0x8482 => {
        Name => 'ModelTiePoint',
        Groups => { 2 => 'Location' },
    },
    0x84e0 => 'Site', #9
    0x84e1 => 'ColorSequence', #9
    0x84e2 => 'IT8Header', #9
    0x84e3 => 'RasterPadding', #9
    0x84e4 => 'BitsPerRunLength', #9
    0x84e5 => 'BitsPerExtendedRunLength', #9
    0x84e6 => 'ColorTable', #9
    0x84e7 => 'ImageColorIndicator', #9
    0x84e8 => 'BackgroundColorIndicator', #9
    0x84e9 => 'ImageColorValue', #9
    0x84ea => 'BackgroundColorValue', #9
    0x84eb => 'PixelIntensityRange', #9
    0x84ec => 'TransparencyIndicator', #9
    0x84ed => 'ColorCharacterization', #9
    0x84ee => 'HCUsage', #9
    0x8568 => {
        Name => 'AFCP_IPTC',
        SubDirectory => {
            DirName => 'IPTC2', # change name because this isn't the IPTC we want to write
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x85d8 => {
        Name => 'ModelTransform',
        Groups => { 2 => 'Location' },
    },
    0x8606 => {
        Name => 'LeafData',
        Format => 'undef',    # avoid converting huge block to string of int8u's!
        SubDirectory => {
            DirName => 'LeafIFD',
            TagTable => 'Image::ExifTool::Leaf::Main',
        },
    },
    0x8649 => {
        Name => 'PhotoshopSettings',
        Format => 'binary',
        SubDirectory => {
            DirName => 'Photoshop',
            TagTable => 'Image::ExifTool::Photoshop::Main',
        },
    },
    0x8769 => {
        Name => 'ExifOffset',
        Groups => { 1 => 'ExifIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'ExifIFD',
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
        ValueConv => '\$val',
    },
    0x87b0 => {
        Name => 'GeoTiffDoubleParams',
        Format => 'binary',
        ValueConv => '\$val',
    },
    0x87b1 => {
        Name => 'GeoTiffAsciiParams',
        ValueConv => '\$val',
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
            DirName => 'GPS',
            TagTable => 'Image::ExifTool::GPS::Main',
            Start => '$val',
        },
    },
    0x8827 => 'ISO',
    0x8828 => 'Opto-ElectricConvFactor',
    0x8829 => 'Interlace',
    0x882a => 'TimeZoneOffset',
    0x882b => 'SelfTimerMode',
    0x885c => 'FaxRecvParams', #9
    0x885d => 'FaxSubAddress', #9
    0x885e => 'FaxRecvTime', #9
    0x888a => { #PH
        Name => 'LeafSubIFD',
        Format => 'int32u',     # Leaf incorrectly uses 'undef' format!
        Groups => { 1 => 'LeafSubIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::SubIFD',
            Start => '$val',
        },
    },
    0x9000 => 'ExifVersion',
    0x9003 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x9004 => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x9101 => {
        Name => 'ComponentsConfiguration',
        PrintConv => '$_=$val;s/\0.*//s;tr/\x01-\x06/YbrRGB/;s/b/Cb/g;s/r/Cr/g;$_',
    },
    0x9102 => 'CompressedBitsPerPixel',
    0x9201 => {
        Name => 'ShutterSpeedValue',
        ValueConv => 'abs($val)<100 ? 1/(2**$val) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x9202 => {
        Name => 'ApertureValue',
        ValueConv => '2 ** ($val / 2)',
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
        ValueConv => '2 ** ($val / 2)',
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
    0x923f => 'StoNits', #9
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
            DirName => 'InteropIFD',
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
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
    },
    0xa409 => {
        Name => 'Saturation',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
    },
    0xa40a => {
        Name => 'Sharpness',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
        },
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
    0xa500 => 'Gamma',
    0xc427 => 'OceScanjobDesc', #3
    0xc428 => 'OceApplicationSelector', #3
    0xc429 => 'OceIDNumber', #3
    0xc42a => 'OceImageLogic', #3
    0xc44f => 'Annotations', #7
    0xc4a5 => {
        Name => 'PrintIM',
        # must set Writable here so this tag will be saved with MakerNotes option
        Writable => 'undef',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    # DNG tags 0xc6XX (ref 2 unless otherwise stated)
    0xc612 => {
        Name => 'DNGVersion',
        Notes => 'tags 0xc612-0xc65d are used in DNG images',
    },
    0xc613 => 'DNGBackwardVersion',
    0xc614 => 'UniqueCameraModel',
    0xc615 => {
        Name => 'LocalizedCameraModel',
        Format => 'string',
        PrintConv => '$self->Printable($val)',
    },
    0xc616 => 'CFAPlaneColor',
    0xc617 => {
        Name => 'CFALayout',
        PrintConv => {
            1 => 'Rectangular',
            2 => 'Even columns offset down 1/2 row',
            3 => 'Even columns offset up 1/2 row',
            4 => 'Even rows offset right 1/2 column',
            5 => 'Even rows offset left 1/2 column',
        },
    },
    0xc618 => {
        Name => 'LinearizationTable',
        ValueConv => '\$val',
    },
    0xc619 => 'BlackLevelRepeatDim',
    0xc61a => 'BlackLevel',
    0xc61b => { Name => 'BlackLevelDeltaH', %longBin },
    0xc61c => { Name => 'BlackLevelDeltaV', %longBin },
    0xc61d => 'WhiteLevel',
    0xc61e => 'DefaultScale',
    0xc61f => 'DefaultCropOrigin',
    0xc620 => 'DefaultCropSize',
    0xc621 => 'ColorMatrix1',
    0xc622 => 'ColorMatrix2',
    0xc623 => 'CameraCalibration1',
    0xc624 => 'CameraCalibration2',
    0xc625 => 'ReductionMatrix1',
    0xc626 => 'ReductionMatrix2',
    0xc627 => 'AnalogBalance',
    0xc628 => 'AsShotNeutral',
    0xc629 => 'AsShotWhiteXY',
    0xc62a => 'BaselineExposure',
    0xc62b => 'BaselineNoise',
    0xc62c => 'BaselineSharpness',
    0xc62d => 'BayerGreenSplit',
    0xc62e => 'LinearResponseLimit',
    0xc62f => {
        Name => 'CameraSerialNumber',
        Groups => { 2 => 'Camera' },
    },
    0xc630 => {
        Name => 'DNGLensInfo',
        Groups => { 2 => 'Camera' },
        PrintConv => '$_=$val;s/(\S+) (\S+) (\S+) (\S+)/$1-$2mm f\/$3-$4/;$_',
    },
    0xc631 => 'ChromaBlurRadius',
    0xc632 => 'AntiAliasStrength',
    0xc633 => 'ShadowScale', #DNG forum at http://www.adobe.com/support/forums/main.html
    0xc634 => [
        {
            Name => 'DNGPrivateData',
            Condition => '$self->{TIFF_TYPE} ne "SR2"',
            ValueConv => '\$val',
        },
        {
            Name => 'SR2Private',
            Groups => { 1 => 'SR2' },
            Flags => 'SubIFD',
            Format => 'int32u',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::SR2Private',
                DirName => 'SR2Private',
                Start => '$val',
            },
        },
    ],
    0xc635 => {
        Name => 'MakerNoteSafety',
        PrintConv => {
            0 => 'Unsafe',
            1 => 'Safe',
        },
    },
    0xc65a => {
        Name => 'CalibrationIlluminant1',
        PrintConv => \%lightSource,
    },
    0xc65b => {
        Name => 'CalibrationIlluminant2',
        PrintConv => \%lightSource,
    },
    0xc65c => 'BestQualityScale', #3 (incorrect in ref 2)
    0xc65d => {
        Name => 'RawDataUniqueID',
        Format => 'undef',
        ValueConv => 'uc(unpack("H*",$val))',
    },
    0xc660 => { #3
        Name => 'AliasLayerMetadata',
        Notes => 'used by Alias Sketchbook Pro, not a DNG tag',
    },
    0xc68b => {
        Name => 'OriginalRawFileName',
        Format => 'string', # sometimes written as int8u
    },
    0xc68c => {
        Name => 'OriginalRawFileData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::DNG::OriginalRaw',
        },
    },
    0xc68d => 'ActiveArea',
    0xc68e => 'MaskedAreas',
    0xc68f => {
        Name => 'AsShotICCProfile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0xc690 => 'AsShotPreProfileMatrix',
    0xc691 => {
        Name => 'CurrentICCProfile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0xc692 => 'CurrentPreProfileMatrix',

    # tags in the range 0xfde8-0xfe58 have been observed in PS7 files
    # generated from RAW images.  They are all strings with the
    # tag name at the start of the string.  To accomodate these types
    # of tags, all tags with values above 0xf000 are handled specially
    # by ProcessExif().
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
        ValueConv => '($val[2] and $val[2]>0) ? $val[2] : (defined($val[0]) ? $val[0] : $val[1])',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    Aperture => {
        Desire => {
            0 => 'FNumber',
            1 => 'ApertureValue',
        },
        RawConv => '($val[0] || $val[1]) ? $val : undef',
        ValueConv => '$val[0] || $val[1]',
        PrintConv => 'sprintf("%.1f", $val)',
    },
    FocalLength35efl => {
        Description => 'Focal Length',
        Notes => 'this value may be incorrect if image has been resized',
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
        Notes => 'this value and any derived values may be incorrect if image has been resized',
        Groups => { 2 => 'Camera' },
        Desire => {
            0 => 'FocalLength',
            1 => 'FocalLengthIn35mmFormat',
            2 => 'FocalPlaneDiagonal',
            3 => 'FocalPlaneXSize',
            4 => 'FocalPlaneYSize',
            5 => 'FocalPlaneResolutionUnit',
            6 => 'FocalPlaneXResolution',
            7 => 'FocalPlaneYResolution',
            8 => 'CanonImageWidth',
            9 => 'CanonImageHeight',
           10 => 'ExifImageWidth',
           11 => 'ExifImageLength',
           12 => 'ImageWidth',
           13 => 'ImageHeight',
        },
        ValueConv => 'Image::ExifTool::Exif::CalcScaleFactor35efl(@val)',
        PrintConv => 'sprintf("%.1f", $val)',
    },
    CircleOfConfusion => {
        Notes => 'this value may be incorrect if image has been resized',
        Require => {
            0 => 'ScaleFactor35efl',
        },
        ValueConv => 'sqrt(24*24+36*36) / ($val[0] * 1440)',
        PrintConv => 'sprintf("%.3f mm",$val)',
    },
    HyperfocalDistance => {
        Notes => 'this value may be incorrect if image has been resized',
        Require => {
            0 => 'FocalLength',
            1 => 'Aperture',
            2 => 'CircleOfConfusion',
        },
        ValueConv => q{
            return undef unless $val[1] and $val[2];
            return $val[0] * $val[0] / ($val[1] * $val[2] * 1000);
        },
        PrintConv => 'sprintf("%.2f m", $val)',
    },
    DOF => {
        Description => 'Depth of Field',
        Notes => 'this value may be incorrect if image has been resized',
        Require => {
            0 => 'FocusDistance', # FocusDistance in meters, 0 means 'inf'
            1 => 'FocalLength',
            2 => 'Aperture',
            3 => 'CircleOfConfusion',
        },
        ValueConv => q{
            return undef unless $val[1] and $val[3];
            $val[0] or $val[0] = 1e10;  # use a large number for 'inf'
            my ($s, $f) = ($val[0], $val[1]);
            my $t = $val[2] * $val[3] * ($s * 1000 - $f) / ($f * $f);
            my @v = ($s / (1 + $t), $s / (1 - $t));
            $v[1] < 0 and $v[1] = 0; # 0 means 'inf'
            return join(' ',@v);
        },
        PrintConv => q{
            $val =~ tr/,/./;    # in case locale is whacky
            my @v = split ' ', $val;
            $v[1] or return sprintf("inf (%.2f m - inf)", $v[0]);
            return sprintf("%.2f m (%.2f - %.2f)",$v[1]-$v[0],$v[0],$v[1]);
        },
    },
    DateTimeCreated => { # used by IPTC, XMP, WAV, etc
        Description => 'Date/Time Created',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateCreated',
            1 => 'TimeCreated',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # set the original date/time from DateTimeCreated if not set already
    DateTimeOriginal => {
        Condition => 'not defined($oldVal)',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateTimeCreated',
        },
        ValueConv => '$val[0]',
        PrintConv => '$prt[0]',
    },
    ThumbnailImage => {
        Writable => 1,
        WriteCheck => '$self->CheckImage(\$val)',
        Require => {
            0 => 'ThumbnailOffset',
            1 => 'ThumbnailLength',
        },
        # retrieve the thumbnail from our EXIF data
        RawConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"ThumbnailImage")',
    },
    PreviewImage => {
        Writable => 1,
        WriteCheck => '$self->CheckImage(\$val)',
        Require => {
            0 => 'PreviewImageStart',
            1 => 'PreviewImageLength',
        },
        Desire => {
            2 => 'PreviewImageValid',
        },
        WriteAlso => {
            PreviewImageValid => 'defined $val and length $val ? 1 : 0',
        },
        RawConv => q{
            return undef if defined $val[2] and not $val[2];
            return Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],'PreviewImage');
        },
        ValueConvInv => '$val',
    },
    JpgFromRaw => {
        Writable => 1,
        WriteCheck => '$self->CheckImage(\$val)',
        Require => {
            0 => 'JpgFromRawStart',
            1 => 'JpgFromRawLength',
        },
        RawConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"JpgFromRaw")',
        ValueConvInv => '$val',
    },
    PreviewImageSize => {
        Require => {
            0 => 'PreviewImageWidth',
            1 => 'PreviewImageHeight',
        },
        ValueConv => '"$val[0]x$val[1]"',
    },
    SubSecDateTimeOriginal => {
        Description => 'Date/Time Original',
        Require => {
            0 => 'DateTimeOriginal',
            1 => 'SubSecTimeOriginal',
        },
        # be careful here in case there is a timezone following the seconds
        ValueConv => '$_=$val[0];s/(.*:\d{2})/$1\.$val[1]/;$_',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CFAPattern => {
        Require => {
            0 => 'CFARepeatPatternDim',
            1 => 'CFAPattern2',
        },
        # generate CFAPattern
        ValueConv => q{
            my @a = split / /, $val[0];
            my @b = split / /, $val[1];
            return undef unless @a==2 and @b==$a[0]*$a[1];
            return Set16u($a[0]) . Set16u($a[1]) . pack('C*', @b);
        },
        PrintConv => 'Image::ExifTool::Exif::PrintCFAPattern($val)',
    },
);

# table for unknown IFD entries
%Image::ExifTool::Exif::Unknown = (
    GROUPS => { 0 => 'EXIF', 1 => 'UnknownIFD', 2 => 'Image'},
    WRITE_PROC => \&WriteExif,
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Exif::Composite');


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
#         2) Focal plane diagonal size (in mm)
#         3/4) Focal plane X/Y size (in mm)
#         5) focal plane resolution units (in mm)
#         6/7) Focal plane X/Y resolution
#         8/9,10/11...) Image width/height in order of precedence (first valid pair is used)
# Returns: 35mm conversion factor (or undefined if it can't be calculated)
sub CalcScaleFactor35efl
{
    my $focal = shift;
    my $foc35 = shift;

    return $foc35 / $focal if $focal and $foc35;

    my $diag = shift;
    unless ($diag and Image::ExifTool::IsFloat($diag)) {
        my $xsize = shift;
        my $ysize = shift;
        if ($xsize and $ysize) {
            $diag = sqrt($xsize * $xsize + $ysize * $ysize);
        } else {
            my $units = shift || return undef;
            my $x_res = shift || return undef;
            my $y_res = shift || return undef;
            my ($w, $h);
            for (;;) {
                @_ < 2 and return undef;
                $w = shift;
                $h = shift;
                next unless $w and $h;
                my $a = $w / $h;
                last if $a > 0.5 and $a < 2; # stop if we get a reasonable value
            }
            # calculate focal plane size in mm
            $w *= $units / $x_res;
            $h *= $units / $y_res;
            $diag = sqrt($w*$w+$h*$h);
            # make sure size is reasonable
            return undef unless $diag > 1 and $diag < 100;
        }
    }
    return sqrt(36*36+24*24) / $diag;
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
    # by the EXIF spec, the string should be "UNICODE\0", but apparently Kodak
    # sometimes uses "Unicode\0" in the APP3 "Meta" information.  But unfortunately
    # Ricoh uses "Unicode\0" in the RR30 EXIF UserComment when the text is actually
    # ASCII, so only recognize uppercase "UNICODE\0" here.
    if ($id eq "UNICODE\0") {
        # convert from unicode
        $str = $exifTool->Unicode2Byte($str);
    } else {
        # assume everything else is ASCII (Don't convert JIS... yet)
        $str =~ s/\0.*//s;   # truncate at null terminator
    }
    return $str;
}

#------------------------------------------------------------------------------
# Print numerical parameter value (with sign, or 'Normal' for zero)
sub PrintParameter($)
{
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
# Convert parameter back to standard EXIF value
#   0 or "Normal" => 0
#   -1,-2,etc or "Soft" or "Low" => 1
#   +1,+2,1,2,etc or "Hard" or "High" => 2
sub ConvertParameter($)
{
    my $val = shift;
    # normal is a value of zero
    return 0 if $val =~ /\bn/i or not $val;
    # "soft", "low" or any negative number is a value of 1
    return 1 if $val =~ /\b(s|l|-)/i;
    # "hard", "high" or any positive number is a vail of 2
    return 2 if $val =~ /\b(h|\+|\d)/i;
    return undef;
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
# extract image from file
# Inputs: 0) ExifTool object reference, 1) data offset (in file), 2) data length
#         3) [optional] tag name
# Returns: Reference to Image if specifically requested or "Binary data" message
#          Returns undef if there was an error loading the image
sub ExtractImage($$$$)
{
    my ($exifTool, $offset, $len, $tag) = @_;
    my $dataPt = \$exifTool->{EXIF_DATA};
    my $dataPos = $exifTool->{EXIF_POS};
    my $image;

    return undef unless $len;   # no image if length is zero

    # take data from EXIF block if possible
    if (defined $dataPos and $offset>=$dataPos and $offset+$len<=$dataPos+length($$dataPt)) {
        $image = substr($$dataPt, $offset-$dataPos, $len);
    } else {
        $image = $exifTool->ExtractBinary($offset, $len, $tag);
        return undef unless defined $image;
    }
    HtmlDump($exifTool, $offset, $len, "$tag data", "$tag\\nSize: $len bytes", 8);
    return $exifTool->ValidateImage(\$image, $tag);
}

#------------------------------------------------------------------------------
# Get lowest address value ptr in a directory
# Inputs: 0) Data pointer, 1) dir start
# Returns: pointer with lowest value (or undef if no valid pointers)
# Notes: Directory size should be validated before calling this routine
sub GetFirstValuePtr($$)
{
    my ($dataPt, $dirStart) = @_;
    my $numEntries = Get16u($dataPt, $dirStart);
    my ($index, $rtnVal);
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $format = Get16u($dataPt, $entry+2);
        last if $format < 1 or $format > 13;
        my $count = Get32u($dataPt, $entry+4);
        my $size = $count * $Image::ExifTool::Exif::formatSize[$format];
        next if $size <= 4;
        my $valuePtr = Get32u($dataPt, $entry+8);
        next if $valuePtr & 1;  # (avoids funny CaplioRR30 offsets)
        # take minimum difference (this is for first value in block)
        $rtnVal = $valuePtr if not defined $rtnVal or $rtnVal > $valuePtr;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Fix offset base if necessary
# Inputs: 0) ExifTool object ref, 1) DirInfo hash ref
# Return: amount of base shift (and $dirInfo Base and DataPos are updated)
sub FixBase($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $dirName = $$dirInfo{DirName};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $minPt = GetFirstValuePtr($$dirInfo{DataPt}, $dirStart);

    return 0 unless defined $minPt;

    my $dataPos = $$dirInfo{DataPos};
    my $dirEnd = $dirStart + 2 + 12 * Get16u($$dirInfo{DataPt}, $dirStart);
    my $diff = ($minPt - $dataPos) - $dirEnd;
    my $fixBase = $exifTool->Options('FixBase');
    my $setBase = (defined $fixBase and $fixBase ne '') ? 1 : 0;

    # normal value data starts 4 bytes after IFD, but allow 0-4...
    return 0 unless $diff > 4 or $diff < 0 or $setBase;
    # ...but this may be different for some camera makes
    my ($makeDiff, $relative) = Image::ExifTool::MakerNotes::GetMakerNoteOffset($exifTool);

    # no base change unless necessary
    return 0 unless (defined $makeDiff and $diff != $makeDiff) or $setBase;

    my $fix;
    $makeDiff = 4 unless defined $makeDiff;
    $fix = $makeDiff - $diff;       # assume standard diff for this make
    if ($$dirInfo{FixBase}) {
        # set flag if offsets are relative
        if ($dataPos - $fix + $dirStart < 0) {
            $$dirInfo{Relative} = (defined $relative) ? $relative : 1;
        }
        if ($setBase) {
            $fix += $fixBase;
            $exifTool->Warn("Adjusted $dirName base by $fixBase",1);
        }
    } elsif (defined $fixBase) {
        $fix = $fixBase if $fixBase ne '';
        $exifTool->Warn("Adjusted $dirName base by $fix",1);
    } else {
        if ($diff < 0 or $diff > 16 or $exifTool->Options('Verbose')) {
            $exifTool->Warn("Possibly incorrect maker notes offsets (fix by $fix?)",1);
        }
        return 0;   # don't do the fix
    }
    $$dirInfo{Base} += $fix;
    $$dirInfo{DataPos} -= $fix;
    return $fix;
}

#------------------------------------------------------------------------------
# Process EXIF directory
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessExif($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dataLen = $$dirInfo{DataLen};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $dataLen - $dirStart;
    my $dirName = $$dirInfo{DirName};
    my $base = $$dirInfo{Base} || 0;
    my $firstBase = $base;
    my $raf = $$dirInfo{RAF};
    my $verbose = $exifTool->Options('Verbose');
    my $htmlDump = $exifTool->{HTML_DUMP};
    my $success = 1;
    my ($tagKey, $name, $dirSize, $makerAddr);

    $verbose = -1 if $htmlDump; # mix htmlDump into verbose so we can test for both at once
    $dirName eq 'EXIF' and $dirName = $$dirInfo{DirName} = 'IFD0';
    $htmlDump and $name = ($dirName eq 'MakerNotes') ? $$dirInfo{Name} : $dirName;
    my ($numEntries, $dirEnd);
    if ($dirStart >= 0 and $dirStart <= $dataLen-2) {
        # make sure data is large enough (patches bug in Olympus subdirectory lengths)
        $numEntries = Get16u($dataPt, $dirStart);
        $dirSize = 2 + 12 * $numEntries;
        $dirEnd = $dirStart + $dirSize;
        if ($dirSize > $dirLen) {
            if ($verbose > 0 and not $$dirInfo{SubIFD}) {
                my $short = $dirSize - $dirLen;
                $exifTool->Warn("Short directory size (missing $short bytes)");
            }
            undef $dirSize if $dirEnd > $dataLen; # read from file if necessary
        }
    }
    # read IFD from file if necessary
    unless ($dirSize) {
        $success = 0;
        if ($raf) {
            # read the count of entries in this IFD
            my $offset = $dirStart + $dataPos;
            my ($buff, $buf2);
            if ($raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2) {
                my $len = 12 * Get16u(\$buff,0);
                # also read next IFD pointer if reading multiple IFD's
                $len += 4 if $$dirInfo{Multi};
                if ($raf->Read($buf2, $len) == $len) {
                    $buff .= $buf2;
                    # make copy of dirInfo since we're going to modify it
                    my %newDirInfo = %$dirInfo;
                    $dirInfo = \%newDirInfo;
                    # update directory parameters for the newly loaded IFD
                    $dataPt = $$dirInfo{DataPt} = \$buff;
                    $dataPos = $$dirInfo{DataPos} = $offset;
                    $dataLen = $$dirInfo{DataLen} = $len + 2;
                    $dirStart = $$dirInfo{DirStart} = 0;
                    $success = 1;
                }
            }
        }
        unless ($success) {
            $exifTool->Warn("Bad $dirName directory");
            return 0;
        }
        $numEntries = Get16u($dataPt, $dirStart);
        $dirSize = 2 + 12 * $numEntries;
        $dirEnd = $dirStart + $dirSize;
    }
    $verbose > 0 and $exifTool->VerboseDir($dirName, $numEntries);
    my $bytesFromEnd = $dataLen - $dirEnd;
    if ($bytesFromEnd < 4) {
        unless ($bytesFromEnd==2 or $bytesFromEnd==0) {
            $exifTool->Warn(sprintf"Illegal $dirName directory size (0x%x entries)",$numEntries);
            return 0;
        }
    }
    # fix base offset for maker notes if necessary
    if (defined $$dirInfo{MakerNoteAddr}) {
        $makerAddr = $$dirInfo{MakerNoteAddr};
        delete $$dirInfo{MakerNoteAddr};
        if (FixBase($exifTool, $dirInfo)) {
            $base = $$dirInfo{Base};
            $dataPos = $$dirInfo{DataPos};
        }
    }
    if ($htmlDump) {
        if (defined $makerAddr) {
            my $hdrLen = $dirStart + $dataPos + $base - $makerAddr;
            HtmlDump($exifTool, $makerAddr, $hdrLen, 'MakerNotes header',
                     "$name header\\nSize: $hdrLen bytes") if $hdrLen > 0;
        }
        my $str = "$name entry count";
        HtmlDump($exifTool, $dirStart + $dataPos + $base, 2, "$name entries",
                 "$name\\nNum entries: $numEntries", 0);
        my $tip;
        if ($bytesFromEnd >= 4) {
            my $nxt = ($name =~ /^IFD(\d+)/) ? "IFD" . ($1 + 1) : 'Next IFD';
            $tip = sprintf("$nxt offset: 0x%.4x", Get32u($dataPt, $dirEnd));
        }
        HtmlDump($exifTool, $dirEnd + $dataPos + $base, 4, "Next IFD", $tip, 0);
        $name = $dirName if $name =~ /^MakerNote/;
    }

    # loop through all entries in an EXIF directory (IFD)
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        my $format = Get16u($dataPt, $entry+2);
        my $count = Get32u($dataPt, $entry+4);
        if ($format < 1 or $format > 13) {
            HtmlDump($exifTool,$entry+$dataPos+$base,12,"[invalid IFD entry]",
                     "Bad format value: $format", 1);
            # warn unless the IFD was just padded with zeros
            $format and $exifTool->Warn(
                sprintf("Unknown format ($format) for $dirName tag 0x%x",$tagID));
            return 0 unless $index; # assume corrupted IFD if this is our first entry
            next;
        }
        my $size = $count * $formatSize[$format];
        my $valueDataPt = $dataPt;
        my $valueDataPos = $dataPos;
        my $valueDataLen = $dataLen;
        my $valuePtr = $entry + 8;      # pointer to value within $$dataPt
        if ($size > 4) {
            $valuePtr = Get32u($dataPt, $valuePtr) - $dataPos;
            if ($valuePtr < 0 or $valuePtr+$size > $dataLen) {
                # get value by seeking in file if we are allowed
                if ($raf) {
                    my $buff;
                    if ($raf->Seek($base + $valuePtr + $dataPos,0) and
                        $raf->Read($buff,$size) == $size)
                    {
                        $valueDataPt = \$buff;
                        $valueDataPos = $valuePtr + $dataPos;
                        $valueDataLen = $size;
                        $valuePtr = 0;
                    } else {
                        $exifTool->Error("Error reading value for $dirName entry $index");
                        return undef;
                    }
                } else {
                    my $tagStr = sprintf("0x%x",$tagID);
                    $exifTool->Warn("Bad $dirName directory pointer for tag $tagStr");
                    next unless $htmlDump;
                    $valueDataPt = \ (' ' x $size);
                    $valueDataPos = $valuePtr = 0;
                    $valueDataLen = -1; # flag the bad pointer
                }
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
        if (defined $tagInfo and not $tagInfo) {
            # GetTagInfo() required the value for a Condition
            my $tmpVal = substr($$valueDataPt, $valuePtr, $size < 48 ? $size : 48);
            $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID, \$tmpVal);
        }
        # override EXIF format if specified
        my $origFormStr;
        if (defined $tagInfo) {
            if ($$tagInfo{Format}) {
                $formatStr = $$tagInfo{Format};
                # must adjust number of items for new format size
                my $newNum = $formatNumber{$formatStr};
                if ($newNum) {
                    $origFormStr = $formatName[$format] . '[' . $count . ']';
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
            if ($htmlDump) {
                my $tagName;
                my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
                if ($tagID == 0x927c and $dirName eq 'ExifIFD') {
                    $tagName = 'MakerNotes';
                } elsif ($tagInfo) {
                    $tagName = $$tagInfo{Name};
                } else {
                    $tagName = sprintf("Tag 0x%.4x",$tagID);
                }
                my $dname = sprintf("${name}_%.2d", $index);
                # make name highlighted if value in value data block
                my $colName;
                if ($size > 4) {
                    my $style = ($valueDataLen < 0) ? 'V' : 'H';
                    $colName = "<span id='$style'>$tagName</span>";
                } else {
                    $colName = $tagName;
                }
                # build our tool tip
                my $tip = sprintf("$name $tagName\\nTag ID: 0x%.4x\\n", $tagID) .
                          "Format: $formatName[$format]\[$count]\\nSize: $size bytes\\n";
                $tip .= sprintf("Value offset: 0x%.4x\\n", Get32u($dataPt,$entry+8)) if $size > 4;
                my $tval = (length $val < 32) ? $val : substr($val,0,28) . '[...]';
                if ($valueDataLen < 0) {
                    $tval = '<bad offset>';
                } elsif ($formatStr =~ /^(string|undef|binary)/) {
                    # translate all characters that could mess up JavaScript
                    $tval =~ tr/\\\x00-\x1f\x7f-\xff/./;
                    $tval =~ tr/"/'/;
                    $tval = "$tval";
                } elsif ($tagInfo and Image::ExifTool::IsInt($tval)) {
                    if ($$tagInfo{IsOffset}) {
                        $tval = sprintf('0x%.4x', $tval);
                    } elsif ($$tagInfo{PrintHex}) {
                        $tval = sprintf('0x%x', $tval);
                    }
                }
                $tip .= "Value: $tval";
                HtmlDump($exifTool,$entry+$dataPos+$base, 12, "$dname $colName", $tip, 1);
                next if $valueDataLen < 0;  # don't process bad pointer entry
                if ($size > 4 ) {
                    my $exifDumpPos = $valuePtr + $valueDataPos + $base;
                    # add value data block (underlining maker notes data)
                    HtmlDump($exifTool,$exifDumpPos,$size,"$dname $tagName value",'',
                             $tagName eq 'MakerNotes' ? 4 : 0);
                }
            } else {
                my $fstr = $formatName[$format];
                $origFormStr and $fstr = "$origFormStr read as $fstr";
                $exifTool->VerboseInfo($tagID, $tagInfo,
                    Table   => $tagTablePtr,
                    Index   => $index,
                    Value   => $val,
                    DataPt  => $valueDataPt,
                    DataPos => $valueDataPos + $base,
                    Size    => $size,
                    Start   => $valuePtr,
                    Format  => $fstr,
                    Count   => $count,
                );
            }
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
                @values = split ' ', $val;
                # limit the number of subdirectories we parse
                pop @values while @values > $$subdir{MaxSubdirs};
                $val = shift @values;
            }
            my ($newTagTable, $dirNum);
            if ($$subdir{TagTable}) {
                $newTagTable = GetTagTable($$subdir{TagTable});
                unless ($newTagTable) {
                    warn "Unknown tag table $$subdir{TagTable}\n";
                    next;
                }
            } else {
                $newTagTable = $tagTablePtr;    # use existing table
            }
            # loop through all sub-directories specified by this tag
            for ($dirNum=0; ; ++$dirNum) {
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
                    $subdirStart += Get32u($subdirDataPt, eval $$subdir{OffsetPt});
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
                                $size = 12 * Get16u(\$buff, 0);
                                # read dir
                                my $buf2;
                                if ($raf->Read($buf2,$size) == $size) {
                                    # set up variables to process new subdir data
                                    $size += 2;
                                    $buff .= $buf2;
                                    $subdirDataPt = \$buff;
                                    $subdirDataPos = $subdirStart;
                                    $subdirDataLen = $size;
                                    $subdirStart = 0;
                                    $dirOK = 1;
                                }
                            }
                        }
                    }
                    unless ($dirOK) {
                        my $msg = "Bad $tagStr SubDirectory start";
                        if ($verbose > 0) {
                            if ($subdirStart < 0) {
                                $msg .= " (directory start $subdirStart is before EXIF start)";
                            } else {
                                my $end = $subdirStart + $size;
                                $msg .= " (directory end is $end but EXIF size is only $subdirDataLen)";
                            }
                        }
                        $exifTool->Warn($msg);
                        last;
                    }
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
                    RAF      => $raf,
                    Parent   => $dirName,
                    FixBase  => $$subdir{FixBase},
                    TagInfo  => $tagInfo,
                    SubIFD   => $$tagInfo{SubIFD},
                );
                # some Pentax cameras (Optio 330) write maker notes in IFD0
                if ($$tagInfo{MakerNotes}) {
                    $subdirInfo{MakerNoteAddr} = $valuePtr + $valueDataPos + $base;
                }
                # set directory IFD name from group name of family 1 in tag information if it exists
                if ($$tagInfo{Groups}) {
                    $subdirInfo{DirName} = $tagInfo->{Groups}->{1};
                    # number multiple subdirectories
                    $dirNum and $subdirInfo{DirName} .= $dirNum;
                }
                SetByteOrder($newByteOrder);        # set byte order for this subdir
                # validate the subdirectory if necessary
                my $dirData = $subdirDataPt;    # set data pointer to be used in eval
                #### eval Validate ($val, $dirData, $subdirStart, $size)
                my $ok = 0;
                if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                    $exifTool->Warn("Invalid $tagStr data");
                } else {
                    # process the subdirectory
                    $ok = $exifTool->ProcessDirectory(\%subdirInfo, $newTagTable, $$subdir{ProcessProc});
                }
                # print debugging information if there were errors
                if (not $ok and $verbose > 1 and $subdirStart != $valuePtr) {
                    my $out = $exifTool->Options('TextOut');
                    printf $out "%s    (SubDirectory start = 0x%x)\n", $exifTool->{INDENT}, $subdirStart;
                }
                SetByteOrder($oldByteOrder);    # restore original byte swapping

                @values or last;
                $val = shift @values;           # continue with next subdir
            }
            next unless $exifTool->Options('MakerNotes') or
                        $exifTool->{REQ_TAG_LOOKUP}->{lc($$tagInfo{Name})};
            if ($$tagInfo{MakerNotes}) {
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
                    Parent   => $dirName,
                    DirName  => 'MakerNotes',
                    TagInfo  => $tagInfo,
                );
                $makerDirInfo{FixBase} = 1 if $$subdir{FixBase};
                my $val2 = RebuildMakerNotes($exifTool, $newTagTable, \%makerDirInfo);
                if (defined $val2) {
                    $val = $val2;
                } else {
                    $exifTool->Warn('Error rebuilding maker notes (may be corrupt)');
                }
            } else {
                # extract this directory as a block if specified
                next unless $$tagInfo{Writable};
            }
        }
 #..............................................................................
        # convert to absolute offsets if this tag is an offset
        if ($$tagInfo{IsOffset}) {
            my $offsetBase = $$tagInfo{IsOffset} eq '2' ? $firstBase : $base;
            my @vals = split(' ',$val);
            foreach $val (@vals) {
                $val += $offsetBase;
            }
            $val = join(' ', @vals);
        }
        # save the value of this tag
        $tagKey = $exifTool->FoundTag($tagInfo, $val);
        # set the group 1 name for tags in main table
        if (defined $tagKey and $tagTablePtr eq \%Image::ExifTool::Exif::Main) {
            $exifTool->SetGroup1($tagKey, $dirName);
        }
    }

    # scan for subsequent IFD's if specified
    if ($$dirInfo{Multi} and $bytesFromEnd >= 4) {
        my $offset = Get32u($dataPt, $dirEnd);
        if ($offset) {
            my $subdirStart = $offset - $dataPos;
            # use same directory information for trailing directory,
            # but change the start location and increment the nesting
            # to avoid recursively processing the same directory
            my %newDirInfo = %$dirInfo;
            # increment IFD number if necessary
            if ($newDirInfo{DirName} =~ /^IFD(\d+)$/) {
                $newDirInfo{DirName} = 'IFD' . ($1 + 1);
            }
            $exifTool->{INDENT} =~ s/..$//;
            $newDirInfo{DirStart} = $subdirStart;
            $exifTool->ProcessDirectory(\%newDirInfo, $tagTablePtr) or $success = 0;
        }
    }
    return $success;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Exif - Read EXIF meta information

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains main definitions required by Image::ExifTool to
interpret EXIF meta information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.exif.org/Exif2-2.PDF>

=item L<http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf>

=item L<http://partners.adobe.com/public/developer/en/tiff/TIFFPM6.pdf>

=item L<http://www.adobe.com/products/dng/pdfs/dng_spec.pdf>

=item L<http://www.awaresystems.be/imaging/tiff/tifftags.html>

=item L<http://www.remotesensing.org/libtiff/TIFFTechNote2.html>

=item L<http://www.asmail.be/msg0054681802.html>

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html>

=item L<http://hul.harvard.edu/jhove/tiff-tags.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Matt Madrid for his help with the XP character code conversions.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/EXIF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
