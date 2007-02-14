#------------------------------------------------------------------------------
# File:         XMP.pm
#
# Description:  Read XMP meta information
#
# Revisions:    11/25/2003 - P. Harvey Created
#               10/28/2004 - P. Harvey Major overhaul to conform with XMP spec
#               02/27/2005 - P. Harvey Also read UTF-16 and UTF-32 XMP
#               08/30/2005 - P. Harvey Split tag tables into separate namespaces
#               10/24/2005 - P. Harvey Added ability to parse .XMP files
#               08/25/2006 - P. Harvey Added ability to handle blank nodes
#
# References:   1) http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf
#               2) http://www.w3.org/TR/rdf-syntax-grammar/  (20040210)
#               3) http://www.portfoliofaq.com/pfaq/v7mappings.htm
#               4) http://www.iptc.org/IPTC4XMP/
#               5) http://creativecommons.org/technology/xmp
#               6) http://www.optimasc.com/products/fileid/xmp-extensions.pdf
#               7) Lou Salkind private communication
#               8) http://partners.adobe.com/public/developer/en/xmp/sdk/xmpspecification.pdf
#
# Notes:      - I am handling property qualifiers as if they were separate
#               properties (with no associated namespace).
#
#             - Currently, there is no special treatment of the following
#               properties which could potentially affect the extracted
#               information: xml:base, xml:lang, rdf:parseType (note that
#               parseType Literal isn't allowed by the XMP spec).
#
#             - The family 2 group names will be set to 'Unknown' for any XMP
#               tags not found in the XMP or Exif tag tables.
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use strict;
use vars qw($VERSION $AUTOLOAD @ISA @EXPORT_OK);
use Image::ExifTool qw(:Utils);
use Image::ExifTool::Exif;
require Exporter;

$VERSION = '1.65';
@ISA = qw(Exporter);
@EXPORT_OK = qw(EscapeHTML UnescapeHTML);

sub ProcessXMP($$;$);
sub WriteXMP($$;$);
sub ParseXMPElement($$$;$$$);
sub DecodeBase64($);
sub SaveBlankInfo($$$;$);
sub ProcessBlankInfo($$$;$);
sub ValidateXMP($;$);

# conversions for GPS coordinates
sub ToDegrees
{
    require Image::ExifTool::GPS;
    Image::ExifTool::GPS::ToDegrees($_[0], 1);
}
my %latConv = (
    ValueConv    => \&ToDegrees,
    RawConv => 'require Image::ExifTool::GPS; $val', # to load Composite tags and routines
    ValueConvInv => q{
        require Image::ExifTool::GPS;
        Image::ExifTool::GPS::ToDMS($self, $val, 2, "N");
    },
    PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    PrintConvInv => \&ToDegrees,
);
my %longConv = (
    ValueConv    => \&ToDegrees,
    RawConv => 'require Image::ExifTool::GPS; $val',
    ValueConvInv => q{
        require Image::ExifTool::GPS;
        Image::ExifTool::GPS::ToDMS($self, $val, 2, "E");
    },
    PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    PrintConvInv => \&ToDegrees,
);

# XMP namespaces which we don't want to contribute to generated EXIF tag names
my %ignoreNamespace = ( 'x'=>1, 'rdf'=>1, 'xmlns'=>1, 'xml'=>1);

# translate XMP namespaces when reading
my %xlatNamespace = (
    # shorten ugly IPTC Core namespace prefix
    'Iptc4xmpCore' => 'iptcCore',
    'photomechanic'=> 'photomech',
    'MicrosoftPhoto' => 'microsoft',
    # also translate older 'xap...' prefixes to 'xmp...'
    'xap'          => 'xmp',
    'xapBJ'        => 'xmpBJ',
    'xapMM'        => 'xmpMM',
    'xapRights'    => 'xmpRights',
);

# these are the attributes that we handle for properties that contain
# sub-properties.  Attributes for simple properties are easy, and we
# just copy them over.  These are harder since we don't store attributes
# for properties without simple values.  (maybe this will change...)
my %recognizedAttrs = (
    'x:xaptk' => 1,
    'x:xmptk' => 1,
    'rdf:about' => 1,
    'rdf:parseType' => 1,
    'rdf:nodeID' => 1,
);

# main XMP tag table
%Image::ExifTool::XMP::Main = (
    GROUPS => { 2 => 'Unknown' },
    PROCESS_PROC => \&ProcessXMP,
    WRITE_PROC => \&WriteXMP,
    dc => {
        Name => 'dc', # (otherwise generated name would be 'Dc')
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::dc' },
    },
    xmp => {
        Name => 'xmp',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmp' },
    },
    xmpDM => {
        Name => 'xmpDM',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpDM' },
    },
    xmpRights => {
        Name => 'xmpRights',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpRights' },
    },
    xmpMM => {
        Name => 'xmpMM',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpMM' },
    },
    xmpBJ => {
        Name => 'xmpBJ',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpBJ' },
    },
    xmpTPg => {
        Name => 'xmpTPg',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpTPg' },
    },
    pdf => {
        Name => 'pdf',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::pdf' },
    },
    photoshop => {
        Name => 'photoshop',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::photoshop' },
    },
    crs => {
        Name => 'crs',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::crs' },
    },
    aux => {
        Name => 'aux',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::aux' },
    },
    tiff => {
        Name => 'tiff',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::tiff' },
    },
    exif => {
        Name => 'exif',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::exif' },
    },
    iptcCore => {
        Name => 'iptcCore',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::iptcCore' },
    },
    PixelLive => {
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::PixelLive' },
    },
    xmpPLUS => {
        Name => 'xmpPLUS',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpPLUS' },
    },
    cc => {
        Name => 'cc',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::cc' },
    },
    dex => {
        Name => 'dex',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::dex' },
    },
    photomech => {
        Name => 'photomech',
        SubDirectory => { TagTable => 'Image::ExifTool::PhotoMechanic::XMP' },
    },
    microsoft => {
        Name => 'microsoft',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Microsoft' },
    },
);

#
# Tag tables for all XMP schemas:
#
# Writable - only need to define this for writable tags if not plain text
#            (boolean, integer, rational, real, date or lang-alt)
# List - XMP list type (Bag, Seq or Alt, or set to 1 for elements in Struct lists)
#
# (Note that family 1 group names are generated from the property namespace, not
#  the group1 names below which exist so the groups will appear in the list.)
#

# Dublin Core schema properties (dc)
%Image::ExifTool::XMP::dc = (
    GROUPS => { 1 => 'XMP-dc', 2 => 'Other' },
    NAMESPACE => 'dc',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'Dublin Core schema tags.',
    contributor => { Groups => { 2 => 'Author' }, List => 'Bag' },
    coverage    => { },
    creator     => { Groups => { 2 => 'Author' }, List => 'Seq' },
    date        => {
        Groups => { 2 => 'Time'   },
        Writable => 'date',
        Shift => 'Time',
        List => 'Seq',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    description => { Groups => { 2 => 'Image'  }, Writable => 'lang-alt' },
   'format'     => { Groups => { 2 => 'Image'  } },
    identifier  => { Groups => { 2 => 'Image'  } },
    language    => { List => 'Bag' },
    publisher   => { Groups => { 2 => 'Author' }, List => 'Bag' },
    relation    => { List => 'Bag' },
    rights      => { Groups => { 2 => 'Author' }, Writable => 'lang-alt' },
    source      => { Groups => { 2 => 'Author' } },
    subject     => { Groups => { 2 => 'Image'  }, List => 'Bag' },
    title       => { Groups => { 2 => 'Image'  }, Writable => 'lang-alt' },
    type        => { Groups => { 2 => 'Image'  }, List => 'Bag' },
);

# XMP Basic schema properties (xmp, xap)
%Image::ExifTool::XMP::xmp = (
    GROUPS => { 1 => 'XMP-xmp', 2 => 'Image' },
    NAMESPACE => 'xmp',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => q{
        XMP Basic schema tags.  If the older "xap", "xapBJ", "xapMM" or "xapRights"
        namespace prefixes are found, they are translated to the newer "xmp",
        "xmpBJ", "xmpMM" and "xmpRights" prefixes for use in family 1 group names.
    },
    Advisory    => { List => 'Bag' },
    BaseURL     => { },
    CreateDate  => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CreatorTool => { },
    Identifier  => { Avoid => 1, List => 'Bag' },
    Label       => { },
    MetadataDate => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ModifyDate => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Nickname    => { },
    Rating      => { Writable => 'integer' },
    Thumbnails => {
        SubDirectory => { },
        Struct => 'Thumbnail',
        List => 'Alt',
    },
    ThumbnailsHeight    => { List => 1 },
    ThumbnailsWidth     => { List => 1 },
    ThumbnailsFormat    => { List => 1 },
    ThumbnailsImage     => {
        # Eventually may want to handle this like a normal thumbnail image
        # -- but not yet!  (need to write EncodeBase64() routine....)
        # Name => 'ThumbnailImage',
        List => 1,
        # translate Base64-encoded thumbnail
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
    },
);

# XMP Rights Management schema properties (xmpRights, xapRights)
%Image::ExifTool::XMP::xmpRights = (
    GROUPS => { 1 => 'XMP-xmpRights', 2 => 'Author' },
    NAMESPACE => 'xmpRights',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'XMP Rights Management schema tags.',
    Certificate     => { },
    Marked          => { Writable => 'boolean' },
    Owner           => { List => 'Bag' },
    UsageTerms      => { Writable => 'lang-alt' },
    WebStatement    => { },
);

# XMP Media Management schema properties (xmpMM, xapMM)
%Image::ExifTool::XMP::xmpMM = (
    GROUPS => { 1 => 'XMP-xmpMM', 2 => 'Other' },
    NAMESPACE => 'xmpMM',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'XMP Media Management schema tags.',
    DerivedFrom     => {
        SubDirectory => { },
        Struct => 'ResourceRef',
    },
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
    History         => {
        SubDirectory => { },
        Struct => 'ResourceEvent',
        List => 'Seq',
    },
    HistoryAction           => { List => 1 },   # we treat these like list items
    HistoryInstanceID       => { List => 1 },
    HistoryParameters       => { List => 1 },
    HistorySoftwareAgent    => { List => 1 },
    HistoryWhen             => {
        List => 1,
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
    },
    ManagedFrom     => { SubDirectory => { }, Struct => 'ResourceRef' },
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
    PreservedFileName => { },   # undocumented
    RenditionClass  => { },
    RenditionParams => { },
    VersionID       => { },
    Versions        => {
        SubDirectory => { },
        Struct => 'Version',
        List => 'Seq',
    },
    VersionsComments    => { List => 1 },   # we treat these like list items
    VersionsEvent       => { SubDirectory => { }, Struct => 'ResourceEvent' },
    VersionsEventAction         => { List => 1 },
    VersionsEventInstanceID     => { List => 1 },
    VersionsEventParameters     => { List => 1 },
    VersionsEventSoftwareAgent  => { List => 1 },
    VersionsEventWhen           => {
        List => 1,
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
    },
    VersionsModifyDate  => {
        List => 1,
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
    },
    VersionsModifier    => { List => 1 },
    VersionsVersion     => { List => 1 },
    LastURL         => { },
    RenditionOf     => { SubDirectory => { }, Struct => 'ResourceRef' },
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
);

# XMP Basic Job Ticket schema properties (xmpBJ, xapBJ)
%Image::ExifTool::XMP::xmpBJ = (
    GROUPS => { 1 => 'XMP-xmpBJ', 2 => 'Other' },
    NAMESPACE => 'xmpBJ',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'XMP Basic Job Ticket schema tags.',
    # Note: JobRef is a List of structures.  To accomplish this, we set the XMP
    # List=>'Bag', but since SubDirectory is defined, this tag isn't writable
    # directly.  Then we need to set List=>1 for the members so the Writer logic
    # will allow us to add list elements.
    JobRef => {
        SubDirectory => { },
        Struct => 'JobRef',
        List => 'Bag',
    },
    JobRefName  => { List => 1 },   # we treat these like list items
    JobRefId    => { List => 1 },
    JobRefUrl   => { List => 1 },
);

# XMP Paged-Text schema properties (xmpTPg)
%Image::ExifTool::XMP::xmpTPg = (
    GROUPS => { 1 => 'XMP-xmpTPg', 2 => 'Image' },
    NAMESPACE => 'xmpTPg',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'XMP Paged-Text schema tags.',
    MaxPageSize => { SubDirectory => { }, Struct => 'Dimensions' },
    MaxPageSizeW    => { Writable => 'real' },
    MaxPageSizeH    => { Writable => 'real' },
    MaxPageSizeUnit => { },
    NPages      => { Writable => 'integer' },
    Fonts       => {
        SubDirectory => { },
        Struct => 'Font',
        List => 'Bag',
    },
    FontsFontName       => { List => 1 },
    FontsFontFamily     => { List => 1 },
    FontsFontFace       => { List => 1 },
    FontsFontType       => { List => 1 },
    FontsVersionString  => { List => 1 },
    FontsComposite      => { List => 1, Writable => 'boolean' },
    FontsFontFileName   => { List => 1 },
    FontsChildFontFiles => { List => 1 },
    Colorants   => {
        SubDirectory => { },
        Struct => 'Colorant',
        List => 'Seq',
    },
    ColorantsSwatchName => { List => 1 },
    ColorantsMode       => { List => 1 },
    ColorantsType       => { List => 1 },
    ColorantsCyan       => { List => 1, Writable => 'real' },
    ColorantsMagenta    => { List => 1, Writable => 'real' },
    ColorantsYellow     => { List => 1, Writable => 'real' },
    ColorantsBlack      => { List => 1, Writable => 'real' },
    ColorantsRed        => { List => 1, Writable => 'integer' },
    ColorantsGreen      => { List => 1, Writable => 'integer' },
    ColorantsBlue       => { List => 1, Writable => 'integer' },
    ColorantsL          => { List => 1, Writable => 'real' },
    ColorantsA          => { List => 1, Writable => 'integer' },
    ColorantsB          => { List => 1, Writable => 'integer' },
    PlateNames  => { List => 'Seq' },
);

# XMP Dynamic Media schema properties (xmpDM)
%Image::ExifTool::XMP::xmpDM = (
    GROUPS => { 1 => 'XMP-xmpDM', 2 => 'Image' },
    NAMESPACE => 'xmpDM',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'XMP Dynamic Media schema tags.',
    projectRef => {
        SubDirectory => { },
        Struct => 'ProjectLink',
    },
    projectRefType      => { },
    projectRefPath      => { },
    videoFrameRate      => { },
    videoFrameSize => {
        SubDirectory => { },
        Struct => 'Dimensions',
    },
    videoFrameSizeW     => { Writable => 'real' },
    videoFrameSizeH     => { Writable => 'real' },
    videoFrameSizeUnit  => { },
    videoPixelAspectRatio => { Writable => 'rational' },
    videoPixelDepth     => { },
    videoColorSpace     => { },
    videoAlphaMode      => { },
    videoAlphaPremultipleColor => {
        SubDirectory => { },
        Struct => 'Colorant',
    },
    videoAlphaPremultipleColorSwatchName => { },
    videoAlphaPremultipleColorMode       => { },
    videoAlphaPremultipleColorType       => { },
    videoAlphaPremultipleColorCyan       => { Writable => 'real' },
    videoAlphaPremultipleColorMagenta    => { Writable => 'real' },
    videoAlphaPremultipleColorYellow     => { Writable => 'real' },
    videoAlphaPremultipleColorBlack      => { Writable => 'real' },
    videoAlphaPremultipleColorRed        => { Writable => 'integer' },
    videoAlphaPremultipleColorGreen      => { Writable => 'integer' },
    videoAlphaPremultipleColorBlue       => { Writable => 'integer' },
    videoAlphaPremultipleColorL          => { Writable => 'real' },
    videoAlphaPremultipleColorA          => { Writable => 'integer' },
    videoAlphaPremultipleColorB          => { Writable => 'integer' },
    videoAlphaUnityIsTransparent => { Writable => 'boolean' },
    videoCompressor     => { },
    videoFieldOrder     => { },
    pullDown            => { },
    audioSampleRate     => { Writable => 'integer' },
    audioSampleType     => { },
    audioChannelType    => { },
    audioCompressor     => { },
    speakerPlacement    => { },
    fileDataRate        => { Writable => 'rational' },
    tapeName            => { },
    altTapeName         => { },
    startTimecode => {
        SubDirectory => { },
        Struct => 'Timecode',
    },
    startTimecodeTimeValue  => { },
    startTimecodeTimeFormat => { },
    altTimecode => {
        SubDirectory => { },
        Struct => 'Timecode',
    },
    altTimecodeTimeValue    => { },
    altTimecodeTimeFormat   => { },
    duration            => { },
    scene               => { Avoid => 1 },
    shotName            => { },
    shotDate => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    shotLocation        => { },
    logComment          => { },
    markers => {
        SubDirectory => { },
        Struct => 'Marker',
        List => 'Seq',
    },
    markersStartTime    => { List => 1 },
    markersDuration     => { List => 1 },
    markersComment      => { List => 1 },
    markersName         => { List => 1 },
    markersLocation     => { List => 1 },
    markersTarget       => { List => 1 },
    markersType         => { List => 1 },
    contributedMedia => {
        SubDirectory => { },
        Struct => 'Media',
        List => 'Bag',
    },
    contributedMediaPath         => { List => 1 },
    contributedMediaTrack        => { List => 1 },
    contributedMediaStartTime    => { List => 1 },
    contributedMediaDuration     => { List => 1 },
    contributedMediaManaged      => { List => 1, Writable => 'boolean' },
    contributedMediaWebStatement => { List => 1 },
    absPeakAudioFilePath => { },
    relativePeakAudioFilePath => { },
    videoModDate => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    audioModDate => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    metadataModDate => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    artist          => { Avoid => 1, Groups => { 2 => 'Author' } },
    album           => { },
    trackNumber     => { Writable => 'integer' },
    genre           => { },
    copyright       => { Avoid => 1, Groups => { 2 => 'Author' } },
    releaseDate => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    composer        => { Groups => { 2 => 'Author' } },
    engineer        => { },
    tempo           => { Writable => 'real' },
    instrument      => { },
    introTime       => { },
    outCue          => { },
    relativeTimestamp => { },
    loop            => { Writable => 'boolean' },
    numberOfBeats   => { Writable => 'real' },
    key             => { },
    stretchMode     => { },
    timeScaleParams => {
        SubDirectory => { },
        Struct => 'TimeScaleStretch',
    },
    timeScaleParamsQuality  => { },
    timeScaleParamsFrameSize=> { Writable => 'real' },
    timeScaleParamsFrameOverlappingPercentage => { Writable => 'real' },
    resampleParams => {
        SubDirectory => { },
        Struct => 'ResampleStretch',
    },
    resampleParamsQuality   => { },
    beatSpliceParams => {
        SubDirectory => { },
        Struct => 'BeatSpliceStretch',
    },
    beatSpliceParamsUseFileBeatsMarker => { Writable => 'boolean' },
    beatSpliceParamsRiseInDecibel      => { Writable => 'real' },
    beatSpliceParamsRiseInTimeDuration => { },
    timeSignature   => { },
    scaleType       => { },
);

# PDF schema properties (pdf)
%Image::ExifTool::XMP::pdf = (
    GROUPS => { 1 => 'XMP-pdf', 2 => 'Image' },
    NAMESPACE => 'pdf',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => q{
        Adobe PDF schema tags.  The official XMP specification defines only
        Keywords, PDFVersion and Producer.  The other tags are included because they
        have been observed in PDF files, but Creator, Subject and Title are avoided
        when writing due to name conflicts with XMP-dc tags.
    },
    Author      => { Groups => { 2 => 'Author' } }, #PH
    ModDate => { #PH
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CreationDate => { #PH
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Creator     => { Groups => { 2 => 'Author' }, Avoid => 1 },
    Subject     => { Avoid => 1 },
    Title       => { Avoid => 1 },
    Keywords    => { },
    PDFVersion  => { },
    Producer    => { Groups => { 2 => 'Author' } },
);

# Photoshop schema properties (photoshop)
%Image::ExifTool::XMP::photoshop = (
    GROUPS => { 1 => 'XMP-photoshop', 2 => 'Image' },
    NAMESPACE => 'photoshop',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'Adobe Photoshop schema tags.',
    AuthorsPosition => { Groups => { 2 => 'Author' } },
    CaptionWriter   => { Groups => { 2 => 'Author' } },
    Category        => { },
    City            => { Groups => { 2 => 'Location' } },
    Country         => { Groups => { 2 => 'Location' } },
    ColorMode       => { }, #PH
    Credit          => { Groups => { 2 => 'Author' } },
    DateCreated => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    Headline        => { },
    Instructions    => { },
    ICCProfile      => { Name => 'ICCProfileName' }, #PH
    Source          => { Groups => { 2 => 'Author' }, Avoid => 1 },
    State           => { Groups => { 2 => 'Location' } },
    # the documentation doesn't show this as a 'Bag', but that's the
    # way Photoshop7.0 writes it - PH
    SupplementalCategories  => { List => 'Bag' },
    TransmissionReference   => { },
    Urgency         => { Writable => 'integer' },
);

# Photoshop Camera Raw Schema properties (crs) - (ref 8)
%Image::ExifTool::XMP::crs = (
    GROUPS => { 1 => 'XMP-crs', 2 => 'Image' },
    NAMESPACE => 'crs',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'Photoshop Camera Raw Schema tags.',
    AlreadyApplied  => { Writable => 'boolean' }, #PH (written by LightRoom beta 4.1)
    AutoBrightness  => { Writable => 'boolean' },
    AutoContrast    => { Writable => 'boolean' },
    AutoExposure    => { Writable => 'boolean' },
    AutoShadows     => { Writable => 'boolean' },
    BlueHue         => { Writable => 'integer' },
    BlueSaturation  => { Writable => 'integer' },
    Brightness      => { Writable => 'integer' },
    CameraProfile   => { },
    ChromaticAberrationB=> { Writable => 'integer' },
    ChromaticAberrationR=> { Writable => 'integer' },
    ColorNoiseReduction => { Writable => 'integer' },
    Contrast        => { Writable => 'integer', Avoid => 1 },
    CropTop         => { Writable => 'real' },
    CropLeft        => { Writable => 'real' },
    CropBottom      => { Writable => 'real' },
    CropRight       => { Writable => 'real' },
    CropAngle       => { Writable => 'real' },
    CropWidth       => { Writable => 'real' },
    CropHeight      => { Writable => 'real' },
    CropUnits => {
        Writable => 'integer',
        PrintConv => {
            0 => 'pixels',
            1 => 'inches',
            2 => 'cm',
        },
    },
    Exposure        => { Writable => 'real' },
    GreenHue        => { Writable => 'integer' },
    GreenSaturation => { Writable => 'integer' },
    HasCrop         => { Writable => 'boolean' },
    HasSettings     => { Writable => 'boolean' },
    LuminanceSmoothing  => { Writable => 'integer' },
    RawFileName     => { },
    RedHue          => { Writable => 'integer' },
    RedSaturation   => { Writable => 'integer' },
    Saturation      => { Writable => 'integer', Avoid => 1 },
    Shadows         => { Writable => 'integer' },
    ShadowTint      => { Writable => 'integer' },
    Sharpness       => { Writable => 'integer', Avoid => 1 },
    Temperature     => { Writable => 'integer' },
    Tint            => { Writable => 'integer' },
    ToneCurve       => { List => 'Seq' },
    ToneCurveName => {
        PrintConv => {
            Linear           => 'Linear',
           'Medium Contrast' => 'Medium Contrast',
           'Strong Contrast' => 'Strong Contrast',
            Custom           => 'Custom',
        },
    },
    Version         => { },
    VignetteAmount  => { Writable => 'integer' },
    VignetteMidpoint=> { Writable => 'integer' },
    WhiteBalance    => {
        Avoid => 1,
        PrintConv => {
           'As Shot'    => 'As Shot',
            Auto        => 'Auto',
            Daylight    => 'Daylight',
            Cloudy      => 'Cloudy',
            Shade       => 'Shade',
            Tungsten    => 'Tungsten',
            Fluorescent => 'Fluorescent',
            Flash       => 'Flash',
            Custom      => 'Custom',
        },
    },
);

# Tiff schema properties (tiff)
%Image::ExifTool::XMP::tiff = (
    GROUPS => { 1 => 'XMP-tiff', 2 => 'Image' },
    NAMESPACE => 'tiff',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'EXIF schema for TIFF tags.',
    ImageWidth  => { Writable => 'integer' },
    ImageLength => {
        Name => 'ImageHeight',
        Writable => 'integer',
    },
    BitsPerSample => { Writable => 'integer', List => 'Seq' },
    Compression => {
        Writable => 'integer',
        PrintConv => \%Image::ExifTool::Exif::compression,
    },
    PhotometricInterpretation => {
        Writable => 'integer',
        PrintConv => \%Image::ExifTool::Exif::photometricInterpretation,
    },
    Orientation => {
        Writable => 'integer',
        PrintConv => \%Image::ExifTool::Exif::orientation,
    },
    SamplesPerPixel => { Writable => 'integer' },
    PlanarConfiguration => {
        Writable => 'integer',
        PrintConv => {
            1 => 'Chunky',
            2 => 'Planar',
        },
    },
    YCbCrSubSampling => {
        PrintConv => {
            '1 1' => 'YCbCr4:4:4',
            '2 1' => 'YCbCr4:2:2',
            '2 2' => 'YCbCr4:2:0',
            '4 1' => 'YCbCr4:1:1',
            '4 2' => 'YCbCr4:1:0',
            '1 2' => 'YCbCr4:4:0',
        },
    },
    YCbCrPositioning => {
        Writable => 'integer',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
    },
    XResolution => { Writable => 'rational' },
    YResolution => { Writable => 'rational' },
    ResolutionUnit => {
        Writable => 'integer',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    TransferFunction      => { Writable => 'integer',  List => 'Seq' },
    WhitePoint            => { Writable => 'rational', List => 'Seq' },
    PrimaryChromaticities => { Writable => 'rational', List => 'Seq' },
    YCbCrCoefficients     => { Writable => 'rational', List => 'Seq' },
    ReferenceBlackWhite   => { Writable => 'rational', List => 'Seq' },
    DateTime => {
        Description => 'Date/Time Modified',
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ImageDescription => { Writable => 'lang-alt' },
    Make  => { Groups => { 2 => 'Camera' } },
    Model => {
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
    },
    Software  => { },
    Artist    => { Groups => { 2 => 'Author' } },
    Copyright => {
        Groups => { 2 => 'Author' },
        Writable => 'lang-alt',
    },
    NativeDigest => { }, #PH
);

# Exif schema properties (exif)
%Image::ExifTool::XMP::exif = (
    GROUPS => { 1 => 'XMP-exif', 2 => 'Image' },
    NAMESPACE => 'exif',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'EXIF schema for EXIF tags.',
    ExifVersion     => { },
    FlashpixVersion => { },
    ColorSpace => {
        Writable => 'integer',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
            0xffffffff => 'Uncalibrated',
        },
    },
    ComponentsConfiguration => {
        List => 'Seq',
        Writable => 'integer',
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
        Writable => 'rational',
    },
    PixelXDimension => {
        Name => 'ExifImageWidth',
        Writable => 'integer',
    },
    PixelYDimension => {
        Name => 'ExifImageLength',
        Writable => 'integer',
    },
    MakerNote => { },
    UserComment => {
        Writable => 'lang-alt',
    },
    RelatedSoundFile => { },
    DateTimeOriginal => {
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    DateTimeDigitized => {
        Description => 'Date/Time Digitized',
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ExposureTime => {
        Writable => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    FNumber => {
        Writable => 'rational',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    ExposureProgram => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
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
    },
    OECF => {
        Name => 'Opto-ElectricConvFactor',
        Groups => { 2 => 'Camera' },
        SubDirectory => { },
        Struct => 'OECF',
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
        Writable => 'rational',
        ValueConv => 'abs($val)<100 ? 1/(2**$val) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : 0',
        # do eval to convert things like '1/100'
        PrintConvInv => 'eval $val',
    },
    ApertureValue => {
        Writable => 'rational',
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    BrightnessValue => {
        Writable => 'rational',
    },
    ExposureBiasValue => {
        Name => 'ExposureCompensation',
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
        Writable => 'integer',
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
    Flash => {
        Groups => { 2 => 'Camera' },
        SubDirectory => { },
        Struct => 'Flash',
    },
    FlashFired => {
        Groups => { 2 => 'Camera' },
        Writable => 'boolean',
    },
    FlashReturn => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'No return detection',
            2 => 'Return not detected',
            3 => 'Return detected',
        },
    },
    FlashMode => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
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
        Writable => 'integer',
        List => 'Seq',
    },
    FlashEnergy => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
    },
    SpatialFrequencyResponse => {
        Groups => { 2 => 'Camera' },
        SubDirectory => { },
        Struct => 'OECF',
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
        Writable => 'integer',
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
        Writable => 'integer',
        List => 'Seq',
    },
    ExposureIndex => {
        Writable => 'rational',
    },
    SensingMethod => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
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
    FileSource => { Writable => 'integer', PrintConv => { 3 => 'Digital Camera' } },
    SceneType  => { Writable => 'integer', PrintConv => { 1 => 'Directly photographed' } },
    CFAPattern => {
        SubDirectory => { },
        Struct => 'CFAPattern',
    },
    CFAPatternColumns   => { Writable => 'integer' },
    CFAPatternRows      => { Writable => 'integer' },
    CFAPatternValues    => { List => 'Seq', Writable => 'integer' },
    CustomRendered => {
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Custom',
        },
    },
    ExposureMode => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
            2 => 'Auto bracket',
        },
    },
    WhiteBalance => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    DigitalZoomRatio => { Writable => 'rational' },
    FocalLengthIn35mmFilm => {
        Name => 'FocalLengthIn35mmFormat',
        Writable => 'integer',
        Groups => { 2 => 'Camera' },
    },
    SceneCaptureType => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Landscape',
            2 => 'Portrait',
            3 => 'Night',
        },
    },
    GainControl => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'None',
            1 => 'Low gain up',
            2 => 'High gain up',
            3 => 'Low gain down',
            4 => 'High gain down',
        },
    },
    Contrast => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    Saturation => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    Sharpness => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    DeviceSettingDescription => {
        Groups => { 2 => 'Camera' },
        SubDirectory => { },
        Struct => 'DeviceSettings',
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
        Writable => 'integer',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Macro',
            2 => 'Close',
            3 => 'Distant',
        },
    },
    ImageUniqueID   => { },
    GPSVersionID    => { Groups => { 2 => 'Location' } },
    GPSLatitude     => { Groups => { 2 => 'Location' }, %latConv },
    GPSLongitude    => { Groups => { 2 => 'Location' }, %longConv },
    GPSAltitudeRef  => {
        Groups => { 2 => 'Location' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    GPSAltitude     => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
        PrintConv => '"$val metres"',
        PrintConvInv => '$val=~s/\s*m.*//;$val',
    },
    GPSTimeStamp    => {
        Groups => { 2 => 'Time' },
        Writable => 'date',
        Shift => 'Time',
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
    GPSMeasureMode => {
        Groups => { 2 => 'Location' },
        Writable => 'integer',
        PrintConv => {
            2 => '2-Dimensional',
            3 => '3-Dimensional',
        },
    },
    GPSDOP => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
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
    GPSDestLatitude => { Groups => { 2 => 'Location' }, %latConv },
    GPSDestLongitude=> { Groups => { 2 => 'Location' }, %longConv },
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
        Writable => 'integer',
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
    NativeDigest => { }, #PH
);

# Auxiliary schema properties (aux) - not fully documented
%Image::ExifTool::XMP::aux = (
    GROUPS => { 1 => 'XMP-aux', 2 => 'Camera' },
    NAMESPACE => 'aux',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'Photoshop Auxiliary schema tags.',
    Firmware        => { }, #7
    FlashCompensation => { Writable => 'rational' }, #7
    ImageNumber     => { }, #7
    LensInfo        => { }, #7
    Lens            => { },
    OwnerName       => { }, #7
    SerialNumber    => { },
);

# IPTC Core schema properties (Iptc4xmpCore)
%Image::ExifTool::XMP::iptcCore = (
    GROUPS => { 1 => 'XMP-iptcCore', 2 => 'Author' },
    NAMESPACE => 'Iptc4xmpCore',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => q{
        IPTC Core schema tags.  The actual IPTC Core namespace schema prefix is
        "Iptc4xmpCore", which is the prefix recorded in the file, but ExifTool
        shortens this for the "XMP-iptcCore" family 1 group name.
    },
    CountryCode         => { Groups => { 2 => 'Location' } },
    CreatorContactInfo => {
        SubDirectory => { },
        Struct => 'ContactInfo',
    },
    CreatorContactInfoCiAdrCity   => { Description => 'Creator City' },
    CreatorContactInfoCiAdrCtry   => { Description => 'Creator Country' },
    CreatorContactInfoCiAdrExtadr => { Description => 'Creator Address' },
    CreatorContactInfoCiAdrPcode  => { Description => 'Creator Postal Code' },
    CreatorContactInfoCiAdrRegion => { Description => 'Creator Region' },
    CreatorContactInfoCiEmailWork => { Description => 'Creator Work Email' },
    CreatorContactInfoCiTelWork   => { Description => 'Creator Work Telephone' },
    CreatorContactInfoCiUrlWork   => { Description => 'Creator Work URL' },
    IntellectualGenre   => { Groups => { 2 => 'Other' } },
    Location            => { Groups => { 2 => 'Location' } },
    Scene               => { Groups => { 2 => 'Other' }, List => 'Bag' },
    SubjectCode         => { Groups => { 2 => 'Other' }, List => 'Bag' },
);

# PixelLive schema properties (PixelLive) (ref 3)
%Image::ExifTool::XMP::PixelLive = (
    GROUPS => { 1 => 'XMP-PixelLive', 2 => 'Image' },
    NAMESPACE => 'PixelLive',
    WRITE_PROC => \&WriteXMP,
    NOTES => q{
        PixelLive schema tags.  These tags are not writable becase they are very
        uncommon and I haven't been able to locate a reference which gives the
        namespace URI.
    },
    AUTHOR    => { Name => 'Author',   Avoid => 1, Groups => { 2 => 'Author'} },
    COMMENTS  => { Name => 'Comments', Avoid => 1 },
    COPYRIGHT => { Name => 'Copyright',Avoid => 1, Groups => { 2 => 'Author'} },
    DATE      => { Name => 'Date',     Avoid => 1, Groups => { 2 => 'Time'} },
    GENRE     => { Name => 'Genre',    Avoid => 1 },
    TITLE     => { Name => 'Title',    Avoid => 1 },
);

# Picture Licensing Universal System schema properties (xmpPLUS)
%Image::ExifTool::XMP::xmpPLUS = (
    GROUPS => { 1 => 'XMP-xmpPLUS', 2 => 'Author' },
    NAMESPACE => 'xmpPLUS',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'XMP Picture Licensing Universal System (PLUS) schema tags.',
    CreditLineReq   => { Writable => 'boolean' },
    ReuseAllowed    => { Writable => 'boolean' },
);

# Creative Commons schema properties (cc) (ref 5)
%Image::ExifTool::XMP::cc = (
    GROUPS => { 1 => 'XMP-cc', 2 => 'Author' },
    NAMESPACE => 'cc',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => 'Creative Commons schema tags.',
    license => { },
);

# Description Explorer schema properties (dex) (ref 6)
%Image::ExifTool::XMP::dex = (
    GROUPS => { 1 => 'XMP-dex', 2 => 'Image' },
    NAMESPACE => 'dex',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => q{
        Description Explorer schema tags.  These tags are not very common.  The
        Source and Rating tags are avoided when writing due to name conflicts with
        other XMP tags.
    },
    crc32       => { Name => 'CRC32', Writable => 'integer' },
    source      => { Avoid => 1 },
    shortdescription => {
        Name => 'ShortDescription',
        Writable => 'lang-alt',
    },
    licensetype => {
        Name => 'LicenseType',
        PrintConv => {
            unknown        => 'Unknown',
            shareware      => 'Shareware',
            freeware       => 'Freeware',
            adware         => 'Adware',
            demo           => 'Demo',
            commercial     => 'Commercial',
           'public domain' => 'Public Domain',
           'open source'   => 'Open Source',
        },
    },
    revision    => { },
    rating      => { Avoid => 1 },
    os          => { Name => 'OS', Writable => 'integer' },
    ffid        => { Name => 'FFID' },
);

# Microsoft Photo schema properties (MicrosoftPhoto) (ref PH)
%Image::ExifTool::XMP::Microsoft = (
    GROUPS => { 1 => 'XMP-microsoft', 2 => 'Image' },
    NAMESPACE => 'MicrosoftPhoto',
    WRITE_PROC => \&WriteXMP,
    WRITABLE => 'string',
    NOTES => q{
        Microsoft Photo schema tags.  This is likely not a complete list, but
        represents tags which have been observed in sample images.  The actual
        namespace prefix is "MicrosoftPhoto", but ExifTool shortens this to
        "XMP-microsoft" in the group1 family name.
    },
    CameraSerialNumber => { },
    DateAcquired => {
        Groups => { 2 => 'Time'  },
        Writable => 'date',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    FlashManufacturer  => { },
    FlashModel         => { },
    LastKeywordIPTC    => { List => 'Bag' },
    LastKeywordXMP     => { List => 'Bag' },
    LensManufacturer   => { },
    LensModel          => { },
    Rating => {
        Name => 'RatingPercent',
        Notes => q{
            normal Rating values of 1,2,3,4 and 5 stars correspond to RatingPercent
            values of 1,25,50,75 and 99 respectively
        },
    },
);

# table to add tags in other namespaces
%Image::ExifTool::XMP::other = (
    GROUPS => { 2 => 'Unknown' },
);

# Composite XMP tags
%Image::ExifTool::XMP::Composite = (
    # get latitude/logitude reference from XMP lat/long tags
    # (used to set EXIF GPS position from XMP tags)
    GPSLatitudeRef => {
        Require => {
            0 => 'XMP:GPSLatitude',
        },
        ValueConv => '$val[0] < 0 ? "S" : "N"',
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    GPSLongitudeRef => {
        Require => {
            0 => 'XMP:GPSLongitude',
        },
        ValueConv => '$val[0] < 0 ? "W" : "E"',
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::XMP');

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
    s/'/&#39;/sg;
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
    s/&#39;/'/sg;
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
# Returns: tagID and outtermost interesting namespace
sub GetXMPTagID($)
{
    my $props = shift;
    my ($tag, $prop, $namespace);
    foreach $prop (@$props) {
        # split name into namespace and property name
        # (Note: namespace can be '' for property qualifiers)
        my ($ns, $nm) = ($prop =~ /(.*?):(.*)/) ? ($1, $2) : ('', $prop);
        $nm =~ s/ .*//;     # remove nodeID if it exists
        if ($ignoreNamespace{$ns}) {
            # special case: don't ignore rdf numbered items
            next unless $prop =~ /^rdf:(_\d+)$/;
            $tag .= $1;
        } else {
            # all uppercase is ugly, so convert it
            if ($nm !~ /[a-z]/) {
                my $xlatNS = $xlatNamespace{$ns} || $ns;
                my $info = $Image::ExifTool::XMP::Main{$xlatNS};
                my $table;
                if (ref $info eq 'HASH' and $info->{SubDirectory}) {
                    $table = GetTagTable($info->{SubDirectory}->{TagTable});
                }
                unless ($table and $table->{$nm}) {
                    $nm = lc($nm);
                    $nm =~ s/_([a-z])/\u$1/g;
                }
            }
            if (defined $tag) {
                $tag .= ucfirst($nm);       # add to tag name
            } else {
                $tag = $nm;
            }
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
# Returns: 1 if valid tag was found
sub FoundXMP($$$$)
{
    local $_;
    my ($exifTool, $tagTablePtr, $props, $val) = @_;

    my ($tag, $namespace) = GetXMPTagID($props);
    return 0 unless $tag;   # ignore things that aren't valid tags

    # translate namespace if necessary
    $namespace = $xlatNamespace{$namespace} if $xlatNamespace{$namespace};
    my $info = $tagTablePtr->{$namespace};
    my $table;
    if ($info) {
        $table = $info->{SubDirectory}->{TagTable} or warn "Missing TagTable for $tag!\n";
    } else {
        $table = 'Image::ExifTool::XMP::other';
    }
    # change pointer to the table for this namespace
    $tagTablePtr = GetTagTable($table);

    # convert quotient and date values to a more sensible format
    if ($val =~ m{^(-?\d+)/(-?\d+)$}) {
        $val = $1 / $2 if $2;       # calculate quotient
    } elsif ($val =~ /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}:\d{2})(:\d{2})?(\S*)$/) {
        my $s = $5 || ':00';        # seconds may be missing
        $val = "$1:$2:$3 $4$s$6";   # convert back to EXIF time format
    } elsif ($exifTool->{OPTIONS}->{Charset} eq 'Latin' and $val =~ /[\x80-\xff]/) {
        # convert from UTF-8 to Latin
        $val = Image::ExifTool::UTF82Unicode($val,'n',$exifTool);
        $val = Image::ExifTool::Unicode2Latin($val,'n',$exifTool);
    }
    # look up this tag in the appropriate table
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
    unless ($tagInfo) {
        if ($exifTool->{OPTIONS}->{Verbose}) {
            my $group1 = $namespace ? "XMP-$namespace" : $tagTablePtr->{GROUPS}->{1};
            $exifTool->VPrint(0, $exifTool->{INDENT}, "[adding $group1:$tag]\n");
        }
        # construct tag information for this unknown tag
        $tagInfo = { Name => ucfirst($tag) };
        Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
    $tag = $exifTool->FoundTag($tagInfo, UnescapeHTML($val));
    $exifTool->SetGroup1($tag, "XMP-$namespace") if $namespace;

    if ($exifTool->Options('Verbose')) {
        my $tagID = join('/',@$props);
        $exifTool->VerboseInfo($tagID, $tagInfo, Value=>$val);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Recursively parse nested XMP data element
# Inputs: 0) ExifTool object reference
#         1) Pointer to tag table
#         2) reference to XMP data
#         3) start of xmp element
#         4) reference to array of enclosing XMP property names (undef if none)
#         5) reference to blank node information hash
# Returns: Number of contained XMP elements
sub ParseXMPElement($$$;$$$)
{
    my ($exifTool, $tagTablePtr, $dataPt, $start, $propListPt, $blankInfo) = @_;
    my $count = 0;
    my $isWriting = $exifTool->{XMP_CAPTURE};
    $start or $start = 0;
    $propListPt or $propListPt = [ ];

    my $processBlankInfo;
    # create empty blank node information hash if necessary
    $blankInfo or $blankInfo = $processBlankInfo = { Prop => { } };
    # keep track of current nodeID at this nesting level
    my $oldNodeID = $$blankInfo{NodeID};

    pos($$dataPt) = $start;
    Element: for (;;) {
        # reset nodeID before processing each element
        my $nodeID = $$blankInfo{NodeID} = $oldNodeID;
        # get next element
        last unless $$dataPt =~ m/<([\w:-]+)(.*?)>/sg;
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
        if ($prop eq 'rdf:li') {
            # add index to list items so we can keep them in order
            # (this also enables us to keep structure elements grouped properly
            # for lists of structures, like JobRef)
            $prop .= sprintf(' %.3d', $count);
        } elsif ($prop eq 'rdf:Description') {
            # trim comments and whitespace from rdf:Description properties only
            $val =~ s/<!--.*?-->//g;
            $val =~ s/^\s*(.*)\s*$/$1/;
        } elsif ($prop eq 'xmp:xmpmeta') {
            # patch MicrosoftPhoto unconformity
            $prop = 'x:xmpmeta';
        }

        # extract property attributes
        my (%attrs, @attrs);
        while ($attrs =~ m/(\S+)=(['"])(.*?)\2/sg) {
            push @attrs, $1;    # preserve order
            $attrs{$1} = $3;
        }

        # add nodeID to property path (with leading ' #') if it exists
        if (defined $attrs{'rdf:nodeID'}) {
            $nodeID = $$blankInfo{NodeID} = $attrs{'rdf:nodeID'};
            delete $attrs{'rdf:nodeID'};
            $prop .= ' #' . $nodeID;
        }

        # push this property name onto our hierarchy list
        push @$propListPt, $prop;

        # handle properties inside element attributes (RDF shorthand format):
        # (attributes take the form a:b='c' or a:b="c")
        my ($shortName, $shorthand, $ignored);
        foreach $shortName (@attrs) {
            my $propName = $shortName;
            my ($ns, $name);
            if ($propName =~ /(.*?):(.*)/) {
                $ns = $1;   # specified namespace
                $name = $2;
            } elsif ($prop =~ /(\S*?):/) {
                $ns = $1;   # assume same namespace as parent
                $name = $propName;
                $propName = "$ns:$name";    # generate full property name
            } else {
                # a property qualifier is the only property name that may not
                # have a namespace, and a qualifier shouldn't have attributes,
                # but what the heck, let's allow this anyway
                $ns = '';
                $name = $propName;
            }
            if ($isWriting) {
                # keep track of our namespaces when writing
                if ($ns eq 'xmlns') {
                    unless ($name eq 'x' or $name eq 'iX') {
                        my $nsUsed = $exifTool->{XMP_NS};
                        $$nsUsed{$name} = $attrs{$shortName} unless defined $$nsUsed{$name};
                    }
                    next;
                } elsif ($recognizedAttrs{$propName}) {
                    # save UUID to use same ID when writing
                    if ($propName eq 'rdf:about') {
                        if (not $exifTool->{XMP_UUID}) {
                            $exifTool->{XMP_UUID} = $attrs{$shortName};
                        } elsif ($exifTool->{XMP_UUID} ne $attrs{$shortName}) {
                            $exifTool->Error("Multiple XMP UUID's not handled", 1);
                        }
                    }
                    next;
                }
            }
            if ($ignoreNamespace{$ns}) {
                $ignored = $propName;
                next;
            }
            my $shortVal = $attrs{$shortName};
            delete $attrs{$shortName};  # don't re-use this attribute
            push @$propListPt, $propName;
            # save this shorthand XMP property
            if (defined $nodeID) {
                SaveBlankInfo($blankInfo, $propListPt, $shortVal);
            } elsif ($isWriting) {
                CaptureXMP($exifTool, $propListPt, $shortVal);
            } else {
                FoundXMP($exifTool, $tagTablePtr, $propListPt, $shortVal);
            }
            pop @$propListPt;
            $shorthand = 1;
        }
        if ($isWriting) {
            if (ParseXMPElement($exifTool, $tagTablePtr, \$val, 0, $propListPt, $blankInfo)) {
                # undefine value since we found more properties within this one
                undef $val;
                # set an error on any ignored attributes here, because they will be lost
                $exifTool->{XMP_ERROR} = "Can't handle XMP attribute '$ignored'" if $ignored;
            }
            if (defined $val and (length $val or not $shorthand)) {
                if (defined $nodeID) {
                    SaveBlankInfo($blankInfo, $propListPt, $val, \%attrs);
                } else {
                    CaptureXMP($exifTool, $propListPt, $val, \%attrs);
                }
            }
        } else {
            # if element value is empty, take value from 'resource' attribute
            # (preferentially) or 'about' attribute (if no 'resource')
            $val = $2 if $val eq '' and ($attrs =~ /\bresource=(['"])(.*?)\1/ or
                                         $attrs =~ /\babout=(['"])(.*?)\1/);

            # look for additional elements contained within this one
            if (!ParseXMPElement($exifTool, $tagTablePtr, \$val, 0, $propListPt, $blankInfo)) {
                # there are no contained elements, so this must be a simple property value
                # (unless we already extracted shorthand values from this element)
                if (length $val or not $shorthand) {
                    if (defined $nodeID) {
                        SaveBlankInfo($blankInfo, $propListPt, $val);
                    } else {
                        FoundXMP($exifTool, $tagTablePtr, $propListPt, $val);
                    }
                }
            }
        }
        pop @$propListPt;
        ++$count;
    }
#
# process resources referenced by blank nodeID's
#
    if ($processBlankInfo and %{$$blankInfo{Prop}}) {
        ProcessBlankInfo($exifTool, $tagTablePtr, $blankInfo, $isWriting);
        %$blankInfo = ();   # free some memory
    }
    return $count;  # return the number of elements found at this level
}

#------------------------------------------------------------------------------
# Process XMP data
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
sub ProcessXMP($$;$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen};
    my $dataLen = $$dirInfo{DataLen};
    my $rtnVal = 0;
    my $bom = 0;
    my ($buff, $fmt, $isXML);

    # read information from XMP file if necessary
    unless ($dataPt) {
        my $raf = $$dirInfo{RAF} or return 0;
        $raf->Read($buff, 128) or return 0;
        my $buf2;
        ($buf2 = $buff) =~ tr/\0//d;    # cheap conversion to UTF-8
        # check to see if this is XMP format
        # - CS2 writes .XMP files without the "xpacket begin"
        unless ($buf2 =~ /^(<\?xpacket begin=|<x(mp)?:xmpmeta)/) {
            # also recognize XML files (and .XMP files with BOM)
            if ($buf2 =~ /^(\xfe\xff)(<\?xml|<x(mp)?:xmpmeta)/g) {
                $fmt = 'n';     # UTF-16 or 32 MM with BOM
            } elsif ($buf2 =~ /^(\xff\xfe)(<\?xml|<x(mp)?:xmpmeta)/g) {
                $fmt = 'v';     # UTF-16 or 32 II with BOM
            } elsif ($buf2 =~ /^(\xef\xbb\xbf)?(<\?xml|<x(mp)?:xmpmeta)/g) {
                $fmt = 0;       # UTF-8 with BOM or unknown encoding without BOM
            } else {
                return 0;       # not XMP or XML
            }
            $bom = 1 if $1;
            if ($2 eq '<?xml') {
                return 0 unless $buf2 =~ /<x(mp)?:xmpmeta/;
                $isXML = 1;
            }
            if ($buff =~ /^\0\0/) {
                $fmt = 'N';     # UTF-32 MM with or without BOM
            } elsif ($buff =~ /^..\0\0/) {
                $fmt = 'V';     # UTF-32 II with or without BOM
            } elsif (not $fmt) {
                if ($buff =~ /^\0/) {
                    $fmt = 'n'; # UTF-16 MM without BOM
                } elsif ($buff =~ /^.\0/) {
                    $fmt = 'v'; # UTF-16 II without BOM
                }
            }
        }
        $raf->Seek(0, 2) or return 0;
        my $size = $raf->Tell() or return 0;
        $raf->Seek(0, 0) or return 0;
        $raf->Read($buff, $size) == $size or return 0;
        $dataPt = \$buff;
        $dirStart = 0;
        $dirLen = $dataLen = $size;
        $exifTool->SetFileType();
    }
    
    # take substring if necessary
    if ($dataLen != $dirStart + $dirLen) {
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
    delete $$exifTool{XMP_IS_XML};
    if ($isXML) {
        $$exifTool{XMP_IS_XML} = 1;
        $$exifTool{XMP_NO_XPACKET} = 1 + $bom;
    } elsif ($$dataPt =~ /\G\Q$begin\E/) {
        delete $$exifTool{XMP_NO_XPACKET};
    } elsif ($$dataPt =~ /<x(mp)?:xmpmeta/) {
        $$exifTool{XMP_NO_XPACKET} = 1 + $bom;
    } else {
        delete $$exifTool{XMP_NO_XPACKET};
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
        defined $fmt or $exifTool->Warn('XMP character encoding error');
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
    }
#
# extract the information
#
    $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
    $rtnVal = 1 if ParseXMPElement($exifTool, $tagTablePtr, $dataPt, $dirStart);
    # return DataPt if successful in case we want it for writing
    $$dirInfo{DataPt} = $dataPt if $rtnVal and $$dirInfo{RAF};
    return $rtnVal;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::XMP - Read XMP meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

XMP stands for Extensible Metadata Platform.  It is a format based on XML
that Adobe developed for embedding metadata information in image files.
This module contains the definitions required by Image::ExifTool to read XMP
information.

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf>

=item L<http://www.w3.org/TR/rdf-syntax-grammar/>

=item L<http://www.portfoliofaq.com/pfaq/v7mappings.htm>

=item L<http://www.iptc.org/IPTC4XMP/>

=item L<http://creativecommons.org/technology/xmp>

=item L<http://www.optimasc.com/products/fileid/xmp-extensions.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
