#------------------------------------------------------------------------------
# File:         Exif.pm
#
# Description:  Definitions for EXIF tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/06/2004 - P. Harvey Moved processing functions from ExifTool
#               03/19/2004 - P. Harvey Check PreviewImage for validity
#
# References:   1) http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf
#               2) http://www.adobe.com/products/dng/pdfs/dng_spec.pdf
#               3) http://www.awaresystems.be/imaging/tiff/tifftags.html
#               4) http://www.remotesensing.org/libtiff/TIFFTechNote2.html
#               5) http://www.asmail.be/msg0054681802.html
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(Get16u Get16s Get32u Get32s GetFloat GetDouble
                       GetByteOrder SetByteOrder ToggleByteOrder);

$VERSION = '1.23';

sub ProcessExif($$$);

# byte sizes for the various EXIF format types below
my @formatSize = (0,1,1,2,4,8,1,1,2,4,8,4,8);

my @formatName = ('err','UChar','String','UShort',
                  'ULong','UShortRational','Char','Undef',
                  'Short','Long','ShortRational','Float',
                  'Double');

# hash to look up EXIF format numbers by name
# (lower case because string is convert to lc() before comparison)
my %formatNumber = (
    'uchar'         => 1,
    'string'        => 2,
    'binary'        => 2,   # (Binary is the same as String in Perl)
    'ushort'        => 3,
    'ulong'         => 4,
    'ushortrational'=> 5,
    'char'          => 6,
    'undefined'     => 7,
    'short'         => 8,
    'long'          => 9,
    'shortrational' => 10,
    'float'         => 11,
    'double'        => 12,
);

# EXIF LightSource PrintConv values
my %lightSource = (
    1 => 'Daylight',
    2 => 'Fluorescent',
    3 => 'Tungsten',
    10 => 'Flash',
    17 => 'Standard light A',
    18 => 'Standard light B',
    19 => 'Standard light C',
    20 => 'D55',
    21 => 'D65',
    22 => 'D75',
    23 => 'D50',
    24 => 'ISO Studio tungsten',
    255 => 'Other',
);


# main EXIF tag table
%Image::ExifTool::Exif::Main = (
    GROUPS => { 0 => 'EXIF', 1 => 'IFD0', 2 => 'Image'},
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
    },
    0x101 => 'ImageHeight',
    0x102 => 'BitsPerSample',
    0x103 => {
        Name => 'Compression',
        PrintConv => {
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
        },
    },
    0x106 => {
        Name => 'PhotometricInterpretation',
        PrintConv => {
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
        },
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
        # truncate string at null terminator and duplicate value
        # at top level in ExifTool object for convenience
        ValueConv => '($self->{CameraMake} = $val) =~ s/\0.*//, $val',
    },
    0x110 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
        # truncate string at null terminator and duplicate value
        # at top level in ExifTool object for convenience
        ValueConv => '($self->{CameraModel} = $val) =~ s/\0.*//, $val',
    },
    0x111 => 'StripOffsets',
    0x112 => {
        Name => 'Orientation',
        PrintConv => {
            1 => 'Horizontal (normal)',
            2 => 'Mirrored horizontal',
            3 => 'Rotated 180',
            4 => 'Mirrored vertical',
            5 => 'Mirrored horizontal then rotated 90 CCW',
            6 => 'Rotated 90 CW',
            7 => 'Mirrored horizontal then rotated 90 CW',
            8 => 'Rotated 90 CCW',
        },
    },
    0x115 => 'SamplesPerPixel',
    0x116 => 'RowsPerStrip',
    0x117 => 'StripByteCounts',
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
    0x120 => 'FreeOffsets',
    0x121 => 'FreeByteCounts',
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
        Format => 'Binary',
        PrintConv => '\$val',
    },
    0x141 => 'HalftoneHints',
    0x142 => 'TileWidth',
    0x143 => 'TileLength',
    0x144 => {
        Name => 'TileOffsets',
        PrintConv => '\$val',
    },
    0x145 => {
        Name => 'TileByteCounts',
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
        SubDirectory => {
            Start => '$dirBase + $val',
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
    0x15b => 'JPEGTables',
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
        SubDirectory => {
            Start => '$dirBase + $val',
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
    0x201 => 'ThumbnailOffset',
    0x202 => 'ThumbnailLength',
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
            Start => '$valuePtr',
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
        Description => 'Tv(Shutter Speed)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x829d => {
        Name => 'FNumber',
        Description => 'Av(Aperture Value)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x830e => 'PixelScale',
    0x83bb => {
        Name => 'IPTC-NAA',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
            Start => '$valuePtr',
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
            Start => '$valuePtr',
        },
    },
    0x85d8 => {
        Name => 'ModelTransform',
        Groups => { 2 => 'Location' },
    },
    0x8649 => {
        Name => 'PhotoshopSettings',
        Format => 'Binary',
        PrintConv => '\$val',
    },
    0x8769 => {
        Name => 'ExifOffset',
        Groups => { 1 => 'ExifIFD' },
        SubDirectory => {
            Start => '$dirBase + $val',
        },
    },
    0x8773 => {
        Name => 'InterColorProfile',
        Format => 'Binary',
        # don't want to print all this because it is a big table
        PrintConv => '\$val',
    },
    0x87ac => 'ImageLayer',
    0x87af => {
        Name => 'GeoTiffDirectory',
        Format => 'Binary',
        PrintConv => '\$val',
    },
    0x87b0 => {
        Name => 'GeoTiffDoubleParams',
        Format => 'Binary',
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
        SubDirectory => {
            TagTable => 'Image::ExifTool::GPS::Main',
            Start => '$dirBase + $val',
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
        PrintConv => '$_=$val;tr/\x01-\x06/YbrRGB/;s/b/Cb/g;s/r/Cr/g;$_',
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
    },    0x9213 => 'ImageHistory',
    #----------------------------------------------------------------------------
    # decide which MakerNotes to use (based on camera make/model)
    #
    0x927c => [    # square brackets for a conditional list
        {
            Condition => '$self->{CameraMake} =~ /^Canon/',
            Name => 'MakerNoteCanon',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::Main',
                Start => '$valuePtr',
            },
        },
        {
            # The Fuji programmers really botched this one up,
            # but with a bit of work we can still read this directory
            Condition => '$self->{CameraMake} =~ /^FUJIFILM/',
            Name => 'MakerNoteFujiFilm',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FujiFilm::Main',
                Start => '$valuePtr',
                # there is an 8-byte maker tag (FUJIFILM) we must skip over
                OffsetPt => '$valuePtr+8',
                ByteOrder => 'LittleEndian',
                # the pointers are relative to the subdirectory start
                # (before adding the offsetPt).  Weird - PH
                Base => '$start',
            },
        },
        {
            Condition => '$self->{CameraMake} =~ /^PENTAX/',
            Name => 'MakerNotePentax',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::Main',
                Start => '$valuePtr+6',
                # byte order varies -- let ProcessExif() figure it out
                ByteOrder => 'Unknown',
            },
        },
        {
            Condition => '$self->{CameraMake} =~ /^OLYMPUS/',
            Name => 'MakerNoteOlympus',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::Main',
                Start => '$valuePtr+8',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^NIKON/',
            Name => 'MakerNoteNikon',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::Main',
                Start => '$valuePtr',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^CASIO COMPUTER CO.,LTD/',
            Name => 'MakerNoteCasio2',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Casio::MakerNote2',
                Start => '$valuePtr + 6',
                ByteOrder => 'Unknown',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^CASIO/',
            Name => 'MakerNoteCasio',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Casio::MakerNote1',
                Start => '$valuePtr',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^Minolta/',
            Name => 'MakerNoteMinolta',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Minolta::Main',
                Start => '$valuePtr',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^SANYO/',
            Name => 'MakerNoteSanyo',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sanyo::Main',
                Validate => '$val =~ /^SANYO/',
                Start => '$valuePtr + 8',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^(SIGMA|FOVEON)/',
            Name => 'MakerNoteSigma',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sigma::Main',
                Validate => '$val =~ /^(SIGMA|FOVEON)/',
                Start => '$valuePtr + 10',
            },
        },
        {
            Condition => '$self->{CameraMake}=~/^SONY/',
            Name => 'MakerNoteSony',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::Main',
                # validate the maker note because this is sometimes garbage
                Validate => 'defined($val) and $val =~ /^SONY DSC/',
                Start => '$valuePtr + 12',
            },
        },
        {
            Name => 'MakerNoteUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Unknown::Main',
                Start => '$valuePtr',
            },
        },
    ],
    #----------------------------------------------------------------------------
    0x9286 => {
        Name => 'UserComment',
        PrintConv => 'substr($val,8)'
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
    0x9c9b => 'XPTitle',
    0x9c9c => 'XPComment',
    0x9c9d => {
        Name => 'XPAuthor',
        Groups => { 2 => 'Author' },
    },
    0x9c9e => 'XPKeywords',
    0x9c9f => 'XPSubject',
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
        Description => 'Interoperability Offset',
        SubDirectory => {
            Start => '$dirBase + $val',
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
            "\3\0\0\0" => 'Digital Camera',
        },
    },
    0xa301 => {
        Name => 'SceneType',
        PrintConv => {
            1 => 'Directly photographed',
        },
    },
    0xa302 => 'CFAPattern',
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
        Condition => 'not defined($oldVal)',    # don't override maker WhiteBalance
        Groups => { 2 => 'Camera' },
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
    0xc427 => 'OceScanjobDesc', #3
    0xc428 => 'OceApplicationSelector', #3
    0xc429 => 'OceIDNumber', #3
    0xc42a => 'OceImageLogic', #3
    0xc4a5 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
        },
    },
    0xc612 => 'DNGVersion', #2
    0xc613 => 'DNGBackwardVersion', #2
    0xc614 => 'UniqueCameraModel', #2
    0xc615 => { #2
        Name => 'LocalizedCameraModel',
        Format => 'String',
        PrintConv => 'Image::ExifTool::Printable($val)',
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
    0xc62f => 'DNGCameraSerialNumber', #2
    0xc630 => { #2
        Name => 'DNGLensInfo',
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
        Description => 'Tv(Shutter Speed)',
        Desire => {
            0 => 'ExposureTime',
            1 => 'ShutterSpeedValue',
            2 => 'BulbDuration',
        },
        ValueConv => '$val[2] ? $val[2] : (defined($val[0]) ? $val[0] : $val[1])',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    Aperture => {
        Description => 'Av(Aperture Value)',
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
    ThumbnailImage => {
        Require => {
            0 => 'ThumbnailOffset',
            1 => 'ThumbnailLength',
        },
        # retrieve the thumbnail from our EXIF data
        ValueConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"ThumbnailImage",$dataPt)',
        PrintConv => '\$val',
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
    PreviewImage => {
        Require => {
            0 => 'PreviewImageStart',
            1 => 'PreviewImageLength',
        },
        ValueConv => 'Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"PreviewImage")',
        PrintConv => '\$val',
    },
    PreviewImageSize => {
        Require => {
            0 => 'PreviewImageWidth',
            1 => 'PreviewImageHeight',
        },
        ValueConv => '"$val[0]x$val[1]"',
    },
    ProcessGeoTiffDirectory => {
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
#
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
# Print parameter value (with sign, or 'Normal' for zero)
sub PrintParameter($) {
    my $val = shift;
    if ($val > 0) {
        $val = "+$val";
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
# - leaves time zone intact if specified (ie. '10:30:55+0500')
sub ExifTime($)
{
    my $time = shift;
    $time =~ tr/ /:/;    # use ':' (not ' ') as a separator
    $time =~ s/\0$//;       # remove any null terminator
    # add separators if they don't exist
    $time =~ s/^(\d{2})(\d{2})(\d{2})/$1:$2:$3/;
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
            # make sure this is a good JPG image if we loaded it
            unless ($image =~ /^(Bi|\xff\xd8)/) {
                undef $image;
                $exifTool->Warn('PreviewImage is not a valid JPG');
            }
        }
    }
    return $image;
}

#------------------------------------------------------------------------------
# get formatted value from binary data
# Inputs: 0) data reference, 1) offset to value, 2) format, 3) number of items
# Returns: Formatted value
sub FormattedValue($$$$)
{
    my ($dataPt, $offset, $format, $count) = @_;
    my $outVal;
    my $i;
    for ($i=0; $i<$count; ++$i) {
        my $val;
        if ($format==1 or ($format==7 and $count==1)) { # unsigned byte or single unknown byte
            $val = unpack('C1',substr($$dataPt,$offset,1));
            ++$offset;
        } elsif ($format==3) {                  # unsigned short
            $val = Get16u($dataPt, $offset);
            $offset += 2;
        } elsif ($format==4) {                  # unsigned long
            $val = Get32u($dataPt, $offset);
            $offset += 4;
        } elsif ($format==5 or $format==10) {   # unsigned or signed rational
            my $denom = Get32s($dataPt,$offset+4);
            if ($denom) {
                $val = sprintf("%.4g",Get32s($dataPt,$offset)/$denom);
            } else {
                $val = 'inf';
            }
            $offset += 8;
        } elsif ($format==6) {                  # signed byte
            $val = unpack('c1',substr($$dataPt,$offset,1));
            ++$offset;
        } elsif ($format==8) {                  # signed short
            $val = Get16s($dataPt, $offset);
            $offset += 2;
        } elsif ($format==9) {                  # signed long
            $val = Get32s($dataPt, $offset);
            $offset += 4;
        } elsif ($format==11) {                 # float
            $val = GetFloat($dataPt, $offset);
            $offset += 4;
        } elsif ($format==12) {                 # double
            $val = GetDouble($dataPt, $offset);
            $offset += 8;
        } else {
            # handle everything else like a string (including ascii string==2 and undefined==7)
            $outVal = substr($$dataPt, $offset, $count);
            last;   # already printed out the array
        }
        if (defined $outVal) {
            $outVal .= " $val";
        } else {
            $outVal = $val;
        }
    }
    return $outVal;
}

#------------------------------------------------------------------------------
# Process EXIF directory
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table for this directory
#         2) Reference to directory information hash
# Returns: 1 on success
sub ProcessExif($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $dataLength = $dirInfo->{DataLen};
    my $dirStart = $dirInfo->{DirStart};
    my $offsetBase = $dirInfo->{DirBase};
    my $raf = $dirInfo->{RAF};
    my $success = 1;
    my $verbose = $exifTool->Options('Verbose');
    my $tagKey;

    if ($dirInfo->{Nesting} > 4) {
        $exifTool->Warn('EXIF nesting level too deep');
        return 0;
    }
    $dirInfo->{IfdName} = 'IFD0' unless $dirInfo->{IfdName};

    my $numEntries = Get16u($dataPt, $dirStart);

    $verbose and print "Directory with $numEntries entries\n";

    my $dirEnd = $dirStart + 2 + 12 * $numEntries;
    my $bytesFromEnd = $offsetBase + $dataLength - $dirEnd;
    if ($bytesFromEnd < 4) {
        unless ($bytesFromEnd==2 or $bytesFromEnd==0) {
            $exifTool->Warn(sprintf"Illegal directory size (0x%x entries)",$numEntries);
            return 0;
        }
    }

    # loop through all entries in an EXIF directory (IFD)
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tag = Get16u($dataPt, $entry);
        my $format = Get16u($dataPt, $entry+2);
        my $numItems = Get32u($dataPt, $entry+4);
        if ($format < 1 or $format > 12) {
            # warn unless the IFD was just padded with zeros
            $format and $exifTool->Warn("Bad EXIF directory entry format ($format)");
            return 0 unless $index; # no success if this is our first entry
            last;   # stop now because this IFD is probably corrupt
        }
        my $size = $numItems * $formatSize[$format];
        my $valuePtr = $entry + 8;
        my $valueData = $dataPt;
        my $valueDataLen = $dataLength;
        if ($size > 4) {
            my $offsetVal = Get32u($dataPt, $valuePtr);
            if ($offsetVal+$size > $dataLength) {
                # get value by seeking in file if we are allowed
                if ($raf) {
                    my $curpos = $raf->Tell();
                    if ($raf->Seek($offsetVal,0)) {
                        my $buff;
                        if ($raf->Read($buff,$size) == $size) {
                            $valueData = \$buff;
                            $valueDataLen = $size;
                            $valuePtr = 0;
                        }
                    }
                    $raf->Seek($curpos,0);  # restore position in file
                }
                if ($valuePtr) {
                    my $tagStr = sprintf("0x%x",$tag);
                    $exifTool->Warn("Bad EXIF directory pointer value for tag $tagStr");
                    next;
                }
            } else {
                $valuePtr = $offsetBase + $offsetVal;
            }
        }
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        my $val;
        if ($tagInfo) {
            # override EXIF format if specified
            if ($tagInfo->{Format}) {
                my $newFormat = $formatNumber{lc($tagInfo->{Format})};
                if ($newFormat) {
                    $format = $newFormat;
                    # must adjust number of items for new format size
                    $numItems = $size / $formatSize[$format];
                } else {
                    warn "Unknown Format $tagInfo->{Format} for tag $tagInfo->{Name}\n";
                }
            }
            # convert according to EXIF format type
            $val = FormattedValue($valueData,$valuePtr,$format,$numItems);
        } else {
            if ($verbose) {
                $verbose>2 and Image::ExifTool::HexDumpTag($tag, $valueData, $size, 'Start'=>$valuePtr);
                $val = FormattedValue($valueData,$valuePtr,$format,$numItems);
                printf("  Tag 0x%.4x, Format $format: %s\n", $tag, 
                       Image::ExifTool::Printable($val));
            }
            next;
        }
        $verbose>2 and Image::ExifTool::HexDumpTag($tag, $valueData, $size, 'Start'=>$valuePtr, 
                                                   'Comment'=>"Format $format=$formatName[$format],");

#..............................................................................
# Handle SubDirectory tag types
#
        my $subdir = $$tagInfo{SubDirectory};
        if ($subdir) {

            my $tagStr = $$tagInfo{Name};
            defined $tagStr or $tagStr = sprintf("0x%x", $tag);

            # save the tag for debugging if specified
            if ($verbose) {
                $tagKey = $exifTool->FoundTag($tagInfo, $verbose>1 ? $val : '(SubDirectory)');
                $exifTool->SetTagExtra($tagKey, $dirInfo->{IfdName});
            }
            my @values;
            if ($$subdir{MaxSubdirs}) {
                @values = split /\s+/, $val;
                # limit the number of subdirectories we parse
                pop @values while @values > $$subdir{MaxSubdirs};
                $val = shift @values;
            }
            # loop through all sub-directories specified by this tag
            for (;;) {
                my $dirData = $dataPt;
                my $dirBase = $offsetBase;
                my $dirLength = $dataLength;
                my $subdirStart;
                if (defined $$subdir{Start}) {
                    # directory data is in valueData block if start is relative to valuePtr
                    if ($$subdir{Start} =~ /\$valuePtr\b/) {
                        $dirData = $valueData;
                        $dirLength = $valueDataLen;
                    }
                    $subdirStart = eval $$subdir{Start};
                } else {
                    $subdirStart = 0;
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
                        # at the number of directory entries.  This is a short
                        # integer that should be a reasonable value.
                        my $num = Image::ExifTool::Get16u($dataPt, $subdirStart);
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
                    my $start = $subdirStart;
                    $dirBase = eval $$subdir{Base};
                }
                # add offset to the start of the directory if necessary
                if ($$subdir{OffsetPt}) {
                    SetByteOrder($newByteOrder);
                    $subdirStart += Get32u($dataPt,eval $$subdir{OffsetPt});
                    SetByteOrder($oldByteOrder);
                }
                if ($subdirStart < $dirBase or $subdirStart > $dirBase + $dirLength) {
                    my $dirOK;
                    if ($raf) {
                        # read the directory from the file
                        my $curpos = $raf->Tell();
                        if ($raf->Seek($subdirStart,0)) {
                            my $buff;
                            if ($raf->Read($buff,2) == 2) {
                                # get no. dir entries
                                my $size = 12 * Get16u(\$buff, 0);
                                # read dir
                                my $buf2;
                                if ($raf->Read($buf2,$size)) {
                                    # set up variables to process new dir data
                                    $buff .= $buf2;
                                    $dirData = \$buff;
                                    $subdirStart = 0;
                                    $dirLength = $size + 2;
                                    $dirBase = 0;
                                    $dirOK = 1;
                                }
                            }
                        }
                        $raf->Seek($curpos,0);  # restore position in file
                    }
                    unless ($dirOK) {
                        my $msg = "Bad $tagStr SubDirectory start";
                        if ($verbose) {
                            if ($subdirStart < $dirBase) {
                                $msg .= " (directory start $subdirStart is before EXIF base=$dirBase)";
                            } else {
                                my $end = $dirBase + $dirLength;
                                $msg .= " (directory start $subdirStart is after EXIF end=$end)";
                            }
                        }
                        $exifTool->Warn($msg);
                        last;
                    }
                }
                my $newTagTable;
                if ($$subdir{TagTable}) {
                    $newTagTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                    unless ($newTagTable) {
                        warn "Unknown tag table $$subdir{TagTable}\n";
                        last;
                    }
                } else {
                    $newTagTable = $tagTablePtr;    # use existing table
                }

                # build information hash for new directory
                my %newDirInfo = (
                    DataPt   => $dirData,
                    DataLen  => $dirLength,
                    DirStart => $subdirStart,
                    DirLen   => $size,
                    DirBase  => $dirBase,
                    Nesting  => $dirInfo->{Nesting} + 1,
                    RAF      => $raf,
                );
                
                # set directory IFD name from group name of family 1 in tag information if it exists
                $tagInfo->{Groups} and $newDirInfo{IfdName} = $tagInfo->{Groups}->{1};

                SetByteOrder($newByteOrder);        # set byte order for this subdir
                # validate the subdirectory if necessary
                if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                    $exifTool->Warn("Invalid $tagStr data");
                } else {
                    # process the subdirectory
                    $verbose and print "-------- Start $tagStr --------\n";
                    $exifTool->ProcessTagTable($newTagTable, \%newDirInfo);
                    $verbose and print "-------- End $tagStr --------\n";
                }
                SetByteOrder($oldByteOrder);    # restore original byte swapping

                @values or last;
                $val = shift @values;           # continue with next subdir
            }
            next;
        }
 #..............................................................................

        # save the value of this tag
        $tagKey = $exifTool->FoundTag($tagInfo, $val);
        $exifTool->SetTagExtra($tagKey, $dirInfo->{IfdName});
    }

    # check for directory immediately following this one
    # (only if this is a standard EXIF table)
    if ($bytesFromEnd >= 4 and $tagTablePtr eq \%Image::ExifTool::Exif::Main) {
        my $offset = Get32u($dataPt, $dirEnd);
        if ($offset) {
            my $subdirStart = $offsetBase + $offset;
            if ($subdirStart > $offsetBase+$dataLength) {
                $exifTool->Warn("Illegal subdirectory link");
            } else {
                # use same directory information for trailing directory,
                # but change the start location and increment the nesting
                # to avoid recursively processing the same directory
                ++$dirInfo->{Nesting};
                # increment IFD number if necessary
                if ($dirInfo->{IfdName} =~ /^IFD(\d+)$/) {
                    $dirInfo->{IfdName} = 'IFD' . ($1 + 1);
                }
                $dirInfo->{DirStart} = $subdirStart;
                ProcessExif($exifTool, $tagTablePtr, $dirInfo) or $success = 0;
                --$dirInfo->{Nesting};
            }
        }
    } 
    return $success;
}

1; # end
