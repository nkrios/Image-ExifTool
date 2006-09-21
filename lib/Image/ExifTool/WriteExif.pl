#------------------------------------------------------------------------------
# File:         WriteExif.pl
#
# Description:  Write EXIF meta information
#
# Revisions:    12/13/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;
use vars qw($VERSION $AUTOLOAD @formatSize @formatName %formatNumber
            %lightSource %compression %photometricInterpretation %orientation);

use Image::ExifTool::Fixup;

sub InsertWritableProperties($$;$);

# some information may be stored in different IFD's with the same meaning.
# Use this lookup to decide when we should delete information that is stored
# in another IFD when we write it to the preferred IFD.
my %crossDelete = (
    ExifIFD => 'IFD0',
    IFD0    => 'ExifIFD',
);

# mandatory tag default values
my %mandatory = (
    IFD0 => {
        0x011a => 72,       # XResolution
        0x011b => 72,       # YResolution
        0x0128 => 2,        # Resoution unit (inches)
        0x0213 => 1,        # YCbCrPositioning (centered)
    },
    IFD1 => {
        0x0103 => 6,        # Compression (JPEG)
        0x011a => 72,       # XResolution
        0x011b => 72,       # YResolution
        0x0128 => 2,        # Resoution unit (inches)
    },
    ExifIFD => {
        0x9000 => '0220',   # ExifVersion
        0x9101 => "\1\2\3\0", # ComponentsConfiguration
        0xa000 => '0100',   # FlashpixVersion
        0xa001 => 0xffff,   # ColorSpace (uncalibrated)
       # 0xa002 => ????,     # ExifImageWidth
       # 0xa003 => ????,     # ExifImageLength
    },
    GPS => {
        0x0000 => '2 2 0 0',# GPSVersionID
    },
);

# The main EXIF table is unique because the tags from this table may appear
# in many different directories.  For this reason, we introduce a
# "WriteGroup" member to the tagInfo that tells us the preferred location
# for writing each tag.  Here is the lookup for Writable flag (format)
# and WriteGroup for all writable tags
# - WriteGroup is ExifIFD unless otherwise specified
# - Protected is 1 if the tag shouldn't be copied with SetNewValuesFromFile()
my %writeTable = (
    0x0001 => {             # InteropIndex
        Writable => 'string',
        WriteGroup => 'InteropIFD',
    },
    0x0002 => {             # InteropVersion
        Writable => 'undef',
        WriteGroup => 'InteropIFD',
    },
    0x00fe => {             # SubfileType
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        ValueConvInv => '$val',
    },
    0x00ff => {             # OldSubfileType
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        ValueConvInv => '$val',
    },
    0x0100 => {             # ImageWidth
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x0101 => {             # ImageHeigth
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x0102 => {             # BitsPerSample
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => -1, # can be 1 or 3: -1 means 'variable'
    },
    0x0103 => {             # Compression
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0106 => {             # PhotometricInterpretation
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0107 => {             # Thresholding
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0108 => {             # CellWidth
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0109 => {             # CellLength
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x010a => {             # FillOrder
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x010d => {             # DocumentName
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x010e => {             # ImageDescription
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x010f => {             # Make
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x0110 => {             # Model
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x0112 => {             # Orientation
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0115 => {             # SamplesPerPixel
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0116 => {             # RowsPerStrip
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x0118 => {             # MinSampleValue
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0119 => {             # MaxSampleValue
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x011a => {             # XResolution
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0x011b => {             # YResolution
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0x011c => {             # PlanarConfiguration
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x011d => {             # PageName
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x011e => {             # XPosition
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0x011f => {             # YPosition
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0x0122 => {             # GrayResponseUnit
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0128 => {             # ResolutionUnit
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0129 => {             # PageNumber
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x0131 => {             # Software
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x0132 => {             # ModifyDate
        Writable => 'string',
        Shift => 'Time',
        WriteGroup => 'IFD0',
        PrintConvInv => '$val',   # (only works if date format not set)
    },
    0x013b => {             # Artist
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x013c => {             # HostComputer
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x013d => {             # Predictor
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x013e => {             # WhitePoint
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x013f => {             # PrimaryChromaticities
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 6,
    },
    0x0141 => {             # HalftoneHints
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x0142 => {             # TileWidth
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x0143 => {             # TileLength
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x014c => {             # InkSet
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0150 => {             # TargetPrinter
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x013c => {             # HostComputer
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x0211 => {             # YCbCrCoefficients
        Protected => 1,
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 3,
    },
    0x0212 => {             # YCbCrSubSampling
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x0213 => {             # YCbCrPositioning
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x0214 => {             # ReferenceBlackWhite
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 6,
    },
    0x1001 => {             # RelatedImageWidth
        Writable => 'int16u',
        WriteGroup => 'InteropIFD',
    },
    0x1002 => {             # RelatedImageHeight
        Writable => 'int16u',
        WriteGroup => 'InteropIFD',
    },
    0x8298 => {             # Copyright
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
#
# Most of the tags below this belong in the ExifIFD...
#
    0x829a => {             # ExposureTime
        Writable => 'rational64u',
        PrintConvInv => 'eval $val',
    },
    0x829d => {             # FNumber
        Writable => 'rational64u',
        PrintConvInv => '$val',
    },
    0x83bb => {             # IPTC-NAA
        # this should actually be written as 'undef' (see
        # http://www.awaresystems.be/imaging/tiff/tifftags/iptc.html),
        # but Photoshop writes it as int32u and Nikon Capture won't read
        # anything else, so we do the same thing here...  Doh!
        Format => 'undef',      # convert binary values as undef
        Writable => 'int32u',   # but write int32u format code in IFD
        WriteGroup => 'IFD0',
    },
    0x8546 => {             # SEMInfo
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x8822 => 'int16u',     # ExposureProgram
    0x8824 => 'string',     # SpectralSensitivity
    0x8827 => 'int16u',     # ISO
    0x882a => {             # TimeZoneOffset
        Writable => 'int16s',
        Count => -1, # can be 1 or 2
        Notes => q{
            1 or 2 values: 1. The time zone offset of DateTimeOriginal from GMT in
            hours, 2. If present, the time zone offset of ModifyDate
        },
    },
    0x882b => 'int16u',     # SelfTimerMode
    0x9000 => 'undef',      # ExifVersion
    0x9003 => {             # DateTimeOriginal
        Writable => 'string',
        Shift => 'Time',
        PrintConvInv => '$val',   # (only works if date format not set)
    },
    0x9004 => {             # CreateDate
        Writable => 'string',
        Shift => 'Time',
        PrintConvInv => '$val',   # (only works if date format not set)
    },
    0x9101 => {             # ComponentsConfiguration
        Writable => 'undef',
        PrintConv => '$_=$val;s/\0.*//s;tr/\x01-\x06/YXWRGB/;s/X/Cb/g;s/W/Cr/g;$_',
        PrintConvInv => q{
            $_=uc($val); s/CR/W/g; s/CB/X/g;
            return undef if /[^YXWRGB]/;
            tr/YXWRGB/\x01-\x06/;
            return $_ . "\0";
        },
    },
    0x9102 => 'rational64u',# CompressedBitsPerPixel
    0x9201 => {             # ShutterSpeedValue
        Writable => 'rational64s',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : -100',
        # do eval to convert things like '1/100'
        PrintConvInv => 'eval $val',
    },
    0x9202 => {             # ApertureValue
        Writable => 'rational64u',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    0x9203 => 'rational64s',# BrightnessValue
    0x9204 => {             # ExposureCompensation
        Writable => 'rational64s',
        # do eval to convert things like '+2/3'
        PrintConvInv => 'eval $val',
    },
    0x9205 => {             # MaxApertureValue
        Writable => 'rational64u',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    0x9206 => {             # SubjectDistance
        Writable => 'rational64u',
        PrintConvInv => '$val=~s/ m$//;$val',
    },
    0x9207 => 'int16u',     # MeteringMode
    0x9208 => 'int16u',     # LightSource
    0x9209 => 'int16u',     # Flash
    0x920a => {             # FocalLength
        Writable => 'rational64u',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0x9211 => 'int32u',     # ImageNumber
    0x9212 => 'string',     # SecurityClassification
    0x9213 => 'string',     # ImageHistory
    0x9214 => {             # SubjectLocation
        Writable => 'int16u',
        Count => 4,  # write this SubjectLocation with 4 and the other with 2 values
    },
#    0x927c => 'undef',      # MakerNotes
    0x9286 => {             # UserComment (string that starts with "ASCII\0\0\0")
        Writable => 'undef',
        PrintConvInv => '"ASCII\0\0\0$val"',
    },
    0x9290 => 'string',     # SubSecTime
    0x9291 => 'string',     # SubSecTimeOriginal
    0x9292 => 'string',     # SubSecTimeDigitized
#    0x9928 => 'undef',      # Opto-ElectricConversionFactor
    0x9c9b => {             # XPTitle
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Notes => q{
            tags 0x9c9b-0x9c9f are used by Windows Explorer; special characters
            in these values are converted to UTF-8 by default, or Windows Latin1
            with the -L option. XPTitle is ignored by Windows Explorer if
            ImageDescription exists
        },
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9c => {             # XPComment
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9d => {             # XPAuthor
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Notes => 'ignored by Windows Explorer if Artist exists',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9e => {             # XPKeywords
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9f => {             # XPSubject
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0xa000 => 'undef',      # FlashpixVersion
    0xa001 => 'int16u',     # ColorSpace
    0xa002 => 'int16u',     # ExifImageWidth (could also be int32u)
    0xa003 => 'int16u',     # ExifImageLength (could also be int32u)
    0xa004 => 'string',     # RelatedSoundFile
    0xa20b => {             # FlashEnergy
        Writable => 'rational64u',
        Count => -1, # 1 or 2 (ref 12)
    },
#    0xa20c => 'undef',      # SpatialFrequencyResponse
    0xa20e => 'rational64u',# FocalPlaneXResolution
    0xa20f => 'rational64u',# FocalPlaneYResolution
    0xa210 => 'int16u',     # FocalPlaneResolutionUnit
    0xa214 => {             # SubjectLocation
        Writable => 'int16u',
        Count => 2,
    },
    0xa215 => 'rational64u',# ExposureIndex
    0xa217 => 'int16u',     # SensingMethod
    0xa300 => {             # FileSource
        Writable => 'undef',
        ValueConvInv => 'chr($val)',
        PrintConvInv => 3,
    },
    0xa301 => {             # SceneType
        Writable => 'undef',
        ValueConvInv => 'chr($val)',
    },
    0xa302 => {             # CFAPattern
        Writable => 'undef',
        PrintConvInv => 'Image::ExifTool::Exif::GetCFAPattern($val)',
    },
    0xa401 => 'int16u',     # CustomRendered
    0xa402 => 'int16u',     # ExposureMode
    0xa403 => 'int16u',     # WhiteBalance
    0xa404 => 'rational64u',# DigitalZoomRatio
    0xa405 => 'int16u',     # FocalLengthIn35mmFormat
    0xa406 => 'int16u',     # SceneCaptureType
    0xa407 => 'int16u',     # GainControl
    0xa408 => {             # Contrast
        Writable => 'int16u',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    0xa409 => {             # Saturation
        Writable => 'int16u',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    0xa40a => {             # Sharpness
        Writable => 'int16u',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
#    0xa40b => 'undef',      # DeviceSettingDescription
    0xa40c => 'int16u',     # SubjectDistanceRange
    0xa420 => 'string',     # ImageUniqueID
    0xa500 => 'rational64u',# Gamma
    0xc4a5 => {             # PrintIM
        Writable => 'undef',
        WriteGroup => 'IFD0',
    },
#
# DNG stuff (back in IFD0)
#
    0xc612 => {             # DNGVersion
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 4,
    },
    0xc613 => {             # DNGBackwardVersion
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 4,
    },
    0xc614 => {             # UniqueCameraModel
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc615 => {             # LocalizedCameraModel
        Writable => 'string',
        WriteGroup => 'IFD0',
        PrintConvInv => '$val',
    },
    0xc61e => {             # DefaultScale
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Count => 2,
    },
    0xc61f => {             # DefaultCropOrigin
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
    },
    0xc620 => {             # DefaultCropSize
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
    },
    0xc629 => {             # AsShotWhiteXY
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0xc62a => {             # BaselineExposure
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
    },
    0xc62b => {             # BaselineNoise
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0xc62c => {             # BaselineSharpness
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0xc62d => {             # BayerGreenSplit
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
    },
    0xc62e => {             # LinearResponseLimit
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0xc62f => {             # CameraSerialNumber
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc630 => {             # DNGLensInfo
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 4,
        PrintConvInv => '$_=$val;s/(-|mm f)/ /g;$_',
    },
    0xc631 => {             # ChromaBlurRadius
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
    },
    0xc632 => {             # AntiAliasStrength
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
    },
    0xc633 => {             # ShadowScale
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0xc635 => {             # MakerNoteSafety
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0xc65a => {             # CalibrationIlluminant1
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0xc65b => {             # CalibrationIlluminant2
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0xc65c => {             # BestQualityScale
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
    },
    0xc65d => {             # RawDataUniqueID
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 16,
        ValueConvInv => 'pack("H*",$val)',
    },
    0xc68b => {             # OriginalRawFileName
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc68c => {             # OriginalRawFileData (a writable directory)
        Writable => 'undef',
        WriteGroup => 'IFD0',
    },
    0xc68d => {             # ActiveArea
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 4,
    },
    0xc68e => {             # MaskedAreas
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 4,
    },
    # tags produced by Photoshop Camera RAW
    # (avoid creating these tags unless there is no other option)
    0xfde8 => {
        Name => 'OwnerName',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Owner's Name: $val"},
        Notes => q{
            tags 0xfde8-0xfe58 are generated by Photoshop Camera RAW -- some
            names are the same as other EXIF tags, but ExifTool will avoid
            writing these unless they already exist in the file
        },
    },
    0xfde9 => {
        Name => 'SerialNumber',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Serial Number: $val"},
    },
    0xfdea => {
        Name => 'Lens',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Lens: $val"},
    },
    0xfe4c => {
        Name => 'RawFile',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Raw File: $val"},
    },
    0xfe4d => {
        Name => 'Converter',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Converter: $val"},
    },
    0xfe4e => {
        Name => 'WhiteBalance',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"White Balance: $val"},
    },
    0xfe51 => {
        Name => 'Exposure',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Exposure: $val"},
    },
    0xfe52 => {
        Name => 'Shadows',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Shadows: $val"},
    },
    0xfe53 => {
        Name => 'Brightness',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Brightness: $val"},
    },
    0xfe54 => {
        Name => 'Contrast',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Contrast: $val"},
    },
    0xfe55 => {
        Name => 'Saturation',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Saturation: $val"},
    },
    0xfe56 => {
        Name => 'Sharpness',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Sharpness: $val"},
    },
    0xfe57 => {
        Name => 'Smoothness',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Smoothness: $val"},
    },
    0xfe58 => {
        Name => 'MoireFilter',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Moire Filter: $val"},
    },
);

# insert our writable properties into main EXIF tag table
InsertWritableProperties('Image::ExifTool::Exif::Main', \%writeTable, \&CheckExif);

#------------------------------------------------------------------------------
# Get binary CFA Pattern from a text string
# Inputs: CFA pattern string (ie. '[Blue,Green][Green,Red]')
# Returns: Binary CFA data or prints warning and returns undef on error
sub GetCFAPattern($)
{
    my $val = shift;
    my @rows = split /\]\s*\[/, $val;
    @rows or warn("Rows not properly bracketed by '[]'\n"), return undef;
    my @cols = split /,/, $rows[0];
    @cols or warn("Colors not separated by ','\n"), return undef;
    my $ny = @cols;
    my $rtnVal = Set16u(scalar(@rows)) . Set16u(scalar(@cols));
    my %cfaLookup = (red=>0, green=>1, blue=>2, cyan=>3, magenta=>4, yellow=>5, white=>6);
    my $row;
    foreach $row (@rows) {
        @cols = split /,/, $row;
        @cols == $ny or warn("Inconsistent number of colors in each row\n"), return undef;
        foreach (@cols) {
            tr/ \]\[//d;    # remove remaining brackets and any spaces
            my $c = $cfaLookup{lc($_)};
            defined $c or warn("Unknown color '$_'\n"), return undef;
            $rtnVal .= Set8u($c);
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and possibly changes value) on success
sub CheckExif($$$)
{
    my ($exifTool, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format} || $$tagInfo{Writable} || $tagInfo->{Table}->{WRITABLE};
    if (not $format or $format eq '1') {
        if ($tagInfo->{Groups}->{0} eq 'MakerNotes') {
            return undef;   # OK to have no format for makernotes
        } else {
            return 'No writable format';
        }
    }
    return Image::ExifTool::CheckValue($valPtr, $format, $$tagInfo{Count});
}

#------------------------------------------------------------------------------
# insert writable properties into main tag table
# Inputs: 0) tag table name, 1) reference to writable properties
#         2) [optional] CHECK_PROC reference
sub InsertWritableProperties($$;$)
{
    my ($tableName, $writeTablePtr, $checkProc) = @_;
    my $tag;
    my $tagTablePtr = GetTagTable($tableName);
    $checkProc and $tagTablePtr->{CHECK_PROC} = $checkProc;
    foreach $tag (keys %$writeTablePtr) {
        my $writeInfo = $$writeTablePtr{$tag};
        my @infoList = GetTagInfoList($tagTablePtr, $tag);
        if (@infoList) {
            my $tagInfo;
            foreach $tagInfo (@infoList) {
                if (ref $writeInfo) {
                    my $key;
                    foreach $key (%$writeInfo) {
                        $$tagInfo{$key} = $$writeInfo{$key};
                    }
                } else {
                    $$tagInfo{Writable} = $writeInfo;
                }
            }
        } else {
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $writeInfo);
        }
    }
}

#------------------------------------------------------------------------------
# rebuild maker notes to properly contain all value data
# (some manufacturers put value data outside maker notes!!)
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) dirInfo reference
# Returns: new maker note data, or undef on error
sub RebuildMakerNotes($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $rtnValue;
    my %subdirInfo = %$dirInfo;

    delete $exifTool->{MAKER_NOTE_FIXUP};

    # don't need to rebuild text or binary-data maker notes
    my $tagInfo = $$dirInfo{TagInfo};
    my $subdir = $$tagInfo{SubDirectory};
    my $proc = $$subdir{ProcessProc} || $$tagTablePtr{PROCESS_PROC} || \&ProcessExif;
    if (($proc ne \&ProcessExif and $$tagInfo{Name} =~ /Text/) or
         $proc eq \&Image::ExifTool::ProcessBinaryData)
    {
        return substr($$dataPt, $dirStart, $dirLen);
    }
    my $saveOrder = GetByteOrder();
    my $loc = Image::ExifTool::MakerNotes::LocateIFD($exifTool,\%subdirInfo);
    if (defined $loc) {
        my $makerFixup = $subdirInfo{Fixup} = new Image::ExifTool::Fixup;
        # create new exiftool object to rewrite the directory without changing it
        my $newTool = new Image::ExifTool;
        # don't copy over preview image
        $newTool->SetNewValue(PreviewImage => '');
        # must set a few member variables used while writing...
        $newTool->{CameraMake} = $exifTool->{CameraMake};
        $newTool->{CameraModel} = $exifTool->{CameraModel};
        # set FILE_TYPE to JPEG so PREVIEW_INFO will be generated
        $newTool->{FILE_TYPE} = 'JPEG';
        # drop any large tags
        $newTool->{DROP_TAGS} = 1;
        # rewrite maker notes
        $rtnValue = $newTool->WriteDirectory(\%subdirInfo, $tagTablePtr);
        if (defined $rtnValue and length $rtnValue) {
            # add the dummy preview image if necessary
            if ($newTool->{PREVIEW_INFO}) {
                $makerFixup->SetMarkerPointers(\$rtnValue, 'PreviewImage', length($rtnValue));
                $rtnValue .= $newTool->{PREVIEW_INFO}->{Data};
                delete $newTool->{PREVIEW_INFO};
            }
            # add makernote header
            $loc and $rtnValue = substr($$dataPt, $dirStart, $loc) . $rtnValue;
            # adjust fixup for shift in start position
            $makerFixup->{Start} += $loc;
            # shift offsets according to original position of maker notes,
            # and relative to the makernotes Base
            $makerFixup->{Shift} += $dataPos + $dirStart +
                                    $$dirInfo{Base} - $subdirInfo{Base};
            # fix up pointers to the specified offset
            $makerFixup->ApplyFixup(\$rtnValue);
        }
        # save fixup information unless offsets were relative
        unless ($subdirInfo{Relative}) {
            # set shift so offsets are all relative to start of maker notes
            $makerFixup->{Shift} -= $dataPos + $dirStart;
            $exifTool->{MAKER_NOTE_FIXUP} = $makerFixup;    # save fixup for later
        }
    }
    $exifTool->{MAKER_NOTE_BYTE_ORDER} = GetByteOrder();    # save maker note byte ordering
    SetByteOrder($saveOrder);

    return $rtnValue;
}

#------------------------------------------------------------------------------
# Sort IFD directory entries
# Inputs: 0) data reference, 1) directory start, 2) number of entries
sub SortIFD($$$)
{
    my ($dataPt, $dirStart, $numEntries) = @_;
    my ($index, %entries);
    # split the directory into separate entries
    my ($padding, $newDir) = ('','');
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        my $entryData = substr($$dataPt, $entry, 12);
        # silly software can pad directories with zero entries -- put these at the end
        $tagID = 0x10000 unless $tagID or $index == 0;
        # add new entry (allow for duplicate tag ID's, which shouldn't normally happen)
        $entries{$tagID} or $entries{$tagID} = '';
        $entries{$tagID} .= $entryData;
    }
    # sort the directory entries
    my @sortedTags = sort { $a <=> $b } keys %entries;
    foreach (@sortedTags) {
        $newDir .= $entries{$_};
    }
    # replace original directory with new, sorted one
    substr($$dataPt, $dirStart + 2, 12 * $numEntries) = $newDir . $padding;
}

#------------------------------------------------------------------------------
# Update TIFF_END member if defined
# Inputs: 0) ExifTool ref, 1) end of valid TIFF data
sub UpdateTiffEnd($$)
{
    my ($exifTool, $end) = @_;
    if (defined $exifTool->{TIFF_END} and
        $exifTool->{TIFF_END} < $end)
    {
        $exifTool->{TIFF_END} = $end;
    }
}

#------------------------------------------------------------------------------
# Handle error while writing EXIF
# Inputs: 0) ExifTool ref, 1) error string, 2) flag set for minor error
# Returns: undef on fatal error, or '' if minor error is ignored
sub ExifErr($$$)
{
    my ($exifTool, $errStr, $minor) = @_;
    return undef if $exifTool->Error($errStr, $minor);
    return '';
}

#------------------------------------------------------------------------------
# Write EXIF directory
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference,
#         2) tag table reference
# Returns: Exif data block (may be empty if no Exif data) or undef on error
# Notes: Increments ExifTool CHANGED flag for each tag changed.  Also updates
#        TIFF_END if defined with location of end of original TIFF image.
# Returns IFD data in the following order:
#   1. IFD0 directory followed by its data
#   2. SubIFD directory followed by its data, thumbnail and image
#   3. GlobalParameters, EXIF, GPS, Interop IFD's each with their data
#   4. IFD1,IFD2,... directories each followed by their data
#   5. Thumbnail and/or image data for each IFD, with IFD0 image last
sub WriteExif($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    unless ($dataPt) {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dataLen = $$dirInfo{DataLen} || length($$dataPt);
    my $dirLen = $$dirInfo{DirLen} || ($dataLen - $dirStart);
    my $base = $$dirInfo{Base} || 0;
    my $firstBase = $base;
    my $raf = $$dirInfo{RAF};
    my $dirName = $$dirInfo{DirName} || 'unknown';
    my $fixup = $$dirInfo{Fixup} || new Image::ExifTool::Fixup;
    my $verbose = $exifTool->Options('Verbose');
    my $out = $exifTool->Options('TextOut');
    my (@offsetInfo, %xDelete);
    my $newData = '';   # initialize buffer to receive new directory data
    my ($nextIfdPos, %offsetData, $inMakerNotes);
    my $deleteAll = 0;

    # allow multiple IFD's in IFD0-IFD1-IFD2... chain
    $$dirInfo{Multi} = 1 if $dirName eq 'IFD0';
    $inMakerNotes = 1 if $tagTablePtr->{GROUPS}->{0} eq 'MakerNotes';
    my $ifd;
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# loop through each IFD
#
    for ($ifd=0; ; ++$ifd) {  # loop through multiple IFD's

        # loop through new values and accumulate all information for this IFD
        my (%set, $tagInfo);
        my $tableGroup = $tagTablePtr->{GROUPS}->{0};
        my $wrongDir = $crossDelete{$dirName};
        foreach $tagInfo ($exifTool->GetNewTagInfoList($tagTablePtr)) {
            my $tagID = $$tagInfo{TagID};
            # evaluate conditional lists now if necessary
            if (ref $tagTablePtr->{$tagID} eq 'ARRAY' or $$tagInfo{Condition}) {
                my $curInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
                if (defined $curInfo and not $curInfo) {
                    # need value to evaluate the condition
                    my ($val) = $exifTool->GetNewValues($tagInfo);
                    # must convert to binary for evaluating in Condition
                    if ($$tagInfo{Format}) {
                        $val = WriteValue($val, $$tagInfo{Format}, $$tagInfo{Count});
                    }
                    if (defined $val) {
                        $curInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID, \$val);
                    }
                }
                # don't set this tag unless valid for the current condition
                next unless defined $curInfo and $curInfo eq $tagInfo;
            }
            if ($$tagInfo{WriteCondition}) {
                my $self = $exifTool;   # set $self to be used in eval
                #### eval WriteCondition ($self)
                unless (eval $$tagInfo{WriteCondition}) {
                    $@ and warn $@;
                    next;
                }
            }
            my $newValueHash = $exifTool->GetNewValueHash($tagInfo, $dirName);
            unless ($newValueHash) {
                next unless $wrongDir;
                # delete stuff from the wrong directory if setting somewhere else
                $newValueHash = $exifTool->GetNewValueHash($tagInfo, $wrongDir);
                next unless Image::ExifTool::IsOverwriting($newValueHash);
                # remove this tag if found in this IFD
                $xDelete{$tagID} = 1;
            }
            $set{$tagID} = $tagInfo;
        }
        # save pointer to start of this IFD within the newData
        my $newStart = length($newData);
        my @subdirs;    # list of subdirectory data and tag table pointers
        # determine if directory is contained within our data
        my $mustRead;
        if ($dirStart < 0 or $dirStart > $dataLen-2) {
            $mustRead = 1;
        } elsif ($dirLen > 2) {
            my $len = 2 + 12 * Get16u($dataPt, $dirStart);
            $mustRead = 1 if $dirStart + $len > $dataLen;
        }
        # read IFD from file if necessary
        if ($raf and $mustRead) {
            # read the count of entries in this IFD
            my $offset = $dirStart + $dataPos;
            my ($buff, $buf2);
            unless ($raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2) {
                return ExifErr($exifTool, "Bad IFD or truncated file in $dirName", $inMakerNotes);
            }
            my $len = 12 * Get16u(\$buff,0);
            # also read next IFD pointer if reading multiple IFD's
            $len += 4 if $$dirInfo{Multi};
            unless ($raf->Read($buf2, $len) == $len) {
                return ExifErr($exifTool, "Error reading $dirName", $inMakerNotes);
            }
            UpdateTiffEnd($exifTool, $offset+$base+2+$len);
            $buff .= $buf2;
            # make copy of dirInfo since we're going to modify it
            my %newDirInfo = %$dirInfo;
            $dirInfo = \%newDirInfo;
            # update directory parameters for the newly loaded IFD
            $dataPt = $$dirInfo{DataPt} = \$buff;
            $dirStart = $$dirInfo{DirStart} = 0;
            $dataPos = $$dirInfo{DataPos} = $offset;
            $dataLen = $$dirInfo{DataLen} = $len + 2;
            $dirLen = $$dirInfo{DirLen} = $dataLen;
        }
        my ($len, $numEntries);
        if ($dirStart + 4 < $dataLen) {
            $numEntries = Get16u($dataPt, $dirStart);
            $len = 2 + 12 * $numEntries;
            if ($dirStart + $len > $dataLen) {
                return ExifErr($exifTool, "Truncated $dirName directory", $inMakerNotes);
            }
            # sort entries if necessary (but not in maker notes IFDs)
            unless ($inMakerNotes) {
                my $index;
                my $lastID = -1;
                for ($index=0; $index<$numEntries; ++$index) {
                    my $tagID = Get16u($dataPt, $dirStart + 2 + 12 * $index);
                    # check for proper sequence (but ignore null entries at end)
                    if ($tagID < $lastID and $tagID) {
                        SortIFD($dataPt, $dirStart, $numEntries);
                        $exifTool->Warn("Entries in $dirName were out of sequence. Fixed.");
                        last;
                    }
                    $lastID = $tagID;
                }
            }
        } else {
            $numEntries = $len = 0;
        }

        # fix base offsets
        if ($dirName eq 'MakerNotes' and $$dirInfo{Parent} eq 'ExifIFD' and
            Image::ExifTool::MakerNotes::FixBase($exifTool, $dirInfo))
        {
            # update local variables from fixed values
            $base = $$dirInfo{Base};
            $dataPos = $$dirInfo{DataPos};
        }

        # initialize variables to handle mandatory tags
        my $mandatory = $mandatory{$dirName};
        my $allMandatory;
        if ($mandatory) {
            $allMandatory = 0;  # initialize to zero
            # add mandatory tags if creating a new directory
            unless ($numEntries) {
                foreach (keys %$mandatory) {
                    $set{$_} or $set{$_} = $$tagTablePtr{$_};
                }
            }
        } else {
            undef $deleteAll;   # don't remove directory (no mandatory entries)
        }
        my ($addDirs, @newTags);
        if ($inMakerNotes) {
            $addDirs = { };
        } else {
            # get a hash of directories we will be writing in this one
            $addDirs = $exifTool->GetAddDirHash($tagTablePtr, $dirName);
            # make a union of tags & dirs (can set whole dirs, like MakerNotes)
            my %allTags = %set;
            foreach (keys %$addDirs) {
                $allTags{$_} = $$addDirs{$_};
            }
            # make sorted list of new tags to be added
            @newTags = sort { $a <=> $b } keys(%allTags);
        }
        my $dirBuff = '';   # buffer for directory data
        my $valBuff = '';   # buffer for value data
        my @valFixups;      # list of fixups for offsets in valBuff
        # fixup for offsets in dirBuff
        my $dirFixup = new Image::ExifTool::Fixup;
        my $entryBasedFixup;
        my $index = 0;
        my $lastTagID = -1;
        my ($oldInfo, $oldFormat, $oldFormName, $oldCount, $oldSize, $oldValue);
        my ($readFormat, $readFormName, $readCount); # format for reading old value(s)
        my ($entry, $valueDataPt, $valueDataPos, $valueDataLen, $valuePtr);
        my $oldID = -1;
        my $newID = -1;
#..............................................................................
# loop through entries in new directory
#
        for (;;) {

            if (defined $oldID and $oldID == $newID) {
#
# read next entry from existing directory
#
                if ($index < $numEntries) {
                    $entry = $dirStart + 2 + 12 * $index;
                    $oldID = Get16u($dataPt, $entry);
                    $readFormat = $oldFormat = Get16u($dataPt, $entry+2);
                    $readCount = $oldCount = Get32u($dataPt, $entry+4);
                    if ($oldFormat < 1 or $oldFormat > 13) {
                        # don't write out null directory entry
                        unless ($oldFormat or $oldCount or not $index) {
                            ++$index;
                            $newID = $oldID;    # pretend we wrote this
                            # must keep same directory size to avoid messing up our fixed offsets
                            $dirBuff .= ("\0" x 12) if $$dirInfo{FixBase};
                            next;
                        }
                        return ExifErr($exifTool, "Bad format ($oldFormat) for $dirName entry $index", $inMakerNotes);
                    }
                    $readFormName = $oldFormName = $formatName[$oldFormat];
                    $valueDataPt = $dataPt;
                    $valueDataPos = $dataPos;
                    $valueDataLen = $dataLen;
                    $valuePtr = $entry + 8;
                    $oldSize = $oldCount * $formatSize[$oldFormat];
                    my $readFromFile;
                    if ($oldSize > 4) {
                        $valuePtr = Get32u($dataPt, $valuePtr);
                        # convert offset to pointer in $$dataPt
                        if ($$dirInfo{EntryBased} or (ref $$tagTablePtr{$oldID} eq 'HASH' and
                            $tagTablePtr->{$oldID}->{EntryBased}))
                        {
                            $valuePtr += $entry;
                        } else {
                            $valuePtr -= $dataPos;
                        }
                        # get value by seeking in file if we are allowed
                        if ($valuePtr < 0 or $valuePtr+$oldSize > $dataLen) {
                            if ($raf) {
                                if ($raf->Seek($base + $valuePtr + $dataPos, 0) and
                                    $raf->Read($oldValue, $oldSize) == $oldSize)
                                {
                                    UpdateTiffEnd($exifTool, $base+$valuePtr+$dataPos+$oldSize);
                                    $valueDataPt = \$oldValue;
                                    $valueDataPos = $valuePtr + $dataPos;
                                    $valueDataLen = $oldSize;
                                    $valuePtr = 0;
                                    $readFromFile = 1;
                                } else {
                                    return ExifErr($exifTool, "Error reading value for $dirName entry $index", $inMakerNotes);
                                }
                            } else {
                                return ExifErr($exifTool, "Bad EXIF directory pointer for $dirName entry $index", $inMakerNotes);
                            }
                        }
                    }
                    # read value if we haven't already
                    $oldValue = substr($$valueDataPt, $valuePtr, $oldSize) unless $readFromFile;
                    # get tagInfo if available
                    $oldInfo = $$tagTablePtr{$oldID};
                    # must evaluate condition if necessary
                    if ($oldInfo and (ref $oldInfo ne 'HASH' or $$oldInfo{Condition})) {
                        $oldInfo = $exifTool->GetTagInfo($tagTablePtr, $oldID, \$oldValue);
                    }
                    # override format we use to read the value if specified
                    if ($oldInfo) {
                        if ($$oldInfo{Drop} and $$exifTool{DROP_TAGS}) {
                            # don't rewrite this tag
                            ++$index;
                            $oldID = $newID;
                            next;
                        }
                        if ($$oldInfo{Format}) {
                            $readFormName = $$oldInfo{Format};
                            $readFormat = $formatNumber{$readFormName};
                            unless ($readFormat) {
                                return ExifErr($exifTool, "Bad format name $readFormName", $inMakerNotes);
                            }
                            # adjust number of items to read if format size changed
                            $readCount = $oldSize / $formatSize[$readFormat];
                        }
                    }
                    if ($oldID <= $lastTagID and not $inMakerNotes) {
                        my $str = $oldInfo ? "$$oldInfo{Name} tag" : sprintf('tag 0x%x',$oldID);
                        if ($oldID == $lastTagID) {
                            $exifTool->Warn("Duplicate $str in $dirName");;
                        } else {
                            $exifTool->Warn("\u$str out of sequence in $dirName");
                        }
                    }
                    $lastTagID = $oldID;
                    ++$index;               # increment index for next time
                } else {
                    undef $oldID;           # no more existing entries
                }
            }
#
# write out all new tags, up to and including this one
#
            $newID = $newTags[0];
            my $isNew;  # -1=tag is old, 0=tag same as existing, 1=tag is new
            if (not defined $oldID) {
                last unless defined $newID;
                $isNew = 1;
            } elsif (not defined $newID) {
                # maker notes will have no new tags defined
                if ($set{$oldID}) {
                    $newID = $oldID;
                    $isNew = 0;
                } else {
                    $isNew = -1;
                }
            } else {
                $isNew = $oldID <=> $newID;
            }
            my $newInfo = $oldInfo;
            my $newFormat = $oldFormat;
            my $newFormName = $oldFormName;
            my $newCount = $oldCount;
            my $ifdFormName;
            my $newValue;
            my $newValuePt = $isNew >= 0 ? \$newValue : \$oldValue;
            my $isOverwriting;

            if ($isNew >= 0) {
                # add, edit or delete this tag
                shift @newTags; # remove from list
                if ($set{$newID}) {
#
# set the new tag value (or 'next' if deleting tag)
#
                    $newInfo = $set{$newID};
                    $newCount = $$newInfo{Count};
                    my ($val, $newVal);
                    my $newValueHash = $exifTool->GetNewValueHash($newInfo, $dirName);
                    if ($isNew > 0) {
                        # don't create new entry unless requested
                        if ($newValueHash) {
                            next unless Image::ExifTool::IsCreating($newValueHash);
                            $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash);
                        } else {
                            next if $xDelete{$newID};       # don't create if cross deleting
                            $newVal = $$mandatory{$newID};  # get value for mandatory tag
                            $isOverwriting = 1;
                        }
                        # convert using new format
                        if ($$newInfo{Format}) {
                            $newFormName = $$newInfo{Format};
                            # use Writable flag to specify IFD format code
                            $ifdFormName = $$newInfo{Writable};
                        } else {
                            $newFormName = $$newInfo{Writable};
                            unless ($newFormName) {
                                warn("No format for $dirName $$newInfo{Name}\n");
                                next;
                            }
                        }
                        $newFormat = $formatNumber{$newFormName};
                    } elsif ($newValueHash or $xDelete{$newID}) {
                        unless ($newValueHash) {
                            $newValueHash = $exifTool->GetNewValueHash($newInfo, $wrongDir);
                        }
                        # read value
                        $val = ReadValue(\$oldValue, 0, $readFormName, $readCount, $oldSize);
                        if ($$newInfo{Format}) {
                            $newFormName = $$newInfo{Format};
                            # override existing format if necessary
                            $ifdFormName = $$newInfo{Writable};
                            $ifdFormName = $oldFormName unless $ifdFormName and $ifdFormName ne '1';
                            $newFormat = $formatNumber{$newFormName};
                        }
                        if ($inMakerNotes and $readFormName ne 'string' and $readFormName ne 'undef') {
                            # keep same size in maker notes unless string or binary
                            $newCount = $oldCount * $formatSize[$oldFormat] / $formatSize[$newFormat];
                        }
                        $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash, $val);
                    }
                    if ($isOverwriting) {
                        $newVal = Image::ExifTool::GetNewValues($newValueHash) unless defined $newVal;
                        # value undefined if deleting this tag
                        if ($xDelete{$newID} or not defined $newVal) {
                            unless ($isNew) {
                                ++$exifTool->{CHANGED};
                                $val = $exifTool->Printable($val);
                                $verbose > 1 and print $out "    - $dirName:$$newInfo{Name} = '$val'\n";
                            }
                            next;
                        }
                        if (length $newVal) {
                            if ($newCount and $newCount < 0) {
                                # set count to number of values if variable
                                my @vals = split ' ',$newVal;
                                $newCount = @vals;
                            }
                            # convert to binary format
                            $newValue = WriteValue($newVal, $newFormName, $newCount);
                            unless (defined $newValue) {
                                $exifTool->Warn("Error writing $dirName:$$newInfo{Name}");
                                next if $isNew > 0;
                                $isNew = -1;    # rewrite existing tag
                            }
                        } else {
                            $exifTool->Warn("Can't write zero length $$newInfo{Name} in $tagTablePtr->{GROUPS}->{1}");
                            next if $isNew > 0;
                            $isNew = -1;        # rewrite existing tag
                        }
                        if ($isNew >= 0) {
                            $newCount = length($newValue) / $formatSize[$newFormat];
                            ++$exifTool->{CHANGED};
                            if ($verbose > 1) {
                                $val = $exifTool->Printable($val);
                                $newVal = $exifTool->Printable($newVal);
                                print $out "    - $dirName:$$newInfo{Name} = '$val'\n" unless $isNew;
                                my $str = $newValueHash ? '' : ' (mandatory)';
                                print $out "    + $dirName:$$newInfo{Name} = '$newVal'$str\n";
                            }
                        }
                    } else {
                        next if $isNew > 0;
                        $isNew = -1;        # rewrite existing tag
                    }
                    # set format for EXIF IFD if different than conversion format
                    if ($ifdFormName) {
                        $newFormName = $ifdFormName;
                        $newFormat = $formatNumber{$newFormName};
                    }

                } elsif ($isNew > 0) {
#
# create new subdirectory
#
                    $newInfo = $$addDirs{$newID} or warn('internal error'), next;
                    # make sure we don't try to generate a new MakerNotes directory
                    # or a SubIFD
                    next if $$newInfo{MakerNotes} or $$newInfo{Name} eq 'SubIFD';
                    my $subTable;
                    if ($newInfo->{SubDirectory}->{TagTable}) {
                        $subTable = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                    } else {
                        $subTable = $tagTablePtr;
                    }
                    # create empty source directory
                    my %sourceDir = (
                        Parent => $dirName,
                        Fixup => new Image::ExifTool::Fixup,
                    );
                    $sourceDir{DirName} = $newInfo->{Groups}->{1} if $$newInfo{SubIFD};
                    $newValue = $exifTool->WriteDirectory(\%sourceDir, $subTable);
                    # only add new directory if it isn't empty
                    next unless defined $newValue and length($newValue);
                    # set the fixup start location
                    if ($$newInfo{SubIFD}) {
                        # subdirectory is referenced by an offset in value buffer
                        my $subdir = $newValue;
                        $newValue = Set32u(0xfeedf00d);
                        push @subdirs, {
                            DataPt => \$subdir,
                            Table => $subTable,
                            Fixup => $sourceDir{Fixup},
                            Offset => length($dirBuff) + 8,
                            Where => 'dirBuff',
                        };
                        $newFormName = 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                    } else {
                        # subdirectory goes directly into value buffer
                        $sourceDir{Fixup}->{Start} += length($valBuff);
                        # use Writable to set format, otherwise 'undef'
                        $newFormName = $$newInfo{Writable};
                        unless ($newFormName and $formatNumber{$newFormName}) {
                            $newFormName = 'undef';
                        }
                        $newFormat = $formatNumber{$newFormName};
                        push @valFixups, $sourceDir{Fixup};
                    }
                } elsif ($$newInfo{Format} and $$newInfo{Writable} and $$newInfo{Writable} ne '1') {
                    # use specified write format
                    $newFormName = $$newInfo{Writable};
                    $newFormat = $formatNumber{$newFormName};
                }
            }
            if ($isNew < 0) {
                # just rewrite existing tag
                $newID = $oldID;
                $newValue = $oldValue;
            }
            if ($newInfo) {
#
# load necessary data for this tag (thumbnail image, etc)
#
                if ($$newInfo{DataTag} and $isNew >= 0) {
                    my $dataTag = $$newInfo{DataTag};
                    # load data for this tag
                    unless (defined $offsetData{$dataTag}) {
                        $offsetData{$dataTag} = $exifTool->GetNewValues($dataTag);
                        my $err;
                        if (defined $offsetData{$dataTag}) {
                            if ($exifTool->{FILE_TYPE} eq 'JPEG' and
                                $dataTag ne 'PreviewImage' and length($offsetData{$dataTag}) > 60000)
                            {
                                delete $offsetData{$dataTag};
                                $err = "$dataTag not written (too large for JPEG segment)";
                            }
                        } else {
                            $err = "$dataTag not found";
                        }
                        if ($err) {
                            $exifTool->Warn($err) if $$newInfo{IsOffset};
                            delete $set{$newID};    # remove from list of tags we are setting
                            next;
                        }
                    }
                }
#
# write maker notes
#
                if ($$newInfo{MakerNotes}) {
                    # don't write new makernotes if we are deleting this group
                    if ($exifTool->{DEL_GROUP} and $exifTool->{DEL_GROUP}->{MakerNotes} and
                        ($exifTool->{DEL_GROUP}->{MakerNotes} != 2 or $isNew <= 0))
                    {
                        if ($isNew <= 0) {
                            ++$exifTool->{CHANGED};
                            $verbose and print $out "  Deleting MakerNotes\n";
                        }
                        next;
                    }
                    my $saveOrder = GetByteOrder();
                    if ($isNew >= 0 and $set{$newID}) {
                        # we are writing a whole new maker note block
                        # --> add fixup information if necessary
                        if ($exifTool->{MAKER_NOTE_FIXUP}) {
                            my $makerFixup = $exifTool->{MAKER_NOTE_FIXUP}->Clone();
                            my $valLen = length($valBuff);
                            $makerFixup->{Start} += $valLen;
                            push @valFixups, $makerFixup;
                        }
                    } else {
                        # update maker notes if possible
                        my %subdirInfo = (
                            Base => $base,
                            DataPt => $valueDataPt,
                            DataPos => $valueDataPos,
                            DataLen => $valueDataLen,
                            DirStart => $valuePtr,
                            DirLen => $oldSize,
                            DirName => 'MakerNotes',
                            Parent => $dirName,
                            TagInfo => $newInfo,
                            RAF => $raf,
                        );
                        if ($$newInfo{SubDirectory}) {
                            $subdirInfo{FixBase} = 1 if $newInfo->{SubDirectory}->{FixBase};
                            $subdirInfo{EntryBased} = $newInfo->{SubDirectory}->{EntryBased};
                        }
                        # get the proper tag table for these maker notes
                        my $subTable;
                        if ($oldInfo and $oldInfo->{SubDirectory}) {
                            $subTable = $oldInfo->{SubDirectory}->{TagTable};
                            $subTable and $subTable = Image::ExifTool::GetTagTable($subTable);
                        } else {
                            $exifTool->Warn('Internal problem getting maker notes tag table');
                        }
                        $subTable or $subTable = $tagTablePtr;
                        my $subdir;
                        # look for IFD-style maker notes
                        my $loc = Image::ExifTool::MakerNotes::LocateIFD($exifTool,\%subdirInfo);
                        if (defined $loc) {
                            # we need fixup data for this subdirectory
                            $subdirInfo{Fixup} = new Image::ExifTool::Fixup;
                            # rewrite maker notes
                            $subdir = $exifTool->WriteDirectory(\%subdirInfo, $subTable);
                        } elsif ($$subTable{PROCESS_PROC} and
                                 $$subTable{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData)
                        {
                            my $sub = $oldInfo->{SubDirectory};
                            if (defined $$sub{Start}) {
                                #### eval Start ($valuePtr)
                                my $start = eval $$sub{Start};
                                $loc = $start - $valuePtr;
                                $subdirInfo{DirStart} = $start;
                                $subdirInfo{DirLen} -= $loc;
                            } else {
                                $loc = 0;
                            }
                            # rewrite maker notes
                            $subdir = $exifTool->WriteDirectory(\%subdirInfo, $subTable);
                        } else {
                            $exifTool->Warn('Maker notes could not be parsed');
                        }
                        if (defined $subdir) {
                            next unless length $subdir;
                            my $valLen = length($valBuff);
                            # restore existing header and substitute the new
                            # maker notes for the old value
                            $newValue = substr($oldValue, 0, $loc) . $subdir;
                            my $makerFixup = $subdirInfo{Fixup};
                            my $previewInfo = $exifTool->{PREVIEW_INFO};
                            if ($subdirInfo{Relative}) {
                                # apply a one-time fixup to $loc since offsets are relative
                                $makerFixup->{Start} += $loc;
                                # shift all offsets to be relative to new base
                                my $baseShift = $valueDataPos + $valuePtr + $base - $subdirInfo{Base};
                                $makerFixup->{Shift} += $baseShift;
                                $makerFixup->ApplyFixup(\$newValue);
                                if ($previewInfo) {
                                    # remove all but PreviewImage fixup (since others shouldn't change)
                                    foreach (keys %{$makerFixup->{Pointers}}) {
                                        /_PreviewImage$/ or delete $makerFixup->{Pointers}->{$_};
                                    }
                                    # zero pointer so we can see how it gets shifted later
                                    $makerFixup->SetMarkerPointers(\$newValue, 'PreviewImage', 0);
                                    # set the pointer to the start of the EXIF information
                                    # add preview image fixup to list of value fixups
                                    $makerFixup->{Start} += $valLen;
                                    push @valFixups, $makerFixup;
                                    $previewInfo->{BaseShift} = $baseShift;
                                    $previewInfo->{Relative} = 1;
                                }
                            } elsif (not defined $subdirInfo{Relative}) {
                                # don't shift anything if relative flag set to zero (Pentax patch)
                                my $baseShift = $base - $subdirInfo{Base};
                                $makerFixup->{Start} += $valLen + $loc;
                                $makerFixup->{Shift} += $baseShift;
                                push @valFixups, $makerFixup;
                                if ($previewInfo and not $previewInfo->{NoBaseShift}) {
                                    $previewInfo->{BaseShift} = $baseShift;
                                }
                            }
                            $newValuePt = \$newValue;   # write new value
                        }
                    }
                    SetByteOrder($saveOrder);

                # process existing subdirectory unless we are overwriting it entirely
                } elsif ($$newInfo{SubDirectory} and $isNew <= 0 and not $isOverwriting) {

                    my $subdir = $$newInfo{SubDirectory};
                    if ($$newInfo{SubIFD}) {
#
# rewrite existing sub IFD's
#
                        my $subdirName = $newInfo->{Groups}->{1};
                        # must handle sub-IFD's specially since the values
                        # are actually offsets to subdirectories
                        unless ($readCount) {   # can't have zero count
                            return ExifErr($exifTool, "$dirName entry $index has zero count", $inMakerNotes);
                        }
                        my $i;
                        $newValue = '';    # reset value because we regenerate it below
                        for ($i=0; $i<$readCount; ++$i) {
                            my $off = $i * $formatSize[$readFormat];
                            my $pt = Image::ExifTool::ReadValue($valueDataPt, $valuePtr + $off,
                                            $readFormName, 1, $oldSize - $off);
                            my $subdirStart = $pt - $dataPos;
                            my %subdirInfo = (
                                Base => $base,
                                DataPt => $dataPt,
                                DataPos => $dataPos,
                                DataLen => $dataLen,
                                DirStart => $subdirStart,
                                DirName => $subdirName . ($i ? $i : ''),
                                Parent => $dirName,
                                Fixup => new Image::ExifTool::Fixup,
                                RAF => $raf,
                            );
                            # read subdirectory from file if necessary
                            if ($subdirStart < 0 or $subdirStart + 2 > $dataLen) {
                                my ($buff, $buf2, $subSize);
                                unless ($raf and $raf->Seek($pt + $base, 0) and
                                        $raf->Read($buff,2) == 2 and
                                        $subSize = 12 * Get16u(\$buff, 0) and
                                        $raf->Read($buf2,$subSize) == $subSize)
                                {
                                    if (defined $subSize and not $subSize) {
                                        next unless $exifTool->Error("$subdirName IFD has zero entries", 1);
                                        return undef;
                                    }
                                    return ExifErr($exifTool, "Can't read $subdirName data", $inMakerNotes);
                                }
                                UpdateTiffEnd($exifTool, $pt+$base+2+$subSize);
                                $buff .= $buf2;
                                # change subdirectory information to data we just read
                                $subdirInfo{DataPt} = \$buff;
                                $subdirInfo{DirStart} = 0;
                                $subdirInfo{DataPos} = $pt;
                                $subdirInfo{DataLen} = $subSize + 2;
                            }
                            my $subTable = $tagTablePtr;
                            if ($$subdir{TagTable}) {
                                $subTable = GetTagTable($$subdir{TagTable});
                            }
                            my $subdirData = $exifTool->WriteDirectory(\%subdirInfo, $subTable);
                            return undef unless defined $subdirData;
                            next unless length($subdirData);
                            # temporarily set value to subdirectory index
                            # (will set to actual offset later when we know what it is)
                            $newValue .= Set32u(0xfeedf00d);
                            my ($offset, $where);
                            if ($readCount > 1) {
                                $offset = length($valBuff) + $i * 4;
                                $where = 'valBuff';
                            } else {
                                $offset = length($dirBuff) + 8;
                                $where = 'dirBuff';
                            }
                            # add to list of subdirectories we will add later
                            push @subdirs, {
                                DataPt => \$subdirData,
                                Table => $subTable,
                                Fixup => $subdirInfo{Fixup},
                                Offset => $offset,
                                Where => $where,
                            };
                        }
                        next unless length $newValue;
                        # set new format to int32u for IFD
                        $newFormName = 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                        $newValuePt = \$newValue;

                    } elsif ((not defined $$subdir{Start} or
                             $$subdir{Start} =~ /\$valuePtr/) and
                             $$subdir{TagTable})
                    {
#
# rewrite other existing subdirectories ('$valuePtr' type only)
#
                        # set subdirectory Start and Base
                        my $subdirStart = $valuePtr;
                        if ($$subdir{Start}) {
                            #### eval Start ($valuePtr)
                            $subdirStart = eval $$subdir{Start};
                            # must adjust directory size if start changed
                            $oldSize -= $subdirStart - $valuePtr;
                        }
                        my $subdirBase = $base;
                        if ($$subdir{Base}) {
                            my $start = $subdirStart + $dataPos;
                            #### eval Base ($start)
                            $subdirBase += eval $$subdir{Base};
                        }
                        my $subFixup = new Image::ExifTool::Fixup;
                        my %subdirInfo = (
                            Base => $subdirBase,
                            DataPt => $valueDataPt,
                            DataPos => $valueDataPos - $subdirBase + $base,
                            DataLen => $valueDataLen,
                            DirStart => $subdirStart,
                            DirLen => $oldSize,
                            Parent => $dirName,
                            Fixup => $subFixup,
                            RAF => $raf,
                        );
                        my $subTable = GetTagTable($$subdir{TagTable});
                        $newValue = $exifTool->WriteDirectory(\%subdirInfo, $subTable);
                        if (defined $newValue) {
                            my $hdrLen = $subdirStart - $valuePtr;
                            if ($hdrLen) {
                                $newValue = substr($$valueDataPt, $valuePtr, $hdrLen) . $newValue;
                                $subFixup->{Start} += $hdrLen;
                            }
                            $newValuePt = \$newValue;
                        }
                        unless (defined $$newValuePt) {
                            $exifTool->Error("Internal error writing $dirName:$$newInfo{Name}");
                            return undef;
                        }
                        next unless length $$newValuePt;
                        if ($subFixup->{Pointers} and $subdirInfo{Base} == $base) {
                            $subFixup->{Start} += length $valBuff;
                            push @valFixups, $subFixup;
                        } else {
                            # apply fixup in case we added a header ($hdrLen above)
                            $subFixup->ApplyFixup(\$newValue);
                        }
                    }

                } elsif ($$newInfo{OffsetPair}) {
#
# keep track of offsets
#
                    my $offsetInfo = $offsetInfo[$ifd];
                    # save original values (for updating TIFF_END later)
                    my @vals;
                    if ($isNew <= 0) {
                        @vals = ReadValue(\$oldValue, 0, $readFormName, $readCount, $oldSize);
                    }
                    # only support int32 pointers (for now)
                    if ($formatSize[$newFormat] != 4 and $$newInfo{IsOffset}) {
                        die "Internal error (Offset not int32)" if $isNew > 0;
                        die "Wrong count!" if $newCount != $readCount;
                        # change to int32
                        $newFormName = 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                        $newValue = WriteValue(join(' ',@vals), $newFormName, $newCount);
                    }
                    $offsetInfo or $offsetInfo = $offsetInfo[$ifd] = { };
                    # save location of valuePtr in new directory
                    # (notice we add 10 instead of 8 for valuePtr because
                    # we will put a 2-byte count at start of directory later)
                    my $ptr = $newStart + length($dirBuff) + 10;
                    $newCount or $newCount = 1; # make sure count is set for offsetInfo
                    # save value pointer and value count for each tag
                    $offsetInfo->{$newID} = [$newInfo, $ptr, $newCount, \@vals, $newFormat];

                } elsif ($$newInfo{DataMember}) {

                    # save any necessary data members (CameraMake, CameraModel)
                    $exifTool->{$$newInfo{DataMember}} = $$newValuePt;
                }
            }
#
# write out the directory entry
#
            my $newSize = length($$newValuePt);
            my $fsize = $formatSize[$newFormat];
            my $offsetVal;
            $newCount = int(($newSize + $fsize - 1) / $fsize);  # set proper count
            if ($newSize > 4) {
                # zero-pad to an even number of bytes (required by EXIF standard)
                # and make sure we are a multiple of the format size
                while ($newSize & 0x01 or $newSize < $newCount * $fsize) {
                    $$newValuePt .= "\0";
                    ++$newSize;
                }
                my $entryBased;
                if ($$dirInfo{EntryBased} or ($newInfo and $$newInfo{EntryBased})) {
                    $entryBased = 1;
                    $offsetVal = Set32u(length($valBuff) - length($dirBuff));
                } else {
                    $offsetVal = Set32u(length $valBuff);
                }
                my $dataTag;
                if ($newInfo and $$newInfo{DataTag}) {
                    $dataTag = $$newInfo{DataTag};
                    if ($dataTag eq 'PreviewImage' and $exifTool->{FILE_TYPE} eq 'JPEG') {
                        # hold onto the PreviewImage until we can determine if it fits
                        $exifTool->{PREVIEW_INFO} or $exifTool->{PREVIEW_INFO} = { };
                        $exifTool->{PREVIEW_INFO}->{Data} = $$newValuePt;
                        if ($$newInfo{Name} eq 'PreviewImage') {
                            $exifTool->{PREVIEW_INFO}->{IsValue} = 1;
                        }
                        if ($$newInfo{IsOffset} and $$newInfo{IsOffset} eq '2') {
                            $exifTool->{PREVIEW_INFO}->{NoBaseShift} = 1;
                        }
                        $$newValuePt = '';
                    }
                }
                $valBuff .= $$newValuePt;       # add value data to buffer
                # must save a fixup pointer for every pointer in the directory
                if ($entryBased) {
                    $entryBasedFixup or $entryBasedFixup = new Image::ExifTool::Fixup;
                    $entryBasedFixup->AddFixup(length($dirBuff) + 8, $dataTag);
                } else {
                    $dirFixup->AddFixup(length($dirBuff) + 8, $dataTag);
                }
            } else {
                $offsetVal = $$newValuePt;      # save value in offset if 4 bytes or less
                # must pad value with zeros if less than 4 bytes
                $newSize < 4 and $offsetVal .= "\0" x (4 - $newSize);
            }
            # write the directory entry
            $dirBuff .= Set16u($newID) . Set16u($newFormat) .
                        Set32u($newCount) . $offsetVal;
            # update flag to keep track of mandatory tags
            while (defined $allMandatory) {
                if (defined $$mandatory{$newID}) {
                    # values must correspond to mandatory values
                    my $mandVal = WriteValue($$mandatory{$newID}, $newFormName, $newCount);
                    if ($mandVal eq $$newValuePt) {
                        ++$allMandatory;        # count mandatory tags
                        last;
                    }
                }
                undef $deleteAll;
                undef $allMandatory;
            }
        }
#..............................................................................
# write directory counts and nextIFD pointer and add value data to end of IFD
#
        # calculate number of entries in new directory
        my $newEntries = length($dirBuff) / 12;
        # delete entire directory if only mandatory tags remain
        if ($newEntries < $numEntries and $allMandatory) {
            $newEntries = 0;
            $dirBuff = '';
            $valBuff = '';
            undef $dirFixup;    # no fixups in this directory
            ++$deleteAll if defined $deleteAll;
            $verbose > 1 and print $out "    - $allMandatory mandatory tag(s)\n";
        }
        if ($ifd and not $newEntries) {
            $verbose and print $out "  Deleting IFD1\n";
            last;   # don't write IFD1 if empty
        }
        # apply one-time fixup for entry-based offsets
        if ($entryBasedFixup) {
            $entryBasedFixup->{Shift} = length($dirBuff) + 4;
            $entryBasedFixup->ApplyFixup(\$dirBuff);
            undef $entryBasedFixup;
        }
        # add directory entry count to start of IFD and next IFD pointer to end
        # (temporarily set next IFD pointer to zero)
        $newData .= Set16u($newEntries) . $dirBuff . Set32u(0);
        # get position of value data in newData
        my $valPos = length($newData);
        # go back now and set next IFD pointer if this isn't the first IFD
        if ($nextIfdPos) {
            # set offset to next IFD
            Set32u($newStart, \$newData, $nextIfdPos);
            $fixup->AddFixup($nextIfdPos,'NextIFD');    # add fixup for this offset in newData
        }
        # remember position of 'next IFD' pointer so we can set it next time around
        $nextIfdPos = $valPos - 4;
        # add value data after IFD
        $newData .= $valBuff;
#
# add any subdirectories, adding fixup information
#
        if (@subdirs) {
            my $subdir;
            foreach $subdir (@subdirs) {
                my $pos = length($newData);    # position of subdirectory in data
                my $subdirFixup = $subdir->{Fixup};
                $subdirFixup->{Start} += $pos;
                $fixup->AddFixup($subdirFixup);
                $newData .= ${$subdir->{DataPt}};   # add subdirectory to our data
                undef ${$subdir->{DataPt}};         # free memory now
                # set the pointer
                my $offset = $subdir->{Offset};
                # if offset is in valBuff, it was added to the end of dirBuff
                # (plus 4 bytes for nextIFD pointer)
                $offset += length($dirBuff) + 4 if $subdir->{Where} eq 'valBuff';
                $offset += $newStart + 2;           # get offset in newData
                # check to be sure we got the right offset
                unless (Get32u(\$newData, $offset) == 0xfeedf00d) {
                    $exifTool->Error("Internal error while rewriting $dirName");
                    return undef;
                }
                # set the offset to the subdirectory data
                Set32u($pos, \$newData, $offset);
                $fixup->AddFixup($offset);  # add fixup for this offset in newData
            }
        }
        # add fixup for all offsets in directory according to value data position
        # (which is at the end of this directory)
        if ($dirFixup) {
            $dirFixup->{Start} = $newStart + 2;
            $dirFixup->{Shift} = $valPos - $dirFixup->{Start};
            $fixup->AddFixup($dirFixup);
        }
        # add valueData fixups, adjusting for position of value data
        my $valFixup;
        foreach $valFixup (@valFixups) {
            $valFixup->{Start} += $valPos;
            $fixup->AddFixup($valFixup);
        }
        # stop if no next IFD pointer
        last unless $$dirInfo{Multi};  # stop unless scanning for multiple IFD's
        my $offset;
        if ($dirStart + $len + 4 <= $dataLen) {
            $offset = Get32u($dataPt, $dirStart + $len);
        } else {
            $offset = 0;
        }
        if ($offset) {
            # continue with next IFD
            $dirStart = $offset - $dataPos;
        } else {
            # create IFD1 if necessary
            last unless $dirName eq 'IFD0' and $exifTool->{ADD_DIRS}->{'IFD1'};
            $verbose and print $out "  Creating IFD1\n";
            my $ifd1 = "\0" x 2;  # empty IFD1 data (zero entry count)
            $dataPt = \$ifd1;
            $dirStart = 0;
            $dirLen = $dataLen = 2;
        }
        # increment IFD0 name to IFD1, IFD2,...
        if ($dirName =~ /^IFD(\d+)$/) {
            $dirName = 'IFD' . ($1+1);
            $exifTool->{DIR_NAME} = $dirName;
            if ($offset) {
                if ($exifTool->{DEL_GROUP} and $exifTool->{DEL_GROUP}->{$dirName}) {
                    $verbose and print $out "  Deleting $dirName\n";
                    ++$exifTool->{CHANGED};
                    if ($exifTool->{DEL_GROUP}->{$dirName} == 2 and
                        $exifTool->{ADD_DIRS}->{$dirName})
                    {
                        $ifd = "\0" x 2;    # start with empty IFD
                        $dataPt = \$ifd;
                        $dirStart = 0;
                        $dirLen = $dataLen = 2;
                    } else {
                        last;   # don't write this IFD (or any subsequent IFD)
                    }
                } else {
                    $verbose and print $out "  Rewriting $dirName\n";
                }
            }
        }
    }
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # do our fixups now so we can more easily calculate offsets below
    $fixup->ApplyFixup(\$newData);
#
# copy over image data for IFD's, starting with the last IFD first
#
    my @imageData; # image data blocks if requested
    if (@offsetInfo) {
        my @writeLater;  # write image data last
        for ($ifd=$#offsetInfo; $ifd>=-1; --$ifd) {
            # build list of offsets to process
            my @offsetList;
            if ($ifd >= 0) {
                my $offsetInfo = $offsetInfo[$ifd] or next;
                my $tagID;
                # loop through all tags in reverse order so we save thumbnail
                # data before main image data if both exist in the same IFD
                foreach $tagID (reverse sort keys %$offsetInfo) {
                    my $tagInfo = $offsetInfo->{$tagID}->[0];
                    next unless $$tagInfo{IsOffset}; # handle byte counts with offsets
                    my $sizeInfo = $offsetInfo->{$$tagInfo{OffsetPair}};
                    my $dataTag = $$tagInfo{DataTag};
                    # write TIFF image data (strips or tiles) later if requested
                    if ($raf and defined $_[1]->{ImageData} and
                        ($tagID == 0x111 or $tagID == 0x144) and
                        (not defined $dataTag or not defined $offsetData{$dataTag}))
                    {
                        push @writeLater, [ $offsetInfo->{$tagID}, $sizeInfo ];
                    } else {
                        push @offsetList, [ $offsetInfo->{$tagID}, $sizeInfo ];
                    }
                }
            } else {
                last unless @writeLater;
                @offsetList = @writeLater;
            }
            my $blockSize = 0;  # total size of blocks to copy later
            my $offsetPair;
            foreach $offsetPair (@offsetList) {
                my ($tagInfo, $offsets, $count, $oldOffset) = @{$$offsetPair[0]};
                my ($cntInfo, $byteCounts, $count2, $oldSize, $format) = @{$$offsetPair[1]};
                # must be the same number of offset and byte count values
                unless ($count == $count2) {
                    $exifTool->Error("Offset/byteCounts disagree on count for $$tagInfo{Name}");
                    return undef;
                }
                my $formatStr = $formatName[$format];
                # follow pointer to value data if necessary
                $count > 1 and $offsets = Get32u(\$newData, $offsets);
                my $n = $count * $formatSize[$format];
                $n > 4 and $byteCounts = Get32u(\$newData, $byteCounts);
                if ($byteCounts < 0 or $byteCounts + $n > length($newData)) {
                    $exifTool->Error("Error reading $$tagInfo{Name} byte counts");
                    return undef;
                }
                # get offset base and data pos (abnormal for some preview images)
                my ($dbase, $dpos);
                if ($$tagInfo{IsOffset} eq '2') {
                    $dbase = $firstBase;
                    $dpos = $dataPos + $base - $firstBase;
                } else {
                    $dbase = $base;
                    $dpos = $dataPos;
                }
                # transfer the data referenced by all offsets of this tag
                for ($n=0; $n<$count; ++$n) {
                    my $oldEnd;
                    if (@$oldOffset and @$oldSize) {
                        # update TIFF_END as if we had read this data from file
                        $oldEnd = $$oldOffset[$n] + $$oldSize[$n];
                        UpdateTiffEnd($exifTool, $oldEnd + $dbase);
                    }
                    my $offsetPos = $offsets + $n * 4;
                    my $byteCountPos = $byteCounts + $n * $formatSize[$format];
                    my $size = ReadValue(\$newData, $byteCountPos, $formatStr, 1, 4);
                    my $offset = Get32u(\$newData, $offsetPos) - $dpos;
                    my $buff;
                    # look for 'feed' code to use our new data
                    if ($size == 0xfeedfeed) {
                        my $dataTag = $$tagInfo{DataTag};
                        unless (defined $dataTag) {
                            $exifTool->Error("No DataTag defined for $$tagInfo{Name}");
                            return undef;
                        }
                        unless (defined $offsetData{$dataTag}) {
                            $exifTool->Error("Internal error (no $dataTag)");
                            return undef;
                        }
                        if ($count > 1) {
                            $exifTool->Error("Can't modify $$tagInfo{Name} with count $count");
                            return undef;
                        }
                        $buff = $offsetData{$dataTag};
                        if ($formatSize[$format] != 4) {
                            $exifTool->Error("$$cntInfo{Name} is not int32");
                            return undef;
                        }
                        # set the data size
                        $size = length($buff);
                        Set32u($size, \$newData, $byteCountPos);
                    } elsif ($ifd < 0) {
                        # pad if necessary (but don't pad contiguous image blocks)
                        my $pad = 0;
                        ++$pad if $size & 0x01 and ($n+1 >= $count or not $oldEnd or
                                  $oldEnd != $$oldOffset[$n+1]);
                        # copy data later
                        push @imageData, [$offset+$dbase+$dpos, $size, $pad];
                        $size += $pad; # account for pad byte if necessary
                        # return ImageData list
                        $_[1]->{ImageData} = \@imageData;
                    } elsif ($offset >= 0 and $offset+$size <= $dataLen) {
                        # take data from old dir data buffer
                        $buff = substr($$dataPt, $offset, $size);
                    } elsif ($raf and $raf->Seek($offset+$dbase+$dpos,0) and
                             $raf->Read($buff,$size) == $size)
                    {
                        # data read OK
                    } elsif ($$tagInfo{Name} eq 'ThumbnailOffset' and $offset>=0 and $offset<$dataLen) {
                        # Grrr.  The Canon 350D writes the thumbnail with an incorrect byte count
                        my $diff = $offset + $size - $dataLen;
                        $exifTool->Warn("ThumbnailImage runs outside EXIF data by $diff bytes -- Truncated");
                        # set the size to the available data
                        $size -= $diff;
                        WriteValue($size, $formatStr, 1, \$newData, $byteCountPos);
                        # get the truncated image
                        $buff = substr($$dataPt, $offset, $size);
                    } elsif ($$tagInfo{Name} eq 'PreviewImageStart' and $exifTool->{FILE_TYPE} eq 'JPEG') {
                        # try to load the preview image using the specified offset
                        undef $buff;
                        my $r = $exifTool->{RAF};
                        if ($r and not $raf) {
                            my $tell = $r->Tell();
                            # read and validate
                            undef $buff unless $r->Seek($offset+$base+$dataPos,0) and
                                               $r->Read($buff,$size) == $size and
                                               $buff =~ /^.\xd8\xff[\xc4\xdb\xe0-\xef]/;
                            $r->Seek($tell, 0) or $exifTool->Error('Seek error'), return undef;
                        }
                        $buff = 'LOAD' unless defined $buff;    # flag indicating we must load PreviewImage
                    } else {
                        my $dataName = $$tagInfo{DataTag} || $$tagInfo{Name};
                        $exifTool->Error("Error reading $dataName data in $dirName");
                        return undef;
                    }
                    if ($$tagInfo{Name} eq 'PreviewImageStart' and $exifTool->{FILE_TYPE} eq 'JPEG') {
                        # hold onto the PreviewImage until we can determine if it fits
                        $exifTool->{PREVIEW_INFO} or $exifTool->{PREVIEW_INFO} = { };
                        $exifTool->{PREVIEW_INFO}->{Data} = $buff;
                        if ($$tagInfo{IsOffset} and $$tagInfo{IsOffset} eq '2') {
                            $exifTool->{PREVIEW_INFO}->{NoBaseShift} = 1;
                        }
                        $buff = '';
                    }
                    # update offset accordingly and add to end of new data
                    Set32u(length($newData)+$blockSize, \$newData, $offsetPos);
                    # add a pointer to fix up this offset value (marked with DataTag name)
                    $fixup->AddFixup($offsetPos, $$tagInfo{DataTag});
                    if ($ifd >= 0) {
                        $buff .= "\0" if $size & 0x01;  # must be even size
                        $newData .= $buff;      # add this strip to the data
                    } else {
                        $blockSize += $size;    # keep track of total size
                    }
                }
            }
        }
    }
#
# apply final shift to new data position if this is the top level IFD
#
    unless ($$dirInfo{Fixup}) {
        my $newDataPos = $$dirInfo{NewDataPos} || 0;
        if ($newDataPos) {
            $fixup->{Shift} += $newDataPos;
            $fixup->ApplyFixup(\$newData);
        }
        # save fixup for PreviewImage in JPEG file if necessary
        my $previewInfo = $exifTool->{PREVIEW_INFO};
        if ($previewInfo) {
            my $pt = \$previewInfo->{Data}; # image data or 'LOAD' flag
            # now that we know the size of the EXIF data, first test to see if our new image fits
            # inside the EXIF segment (remember about the TIFF and EXIF headers: 8+6 bytes)
            if (($$pt ne 'LOAD' and length($$pt) + length($newData) + 14 <= 0xfffd) or
                $previewInfo->{IsValue})
            {
                # It fits! (or must exist in EXIF segment), so fixup the
                # PreviewImage pointers and stuff the preview image in here
                my $newPos = length($newData) + ($newDataPos || 0);
                $newPos += ($previewInfo->{BaseShift} || 0);
                if ($previewInfo->{Relative}) {
                    # calculate our base by looking at how far the pointer got shifted
                    $newPos -= $fixup->GetMarkerPointers(\$newData, 'PreviewImage');
                }
                $fixup->SetMarkerPointers(\$newData, 'PreviewImage', $newPos);
                $newData .= $$pt;
                delete $exifTool->{PREVIEW_INFO};   # done with our preview data
                $exifTool->{DEL_PREVIEW} = 1;       # set flag to delete old preview
            } else {
                # Doesn't fit, or we still don't know, so save fixup information
                # and put the preview at the end of the file
                $previewInfo->{Fixup} or $previewInfo->{Fixup} = new Image::ExifTool::Fixup;
                $previewInfo->{Fixup}->AddFixup($fixup);
            }
        } else {
            # delete both IFD0 and IFD1 if only mandatory tags remain
            $newData = '' if defined $newData and $deleteAll;
        }
        # save location of last IFD for use in Canon RAW header
        if ($newDataPos == 16) {
            my @ifdPos = $fixup->GetMarkerPointers(\$newData,'NextIFD');
            $_[1]->{LastIFD} = pop @ifdPos;
        }
    }
    # return empty string if no entries in directory
    # (could be up to 10 bytes and still be empty)
    $newData = '' if defined $newData and length($newData) < 12;

    return $newData;    # return our directory data
}

1; # end

__END__

=head1 NAME

Image::ExifTool::WriteExif.pl - Write EXIF meta information

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::Exif.

=head1 DESCRIPTION

This file contains routines to write EXIF metadata.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::Exif(3pm)|Image::ExifTool::Exif>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
