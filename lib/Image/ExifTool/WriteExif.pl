#------------------------------------------------------------------------------
# File:         WriteExif.pl
#
# Description:  Routines for writing EXIF meta information
#
# Revisions:    12/13/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;

use Image::ExifTool::Fixup;

sub InsertWritableProperties($$;$$);
sub BuildFixup($$$);

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
        Protected => 1,
        Writable => 'string',
        WriteGroup => 'InteropIFD',
    },
    0x0002 => {             # InteropVersion
        Protected => 1,
        Writable => 'undef',
        WriteGroup => 'InteropIFD',
    },
    0x00fe => {             # SubfileType
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x00ff => {             # OldSubfileType
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
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
        Count => 3,
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
        ValueConvInv => '$val',
    },
    0x0110 => {             # Model
        Writable => 'string',
        WriteGroup => 'IFD0',
        ValueConvInv => '$val',
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
    0x011a => {             # XResolution
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0x011b => {             # YResolution
        Writable => 'rational32u',
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
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0x011f => {             # YPosition
        Writable => 'rational32u',
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
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x013f => {             # PrimaryChromaticities
        Writable => 'rational32u',
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
    0x1001 => {             # RelatedImageWidth
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'InteropIFD',
    },
    0x1002 => {             # RelatedImageHeight
        Protected => 1,
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
        Writable => 'rational32u',
        PrintConvInv => 'eval $val',
    },
    0x829d => {             # FNumber
        Writable => 'rational32u',
        PrintConvInv => '$val',
    },
    0x83bb => {             # IPTC-NAA
        Writable => 'undef',
        WriteGroup => 'IFD0',
    },
    0x8822 => 'int16u',     # ExposureProgram
    0x8824 => 'string',     # SpectralSensitivity
    0x8827 => 'int16u',     # ISO
    0x882a => 'int16s',     # TimeZoneOffset
    0x882b => 'int16u',     # SelfTimerMode
    0x9000 => 'undef',      # ExifVersion
    0x9003 => {             # DateTimeOriginal
        Writable => 'string',
        PrintConvInv => '$val',   # (only works if date format not set)
    },
    0x9004 => {             # DateTimeDigitized
        Writable => 'string',
        PrintConvInv => '$val',   # (only works if date format not set)
    },
    0x9101 => {             # ComponentsConfiguration
        Protected => 1,
        Writable => 'undef',
    },
    0x9201 => {             # ShutterSpeedValue
        Writable => 'rational32s',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : -100',
        # do eval to convert things like '1/100'
        PrintConvInv => 'eval $val',
    },
    0x9202 => {             # ApertureValue
        Writable => 'rational32u',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    0x9203 => 'rational32s',# BrightnessValue
    0x9204 => {             # ExposureCompensation
        Writable => 'rational32s',
        # do eval to convert things like '+2/3'
        PrintConvInv => 'eval $val',
    },
    0x9205 => {             # MaxApertureValue
        Writable => 'rational32u',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    0x9206 => {             # SubjectDistance
        Writable => 'rational32u',
        PrintConvInv => '$val=~s/ m$//;$val',
    },
    0x9207 => 'int16u',     # MeteringMode
    0x9208 => 'int16u',     # LightSource
    0x9209 => 'int16u',     # Flash
    0x920a => {             # FocalLength
        Writable => 'rational32u',
        PrintConvInv => '$val=~s/mm$//;$val',
    },
    0x9214 => {             # SubjectLocation
        Writable => 'int16u',
        Count => 2,  # actually, 2 or 4 allowed... (how to handle this?)
    },
#    0x927c => 'undef',      # MakerNotes
    0x9286 => {             # UserComment (string that starts with "ASCII\0\0\0")
        Writable => 'undef',
        PrintConvInv => '"ASCII\0\0\0$val\0"',
    },
    0x9290 => 'string',     # SubSecTime
    0x9291 => 'string',     # SubSecTimeOriginal
    0x9292 => 'string',     # SubSecTimeDigitized
#    0x9928 => 'undef',      # Opto-ElectricConversionFactor
    0x9c9b => {             # XPTitle
        Writable => 'int8u',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9c => {             # XPComment
        Writable => 'int8u',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9d => {             # XPAuthor
        Writable => 'int8u',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9e => {             # XPKeywords
        Writable => 'int8u',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0x9c9f => {             # XPSubject
        Writable => 'int8u',
        ValueConvInv => '$self->Byte2Unicode($val,"II")',
    },
    0xa000 => 'undef',      # FlashpixVersion
    0xa001 => 'int16u',     # ColorSpace
    0xa002 => 'int16u',     # ExifImageWidth (could also be int32u)
    0xa003 => 'int16u',     # ExifImageLength (could also be int32u)
    0xa004 => 'string',     # RelatedSoundFile
    0xa20b => 'rational32u',# FlashEnergy
#    0xa20c => 'undef',      # SpatialFrequencyResponse
    0xa20e => 'rational32u',# FocalPlaneXResolution
    0xa20f => 'rational32u',# FocalPlaneYResolution
    0xa210 => 'int16u',     # FocalPlaneResolutionUnit
    0xa214 => {             # SubjectLocation
        Writable => 'int16u',
        Count => 2,
    },
    0xa215 => 'rational32u',# ExposureIndex
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
#    0xa302 => 'undef',      # CFAPattern
    0xa401 => 'int16u',     # CustomRendered
    0xa402 => 'int16u',     # ExposureMode
    0xa403 => 'int16u',     # WhiteBalance
    0xa404 => 'rational32u',# DigitalZoomRatio
    0xa405 => 'int16u',     # FocalLengthIn35mmFormat
    0xa406 => 'int16u',     # SceneCaptureType
    0xa407 => 'int16u',     # GainControl
    0xa408 => {             # Contrast
        Writable => 'int16u',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xa409 => {             # Saturation
        Writable => 'int16u',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    0xa40a => {             # Sharpness
        Writable => 'int16u',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
#    0xa40b => 'undef',      # DeviceSettingDescription
    0xa40c => 'int16u',     # SubjectDistanceRange
    0xa420 => 'string',     # ImageUniqueID
#
# DNG stuff (back in IFD0)
#
    0xc612 => {             # DNGVersion
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 4,
    },
    0xc612 => {             # DNGBackwardVersion
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
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0xc61f => {             # DefaultCropOrigin
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0xc620 => {             # DefaultCropSize
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0xc62a => {             # BaselineExposure
        Writable => 'rational32s',
        WriteGroup => 'IFD0',
    },
    0xc62b => {             # BaselineNoise
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0xc62c => {             # BaselineSharpness
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0xc62d => {             # BayerGreenSplit
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0xc62e => {             # LinearResponseLimit
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0xc62f => {             # DNGCameraSerialNumber
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc630 => {             # DNGLensInfo
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
        Count => 4,
        PrintConvInv => '$_=$val;s/(-|mm f)/ /g;$_',
    },
    0xc631 => {             # ChromaBlurRadius
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0xc632 => {             # AntiAliasStrength
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0xc633 => {             # ShadowScale
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    0xc635 => {             # MakerNoteSafety
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0xc65c => {             # BestQualityScale
        Writable => 'rational32u',
        WriteGroup => 'IFD0',
    },
    # tags produced by Photoshop Camera RAW
    # (avoid creating these tags unless there is no other option)
    0xfde8 => {
        Name => 'OwnerName',
        Avoid => 1,
        Writable => 'string',
        ValueConv => '$val=~s/.*: //;$val',
        ValueConvInv => q{"Owner's Name: $val"},
        Notes => q{tags 0xfde8-0xfe58 are generated by Photoshop Camera RAW --
                   some names are the same as other EXIF tags, but ExifTool will
                   avoid writing these unless they already exist in the file},
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
InsertWritableProperties('Image::ExifTool::Exif::Main', \%writeTable, 'ExifIFD', \&CheckExif);


#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and possibly changes value) on success
sub CheckExif($$$)
{
    my ($exifTool, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format} || $$tagInfo{Writable};
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
#         2) [optional] default WriteGroup, 3) Optional CHECK_PROC reference
sub InsertWritableProperties($$;$$)
{
    my ($tableName, $writeTablePtr, $writeGroup, $checkProc) = @_;
    my $tag;
    my $tagTablePtr = GetTagTable($tableName);
    $checkProc and $tagTablePtr->{CHECK_PROC} = $checkProc;
    foreach $tag (keys %$writeTablePtr) {
        my $writeInfo = $$writeTablePtr{$tag};
        my @infoList = GetTagInfoList($tagTablePtr, $tag);
        if (@infoList) {
            my $tagInfo;
            foreach $tagInfo (@infoList) {
                $writeGroup and $$tagInfo{WriteGroup} = $writeGroup;
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
            if ($writeGroup and not $$writeInfo{WriteGroup}) {
                $$writeInfo{WriteGroup} = $writeGroup;
            }
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $writeInfo);
        }
    }
}

#------------------------------------------------------------------------------
# build fixup table for specified directory
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) dirInfo reference
# Returns: fixup object reference, or undef if not fixup needed.
#          -> Fixup start is relative to the start of the data.
# Notes: Sets a Warning if any problems were encountered
sub BuildFixup($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart} || 0;
    my $dataLen = $dirInfo->{DataLen} || length($$dataPt);
    my $dataPos = $dirInfo->{DataPos};
    my $fixup = new Image::ExifTool::Fixup;

    my $numEntries = Get16u($dataPt, $dirStart);
    my $dirEnd = $dirStart + 2 + 12 * $numEntries;
    if ($dirEnd > $dataLen) {
        $exifTool->Warn("Directory longer than data");
        return undef;
    }
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        my $format = Get16u($dataPt, $entry+2);
        my $count = Get32u($dataPt, $entry+4);
        my $valuePtr = $entry + 8;
        if ($format < 1 or $format > 13) {
            # allow zero padding (some manufacturers do this) - grrrr
            last unless $format or $count or not $index;
            $exifTool->Warn("Bad format ($format) for IFD entry");
            return undef;
        }
        my $size = $count * $formatSize[$format];
        if ($size > 4) {
            # save pointer to this offset
            $fixup->AddFixup($valuePtr);
            $valuePtr = Get32u($dataPt, $valuePtr) - $dataPos;
        }
        # recurse into EXIF-type subdirectories
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
        next unless $tagInfo and $$tagInfo{SubDirectory};
        my $subdir = $$tagInfo{SubDirectory};
        next unless $$subdir{TagTable};
        my $subTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
        next if $$subTable{PROCESS_PROC} and $$subTable{PROCESS_PROC} ne \&ProcessExif;
        my %subdirInfo = %$dirInfo;
        my $subdirDataPos = $dataPos;
        my $subdirStart = $valuePtr;
        if (defined $$subdir{Start}) {
            if ($valuePtr < 0 or $valuePtr + $size > $dataLen) {
                $exifTool->Warn('Error building fixup (pointer outside data)');
                next;
            }
            my $val = ReadValue($dataPt,$valuePtr,$formatName[$format],$count,$size);
            # set local $valuePtr relative to file $base for eval
            my $valuePtr = $subdirStart + $subdirDataPos;
            #### eval Start ($valuePtr, $val)
            $subdirStart = eval($$subdir{Start});
            # convert back to relative to $subdirDataPt
            $subdirStart -= $subdirDataPos;
        }
        $subdirInfo{DirStart} = $subdirStart;
        my $subFixup = BuildFixup($exifTool, $subTable, \%subdirInfo);
        $fixup->AddFixup($subFixup);
    }
    return $fixup;
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
    my $dirStart = $dirInfo->{DirStart};
    my $dirLen = $dirInfo->{DirLen};
    my $dataPt = $dirInfo->{DataPt};
    my $dataPos = $dirInfo->{DataPos} || 0;
    my $rtnValue;
    my %subdirInfo = %$dirInfo;

    my $saveOrder = GetByteOrder();
    my $loc = Image::ExifTool::MakerNotes::LocateIFD(\%subdirInfo);
    if (defined $loc) {
        my $makerFixup = $subdirInfo{Fixup} = new Image::ExifTool::Fixup;
        # create new exiftool object to rewrite the directory without changing it
        my $newTool = new Image::ExifTool;
        # might need these two member variables...
        $newTool->{CameraMake} = $exifTool->{CameraMake};
        $newTool->{CameraModel} = $exifTool->{CameraModel};
        # rewrite maker notes
        $rtnValue = $newTool->WriteTagTable($tagTablePtr, \%subdirInfo);
        if (defined $rtnValue and length $rtnValue) {
            # add makernote header
            $loc and $rtnValue = substr($$dataPt, $dirStart, $loc) . $rtnValue;
            # adjust fixup for shift in start position
            $makerFixup->{Start} += $loc;
            # shift offsets according to original position of maker notes,
            # and relative to the makernotes Base
            $makerFixup->{Shift} += $dataPos + $dirStart +
                                    $dirInfo->{Base} - $subdirInfo{Base};
            # fix up pointers to the specified offset
            $makerFixup->ApplyFixup(\$rtnValue);
        }
    }
    SetByteOrder($saveOrder);

    return $rtnValue;
}

#------------------------------------------------------------------------------
# Write EXIF directory
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) source dirInfo reference
# Returns: Exif data block (may be empty if no Exif data) or undef on error
# Notes: Increments ExifTool CHANGED flag for each tag changed
# Returns IFD data in the following order:
#   1. IFD0 directory followed by its data
#   2. SubIFD directory followed by its data, thumbnail and image
#   3. GlobalParameters, EXIF, GPS, Interop IFD's each with their data
#   4. IFD1,IFD2,... directories each followed by their data
#   5. Thumbnail and/or image data for each IFD, with IFD0 image last
sub WriteExif($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dataPt = $dirInfo->{DataPt};
    unless ($dataPt) {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
    my $dirStart = $dirInfo->{DirStart} || 0;
    my $dataLen = $dirInfo->{DataLen} || length($$dataPt);
    my $dirLen = $dirInfo->{DirLen} || ($dataLen - $dirStart);
    my $base = $dirInfo->{Base} || 0;
    my $dataPos = $dirInfo->{DataPos} || 0;
    my $raf = $dirInfo->{RAF};
    my $dirName = $dirInfo->{DirName} || 'unknown';
    my $fixup = $dirInfo->{Fixup} || new Image::ExifTool::Fixup;
    my $verbose = $exifTool->Options('Verbose');
    my (@offsetInfo, %delete);
    my $newData = '';   # initialize buffer to receive new directory data
    my ($nextIfdPos, %offsetData, $inMakerNotes);
    my $deleteAll = 0;

    $inMakerNotes = 1 if $dirName eq 'MakerNotes';
    my $ifd;
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# loop through each IFD
#
    for ($ifd=0; ; ++$ifd) {  # loop through multiple IFD's

        # loop through new values and accumulate all information for this IFD
        my (%set, $tagInfo);
        my $tableGroup = $tagTablePtr->{GROUPS}->{0};
        foreach $tagInfo ($exifTool->GetNewTagInfoList($tagTablePtr)) {
            my $tagID = $$tagInfo{TagID};
            # evaluate conditional lists now if necessary
            if (ref $tagTablePtr->{$tagID} eq 'ARRAY') {
                my $curInfo = $exifTool->GetTagInfo($tagTablePtr, $tagID);
                # don't set this tag unless valid for the current condition
                next unless $tagInfo eq $curInfo;
            }
            if ($$tagInfo{WriteCondition}) {
                my $self = $exifTool;   # set $self to be used in eval
                #### eval WriteCondition ($self)
                unless (eval $$tagInfo{WriteCondition}) {
                    $@ and warn $@;
                    next;
                }
            }
            if ($tableGroup eq 'EXIF') {
                my $newValueHash = $exifTool->GetNewValueHash($tagInfo, $dirName);
                unless ($newValueHash) {
                    # delete stuff from the wrong directory if setting somewhere else
                    my $wrongDir = $crossDelete{$dirName} or next;
                    $newValueHash = $exifTool->GetNewValueHash($tagInfo, $wrongDir);
                    next unless Image::ExifTool::IsOverwriting($newValueHash) > 0;
                    # remove this tag if found in this IFD
                    $delete{$tagID} = 1;
                }
            }
            $set{$tagID} = $tagInfo;
        }
        # save pointer to start of this IFD within the newData
        my $newStart = length($newData);
        my @subdirs;    # list of subdirectory data and tag table pointers
        # read IFD from file if necessary
        if ($raf and ($dirStart < 0 or $dirStart > $dataLen-2)) {
            # read the count of entries in this IFD
            my $offset = $dirStart + $dataPos;
            my ($buff, $buf2);
            unless ($raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2) {
                $exifTool->Error("Bad IFD or truncated file in $dirName");
                return undef;
            }
            my $len = 12 * Get16u(\$buff,0);
            # also read next IFD pointer if reading multiple IFD's
            $len += 4 if $dirInfo->{Multi};
            unless ($raf->Read($buf2, $len) == $len) {
                $exifTool->Error("Error reading $dirName");
                return undef;
            }
            $buff .= $buf2;
            # make copy of dirInfo since we're going to modify it
            my %newDirInfo = %$dirInfo;
            $dirInfo = \%newDirInfo;
            # update directory parameters for the newly loaded IFD
            $dataPt = $dirInfo->{DataPt} = \$buff;
            $dirStart = $dirInfo->{DirStart} = 0;
            $dataPos = $dirInfo->{DataPos} = $offset;
            $dataLen = $dirInfo->{DataLen} = $len + 2;
            $dirLen = $dirInfo->{DirLen} = $dataLen;
        }
        my ($len, $numEntries);
        if ($dirStart + 4 < $dataLen) {
            $numEntries = Get16u($dataPt, $dirStart);
            $len = 2 + 12 * $numEntries;
        } else {
            $numEntries = $len = 0;
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
        if ($dirStart + $len > $dataLen) {
            $exifTool->Error("Truncated $dirName directory");
            return undef;
        }
        my $dirBuff = '';   # buffer for directory data
        my $valBuff = '';   # buffer for value data
        my @valFixups;      # list of fixups for offsets in valBuff
        # fixup for offsets in dirBuff
        my $dirFixup = new Image::ExifTool::Fixup;
        my $index = 0;
        my $lastTagID = -1;
        my ($oldInfo, $oldFormat, $oldFormName, $oldCount, $oldSize, $oldValue);
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
                    my $entry = $dirStart + 2 + 12 * $index;
                    $oldID = Get16u($dataPt, $entry);
                    $oldFormat = Get16u($dataPt, $entry+2);
                    $oldCount = Get32u($dataPt, $entry+4);
                    if ($oldFormat < 1 or $oldFormat > 13) {
                        # don't write out null directory entry
                        unless ($oldFormat or $oldCount or not $index) {
                            ++$index;
                            $newID = $oldID;    # pretend we wrote this
                            next;
                        }
                        $exifTool->Error("Bad format ($oldFormat) for $dirName entry $index");
                        return undef;
                    }
                    $oldFormName = $formatName[$oldFormat];
                    $valueDataPt = $dataPt;
                    $valueDataPos = $dataPos;
                    $valueDataLen = $dataLen;
                    $valuePtr = $entry + 8;
                    $oldSize = $oldCount * $formatSize[$oldFormat];
                    my $readFromFile;
                    if ($oldSize > 4) {
                        $valuePtr = Get32u($dataPt, $valuePtr) - $dataPos;
                        # get value by seeking in file if we are allowed
                        if ($valuePtr < 0 or $valuePtr+$oldSize > $dataLen) {
                            if ($raf) {
                                if ($raf->Seek($base + $valuePtr + $dataPos, 0) and
                                    $raf->Read($oldValue, $oldSize) == $oldSize)
                                {
                                    $valueDataPt = \$oldValue;
                                    $valueDataPos = $valuePtr + $dataPos;
                                    $valueDataLen = $oldSize;
                                    $valuePtr = 0;
                                    $readFromFile = 1;
                                } else {
                                    $exifTool->Error("Error reading value for $dirName entry $index");
                                    return undef;
                                }
                            } else {
                                $exifTool->Error("Bad EXIF directory pointer for $dirName entry $index");
                                return undef;
                            }
                        }
                        # save maker note header
                        if ($oldID == 0x927c and $tagTablePtr eq \%Image::ExifTool::Exif::Main) {
                            my $hdrLen = $oldSize < 48 ? $oldSize : 48;
                            $exifTool->{MAKER_NOTE_HEADER} = substr($$valueDataPt, $valuePtr, $hdrLen);
                        }
                    }
                    # read value if we haven't already
                    $oldValue = substr($$valueDataPt, $valuePtr, $oldSize) unless $readFromFile;
                    # get tagInfo if available
                    $oldInfo = $$tagTablePtr{$oldID};
                    if ($oldInfo and ref $oldInfo ne 'HASH') {
                        $oldInfo = $exifTool->GetTagInfo($tagTablePtr, $oldID);
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
            my $ifdFormName;
            my $newCount = $oldCount;
            my $newValue;
            my $newValuePt = $isNew >= 0 ? \$newValue : \$oldValue;

            if ($isNew >= 0) {
                # add, edit or delete this tag
                shift @newTags; # remove from list
                if ($set{$newID}) {
#
# set the new tag value (or 'next' if deleting tag)
#
                    $newInfo = $set{$newID};
                    $newCount = $$newInfo{Count};
                    my $val;
                    my $newValueHash = $exifTool->GetNewValueHash($newInfo, $dirName);
                    my ($isOverwriting, $newVal);
                    if ($isNew > 0) {
                        # don't create new entry unless requested
                        if ($newValueHash) {
                            next unless Image::ExifTool::IsCreating($newValueHash);
                            $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash);
                        } else {
                            $newVal = $$mandatory{$newID};  # get value for mandatory tag
                            $isOverwriting = 1;
                        }
                        # convert using new format
                        $newFormName = $$newInfo{Format};
                        if ($newFormName) {
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
                    } elsif ($newValueHash) {
                        # write in existing format
                        $val = ReadValue(\$oldValue, 0, $oldFormName, $oldCount, $oldSize);
                        if ($$newInfo{Format}) {
                            # override existing format if necessary
                            $ifdFormName = $$newInfo{Writable};
                            $ifdFormName = $oldFormName unless $ifdFormName and $ifdFormName ne '1';
                            $newFormName = $$newInfo{Format};
                            $newFormat = $formatNumber{$newFormName};
                        }
                        if ($inMakerNotes and $oldFormName ne 'string' and
                            $oldFormName ne 'undef')
                        {
                            # keep same size in maker notes unless string or binary
                            $newCount = $oldCount * $formatSize[$oldFormat] / $formatSize[$newFormat];
                        }
                        $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash, $val);
                    }
                    if ($isOverwriting) {
                        $newVal = Image::ExifTool::GetNewValues($newValueHash) unless defined $newVal;
                        # value undefined if deleting this tag
                        if ($delete{$newID} or not defined $newVal) {
                            unless ($isNew) {
                                ++$exifTool->{CHANGED};
                                $val = $exifTool->Printable($val);
                                $verbose > 1 and print "    - $$newInfo{Name} = '$val'\n";
                            }
                            next;
                        }
                        # convert to binary format
                        $newValue = WriteValue($newVal, $newFormName, $newCount);
                        unless (defined $newValue) {
                            $exifTool->Warn("Error writing $dirName:$$newInfo{Name}");
                            next if $isNew > 0;
                            $isNew = -1;        # rewrite existing tag
                        }
                        if ($isNew >= 0) {
                            $newCount = length($newValue) / $formatSize[$newFormat];
                            ++$exifTool->{CHANGED};
                            if ($verbose > 1) {
                                $val = $exifTool->Printable($val);
                                $newVal = $exifTool->Printable($newVal);
                                print "    - $$newInfo{Name} = '$val'\n" unless $isNew;
                                print "    + $$newInfo{Name} = '$newVal'\n";
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
                    next if $$newInfo{MakerNotes};
                    my $subTable;
                    if ($newInfo->{SubDirectory}->{TagTable}) {
                        $subTable = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                    } else {
                        $subTable = $tagTablePtr;
                    }
                    # create empty source directory
                    my %sourceDir = (
                        Parent => $dirInfo->{DirName},
                        Fixup => new Image::ExifTool::Fixup,
                    );
                    $sourceDir{DirName} = $newInfo->{Groups}->{1} if $$newInfo{SubIFD};
                    $newValue = $exifTool->WriteTagTable($subTable, \%sourceDir);
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
                        $newFormName = 'undef';
                        $newFormat = $formatNumber{$newFormName};
                        push @valFixups, $sourceDir{Fixup};
                    }
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
                            if ($exifTool->{FILE_TYPE} eq 'JPEG' and length($offsetData{$dataTag}) > 60000) {
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
                    my $saveOrder = GetByteOrder();
                    if ($isNew >= 0 and $set{$newID}) {
                        # we are writing a whole new maker note block
                        my $oldPos = $exifTool->{MAKER_NOTE_POS};
                        if (defined $oldPos) {
                            my %subdirInfo = (
                                DataPt => \$newValue,
                                DirStart => 0,
                                DataLen => length($newValue),
                                DirLen => length($newValue),
                                DataPos => $oldPos,
                                Base => 0,
                            );
                            my $loc = Image::ExifTool::MakerNotes::LocateIFD(\%subdirInfo);
                            # don't need to shift IFD pointers if this is a TIFF-type Makernote
                            # (in which case the Relative will be set)
                            if (defined $loc and not $subdirInfo{Relative}) {
                                $subdirInfo{DirStart} = $loc;
                                $subdirInfo{DirLen} -= $loc;
                                my $subTable;
                                $subTable = $newInfo->{SubDirectory}->{TagTable} if $$newInfo{SubDirectory};
                                $subTable = 'Image::ExifTool::Exif' unless $subTable;
                                $subTable = Image::ExifTool::GetTagTable($subTable);
                                my $makerFixup = BuildFixup($exifTool, $subTable, \%subdirInfo);
                                if ($makerFixup) {
                                    my $valLen = length($valBuff);
                                    $makerFixup->{Start} += $valLen;
                                    $makerFixup->{Shift} -= $oldPos;
                                    push @valFixups, $makerFixup;
                                }
                            }
                        } else {
                            $exifTool->Warn("Can't shift new MakerNotes offsets (position not known)");
                        }
                    } else {
                        # update maker notes if possible
                        my %subdirInfo = (
                            Base => $base,
                            DataPt => $valueDataPt,
                            DirStart => $valuePtr,
                            DataPos => $valueDataPos,
                            DataLen => $valueDataLen,
                            DirLen => $oldSize,
                            DirName => 'MakerNotes',
                            RAF => $raf,
                        );
                        # get the proper tag table for these maker notes
                        my $subInfo = $exifTool->GetTagInfo($tagTablePtr, $oldID);
                        my $subTable;
                        if ($subInfo and $subInfo->{SubDirectory}) {
                            $subTable = $subInfo->{SubDirectory}->{TagTable};
                            $subTable and $subTable = Image::ExifTool::GetTagTable($subTable);
                        } else {
                            $exifTool->Warn('Internal problem getting maker notes tag table');
                        }
                        $subTable or $subTable = $tagTablePtr;
                        my $subdir;
                        # look for IFD-style maker notes
                        my $loc = Image::ExifTool::MakerNotes::LocateIFD(\%subdirInfo);
                        if (defined $loc) {
                            # we need fixup data for this subdirectory
                            $subdirInfo{Fixup} = new Image::ExifTool::Fixup;
                            # rewrite maker notes
                            $subdir = $exifTool->WriteTagTable($subTable, \%subdirInfo);
                        } elsif ($$subTable{PROCESS_PROC} and
                                 $$subTable{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData)
                        {
                            my $sub = $subInfo->{SubDirectory};
                            if (defined $$sub{Start}) {
                                #### eval Start ($valuePtr)
                                my $start = eval($$sub{Start});
                                $loc = $start - $valuePtr;
                                $subdirInfo{DirStart} = $start;
                                $subdirInfo{DirLen} -= $loc;
                            } else {
                                $loc = 0;
                            }
                            # rewrite maker notes
                            $subdir = $exifTool->WriteTagTable($subTable, \%subdirInfo);
                        } else {
                            $exifTool->Warn('Maker notes could not be parsed');
                        }
                        if (defined $subdir and length $subdir) {
                            my $valLen = length($valBuff);
                            # restore existing header and substitute the new
                            # maker notes for the old value
                            $newValue = substr($oldValue, 0, $loc) . $subdir;
                            my $makerFixup = $subdirInfo{Fixup};
                            if (not $subdirInfo{Relative}) {
                                $makerFixup->{Start} += $valLen + $loc;
                                $makerFixup->{Shift} += $base - $subdirInfo{Base};
                                push @valFixups, $makerFixup;
                            } elsif ($loc) {
                                # apply a one-time fixup to $loc since offsets are relative
                                $makerFixup->{Start} += $loc;
                                # shift all offsets to be relative to new base
                                $makerFixup->{Shift} += $valueDataPos + $valuePtr +
                                                        $base - $subdirInfo{Base};
                                $makerFixup->ApplyFixup(\$newValue);
                            }
                            $newValuePt = \$newValue;   # write new value
                        }
                    }
                    SetByteOrder($saveOrder);

                } elsif ($$newInfo{SubDirectory} && $isNew <= 0) {
                
                    if ($$newInfo{SubIFD}) {
#
# rewrite existing sub IFD's
#
                        my $subdirName = $newInfo->{Groups}->{1};
                        # must handle sub-IFD's specially since the values
                        # are actually offsets to subdirectories
                        unless ($oldCount) {   # can't have zero count
                            $exifTool->Error("$dirName entry $index has zero count");
                            return undef;
                        }
                        my $i;
                        $newValue = '';    # reset value because we regenerate it below
                        for ($i=0; $i<$oldCount; ++$i) {
                            my $pt = Image::ExifTool::ReadValue($valueDataPt,
                                            $valuePtr + $i * $formatSize[$oldFormat],
                                            $formatName[$oldFormat], 1, $oldSize);
                            my $subdirStart = $pt - $dataPos;
                            my %subdirInfo = (
                                Base => $base,
                                DataPt => $dataPt,
                                DirStart => $subdirStart,
                                DataPos => $dataPos,
                                DataLen => $dataLen,
                                DirName => $subdirName,
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
                                    $exifTool->Error("Can't read $subdirName data");
                                    return undef;
                                }
                                $buff .= $buf2;
                                # change subdirectory information to data we just read
                                $subdirInfo{DataPt} = \$buff;
                                $subdirInfo{DirStart} = 0;
                                $subdirInfo{DataPos} = $pt;
                                $subdirInfo{DataLen} = $subSize + 2;
                            }
                            my $subTable = $tagTablePtr;
                            if ($newInfo->{SubDirectory}->{TagTable}) {
                                $subTable = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                            }
                            my $subdir = $exifTool->WriteTagTable($subTable, \%subdirInfo);
                            return undef unless defined $subdir;
                            next unless length($subdir);
                            # temporarily set value to subdirectory index
                            # (will set to actual offset later when we know what it is)
                            $newValue .= Set32u(0xfeedf00d);
                            my ($offset, $where);
                            if ($oldCount > 1) {
                                $offset = length($valBuff) + $i * 4;
                                $where = 'valBuff';
                            } else {
                                $offset = length($dirBuff) + 8;
                                $where = 'dirBuff';
                            }
                            # add to list of subdirectories we will add later
                            push @subdirs, {
                                DataPt => \$subdir,
                                Table => $subTable,
                                Fixup => $subdirInfo{Fixup},
                                Offset => $offset,
                                Where => $where,
                            };
                        }
                        next unless length $newValue;
                        # set new format to int32u
                        $newFormName = 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                        $newValuePt = \$newValue;
    
                    } elsif ((not defined $newInfo->{SubDirectory}->{Start} or
                             $newInfo->{SubDirectory}->{Start} =~ /\$valuePtr/) and
                             $newInfo->{SubDirectory}->{TagTable})
                    {
#
# rewrite other existing subdirectories ('$valuePtr' type only)
#
                        my $subdirStart = $valuePtr;
                        if ($newInfo->{SubDirectory}->{Start}) {
                            #### eval Start ($valuePtr)
                            $subdirStart = eval($newInfo->{SubDirectory}->{Start});
                        }
                        my $subFixup = new Image::ExifTool::Fixup;
                        my %subdirInfo = (
                            Base => $base,
                            DataPt => $valueDataPt,
                            DirStart => $subdirStart,
                            DataPos => $valueDataPos,
                            DataLen => $valueDataLen,
                            DirLen => $oldSize,
                            RAF => $raf,
                            Parent => $dirInfo->{DirName},
                            Fixup => $subFixup,
                        );
                        my $subTable = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                        if ($subTable) {
                            $subTable = GetTagTable($subTable);
                        } else {
                            $subTable = $tagTablePtr;
                        }
                        $newValue = $exifTool->WriteTagTable($subTable, \%subdirInfo);
                        if (defined $newValue) {
                            my $hdrLen = $subdirStart - $valuePtr;
                            if ($hdrLen) {
                                $newValue = substr($$valueDataPt, $valuePtr, $hdrLen) . $newValue;
                                $subFixup->{Start} += $hdrLen;
                            }
                            $newValuePt = \$newValue;
                        }
                        unless (defined $$newValuePt) {
                            $exifTool->Error("Internal error writing $$dirInfo{DirName}");
                            return undef;
                        }
                        next unless length $$newValuePt;
                        if ($subFixup->{Pointers} and $subdirInfo{Base} == $base) {
                            $subFixup->{Start} += length $valBuff;
                            push @valFixups, $subFixup;
                        }
                    }

                } elsif ($$newInfo{OffsetPair}) {
#
# keep track of offsets
#
                    my $offsetInfo = $offsetInfo[$ifd];
                    # only support int32 pointers (for now)
                    if ($formatSize[$newFormat] != 4 and $$newInfo{IsOffset}) {
                        die "Internal error (Offset not int32)" if $isNew > 0;
                        die "Wrong count!" if $newCount != $oldCount;
                        # change to int32
                        my $val = ReadValue(\$oldValue, 0, $oldFormName, $oldCount, $oldSize);
                        $newFormName = 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                        $newValue = WriteValue($val, $newFormName, $newCount);
                    }
                    $offsetInfo or $offsetInfo = $offsetInfo[$ifd] = { };
                    # save location of valuePtr in new directory
                    # (notice we add 10 instead of 8 for valuePtr because
                    # we will put a 2-byte count at start of directory later)
                    my $ptr = $newStart + length($dirBuff) + 10;
                    $newCount or $newCount = 1; # make sure count is set for offsetInfo
                    # save value pointer and value count for each tag
                    $offsetInfo->{$newID} = [$newInfo, $ptr, $newCount, $newFormat];

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
                $offsetVal = Set32u(length $valBuff);
                $valBuff .= $$newValuePt;       # add value data to buffer
                # must save a fixup pointer for every pointer in the directory
                $dirFixup->AddFixup(length($dirBuff) + 8);
            } else {
                $offsetVal = $$newValuePt;      # save value in offset if 4 bytes or less
                # must pad value with zeros if less than 4 bytes
                $newSize < 4 and $offsetVal .= "\0" x (4 - $newSize);
            }
            # write new directory entry
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
            $verbose > 1 and print "    - $allMandatory mandatory tag(s)\n";
        }
        if ($ifd and not $newEntries) {
            $verbose and print "  Deleting IFD1\n";
            last;   # don't write IFD1 if empty
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
            $fixup->AddFixup($nextIfdPos);  # add fixup for this offset in newData
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
        last unless $dirInfo->{Multi};  # stop unless scanning for multiple IFD's
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
            $verbose and print "  Creating IFD1\n";
            my $ifd1 = '\0' x 2;  # empty IFD1 data (zero entry count)
            $dataPt = \$ifd1;
            $dirStart = 0;
            $dirLen = $dataLen = 2;
        }
        # increment IFD0 name to IFD1, IFD2,...
        if ($dirName =~ /^IFD(\d+)$/) {
            $dirName = 'IFD' . ($1+1);
            $exifTool->{DIR_NAME} = $dirName;
            $offset and $verbose and print "  Rewriting $dirName\n";
        }
    }
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # do our fixups now so we can more easily calculate offsets below
    $fixup->ApplyFixup(\$newData);
#
# copy over image data for IFD's, starting with the last IFD first
#
    if (@offsetInfo) {
        for ($ifd=$#offsetInfo; $ifd>=0; --$ifd) {
            my $offsetInfo = $offsetInfo[$ifd];
            next unless $offsetInfo;
            my $tagID;
            # loop through all tags in reverse order so we save thumbnail
            # data before main image data if both exist in the same IFD
            foreach $tagID (reverse sort keys %$offsetInfo) {
                my ($tagInfo, $offsets, $count) = @{$offsetInfo->{$tagID}};
                next unless $$tagInfo{IsOffset}; # handle byte counts with offsets
                my ($cntInfo, $byteCounts, $count2, $format) = @{$offsetInfo->{$$tagInfo{OffsetPair}}};
                # must be the same number of offset and byte count values
                unless ($count == $count2) {
                    $exifTool->Error("Offset/byteCounts disagree on count for $$tagInfo{Name}");
                    return undef;
                }
                my $formatStr = $formatName[$format];
                # follow pointer to value data if necessary
                if ($count > 1) {
                    $offsets = Get32u(\$newData, $offsets);
                }
                if ($count * $formatSize[$format] > 4) {
                    $byteCounts = Get32u(\$newData, $byteCounts);
                }
                # transfer the data referenced by all offsets of this tag
                my $n;
                for ($n=0; $n<$count; ++$n) {
                    my $offset = Get32u(\$newData, $offsets + $n*4) - $dataPos;
                    my $byteCountPos = $byteCounts + $n * $formatSize[$format];
                    my $size = ReadValue(\$newData, $byteCountPos, $formatStr, 1, 4);
                    unless (defined $size) {
                        $exifTool->Error("Error reading $$tagInfo{Name} values");
                        return undef;
                    }
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
                        $buff = $offsetData{$dataTag};
                        if ($formatSize[$format] != 4) {
                            $exifTool->Error("$$cntInfo{Name} is not int32");
                            return undef;
                        }
                        # set the data size
                        $size = length($buff);
                        Set32u($size, \$newData, $byteCounts + $n*4);
                    } elsif ($offset < 0 or $offset+$size > $dataLen) {
                        # read data from file
                        unless ($raf and $raf->Seek($offset+$base+$dataPos,0) and
                                $raf->Read($buff,$size) == $size)
                        {
                            my $dataName = $$tagInfo{DataTag} || $$tagInfo{Name};
                            my $str = "Error reading $dataName data in $dirName";
                            if ($$tagInfo{Name} eq 'PreviewImageStart') {
                                $exifTool->Warn($str);
                                $buff = '<invalid preview image>';
                            } else {
                                $exifTool->Error($str);
                                return undef;
                            }
                        }
                    } else {
                        # take data from old dir data buffer
                        $buff = substr($$dataPt, $offset, $size);
                    }
                    # update offset accordingly and add to end of new data
                    Set32u(length($newData), \$newData, $offsets + $n*4);
                    # add a pointer to fix up this offset value
                    $fixup->AddFixup($offsets + $n*4);
                    $buff .= "\0" if $size & 0x01;  # must be even size
                    # add this strip to the data
                    $newData .= $buff;
                }
            }
        }
    }
    # apply final shift to new data position if this is the top level IFD
    if (not $dirInfo->{Fixup} and $dirInfo->{NewDataPos}) {
        $fixup->{Shift} += $dirInfo->{NewDataPos};
        $fixup->ApplyFixup(\$newData);
        # delete both IFD0 and IFD1 if only mandatory tags remain
        $newData = '' if defined $newData and $deleteAll;
    }
    # return empty string if no entries in directory
    # (could be up to 10 bytes and still be empty)
    $newData = '' if defined $newData and length($newData) < 12;

    return $newData;    # return our directory data
}

1; # end

__END__

=head1 NAME

Image::ExifTool::WriteExif.pl - Routines for writing EXIF meta information

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::Exif.

=head1 DESCRIPTION

This file contains routines to write EXIF metadata.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
