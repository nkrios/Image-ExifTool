#------------------------------------------------------------------------------
# File:         XMP.pm
#
# Description:  Definitions for XMP tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               10/28/2004 - P. Harvey Major overhaul to conform with XMP spec
#               02/27/2005 - P. Harvey Also read UTF-16 and UTF-32 XMP
#
# References:   1) http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf
#               2) http://www.w3.org/TR/rdf-syntax-grammar/  (20040210)
#               3) http://www.portfoliofaq.com/pfaq/v7mappings.htm
#               4) http://www.iptc.org/IPTC4XMP/
#
# Notes:      - I am handling property qualifiers as if they were separate
#               properties (with no associated namespace).
#
#             - Currently, there is no special treatment of the following
#               properties which could potentially effect the extracted
#               information: xml:base, xml:lang, rdf:parseType (note that
#               parseType Literal isn't allowed by the XMP spec).
#
#             - The family 2 group names will be set to 'Unknown' for any XMP
#               tags not found in the XMP or Exif tag tables.
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use strict;
use vars qw($VERSION $AUTOLOAD @ISA @EXPORT_OK %ignoreNamespace %xlatNamespace);
use Image::ExifTool::Exif;
require Exporter;

$VERSION = '1.31';
@ISA = qw(Exporter);
@EXPORT_OK = qw(EscapeHTML UnescapeHTML);

sub ProcessXMP($$$);
sub WriteXMP($$$);
sub ParseXMPElement($$$;$$);
sub DecodeBase64($);

# XMP namespaces which we don't want to contribute to generated EXIF tag names
%ignoreNamespace = ( 'x'=>1, 'rdf'=>1, 'xmlns'=>1, 'xml'=>1);

# translate XMP namespaces for use in family 1 group names
%xlatNamespace = (
    # shorten ugly IPTC Core namespace prefix
    'Iptc4xmpCore' => 'iptcCore',
    # also translate older 'xap...' prefixes to 'xmp...'
    'xap'          => 'xmp',
    'xapBJ'        => 'xmpBJ',
    'xapMM'        => 'xmpMM',
    'xapRights'    => 'xmpRights',
);

# main XMP tag table
%Image::ExifTool::XMP::Main = (
    GROUPS => { 2 => 'Unknown' },
    PROCESS_PROC => \&ProcessXMP,
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
#
# Define tags for necessary schema properties
# (only need to define tag if we want to change the default group
#  or any other tag information, or if we want the tag name to show
#  up in the complete list of tags.  Also, we give the family 1 group
#  name for one of the properties so it will show up in the group list.
#  Family 1 groups are generated from the property namespace.)
#
# Writable - only need to define this for writable tags if not plain text
#            (boolean, integer, rational, date or lang-alt)
# List - XMP list type (Bag, Seq or Alt)
#
# - Dublin Core schema properties (dc)
#
    Contributor     => { Groups => { 1 => 'XMP-dc', 2 => 'Author' }, List => 'Bag' },
    Coverage        => { },
    Creator         => { Groups => { 2 => 'Author' }, List => 'Seq' },
    Date            => {
        Groups => { 2 => 'Time'   },
        Writable => 'date',
        List => 'Seq',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Description     => { Groups => { 2 => 'Image'  }, Writable => 'lang-alt' },
    Format          => { Groups => { 2 => 'Image'  } },
    Identifier      => [
        { Groups => { 2 => 'Image'  }, Namespace => 'dc' },
        { List => 'Bag' , Namespace => 'xmp' },
    ],
    Language        => { List => 'Bag' },
    Publisher       => { Groups => { 2 => 'Author' }, List => 'Bag' },
    Relation        => { List => 'Bag' },
    Rights          => { Groups => { 2 => 'Author' }, Writable => 'lang-alt' },
    Source          => [
        { Groups => { 2 => 'Author' }, Namespace => 'dc' },
        { Groups => { 2 => 'Author' }, Namespace => 'photoshop' },
    ],
    Subject         => { Groups => { 2 => 'Image'  }, List => 'Bag' },
    Title           => { Groups => { 2 => 'Image'  }, Writable => 'lang-alt' },
    Type            => { Groups => { 2 => 'Image'  }, List => 'Bag' },
#
# - XMP Basic schema properties (xmp (was xap))
#
    Advisory        => { Groups => { 1 => 'XMP-xmp' }, List => 'Bag' },
    BaseURL         => { },
    CreateDate      => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CreatorTool     => { },
    # Identifier (covered by dc)
    MetadataDate    => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ModifyDate => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Nickname        => { },
    # Thumbnails - structure (Height,Width,Format,Image)
    Thumbnails      => {
        Writable => 0,
        List => 'Alt',
    },
    ThumbnailsHeight    => { Groups => { 2 => 'Image'  } },
    ThumbnailsWidth     => { Groups => { 2 => 'Image'  } },
    ThumbnailsFormat    => { Groups => { 2 => 'Image'  } },
    ThumbnailsImage     => {
        # Eventually may want to handle this like a normal thumbnail image
        # -- but not yet!  (need to write EncodeBase64() routine....
        # Name => 'ThumbnailImage',
        Groups => { 2 => 'Image' },
        # translate Base64-encoded thumbnail
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
    },
#
# - XMP Rights Management schema properties (xmpRights)
#
    Certificate     => { Groups => { 1 => 'XMP-xmpRights', 2 => 'Author' } },
    Marked          => { Writable => 'boolean' },
    Owner           => { Groups => { 2 => 'Author' }, List => 'Bag' },
    UsageTerms      => { Writable => 'lang-alt' },
    WebStatement    => { Groups => { 2 => 'Author' } },
#
# - XMP Media Management schema properties (xmpMM)
#
  # DerivedFrom - structure (ResourceRef=InstanceID,DocumentID,VersionID,RenditionClass
  #              RenditionParams,Manager,ManagerVariant,ManageTo,ManageUI)
    DerivedFrom     => { Groups => { 1 => 'XMP-xmpMM'}, Writable => 0 },
    DerivedFromInstanceID       => { },
    DerivedFromDocumentID       => { },
    DerivedFromVersionID        => { },
    DerivedFromRenditionClass   => { },
    DerivedFromRenditionParams  => { },
    DerivedFromManager          => { },
    DerivedFromManagerVariant   => { },
    DerivedFromManageTo         => { },
    DerivedFromManageUI         => { },
    DocumentID      => { },
  # History - structure (ResourceEvent=Action,InstanceID,Parameters,SoftwareAgent,When)
    History         => { List => 'Seq', Writable => 0 },
    HistoryAction           => { },
    HistoryInstanceID       => { },
    HistoryParameters       => { },
    HistorySoftwareAgent    => { },
    HistoryWhen             => { Groups => { 2 => 'Time'  }, Writable => 'date' },
  # ManagedFrom - structure (ResourceRef)
    ManagedFrom     => { Writable => 0 },
    ManagedFromInstanceID       => { },
    ManagedFromDocumentID       => { },
    ManagedFromVersionID        => { },
    ManagedFromRenditionClass   => { },
    ManagedFromRenditionParams  => { },
    ManagedFromManager          => { },
    ManagedFromManagerVariant   => { },
    ManagedFromManageTo         => { },
    ManagedFromManageUI         => { },
    Manager         => { Groups => { 2 => 'Author' } },
    ManageTo        => { Groups => { 2 => 'Author' } },
    ManageUI        => { },
    ManagerVariant  => { },
    RenditionClass  => { },
    RenditionParams => { },
    VersionID       => { },
  # Versions - structure (Version=Comments,Event,ModifyDate,Modifier,Version)
    Versions        => { List => 'Seq', Writable => 0 },
    VersionsComments    => { },
    VersionsEvent       => { Writable => 0 },
    VersionsEventAction         => { },
    VersionsEventInstanceID     => { },
    VersionsEventParameters     => { },
    VersionsEventSoftwareAgent  => { },
    VersionsEventWhen           => { Groups => { 2 => 'Time' }, Writable => 'date' },
    VersionsModifyDate  => { Groups => { 2 => 'Time' }, Writable => 'date' },
    VersionsModifier    => { },
    VersionsVersion     => { },
    LastURL         => { },
    RenditionOf     => { Writable => 0 },
    RenditionOfInstanceID       => { },
    RenditionOfDocumentID       => { },
    RenditionOfVersionID        => { },
    RenditionOfRenditionClass   => { },
    RenditionOfRenditionParams  => { },
    RenditionOfManager          => { },
    RenditionOfManagerVariant   => { },
    RenditionOfManageTo         => { },
    RenditionOfManageUI         => { },
    SaveID          => { Writable => 'integer' },
#
# - XMP Basic Job Ticket schema properties (xmpBJ)
#
  # JobRef - structure (Job=Name,Id,Url)
    # Note: JobRef is a List of structures.  To accomplish this, we set the XMP
    # List=>'Bag', but Writable=>0 since we don't write the top level structure
    # directly.  Then we need to set List=>1 for the members so the Writer logic
    # will allow us to add list elements.
    JobRef          => { Groups => { 1 => 'XMP-xmpBJ'}, List => 'Bag', Writable => 0 },
    JobRefName          => { List => 1 },   # we treat this like a list item
    JobRefId            => { List => 1 },
    JobRefUrl           => { List => 1 },
#
# - PDF schema properties (pdf)
#
    Author          => { Groups => { 1 => 'XMP-pdf', 2 => 'Author' } }, #PH
    ModDate => { #PH
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CreationDate => { #PH
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
  # Creator (covered by dc) #PH
  # Subject (covered by dc) #PH
  # Title (covered by dc) #PH
    Keywords        => { Groups => { 2 => 'Image' } },
    PDFVersion      => { },
    Producer        => { Groups => { 2 => 'Author' } },
#
# - Photoshop schema properties (photoshop)
#
    AuthorsPosition => { Groups => { 1 => 'XMP-photoshop', 2 => 'Author' } },
    CaptionWriter   => { Groups => { 2 => 'Author' } },
    Category        => { Groups => { 2 => 'Image'  } },
    City            => { Groups => { 2 => 'Location' } },
    Country         => { Groups => { 2 => 'Location' } },
    Credit          => { Groups => { 2 => 'Author' } },
    DateCreated => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    Headline        => { Groups => { 2 => 'Image'  } },
    Instructions    => { },
  # Source (covered by dc)
    State           => { Groups => { 2 => 'Location' } },
    # the documentation doesn't show this as a 'Bag', but that's the
    # way Photoshop7.0 writes it - PH
    SupplementalCategories  => { Groups => { 2 => 'Image' }, List => 'Bag' },
    TransmissionReference   => { Groups => { 2 => 'Image' } },
    Urgency         => { Writable => 'integer' },
#
# - Photoshop Raw Converter schema properties (crs) - not documented
#
    Version         => { Groups => { 1 => 'XMP-crs', 2 => 'Image' } },
    RawFileName     => { Groups => { 2 => 'Image' } },
    # we handle tags which are common to more than one namespace
    # by using a tag list
    WhiteBalance => [
        { Groups => { 2 => 'Image' }, Namespace => 'crs' },
        {
            Groups => { 2 => 'Camera' },
            Namespace => 'exif',
            PrintConv => {
                0 => 'Auto',
                1 => 'Manual',
            },
        },
    ],
    Exposure        => { Groups => { 2 => 'Image' } },
    Shadows         => { Groups => { 2 => 'Image' } },
    Brightness      => { Groups => { 2 => 'Image' } },
    Contrast => [
        { Groups => { 2 => 'Image' }, Namespace => 'crs' },
        {
            Groups => { 2 => 'Camera' },
            Namespace => 'exif',
            PrintConv => {
                0 => 'Normal',
                1 => 'Low',
                2 => 'High',
            },
            PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
        },
    ],
    Saturation => [
        { Groups => { 2 => 'Image' }, Namespace => 'crs' },
        {
            Groups => { 2 => 'Camera' },
            Namespace => 'exif',
            PrintConv => {
                0 => 'Normal',
                1 => 'Low',
                2 => 'High',
            },
            PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
        },
    ],
    Sharpness => [
        { Groups => { 2 => 'Image' }, Namespace => 'crs' },
        {
            Groups => { 2 => 'Camera' },
            Namespace => 'exif',
            PrintConv => {
                0 => 'Normal',
                1 => 'Soft',
                2 => 'Hard',
            },
            PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
        },
    ],
    LuminanceSmoothing  => { Groups => { 2 => 'Image' } },
    ColorNoiseReduction => { Groups => { 2 => 'Image' } },
    ChromaticAberrationR=> { Groups => { 2 => 'Image' } },
    ChromaticAberrationB=> { Groups => { 2 => 'Image' } },
    VignetteAmount  => { Groups => { 2 => 'Image' } },
    VignetteMidpoint=> { Groups => { 2 => 'Image' } },
    ShadowTint      => { Groups => { 2 => 'Image' } },
    RedHue          => { Groups => { 2 => 'Image' } },
    RedSaturation   => { Groups => { 2 => 'Image' } },
    GreenHue        => { Groups => { 2 => 'Image' } },
    GreenSaturation => { Groups => { 2 => 'Image' } },
    BlueHue         => { Groups => { 2 => 'Image' } },
    BlueSaturation  => { Groups => { 2 => 'Image' } },
#
# - Auxiliary schema properties (aux) - not documented
#
    Lens            => { Groups => { 1 => 'XMP-aux', 2 => 'Camera' } },
    SerialNumber    => { Groups => { 2 => 'Camera' } },
#
# - Tiff schema properties (tiff)
#
    ImageWidth => {
        Groups => { 1 => 'XMP-tiff', 2 => 'Image' },
        Writable => 'integer',
    },
    ImageLength => {
        Name => 'ImageHeight',
        Groups => { 2 => 'Image' },
        Writable => 'integer',
    },
    BitsPerSample => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
        List => 'Seq',
    },
    Compression => {
        Groups => { 2 => 'Image' },
        PrintConv => \%Image::ExifTool::Exif::compression,
    },
    PhotometricInterpretation => {
        Groups => { 2 => 'Image' },
        PrintConv => \%Image::ExifTool::Exif::photometricInterpretation,
    },
    Orientation => {
        Groups => { 2 => 'Image' },
        PrintConv => \%Image::ExifTool::Exif::orientation,
    },
    SamplesPerPixel => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
    },
    PlanarConfiguration => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            1 => 'Chunky',
            2 => 'Planar',
        },
    },
    YCbCrSubSampling => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            '1 1' => 'YCbCr4:4:4',
            '2 1' => 'YCbCr4:2:2',
            '2 2' => 'YCbCr4:2:0',
            '4 1' => 'YCbCr4:1:1',
            '4 2' => 'YCbCr4:1:0',
            '1 2' => 'YCbCr4:4:0',
        },
    },
    XResolution => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
    },
    YResolution => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
    },
    ResolutionUnit => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    TransferFunction => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
        List => 'Seq',
    },
    WhitePoint => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        List => 'Seq',
    },
    PrimaryChromaticities => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        List => 'Seq',
    },
    YCbCrCoefficients => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        List => 'Seq',
    },
    ReferenceBlackWhite => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        List => 'Seq',
    },
    DateTime => {
        Description => 'Date/Time Of Last Modification',
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ImageDescription => {
        Groups => { 2 => 'Image' },
        Writable => 'lang-alt',
    },
    Make => {
        Groups => { 2 => 'Camera' },
    },
    Model => {
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
    },
    Software => {
        Groups => { 2 => 'Image' },
    },
    Artist => {
        Groups => { 2 => 'Author' },
    },
    Copyright => {
        Groups => { 2 => 'Author' },
        Writable => 'lang-alt',
    },
#
# - Exif schema properties (exif)
#
    ExifVersion     => { Groups => { 1 => 'XMP-exif', 2 => 'Image' } },
    FlashpixVersion => { Groups => { 2 => 'Image' } },
    ColorSpace => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
            0xffffffff => 'Uncalibrated',
        },
    },
    ComponentsConfiguration => {
        Groups => { 2 => 'Image' },
        List => 'Seq',
        PrintConv => {
            0 => '.',
            1 => 'Y',
            2 => 'Cb',
            3 => 'Cr',
            4 => 'R',
            5 => 'G',
            6 => 'B',
        },
    },
    CompressedBitsPerPixel => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
    },
    PixelXDimension => {
        Name => 'ExifImageWidth',
        Groups => { 2 => 'Image' },
        Writable => 'integer',
    },
    PixelYDimension => {
        Name => 'ExifImageHeight',
        Groups => { 2 => 'Image' },
        Writable => 'integer',
    },
    MakerNote => { Groups => { 2 => 'Image' } },
    UserComment => {
        Groups => { 2 => 'Image' },
        Writable => 'lang-alt',
    },
    RelatedSoundFile => { },
    DateTimeOriginal => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    DateTimeDigitized => {
        Description => 'Date/Time Digitized',
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ExposureTime => {
        Description => 'Shutter Speed',
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    FNumber => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        Description => 'Aperture',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    ExposureProgram => {
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
    SpectralSensitivity => {
        Groups => { 2 => 'Camera' },
    },
    ISOSpeedRatings => {
        Name => 'ISO',
        Writable => 'integer',
        List => 'Seq',
        Description => 'ISO Speed',
        Groups => { 2 => 'Image' },
    },
    # OECF - structure (OECF/SFR=Columns,Rows,Names,Values)
    OECF => {
        Name => 'Opto-ElectricConvFactor',
        Groups => { 2 => 'Camera' },
        Writable => 0,  # (this is a structure)
    },
    OECFColumns => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
    },
    OECFRows => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
    },
    OECFNames => {
        Groups => { 2 => 'Camera' },
        List => 'Seq',
    },
    OECFValues => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        List => 'Seq',
    },
    ShutterSpeedValue => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        ValueConv => 'abs($val)<100 ? 1/(2**$val) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : 0',
        # do eval to convert things like '1/100'
        PrintConvInv => 'eval $val',
    },
    ApertureValue => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    BrightnessValue => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
    },
    ExposureBiasValue => {
        Name => 'ExposureCompensation',
        Groups => { 2 => 'Image' },
        Writable => 'rational',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => '$val',
    },
    MaxApertureValue => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    SubjectDistance => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        PrintConv => '"$val m"',
        PrintConvInv => '$val=~s/ m$//;$val',
    },
    MeteringMode => {
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
    LightSource => {
        Groups => { 2 => 'Camera' },
        PrintConv =>  \%Image::ExifTool::Exif::lightSource,
    },
    # Flash - structure (Flash=Fired,Return,Mode,Function,RedEyeMode)
    Flash => {
        Groups => { 2 => 'Camera' },
        Writable => 0,
    },
    FlashFired => {
        Groups => { 2 => 'Camera' },
        Writable => 'boolean',
    },
    FlashReturn => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'No return detection',
            2 => 'Return not detected',
            3 => 'Return detected',
        },
    },
    FlashMode => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Unknown',
            1 => 'On',
            2 => 'Off',
            3 => 'Auto',
        },
    },
    FlashFunction => {
        Groups => { 2 => 'Camera' },
        Writable => 'boolean',
    },
    FlashRedEyeMode => {
        Groups => { 2 => 'Camera' },
        Writable => 'boolean',
    },
    FocalLength=> {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        PrintConv => 'sprintf("%.1fmm",$val)',
        PrintConvInv => '$val=~s/mm$//;$val',
    },
    SubjectArea => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
        List => 'Seq',
    },
    FlashEnergy => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
    },
    # SpatialFrequencyResponse - structure (OECF/SFR=Columns,Rows,Names,Values)
    SpatialFrequencyResponse => {
        Groups => { 2 => 'Camera' },
        Writable => 0,  # (this is a structure)
    },
    SpatialFrequencyResponseColumns => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
    },
    SpatialFrequencyResponseRows => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
    },
    SpatialFrequencyResponseNames => {
        Groups => { 2 => 'Camera' },
        List => 'Seq',
    },
    SpatialFrequencyResponseValues => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        List => 'Seq',
    },
    FocalPlaneXResolution => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
    },
    FocalPlaneYResolution => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
    },
    FocalPlaneResolutionUnit => {
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
    SubjectLocation => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
        List => 'Seq',
    },
    ExposureIndex => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
    },
    SensingMethod => {
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
    FileSource => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            3 => 'Digital Camera',
        },
    },
    SceneType => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            1 => 'Directly photographed',
        },
    },
    # CFAPattern - structure (CFAPattern=Columns,Rows,Values)
    CFAPattern => {
        Groups => { 2 => 'Image' },
        Writable => 0,
    },
    CFAPatternColumns => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
    },
    CFAPatternRows => {
        Groups => { 2 => 'Image' },
        Writable => 'integer',
    },
    CFAPatternValues => {
        Groups => { 2 => 'Image' },
        List => 'Seq',
        Writable => 'integer',
    },
    CustomRendered => {
        Groups => { 2 => 'Image' },
        PrintConv => {
            0 => 'Normal',
            1 => 'Custom',
        },
    },
    ExposureMode => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
            2 => 'Auto bracket',
        },
    },
# (covered by crs)
#    WhiteBalance => {
#        Groups => { 2 => 'Camera' },
#        PrintConv => {
#            0 => 'Auto',
#            1 => 'Manual',
#        },
#    },
    DigitalZoomRatio => {
        Groups => { 2 => 'Image' },
        Writable => 'rational',
    },
    FocalLengthIn35mmFilm => {
        Name => 'FocalLengthIn35mmFormat',
        Writable => 'integer',
        Groups => { 2 => 'Camera' },
    },
    SceneCaptureType => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Standard',
            1 => 'Landscape',
            2 => 'Portrait',
            3 => 'Night',
        },
    },
    GainControl => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'None',
            1 => 'Low gain up',
            2 => 'High gain up',
            3 => 'Low gain down',
            4 => 'High gain down',
        },
    },
# (covered by crs)
#    Contrast => {
#        Groups => { 2 => 'Camera' },
#        PrintConv => {
#            0 => 'Normal',
#            1 => 'Soft',
#            2 => 'Hard',
#        },
#    },
# (covered by crs)
#    Saturation => {
#        Groups => { 2 => 'Camera' },
#        PrintConv => {
#            0 => 'Normal',
#            1 => 'Low',
#            2 => 'High',
#        },
#    },
# (covered by crs)
#    Sharpness => {
#        Groups => { 2 => 'Camera' },
#        PrintConv => {
#            0 => 'Normal',
#            1 => 'Soft',
#            2 => 'Hard',
#        },
#    },
    # DeviceSettingDescription (DeviceSettings structure=Columns,Rows,Settings)
    DeviceSettingDescription => {
        Groups => { 2 => 'Camera' },
        Writable => 0,
    },
    DeviceSettingDescriptionColumns => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
    },
    DeviceSettingDescriptionRows => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
    },
    DeviceSettingDescriptionSettings => {
        Groups => { 2 => 'Camera' },
        List => 'Seq',
    },
    SubjectDistanceRange => {
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'Unknown',
            1 => 'Macro',
            2 => 'Close',
            3 => 'Distant',
        },
    },
    ImageUniqueID   => { Groups => { 2 => 'Image' } },
    GPSVersionID    => { Groups => { 2 => 'Location' } },
    GPSLatitude     => { Groups => { 2 => 'Location' } },
    GPSLongitude    => { Groups => { 2 => 'Location' } },
    GPSAltitudeRef  => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    GPSAltitude     => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSVersionID    => { Groups => { 2 => 'Location' } },
    GPSTimeStamp    => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    GPSSatellites   => { Groups => { 2 => 'Location' } },
    GPSStatus => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            A => 'Measurement In Progress',
            V => 'Measurement Interoperability',
        },
    },
    GPSSpeedRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    GPSSpeed => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSTrackRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSTrack => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSImgDirectionRef => {
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSImgDirection => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSMapDatum     => { Groups => { 2 => 'Location' } },
    GPSDestLatitude => { Groups => { 2 => 'Location' } },
    GPSDestLongitude=> { Groups => { 2 => 'Location' } },
    GPSDestBearingRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSDestBearing => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSDestDistanceRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            K => 'Kilometers',
            M => 'Miles',
            N => 'Nautical Miles',
        },
    },
    GPSDestDistance => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSProcessingMethod => { Groups => { 2 => 'Location' } },
    GPSAreaInformation  => { Groups => { 2 => 'Location' } },
    GPSDifferential => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
#
# - IPTC Core schema properties (Iptc4xmpCore)
#
    CountryCode         => { Groups => { 1 => 'XMP-iptcCore', 2 => 'Location' } },
    # CreatorContactInfo - structure (ContactInfo=CiAdrCity,CiAdrCtry,CiAdrExtadr,
    #                       CiAdrPcode, CiAdrRegion, CiEmailWork, CiTelWork, CiUrlWork)
    CreatorContactInfo => {
        Groups => { 2 => 'Author' },
        Writable => 0,
    },
    CreatorContactInfoCiAdrCity => {
        Description => 'Creator City',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiAdrCtry => {
        Description => 'Creator Country',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiAdrExtadr => {
        Description => 'Creator Address',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiAdrPcode => {
        Description => 'Creator Postal Code',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiAdrRegion => {
        Description => 'Creator Region',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiEmailWork => {
        Description => 'Creator Work Email',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiTelWork => {
        Description => 'Creator Work Telephone',
        Groups => { 2 => 'Author' }
    },
    CreatorContactInfoCiUrlWork => {
        Description => 'Creator Work URL',
        Groups => { 2 => 'Author' }
    },
    IntellectualGenre   => { Groups => { 2 => 'Other' } },
    Location            => { Groups => { 2 => 'Location' } },
    Scene               => { Groups => { 2 => 'Other' }, List => 'Bag' },
    SubjectCode         => { Groups => { 2 => 'Other' }, List => 'Bag' },
);

# composite tags
# (the main script looks for the special 'Composite' hash)
%Image::ExifTool::XMP::Composite = (
    # Note: the following 2 composite tags are duplicated in Image::ExifTool::IPTC
    # (only the first loaded definition is used)
    DateTimeCreated => {
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
        Description => 'Shooting Date/Time',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateTimeCreated',
        },
        ValueConv => '$val[0]',
        PrintConv => '$valPrint[0]',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::XMP::Composite');


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Escape necessary HTML(XML) characters
# Inputs: 0) string to be escaped
# Returns: escaped string
sub EscapeHTML($)
{
    local $_ = shift;
    s/&/&amp;/sg;
    s/>/&gt;/sg;
    s/</&lt;/sg;
    s/'/&apos;/sg;
    s/"/&quot;/sg;
    return $_;
}

#------------------------------------------------------------------------------
# Unescape necessary HTML(XML) characters
# Inputs: 0) string to be unescaped
# Returns: unescaped string
sub UnescapeHTML($)
{
    local $_ = shift;
    s/&gt;/>/sg;
    s/&lt;/</sg;
    s/&apos;/'/sg;
    s/&quot;/"/sg;
    s/&amp;/&/sg;   # do this last or things like '&amp;lt;' will get double-unescaped
    return $_;
}

#------------------------------------------------------------------------------
# Utility routine to decode a base64 string
# Inputs: 0) base64 string
# Returns:   reference to decoded data
sub DecodeBase64($)
{
    local($^W) = 0; # unpack('u',...) gives bogus warning in 5.00[123]
    my $str = shift;

    # truncate at first unrecognized character (base 64 data
    # may only contain A-Z, a-z, 0-9, +, /, =, or white space)
    $str =~ s/[^A-Za-z0-9+\/= \t\n\r\f].*//;
    # translate to uucoded and remove padding and white space
    $str =~ tr/A-Za-z0-9+\/= \t\n\r\f/ -_/d;

    # convert the data to binary in chunks
    my $chunkSize = 60;
    my $uuLen = pack('c', 32 + $chunkSize * 3 / 4); # calculate length byte
    my $dat = '';
    my ($i, $substr);
    # loop through the whole chunks
    my $len = length($str) - $chunkSize;
    for ($i=0; $i<=$len; $i+=$chunkSize) {
        $substr = substr($str, $i, $chunkSize);     # get a chunk of the data
        $dat .= unpack('u', $uuLen . $substr);      # decode it
    }
    $len += $chunkSize;
    # handle last partial chunk if necessary
    if ($i < $len) {
        $uuLen = pack('c', 32 + ($len-$i) * 3 / 4); # recalculate length
        $substr = substr($str, $i, $len-$i);        # get the last partial chunk
        $dat .= unpack('u', $uuLen . $substr);      # decode it
    }
    return \$dat;
}

#------------------------------------------------------------------------------
# Generate a name for this XMP tag
# Inputs: 0) reference to tag property name list
# Returns: tag name and outtermost interesting namespace
sub GetXMPTagName($)
{
    my $props = shift;
    my $tag = '';
    my $prop;
    my $namespace;
    foreach $prop (@$props) {
        # split name into namespace and property name
        # (Note: namespace can be '' for property qualifiers)
        my ($ns, $nm) = ($prop =~ /(.*?):(.*)/) ? ($1, $2) : ('', $prop);
        if ($ignoreNamespace{$ns}) {
            # special case: don't ignore rdf numbered items
            next unless $prop =~ /^rdf:(_\d+)$/;
            $tag .= $1;
        } else {
            # all uppercase is ugly, so convert it
            unless ($Image::ExifTool::XMP::Main{$nm} or $nm =~ /[a-z]/) {
                $nm = lc($nm);
                $nm =~ s/_([a-z])/\u$1/g;
            }
            $tag .= ucfirst($nm);       # add to tag name
        }
        # save namespace of first property to contribute to tag name
        $namespace = $ns unless defined $namespace;
    }
    if (wantarray) {
        return ($tag, $namespace);
    } else {
        return $tag;
    }
}

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table
#         2) reference to array of XMP property names (last is current property)
#         3) property value
sub FoundXMP($$$$)
{
    local $_;
    my ($exifTool, $tagTablePtr, $props, $val) = @_;

    my ($tag, $namespace) = GetXMPTagName($props);
    return unless $tag;     # ignore things that aren't valid tags

    # convert quotient and date values to a more sensible format
    if ($val =~ /^(-?\d+)\/(-?\d+)/) {
        $val = $1 / $2 if $2;       # calculate quotient
    } elsif ($val =~ /^(\d{4})-(\d{2})-(\d{2}).{1}(\d{2}:\d{2}:\d{2})(\S*)/) {
        $val = "$1:$2:$3 $4$5";     # convert back to EXIF time format
    }
    # look up this tag in the XMP table
    my $tagInfo;
    my @tagInfoList = Image::ExifTool::GetTagInfoList($tagTablePtr, $tag);
    if (@tagInfoList == 1) {
        $tagInfo = $tagInfoList[0];
    } elsif (@tagInfoList > 1) {
        # decide which tag this is (decide based on group1 name)
        foreach (@tagInfoList) {
            next unless $_->{Namespace} and $_->{Namespace} eq $namespace;
            $tagInfo = $_;
            last;
        }
        # take first one from list if we didn't get a match
        $tagInfo or $tagInfo = $tagInfoList[0];
    } else {
        # construct tag information for this unknown tag
        $tagInfo = { Name => $tag };
        Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
    $tag = $exifTool->FoundTag($tagInfo, UnescapeHTML($val));
    # translate namespace if necessary
    $namespace = $xlatNamespace{$namespace} if $xlatNamespace{$namespace};
    $exifTool->SetTagExtra($tag, $namespace);

    if ($exifTool->Options('Verbose')) {
        my $tagID = join('/',@$props);
        $exifTool->VerboseInfo($tagID, $tagInfo, Value=>$val);
    }
}

#------------------------------------------------------------------------------
# Recursively parse nested XMP data element
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table
#         2) reference to XMP data
#         3) start of xmp element
#         4) reference to array of enclosing XMP property names (undef if none)
# Returns: Number of contained XMP elements
sub ParseXMPElement($$$;$$)
{
    my $exifTool = shift;
    my $tagTablePtr = shift;
    my $dataPt = shift;
    my $start = shift || 0;
    my $propListPt = shift || [ ];
    my $count = 0;
    my $isWriting = $exifTool->{XMP_CAPTURE};

    pos($$dataPt) = $start;
    Element: while ($$dataPt =~ m/<([\w:-]+)(.*?)>/sg) {
        my ($prop, $attrs) = ($1, $2);
        my $val = '';
        # only look for closing token if this is not an empty element
        # (empty elements end with '/', ie. <a:b/>)
        if ($attrs !~ s/\/$//) {
            my $nesting = 1;
            for (;;) {
# this match fails with perl 5.6.2 (perl bug!), but it works without
# the '(.*?)', so do it the hard way instead...
#                $$dataPt =~ m/(.*?)<\/$prop>/sg or last Element;
#                my $val2 = $1;
                my $pos = pos($$dataPt);
                $$dataPt =~ m/<\/$prop>/sg or last Element;
                my $len = pos($$dataPt) - $pos - length($prop) - 3;
                my $val2 = substr($$dataPt, $pos, $len);
                # increment nesting level for each contained similar opening token
                ++$nesting while $val2 =~ m/<$prop\b.*?(\/?)>/sg and $1 ne '/';
                $val .= $val2;
                --$nesting or last;
                $val .= "</$prop>";
            }
        }
        # push this property name onto our hierarchy list
        push @$propListPt, $prop;

        if ($isWriting) {
            my %attrs;
            $attrs{$1} = $3 while $attrs =~ m/(\S+)=(['"])(.*?)\2/sg;
            # add index to list items so we can keep them in order
            # (this also enables us to keep structure elements grouped properly
            # for lists of structures, like JobRef)
            if ($prop eq 'rdf:li') {
                $$propListPt[$#$propListPt] = sprintf('rdf:li %.3d', $count);
            }
            # undefine value if we found more properties within this one
            undef $val if ParseXMPElement($exifTool, $tagTablePtr, \$val, 0, $propListPt);
            CaptureXMP($exifTool, $tagTablePtr, $propListPt, $val, \%attrs);
        } else {
            # trim comments and whitespace from rdf:Description properties only
            if ($prop eq 'rdf:Description') {
                $val =~ s/<!--.*?-->//g;
                $val =~ s/^\s*(.*)\s*$/$1/;
            }
            # handle properties inside element attributes (RDF shorthand format):
            # (attributes take the form a:b='c' or a:b="c")
            while ($attrs =~ m/(\S+)=(['"])(.*?)\2/sg) {
                my ($shortName, $shortVal) = ($1, $3);
                my $ns;
                if ($shortName =~ /(.*?):/) {
                    $ns = $1;   # specified namespace
                } elsif ($prop =~ /(.*?):/) {
                    $ns = $1;   # assume same namespace as parent
                    $shortName = "$ns:$shortName";    # add namespace to property name
                } else {
                    # a property qualifier is the only property name that may not
                    # have a namespace, and a qualifier shouldn't have attributes,
                    # but what the heck, let's allow this anyway
                    $ns = '';
                }
                $ignoreNamespace{$ns} and next;
                push @$propListPt, $shortName;
                # save this shorthand XMP property
                FoundXMP($exifTool, $tagTablePtr, $propListPt, $shortVal);
                pop @$propListPt;
            }
            # if element value is empty, take value from 'resource' attribute
            # (preferentially) or 'about' attribute (if no 'resource')
            $val = $2 if $val eq '' and ($attrs =~ /\bresource=(['"])(.*?)\1/ or
                                         $attrs =~ /\babout=(['"])(.*?)\1/);
            # look for additional elements contained within this one
            if (!ParseXMPElement($exifTool, $tagTablePtr, \$val, 0, $propListPt)) {
                # there are no contained elements, so this must be a simple property value
                FoundXMP($exifTool, $tagTablePtr, $propListPt, $val);
            }
        }
        pop @$propListPt;
        ++$count;
    }
    return $count;  # return the number of elements found at this level
}

#------------------------------------------------------------------------------
# Process XMP data
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessXMP($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart} || 0;
    my $dirLen = $dirInfo->{DirLen};
    my $rtnVal = 0;
    my $buff;

    return 0 unless $tagTablePtr;
    # take substring if necessary
    if ($dirInfo->{DataLen} != $dirStart + $dirLen) {
        $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
        $dirStart = 0;
    }
    if ($exifTool->{REQ_TAG_LOOKUP}->{xmp}) {
        $exifTool->FoundTag('XMP', substr($$dataPt, $dirStart, $dirLen));
    }
    if ($exifTool->Options('Verbose') and not $exifTool->{XMP_CAPTURE}) {
        $exifTool->VerboseDir('XMP', 0, $dirLen);
    }
#
# convert UTF-16 or UTF-32 encoded XMP to UTF-8 if necessary
#
    my $begin = '<?xpacket begin=';
    pos($$dataPt) = $dirStart;
    unless ($$dataPt =~ /\G\Q$begin\E/) {
        my ($fmt, $len);
        # check for UTF-16 encoding (insert one \0 between characters)
        $begin = join "\0", split //, $begin;
        if ($$dataPt =~ /\G(\0)?\Q$begin\E\0./g) {
            # validate byte ordering by checking for U+FEFF character
            if ($1) {
                # should be big-endian since we had a leading \0
                $fmt = 'n' if $$dataPt =~ /\G\xfe\xff/;
            } else {
                $fmt = 'v' if $$dataPt =~ /\G\0\xff\xfe/;
            }
        } else {
            # check for UTF-32 encoding (with three \0's between characters)
            $begin =~ s/\0/\0\0\0/g;
            # must reset pos because it was killed by previous unsuccessful //g match
            pos($$dataPt) = $dirStart;
            if ($$dataPt !~ /\G(\0\0\0)?\Q$begin\E\0\0\0./g) {
                $fmt = 0;   # set format to zero as indication we didn't find encoded XMP
            } elsif ($1) {
                # should be big-endian
                $fmt = 'N' if $$dataPt =~ /\G\0\0\xfe\xff/;
            } else {
                $fmt = 'V' if $$dataPt =~ /\G\0\0\0\xff\xfe\0\0/;
            }
        }
        if ($fmt) {
            # translate into UTF-8
            if ($] >= 5.006001) {
                $buff = pack('C0U*',unpack("x$dirStart$fmt*",$$dataPt));
            } else {
                # hack for pre 5.6.1 (because the code to do the
                # translation properly is unnecesarily bulky)
                my @unpk = unpack("x$dirStart$fmt*",$$dataPt);
                foreach (@unpk) {
                    $_ > 0xff and $_ = ord('?');
                }
                $buff = pack('C*', @unpk);
            }
            $dataPt = \$buff;
            $dirStart = 0;
        } else {
            defined $fmt or $exifTool->Warn('XMP character encoding error');
        }
    }
#
# extract the information
#
    $rtnVal = 1 if ParseXMPElement($exifTool, $tagTablePtr, $dataPt, $dirStart);

    return $rtnVal;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::XMP - Definitions for XMP meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

XMP stands for Extensible Metadata Platform.  It is a format based on XML that
Adobe developed for embedding metadata information in image files.  This module
contains the definitions required by Image::ExifTool to read XMP information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf>

=item L<http://www.w3.org/TR/rdf-syntax-grammar/>

=item L<http://www.portfoliofaq.com/pfaq/v7mappings.htm>

=item L<http://www.iptc.org/IPTC4XMP/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
