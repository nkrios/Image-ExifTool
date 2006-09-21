#------------------------------------------------------------------------------
# File:         MIE.pm
#
# Description:  Read/write MIE meta information
#
# Revisions:    11/18/2005 - P. Harvey Created
#
# Notes:        The following command line will create a MIE file from any other
#               recognized file type.
#
#                 exiftool -o new.mie -tagsfromfile SRC "-mie:all<all" \
#                    "-subfilename<filename" "-subfiletype<filetype" \
#                    "-subfilemimetype<mimetype" "-subfile<=SRC"
#
#               For unrecognized file types, this command may be used:
#
#                 exiftool -o new.mie "-subfilename<SRC" "-subfiletype<TYPE" \
#                    "-subfilemimetype<MIME" "-subfile<=SRC"
#
#               where SRC, TYPE and MIME represent the source file name, file
#               type and MIME type respectively.
#------------------------------------------------------------------------------

# things to document:
# - MIE tags (with note about flexibility of format types)
# - BOM is optional in UTF strings (order taken from group byte ordering)

package Image::ExifTool::MIE;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '0.21';

sub ProcessMIEGroup($$$);
sub WriteMIEGroup($$$);
sub GetLangInfo($$);

# local variables
my $hasZlib;        # 1=Zlib available, 0=no Zlib
my %mieCode;        # reverse lookup for MIE format names

# MIE format codes
my %mieFormat = (
    0x00 => 'undef',
    0x10 => 'MIE',
    0x18 => 'MIE',
    0x20 => 'string', # ASCII
    0x28 => 'utf8',
    0x29 => 'utf16',
    0x2a => 'utf32',
    0x30 => 'string_list',
    0x38 => 'utf8_list',
    0x39 => 'utf16_list',
    0x3a => 'utf32_list',
    0x40 => 'int8u',
    0x41 => 'int16u',
    0x42 => 'int32u',
    0x43 => 'int64u',
    0x48 => 'int8s',
    0x49 => 'int16s',
    0x4a => 'int32s',
    0x4b => 'int64s',
    0x52 => 'rational32u',
    0x53 => 'rational64u',
    0x5a => 'rational32s',
    0x5b => 'rational64s',
    0x61 => 'fixed16u',
    0x62 => 'fixed32u',
    0x69 => 'fixed16s',
    0x6a => 'fixed32s',
    0x72 => 'float',
    0x73 => 'double',
    0x80 => 'free',
);

# map of MIE directory locations
my %mieMap = (
   'MIE-Meta'       => 'MIE',
   'MIE-Audio'      => 'MIE-Meta',
   'MIE-Camera'     => 'MIE-Meta',
   'MIE-Doc'        => 'MIE-Meta',
   'MIE-Geo'        => 'MIE-Meta',
   'MIE-Image'      => 'MIE-Meta',
   'MIE-MakerNotes' => 'MIE-Meta',
   'MIE-Preview'    => 'MIE-Meta',
   'MIE-Thumbnail'  => 'MIE-Meta',
   'MIE-Video'      => 'MIE-Meta',
   'MIE-Extender'   => 'MIE-Camera',
   'MIE-Flash'      => 'MIE-Camera',
   'MIE-Lens'       => 'MIE-Camera',
    EXIF            => 'MIE-Meta',
    XMP             => 'MIE-Meta',
    IPTC            => 'MIE-Meta',
    ICC_Profile     => 'MIE-Meta',
    ID3             => 'MIE-Meta',
    IFD0            => 'EXIF',
    IFD1            => 'IFD0',
    ExifIFD         => 'IFD0',
    GPS             => 'IFD0',
    SubIFD          => 'IFD0',
    GlobParamIFD    => 'IFD0',
    PrintIM         => 'IFD0',
    InteropIFD      => 'ExifIFD',
    MakerNotes      => 'ExifIFD',
);

# convenience variables for common tagInfo entries
my %binaryConv = (
    Writable => 'undef',
    ValueConv => '\$val',
    ValueConvInv => '$val',
);
my %dateConv = (
    Shift => 'Time',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$val',
);
my %noYes = ( 0 => 'No', 1 => 'Yes' );
my %offOn = ( 0 => 'Off', 1 => 'On' );

# MIE info
%Image::ExifTool::MIE::Main = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Main' },
    WRITE_GROUP => 'MIE-Main',
    WRITABLE => 'string',
    PREFERRED => 1,
    NOTES => q{
        MIE is flexible format which may be used as either a standalone meta
        information format, or for encapsulation of any other file type.  The tables
        below represent currently defined MIE tags, however ExifTool will also
        extract any other information present in a MIE file.
    },
   '0Type' => {
        Name => 'SubfileType',
        Notes => q{
            Currently defined types are ACR, AIFC, AIFF, ASF, AVI, BMP, CR2, CRW, DICOM,
            DNG, EPS, ERF, GIF, ICC, JNG, JP2, JPEG, MIE, MIFF, MNG, MOS, MOV, MP3, MP4,
            MPEG, MRW, NEF, ORF, PBM, PDF, PGM, PICT, PNG, PPM, PS, PSD, QTIF, RAF, RAW,
            RIFF, SR2, SRF, TIFF, WAV, WMA, WMV, X3F and XMP.  Other types should use
            the common file extension.
        },
    },
   '1Directory' => { Name => 'SubfileDirectory' },
   '1Name'      => { Name => 'SubfileName' },
   '2MIME'      => { Name => 'SubfileMIMEType' },
    Meta => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Meta',
            DirName => 'MIE-Meta',
        },
    },
    data => {
        Name => 'Subfile',
        Notes => 'the subfile data',
        %binaryConv,
    },
    resource => {
        Name => 'SubfileResource',
        Notes => 'subfile resource fork if it exists',
        %binaryConv,
    },
);

# MIE meta information group
%Image::ExifTool::MIE::Meta = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Meta', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Meta',
    WRITABLE => 'string',
    PREFERRED => 1,
    Audio       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Audio', DirName => 'MIE-Audio' } },
    Camera      => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Camera', DirName => 'MIE-Camera' } },
    Document    => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Doc', DirName => 'MIE-Doc' } },
    EXIF => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    Geo         => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Geo', DirName => 'MIE-Geo' } },
    ICCProfile  => { Name => 'ICC_Profile', SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' } },
    ID3         => { SubDirectory => { TagTable => 'Image::ExifTool::ID3::Main' } },
    IPTC        => { SubDirectory => { TagTable => 'Image::ExifTool::IPTC::Main' } },
    Image       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Image', DirName => 'MIE-Image' } },
    MakerNotes  => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::MakerNotes', DirName => 'MIE-MakerNotes' } },
    Preview     => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Preview', DirName => 'MIE-Preview' } },
    Thumbnail   => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Thumbnail', DirName => 'MIE-Thumbnail' } },
    Video       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Video', DirName => 'MIE-Video' } },
    XMP         => { SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' } },
);

# MIE document information
%Image::ExifTool::MIE::Doc = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Doc', 2 => 'Document' },
    WRITE_GROUP => 'MIE-Doc',
    WRITABLE => 'string',
    PREFERRED => 1,
    NOTES => 'Information describing the main document, image or file.',
    Author      => { Groups => { 2 => 'Author' } },
    Comment     => { },
    Contributors=> { Groups => { 2 => 'Author' }, List => 1 },
    Copyright   => { Groups => { 2 => 'Author' } },
    CreateDate  => { %dateConv, Groups => { 2 => 'Time' } },
    Keywords    => { List => 1 },
    ModifyDate  => { %dateConv, Groups => { 2 => 'Time' } },
    OriginalDate=> { Name => 'DateTimeOriginal', %dateConv, Groups => { 2 => 'Time' } },
    References  => { List => 1 },
    Software    => { },
    Title       => { },
    URL         => { },
);

# MIE geographic information
%Image::ExifTool::MIE::Geo = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Geo', 2 => 'Location' },
    WRITE_GROUP => 'MIE-Geo',
    WRITABLE => 'string',
    PREFERRED => 1,
    NOTES => 'Information describing geographic location.',
    Address     => { },
    City        => { },
    Country     => { },
    Elevation   => { Writable => 'rational64s', Notes => 'm above sea level' },
    Latitude => {
        Notes => 'degrees, negative for south latitudes',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
    },
    Longitude => {
        Notes => 'degrees, negative for west longitudes',
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val)',
        ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
    },
    State       => { },
);

# MIE image information
%Image::ExifTool::MIE::Image = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Image', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Image',
    WRITABLE => 'string',
    PREFERRED => 1,
   '0Type'          => { Name => 'FullSizeImageType', Notes => 'JPEG if not specified' },
   '1Name'          => { Name => 'FullSizeImageName' },
    BitDepth        => { Name => 'BitDepth', Writable => 'int16u' },
    ColorSpace      => { Notes => 'standard ColorSpace values are "sRGB" and "Adobe RGB"' },
    Components      => { Name => 'ComponentsConfiguration', Notes => 'string composed of R, G, B, Y, Cb and Cr' },
    Compression     => { Name => 'CompressionRatio', Writable => 'rational32u' },
    ImageSize       => {
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    Resolution      => { Writable => 'rational64u', Count => -1, Notes => '2 or 3 values for XY or XYZ resolution' },
    ResolutionUnits => { Writable => 'int16u', PrintConv => { 0 => 'none', 1 => 'inches', 2 => 'cm' } },
    data => {
        Name => 'FullSizeImage',
        %binaryConv,
        ValueConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE preview image
%Image::ExifTool::MIE::Preview = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Preview', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Preview',
    WRITABLE => 'string',
    PREFERRED => 1,
   '0Type'  => { Name => 'PreviewImageType', Notes => 'JPEG if not specified' },
   '1Name'  => { Name => 'PreviewImageName' },
    ImageSize => {
        Name => 'PreviewImageSize',
        Writable => 'int16u',
        Count => -1,
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'PreviewImage',
        %binaryConv,
        ValueConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE thumbnail image
%Image::ExifTool::MIE::Thumbnail = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Thumbnail', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Thumbnail',
    WRITABLE => 'string',
    PREFERRED => 1,
   '0Type'  => { Name => 'ThumbnailImageType', Notes => 'JPEG if not specified' },
   '1Name'  => { Name => 'ThumbnailImageName' },
    ImageSize => {
        Name => 'ThumbnailImageSize',
        Writable => 'int16u',
        Count => -1,
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'ThumbnailImage',
        %binaryConv,
        ValueConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE audio information
%Image::ExifTool::MIE::Audio = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Audio', 2 => 'Audio' },
    WRITE_GROUP => 'MIE-Audio',
    WRITABLE => 'string',
    PREFERRED => 1,
    NOTES => q{
        For the Audio group (and any other group containing a 'data' element), tags
        refer to the contained data if present, otherwise they refer to the main
        Subfile data.  The '0Type' and '1Name' elements should exist only if 'data'
        is present.
    },
   '0Type'      => { Name => 'RelatedAudioFileType', Notes => 'MP3 if not specified' },
   '1Name'      => { Name => 'RelatedAudioFileName' },
    SampleBits  => { Writable => 'int16u' },
    Channels    => { Writable => 'int8u' },
    Compression => { Name => 'AudioCompression' },
    Duration    => { Writable => 'rational64u' },
    SampleRate  => { Writable => 'int32u' },
    data        => { Name => 'RelatedAudioFile', %binaryConv },
);

# MIE video information
%Image::ExifTool::MIE::Video = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Video', 2 => 'Video' },
    WRITE_GROUP => 'MIE-Video',
    WRITABLE => 'string',
    PREFERRED => 1,
   '0Type'      => { Name => 'RelatedVideoFileType', Notes => 'MOV if not specified' },
   '1Name'      => { Name => 'RelatedVideoFileName' },
    Codec       => { },
    Duration    => { Writable => 'rational64u' },
    data        => { Name => 'RelatedVideoFile', %binaryConv },
);

# MIE camera information
%Image::ExifTool::MIE::Camera = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Camera', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Camera',
    WRITABLE => 'string',
    PREFERRED => 1,
    AnalogZoom      => { Writable => 'rational64u' },
    BlueBalance     => { Writable => 'rational64u' },
    ColorTemperature=> { Writable => 'int32u' },
    Brightness      => { Writable => 'int8s' },
    Contrast        => { Writable => 'int8s' },
    DigitalZoom     => { Writable => 'rational64u' },
    ExposureComp    => { Name => 'ExposureCompensation', Writable => 'rational64s' },
    ExposureMode    => { },
    ExposureTime    => {
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    Extender        => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Extender', DirName => 'MIE-Extender' } },
    FNumber         => { Writable => 'rational64u' },
    Flash           => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Flash', DirName => 'MIE-Flash' } },
    FirmwareVersion => { },
    FocalLength     => { Writable => 'rational64u', Notes => 'includes affect of extender, if any' },
    FocusDistance   => { Writable => 'rational64u' },
    FocusMode       => { },
    ISO             => { Writable => 'int16u' },
    ISOSetting      => { Writable => 'int16u', Notes => '0 = Auto, otherwise manual ISO speed setting' },
    ImageNumber     => { Writable => 'int32u' },
    ImageQuality    => { Notes => 'Economy, Normal, Fine, Super Fine or Raw' },
    ImageStabilization => { Writable => 'int8u', %offOn },
    Lens            => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Lens', DirName => 'MIE-Lens' } },
    Make            => { },
    MaxAperture     => { Writable => 'rational64u' },
    MaxApertureAtMaxFocal => { Writable => 'rational64u' },
    MaxFocalLength  => { Writable => 'rational64u' },
    MeasuredEV      => { Writable => 'rational64s' },
    MinAperture     => { Writable => 'rational64u' },
    MinFocalLength  => { Writable => 'rational64u' },
    Model           => { },
    Orientation     => { Writable => 'int16u', Notes => 'CW rotation angle of camera' },
    OwnerName       => { },
    RedBalance      => { Writable => 'rational64u' },
    Saturation      => { Writable => 'int8s' },
    SensorSize      => { Writable => 'rational64u', Count => 2, Notes => 'width and height of active sensor area in mm' },
    SerialNumber    => { },
    Sharpness       => { Writable => 'int8s' },
    ShootingMode    => { },
);

# MIE lens extender information
%Image::ExifTool::MIE::Extender = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Extender', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Extender',
    WRITABLE => 'string',
    PREFERRED => 1,
    Magnification   => { Writable => 'rational64s' },
    Make            => { Name => 'ExtenderMake' },
    Model           => { Name => 'ExtenderModel' },
    SerialNumber    => { Name => 'ExtenderSerialNumber' },
);

# MIE camera flash information
%Image::ExifTool::MIE::Flash = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Flash', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Flash',
    WRITABLE => 'string',
    PREFERRED => 1,
    ExposureComp    => { Name => 'FlashExposureComp', Writable => 'rational64s' },
    Fired           => { Name => 'FlashFired', Writable => 'int8u', PrintConv => \%noYes },
    GuideNumber     => { Name => 'FlashGuideNumber' },
    Make            => { Name => 'FlashMake' },
    Mode            => { Name => 'FlashMode' },
    Model           => { Name => 'FlashModel' },
    SerialNumber    => { Name => 'FlashSerialNumber' },
    Type            => { Name => 'FlashType', Notes => '"Internal" or "External"' },
);

# MIE camera lens information
%Image::ExifTool::MIE::Lens = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-Lens', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Lens',
    WRITABLE => 'string',
    PREFERRED => 1,
    Make            => { Name => 'LensMake' },
    Model           => { Name => 'LensModel' },
    SerialNumber    => { Name => 'LensSerialNumber' },
);

# MIE maker notes information
%Image::ExifTool::MIE::MakerNotes = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    WRITE_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    LANG_INFO => \&GetLangInfo,
    GROUPS => { 1 => 'MIE-MakerNotes' },
    WRITE_GROUP => 'MIE-MakerNotes',
    PREFERRED => 1,
    NOTES => q{
        MIE maker notes are contained within separate groups for each manufacturer
        to avoid name conflicts.  Currently no specific manufacturer information has
        been defined.
    },
    Canon       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Casio       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    FujiFilm    => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Kodak       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    KonicaMinolta=>{ SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Nikon       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Olympus     => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Panasonic   => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Pentax      => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Ricoh       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Sigma       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Sony        => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
);

%Image::ExifTool::MIE::Unknown = (
    PROCESS_PROC => \&Image::ExifTool::MIE::ProcessMIE,
    GROUPS => { 1 => 'MIE-Unknown' },
);

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash
# Inputs: 0) tagInfo hash ref, 1) locale code (ie. "en_CA")
# Returns: new tagInfo hash ref, or undef if invalid
sub GetLangInfo($$)
{
    my ($tagInfo, $langCode) = @_;
    # can only set locale on string types
    return undef if $$tagInfo{Writable} and $$tagInfo{Writable} ne 'string';
    # make a new tagInfo hash for this locale
    my $table = $$tagInfo{Table};
    Image::ExifTool::GenerateTagIDs($table);
    my $tagID = $$tagInfo{TagID} . '-' . $langCode;
    my $langInfo = $$table{$tagID};
    unless ($langInfo) {
        # make a new tagInfo entry for this locale
        $langInfo = {
            %$tagInfo,
            Name => $$tagInfo{Name} . '-' . $langCode,
            Description => Image::ExifTool::MakeDescription($$tagInfo{Name}) . " ($langCode)",
        };
        Image::ExifTool::AddTagToTable($table, $tagID, $langInfo);
    }
    return $langInfo;
}

#------------------------------------------------------------------------------
# return true if we have Zlib::Compress
# Inputs: 0) ExifTool object ref, 1) verb for what you want to do with the info
# Returns: 1 if Zlib available, 0 otherwise
sub HasZlib($$)
{
    unless (defined $hasZlib) {
        $hasZlib = eval 'require Compress::Zlib';
        unless ($hasZlib) {
            $hasZlib = 0;
            $_[0]->Warn("Install Compress::Zlib to $_[1] compressed information");
        }
    }
    return $hasZlib;
}

#------------------------------------------------------------------------------
# Get format code for MIE group element with current byte order
# Inputs: 0) [optional] true to convert result to chr()
# Returns: format code
sub MIEGroupFormat(;$)
{
    my $chr = shift;
    my $format = GetByteOrder() eq 'MM' ? 0x10 : 0x18;
    return $chr ? chr($format) : $format;
}

#------------------------------------------------------------------------------
# Does a string contain valid UTF-8 characters?
# Inputs: 0) string
# Returns: 0=regular ASCII, -1=invalid UTF-8, 1=valid UTF-8 with maximum 16-bit
#          wide characters, 2=valid UTF-8 requiring 32-bit wide characters
# Notes: Changes current string position
sub IsUTF8($)
{
    my $rtnVal = 0;
    pos($_[0]) = 0; # start at beginning of string
    for (;;) {
        last unless $_[0] =~ /([\xc0-\xff])/g;
        my $ch = ord($1);
        return -1 if $ch >= 0xfe;  # 0xfe and 0xff are not valid in UTF-8 strings
        my $n = 1;
        foreach (0xe0, 0xf0, 0xf8, 0xfc) {
            last if $ch < $_;
            ++$n;
        }
        return -1 unless $_[0] =~ /\G[\x80-\xbf]{$n}/g;
        # character code is greater than 0xffff if more than 2 extra bytes were
        # required in the UTF-8 character
        $rtnVal < 2 and $rtnVal = ($n > 2) ? 2 : 1;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# ReadValue() with added support for UTF formats (utf8, utf16 and utf32)
# Inputs: 0) data reference, 1) value offset, 2) format string,
#         3) number of values (or undef to use all data)
#         4) valid data length relative to offset
# Returns: converted value, or undefined if data isn't there
#          or list of values in list context
sub ReadMIEValue($$$$$)
{
    my ($dataPt, $offset, $format, $count, $size) = @_;
    my $val;
    if ($format =~ /^utf(8|16|32)/) {
        if ($1 == 8) {
            # return UTF8 string
            $val = substr($$dataPt, $offset, $size);
        } else {
            # convert to UTF8
            my $fmt;
            if (GetByteOrder() eq 'MM') {
                $fmt = ($1 == 16) ? 'n' : 'N';
            } else {
                $fmt = ($1 == 16) ? 'v' : 'V';
            }
            my @unpk = unpack("x$offset$fmt$size",$$dataPt);
            if ($] >= 5.006001) {
                $val = pack('C0U*', @unpk);
            } else {
                # hack for pre 5.6.1 (because the code to do the
                # translation properly is unnecesarily bulky)
                foreach (@unpk) {
                    $_ > 0xff and $_ = ord('?');
                }
                $val = pack('C*', @unpk);
            }
        }
        # truncate at null unless this is a list
        $val =~ s/\0.*//s unless $format =~ /_list$/;
        return $val;
    } else {
        # don't modify string lists
        $format = 'undef' if $format eq 'string_list' or $format eq 'free';
        return ReadValue($dataPt, $offset, $format, $count, $size);
    }
}

#------------------------------------------------------------------------------
# Rewrite a MIE directory
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ptr
# Returns: undef on success, otherwise error message (empty message if nothing to write)
sub WriteMIEGroup($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $dirName = $$dirInfo{DirName};
    my $toWrite = $$dirInfo{ToWrite} || '';
    my $raf = $$dirInfo{RAF};
    my $verbose = $exifTool->Options('Verbose');
    my $optCompress = $exifTool->Options('Compress');
    my $out = $exifTool->Options('TextOut');
    my ($buff, $msg, $err, $ok, $sync, $delGroup);
    my $tag = '';
    my $deletedTag = '';

    # count each MIE directory found and make name for this specific instance
    my ($grp1, %isWriting);
    my $cnt = $exifTool->{MIE_COUNT};
    my $grp = $tagTablePtr->{GROUPS}->{1};
    my $n = $$cnt{'MIE-Main'} || 0;
    if ($grp eq 'MIE-Main') {
        $$cnt{$grp} = ++$n;
        ($grp1 = $grp) =~ s/MIE-/MIE$n-/;
    } else {
        ($grp1 = $grp) =~ s/MIE-/MIE$n-/;
        my $m = $$cnt{$grp1} = ($$cnt{$grp1} || 0) + 1;
        $isWriting{"$grp$m"} = 1;   # ie. 'MIE-Doc2'
        $isWriting{$grp1} = 1;      # ie. 'MIE1-Doc'
        $grp1 .= $m;
    }
    # build lookup for all valid group names for this MIE group
    $isWriting{$grp} = 1;           # ie. 'MIE-Doc'
    $isWriting{$grp1} = 1;          # ie. 'MIE1-Doc2'
    $isWriting{"MIE$n"} = 1;        # ie. 'MIE1'

    # determine if we are deleting this group
    if ($exifTool->{DEL_GROUP}) {
        $delGroup = 1 if $exifTool->{DEL_GROUP}->{MIE} or
                         $exifTool->{DEL_GROUP}->{$grp} or
                         $exifTool->{DEL_GROUP}->{$grp1} or
                         $exifTool->{DEL_GROUP}->{"MIE$n"};
    }

    # prepare lookups and lists for writing
    my $newTags = $exifTool->GetNewTagInfoHash($tagTablePtr);
    my ($addDirs, $editDirs) = $exifTool->GetAddDirHash($tagTablePtr, $dirName);
    my @editTags = sort keys %$newTags, keys %$editDirs;
    $verbose and print $out $raf ? 'Writing' : 'Creating', " $grp1:\n";

    # loop through elements in MIE group
    MieElement: for (;;) {
        my ($format, $tagLen, $valLen, $buf2);
        my $lastTag = $tag;
        if ($raf) {
            my $n = $raf->Read($buff, 4);
            if ($n != 4) {
                last if $n or defined $sync;
                undef $raf; # all done reading
                $ok = 1;
            }
        }
        if ($raf) {
            ($sync, $format, $tagLen, $valLen) = unpack('aC3', $buff);
            $sync eq '~' or $msg = 'Invalid sync byte', last;

            # read tag name
            if ($tagLen) {
                $raf->Read($tag, $tagLen) == $tagLen or last;
                $exifTool->Warn("MIE tag '$tag' out of sequence") if $tag lt $lastTag;
            } else {
                $tag = '';
            }

            # get multi-byte value length if necessary
            if ($valLen > 252) {
                # calculate number of bytes in extended DataLength
                my $n = 1 << (256 - $valLen);
                $raf->Read($buf2, $n) == $n or last;
                my $fmt = 'int' . ($n * 8) . 'u';
                $valLen = ReadValue(\$buf2, 0, $fmt, 1, $n);
                if ($valLen > 0x7fffffff) {
                    $msg = "Can't write $tag (DataLength > 2GB not yet supported)";
                    last;
                }
            }
            # don't rewrite free bytes or information in deleted groups
            if ($format eq 0x80 or ($delGroup and $tagLen and ($format & 0xf0) != 0x10)) {
                $raf->Seek($valLen, 1) or $msg = 'Seek error', last;
                if ($verbose > 1) {
                    my $free = ($format eq 0x80) ? ' free' : '';
                    print $out "    - $grp1:$tag ($valLen$free bytes)\n";
                }
                next;
            }
        } else {
            # no more elements to read
            $tagLen = $valLen = 0;
            $tag = '';
        }
#
# write necessary new tags and process directories
#
        while (@editTags) {
            last if $tagLen and $editTags[0] gt $tag;
            # we are writing the new tag now
            my ($newVal, $writable, $oldVal, $newFormat, $compress);
            my $newTag = shift @editTags;
            my $newInfo = $$editDirs{$newTag};
            if ($newInfo) {
                # create the new subdirectory or rewrite existing non-MIE directory
                my $subTablePtr = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                unless ($subTablePtr) {
                    $exifTool->Warn("No tag table for $newTag $$newInfo{Name}");
                    next;
                }
                my %subdirInfo;
                my $isMieGroup = ($$subTablePtr{WRITE_PROC} and
                                  $$subTablePtr{WRITE_PROC} eq \&ProcessMIE);

                if ($newTag eq $tag) {
                    # make sure that either both or neither old and new tags are MIE groups
                    if ($isMieGroup xor ($format & 0xf3) == 0x10) {
                        $exifTool->Warn("Tag '$tag' not expected type");
                        next;   # don't write our new tag
                    }
                    # uncompress existing directory into $oldVal since we are editing it
                    if ($format & 0x04) {
                        last unless HasZlib($exifTool, 'edit');
                        $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        my $stat;
                        my $inflate = Compress::Zlib::inflateInit();
                        $inflate and ($oldVal, $stat) = $inflate->inflate($oldVal);
                        unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                            $msg = "Error inflating $tag";
                            last MieElement;
                        }
                        $compress = 1;
                        $valLen = length $oldVal;    # uncompressed value length
                    }
                }

                if ($isMieGroup) {
                    my $hdr;
                    if ($newTag eq $tag) {
                        # rewrite existing directory later unless it was compressed
                        last unless $compress;
                        # rewrite directory to '$newVal'
                        $newVal = '';
                        %subdirInfo = (
                            OutFile => \$newVal,
                            RAF => new File::RandomAccess(\$oldVal),
                        );
                    } elsif ($optCompress and not $$dirInfo{IsCompressed}) {
                        # write to memory so we can compress the new MIE group
                        $compress = 1;
                        %subdirInfo = (
                            OutFile => \$newVal,
                        );
                    } else {
                        $hdr = '~' . MIEGroupFormat(1) . chr(length($newTag)) .
                               "\0" . $newTag;
                        %subdirInfo = (
                            OutFile => $outfile,
                            ToWrite => $toWrite . $hdr,
                        );
                    }
                    $subdirInfo{DirName} = $newInfo->{SubDirectory}->{DirName} || $newTag;
                    $subdirInfo{Parent} = $dirName;
                    # don't compress elements of an already compressed group
                    $subdirInfo{IsCompressed} = 1;
                    $msg = WriteMIEGroup($exifTool, \%subdirInfo, $subTablePtr);
                    last MieElement if $msg;
                    # message is defined but empty if nothing was written
                    if (defined $msg) {
                        undef $msg; # not a problem if nothing was written
                        last MieElement;
                    } elsif (not $compress) {
                        # group was written already
                        $toWrite = '';
                        next;
                    }
                    $writable = 'undef';
                    $newFormat = MIEGroupFormat();
                } else {
                    if ($newTag eq $tag) {
                        unless ($compress) {
                            # read and edit existing directory
                            $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        }
                        %subdirInfo = (
                            DataPt => \$oldVal,
                            DataLen => $valLen,
                            DirName => $$newInfo{Name},
                            DataPos => $raf->Tell() - $valLen,
                            DirStart => 0,
                            DirLen => $valLen,
                        );
                    } else {
                        # don't create this directory unless necessary
                        next unless $$addDirs{$newTag};
                    }
                    $subdirInfo{Parent} = $dirName;
                    my $writeProc = $newInfo->{SubDirectory}->{WriteProc};
                    $newVal = $exifTool->WriteDirectory(\%subdirInfo, $subTablePtr, $writeProc);
                    if (defined $newVal) {
                        if ($newVal eq '') {
                            next MieElement if $newTag eq $tag; # deleting the directory
                            next;       # not creating the new directory
                        }
                    } else {
                        next unless defined $oldVal;
                        $newVal = $oldVal;  # just copy over the old directory
                    }
                    $writable = 'undef';
                    $newFormat = 0x00;  # all other directories are 'undef' format
                }
            } else {

                # get the new tag information
                $newInfo = $$newTags{$newTag};
                my $newValueHash = $exifTool->GetNewValueHash($newInfo);
                my @newVals;

                # write information only to specified group
                my $writeGroup = $$newValueHash{WriteGroup};
                last unless $isWriting{$writeGroup};

                # if tag existed, must decide if we want to overwrite the value
                if ($newTag eq $tag) {
                    my $isOverwriting;
                    my $isList = $$newInfo{List};
                    if ($isList) {
                        $isOverwriting = -1;    # force processing list elements individually
                    } else {
                        $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash);
                        last unless $isOverwriting;
                    }
                    my $val;
                    if ($isOverwriting < 0 or $verbose > 1) {
                        # check to be sure we can uncompress the value if necessary
                        HasZlib($exifTool, 'edit') or last if $format & 0x04;
                        # read the old value
                        $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        # uncompress if necessary
                        if ($format & 0x04) {
                            my $stat;
                            my $inflate = Compress::Zlib::inflateInit();
                            $inflate and ($oldVal, $stat) = $inflate->inflate($oldVal);
                            unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                                $msg = "Error inflating $tag";
                                last MieElement;
                            }
                            $valLen = length $oldVal;    # update value length
                        }
                        # convert according to specified format
                        my $formatStr = $mieFormat{$format & 0xfb} || 'undef';
                        $val = ReadMIEValue(\$oldVal, 0, $formatStr, undef, $valLen);
                        if ($isOverwriting < 0 and defined $val) {
                            # handle list values individually
                            if ($isList) {
                                my (@vals, $v);
                                if ($formatStr =~ /_list$/) {
                                    @vals = split "\0", $val;
                                } else {
                                    @vals = $val;
                                }
                                # keep any list items that we aren't overwriting
                                foreach $v (@vals) {
                                    next if Image::ExifTool::IsOverwriting($newValueHash, $v);
                                    push @newVals, $v;
                                }
                            } else {
                                # test to see if we really want to overwrite the value
                                $isOverwriting = Image::ExifTool::IsOverwriting($newValueHash, $val);
                            }
                        }
                    }
                    if ($isOverwriting) {
                        # skip the old value if we didn't read it already
                        unless (defined $oldVal) {
                            $raf->Seek($valLen, 1) or $msg = 'Seek error';
                        }
                        if ($verbose > 1) {
                            $val = $exifTool->Printable($val);
                            print $out "    - $grp1:$$newInfo{Name} = '$val'\n";
                        }
                        $deletedTag = $tag;     # remember that we deleted this tag
                        ++$exifTool->{CHANGED}; # we deleted the old value
                    } else {
                        unless (defined $oldVal) {
                            $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        }
                        # write the old value now
                        Write($outfile, $toWrite, $buff, $tag, $oldVal) or $err = 1;
                        $toWrite = '';
                    }
                    unless (@newVals) {
                        # unshift the new tag info to write it later
                        unshift @editTags, $newTag;
                        next MieElement;    # get next element from file
                    }
                } else {
                    # write new value if creating, or if List and list existed, or
                    # if tag was previously deleted
                    next unless Image::ExifTool::IsCreating($newValueHash) or
                        ($newTag eq $lastTag and ($$newInfo{List} or $deletedTag eq $lastTag));
                }
                # get the new value to write (undef to delete)
                push @newVals, Image::ExifTool::GetNewValues($newValueHash);
                next unless @newVals;
                $writable = $$newInfo{Writable} || $$tagTablePtr{WRITABLE};
                if ($writable eq 'string') {
                    # join multiple values into a single string
                    $newVal = join "\0", @newVals;
                    # write string as UTF-8,16 or 32 if value contains valid UTF-8 codes
                    my $isUTF8 = IsUTF8($newVal);
                    if ($isUTF8 > 0) {
                        $writable = 'utf8';
                        # write UTF-16 or UTF-32 if it is more compact
                        # (only if Perl version is 5.6.1 or greater)
                        if ($] >= 5.006001) {
                            # pack with current byte order
                            my $pk = (GetByteOrder() eq 'MM') ? 'n' : 'v';
                            $pk = uc($pk) if $isUTF8 > 1;
                            # translate to utf16 or utf32
                            my $tmp = pack("$pk*",unpack('U0U*',$newVal));
                            if (length $tmp < length $newVal) {
                                $newVal = $tmp;
                                $writable = ($isUTF8 > 1) ? 'utf32' : 'utf16';
                            }
                        }
                    }
                    # write as a list if we have multiple values
                    $writable .= '_list' if @newVals > 1;
                } else {
                    # should only be one element in the list
                    $newVal = shift @newVals;
                }
                $newFormat = $mieCode{$writable};
                unless (defined $newFormat) {
                    $msg = "Bad format '$writable' for $$newInfo{Name}";
                    next MieElement;
                }
            }

            # write the new or edited element
            while (defined $newFormat) {
                my $valPt = \$newVal;
                # convert value if necessary
                if ($writable !~ /^(utf|string|undef)/) {
                    my $wrVal = WriteValue($newVal, $writable, $$newInfo{Count});
                    unless (defined $wrVal) {
                        $exifTool->Warn("Error writing $newTag");
                        last;
                    }
                    $valPt = \$wrVal;
                }
                my $len = length $$valPt;
                # compress value before writing if required
                if (($compress or $optCompress) and not $$dirInfo{IsCompressed} and
                    HasZlib($exifTool, 'write'))
                {
                    my $deflate = Compress::Zlib::deflateInit();
                    my $val2;
                    if ($deflate) {
                        $val2 = $deflate->deflate($$valPt);
                        $val2 .= $deflate->flush() if defined $val2;
                    }
                    if (defined $val2) {
                        my $len2 = length $val2;
                        my $saved = $len - $len2;
                        # only use compressed data if it is smaller
                        if ($saved > 0) {
                            $verbose and print $out "  [$newTag compression saved $saved bytes]\n";
                            $newFormat |= 0x04; # set compressed bit
                            $len = $len2;       # set length
                            $valPt = \$val2;    # set value pointer
                        } elsif ($verbose) {
                            print $out "  [$newTag compression saved $saved bytes -- written uncompressed]\n";
                        }
                    } else {
                        $exifTool->Warn("Error deflating $newTag -- written uncompressed");
                    }
                }
                # calculate the DataLength code
                my $extLen;
                if ($len < 253) {
                    $extLen = '';
                } elsif ($len < 65536) {
                    $extLen = Set16u($len);
                    $len = 255;
                } elsif ($len <= 0x7fffffff) {
                    $extLen = Set32u($len);
                    $len = 254;
                } else {
                    $exifTool->Warn("Can't write $newTag (DataLength > 2GB not yet suppported)");
                    last; # don't write this tag
                }
                # write this element (with leading MIE group element if not done already)
                my $hdr = $toWrite . '~' . chr($newFormat) . chr(length $newTag);
                Write($outfile, $hdr, chr($len), $newTag, $extLen, $$valPt) or $err = 1;
                $toWrite = '';
                if ($verbose > 1 and not $$editDirs{$newTag}) {
                    $newVal = $exifTool->Printable($newVal);
                    print $out "    + $grp1:$$newInfo{Name} = '$newVal'\n";
                }
                ++$exifTool->{CHANGED};
                last;   # didn't want to loop anyway
            }
            next MieElement if defined $oldVal;
        }
#
# rewrite existing element or descend into uncompressed MIE group
#
        # all done this MIE group if we reached the terminator element
        unless ($tagLen) {
            # skip over existing terminator data (if any)
            last if $valLen and not $raf->Seek($valLen, 1);
            $ok = 1;
            # write group terminator if necessary
            unless ($toWrite) {
                # write end-of-group terminator element
                my $term = "~\0\0\0";
                unless ($$dirInfo{Parent}) {
                    # write extended terminator for file-level group
                    my $len = ref $outfile eq 'SCALAR' ? length($$outfile) : tell $outfile;
                    $len += 10; # include length of terminator itself
                    if ($len and $len <= 0x7fffffff) {
                        $term = "~\0\0\x06" . Set32u($len) . MIEGroupFormat(1) . "\x04";
                    }
                }
                Write($outfile, $term) or $err = 1;
            }
            last;
        }

        # descend into existing uncompressed MIE group
        if ($format == 0x10 or $format == 0x18) {
            my ($subTablePtr, $dirName);
            my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $dirName = $tagInfo->{SubDirectory}->{DirName};
                my $subTable = $tagInfo->{SubDirectory}->{TagTable};
                $subTablePtr = $subTable ? GetTagTable($subTable) : $tagTablePtr;
            } else {
                $subTablePtr = GetTagTable('Image::ExifTool::MIE::Unknown');
            }
            my $hdr = '~' . chr($format) . chr(length $tag) . "\0" . $tag;
            my %subdirInfo = (
                DirName => $dirName || $tag,
                RAF     => $raf,
                ToWrite => $toWrite . $hdr,
                OutFile => $outfile,
                Parent  => $dirName,
                IsCompressed => $$dirInfo{IsCompressed},
            );
            my $oldOrder = GetByteOrder();
            SetByteOrder($format & 0x08 ? 'II' : 'MM');
            $msg = WriteMIEGroup($exifTool, \%subdirInfo, $subTablePtr);
            SetByteOrder($oldOrder);
            last if $msg;
            if (defined $msg) {
                undef $msg; # no problem if nothing written
            } else {
                $toWrite = '';
            }
            next;
        }
        # just copy existing element
        my $oldVal;
        $raf->Read($oldVal, $valLen) == $valLen or last;
        if ($toWrite) {
            Write($outfile, $toWrite) or $err = 1;
            $toWrite = '';
        }
        $tag .= $buf2 if defined $buf2; # add extra data length if nececessary
        Write($outfile, $buff, $tag, $oldVal) or $err = 1;
    }
    # return error message
    if ($err) {
        $msg = 'Error writing file';
    } elsif (not $ok and not $msg) {
        $msg = 'Unexpected end of file';
    } elsif (not $msg and $toWrite) {
        $msg = '';  # flag for nothing written
        $verbose and print $out "Deleted $grp1 (empty)\n";
    }
    return $msg;
}

#------------------------------------------------------------------------------
# Process MIE directory
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: undef on success, or error message if there was a problem
# Notes: file pointer is positioned at the MIE end on entry
sub ProcessMIEGroup($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $exifTool->Options('Verbose');
    my $out = $exifTool->Options('TextOut');
    my ($msg, $buff, $ok, $oldIndent, $mime);
    my $lastTag = '';

    # get group 1 names: $grp doesn't have numbers (ie. 'MIE-Doc'),
    # and $grp1 does (ie. 'MIE1-Doc1')
    my $cnt = $exifTool->{MIE_COUNT};
    my $grp1 = $tagTablePtr->{GROUPS}->{1};
    my $n = $$cnt{'MIE-Main'} || 0;
    if ($grp1 eq 'MIE-Main') {
        $$cnt{$grp1} = ++$n;
        $grp1 =~ s/MIE-/MIE$n-/ if $n > 1;
    } else {
        $grp1 =~ s/MIE-/MIE$n-/ if $n > 1;
        $$cnt{$grp1} = ($$cnt{$grp1} || 0) + 1;
        $grp1 .= $$cnt{$grp1} if $$cnt{$grp1} > 1;
    }
    # set group1 name for all tags extracted from this group
    $exifTool->{SET_GROUP1} = $grp1;

    if ($verbose) {
        $oldIndent = $exifTool->{INDENT};
        $exifTool->{INDENT} .= '| ';
        $exifTool->VerboseDir($grp1);
    }

    # process all MIE elements
    for (;;) {
        $raf->Read($buff, 4) == 4 or last;
        my ($sync, $format, $tagLen, $valLen) = unpack('aC3', $buff);
        $sync eq '~' or $msg = 'Invalid sync byte', last;

        # read tag name
        my $tag;
        if ($tagLen) {
            $raf->Read($tag, $tagLen) == $tagLen or last;
            $exifTool->Warn("MIE tag '$tag' out of sequence") if $tag lt $lastTag;
            $lastTag = $tag;
        } else {
            $tag = '';
        }

        # get multi-byte value length if necessary
        if ($valLen > 252) {
            my $n = 1 << (256 - $valLen);
            $raf->Read($buff, $n) == $n or last;
            my $fmt = 'int' . ($n * 8) . 'u';
            $valLen = ReadValue(\$buff, 0, $fmt, 1, $n);
            if ($valLen > 0x7fffffff) {
                $msg = "Can't read $tag (DataLength > 2GB not yet supported)";
                last;
            }
        }

        # all done if we reached the group terminator
        unless ($tagLen) {
            # skip over terminator data block
            $ok = 1 unless $valLen and not $raf->Seek($valLen, 1);
            last;
        }

        # get tag information hash unless this is free space
        my ($tagInfo, $value);
        while ($format != 0x80) {
            $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
            last if $tagInfo;
            # extract tags with locale code
            if ($tag =~ /\W/) {
                if ($tag =~ /^(\w+)-([a-z]{2}_[A-Z]{2})$/) {
                    my ($baseTag, $langCode) = ($1, $2);
                    $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $baseTag);
                    $tagInfo = GetLangInfo($tagInfo, $langCode) if $tagInfo;
                    last if $tagInfo;
                } else {
                    $exifTool->Warn('Invalid MIE tag name');
                    last;
                }
            }
            # extract unknown tags if specified
            $tagInfo = {
                Name => $tag,
                Writable => 0,
                PrintConv => 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val',
            };
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
            last;
        }

        # read value and uncompress if necessary
        my $formatStr = $mieFormat{$format & 0xfb} || 'undef';
        if ($tagInfo or ($formatStr eq 'MIE' and $format & 0x04)) {
            $raf->Read($value, $valLen) == $valLen or last;
            if ($format & 0x04) {
                if ($verbose) {
                    print $out "$$exifTool{INDENT}\[Tag '$tag' $valLen bytes compressed]\n";
                }
                next unless HasZlib($exifTool, 'decode');
                my $stat;
                my $inflate = Compress::Zlib::inflateInit();
                $inflate and ($value, $stat) = $inflate->inflate($value);
                unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                    $exifTool->Warn("Error inflating $tag");
                    next;
                }
                $valLen = length $value;
            }
        }

        # process this tag
        if ($formatStr eq 'MIE') {
            # process MIE directory
            my ($subTablePtr, $dirName);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $dirName = $tagInfo->{SubDirectory}->{DirName};
                my $subTable = $tagInfo->{SubDirectory}->{TagTable};
                $subTablePtr = $subTable ? GetTagTable($subTable) : $tagTablePtr;
            } else {
                $subTablePtr = GetTagTable('Image::ExifTool::MIE::Unknown');
            }
            if ($verbose) {
                my $order = ', byte order ' . GetByteOrder();
                $exifTool->VerboseInfo($tag, $tagInfo, Size => $valLen, Extra => $order);
            }
            my %subdirInfo = (
                DirName => $dirName || $tag,
                RAF => $raf,
                Parent => $$dirInfo{DirName},
            );
            # read from uncompressed data instead if necessary
            $subdirInfo{RAF} = new File::RandomAccess(\$value) if $format & 0x04;

            my $oldOrder = GetByteOrder();
            SetByteOrder($format & 0x08 ? 'II' : 'MM');
            $msg = ProcessMIEGroup($exifTool, \%subdirInfo, $subTablePtr);
            SetByteOrder($oldOrder);
            $exifTool->{SET_GROUP1} = $grp1;    # restore this group1 name
            last if $msg;
        } else {
            # process MIE data format types
            if ($tagInfo) {
                # extract tag value
                my $val = ReadMIEValue(\$value, 0, $formatStr, undef, $valLen);
                unless (defined $val) {
                    $exifTool->Warn("Error reading $tag value");
                    $val = '<err>';
                }
                # save type or mime type
                $mime = $val if $tag eq '0Type' or $tag eq '2MIME';
                $verbose and $exifTool->VerboseInfo($tag, $tagInfo,
                    DataPt => \$value,
                    DataPos => $raf->Tell() - $valLen,
                    Size => $valLen,
                    Format => $formatStr,
                    Value => $val,
                );
                if ($$tagInfo{SubDirectory}) {
                    my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                    my %subdirInfo = (
                        DirName => $$tagInfo{Name},
                        DataPt => \$value,
                        DataPos => $raf->Tell() - $valLen,
                        DataLen => $valLen,
                        DirStart => 0,
                        DirLen => $valLen,
                    );
                    my $processProc = $tagInfo->{SubDirectory}->{ProcessProc};
                    delete $exifTool->{SET_GROUP1};
                    $exifTool->ProcessDirectory(\%subdirInfo, $subTablePtr, $processProc);
                    $exifTool->{SET_GROUP1} = $grp1;
                } elsif ($formatStr =~ /_list$/) {
                    # split list value into separate strings
                    my @vals = split "\0", $val;
                    $exifTool->FoundTag($tagInfo, \@vals);
                } else {
                    $exifTool->FoundTag($tagInfo, $val);
                }
            } else {
                # skip over unknown information or free bytes
                $raf->Seek($valLen, 1) or $msg = 'Seek error', last;
                $verbose and $exifTool->VerboseInfo($tag, undef, Size => $valLen);
            }
        }
    }
    # modify MIME type if necessary
    $mime and not $$dirInfo{Parent} and $exifTool->ModifyMimeType($mime);

    $ok or $msg or $msg = 'Unexpected end of file';
    $verbose and $exifTool->{INDENT} = $oldIndent;
    return $msg;
}

#------------------------------------------------------------------------------
# Read/write a MIE file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MIE file, or -1 on write error
sub ProcessMIE($$)
{
    my ($exifTool, $dirInfo) = @_;
    return 1 unless defined $exifTool;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my ($buff, $err, $msg);
    my $numDocs = 0;
#
# loop through all documents in MIE file
#
    for (;;) {
        # look for "0MIE" group element
        my $num = $raf->Read($buff, 8);
        if ($num == 8) {
            # verify file identifier
            if ($buff =~ /^~(\x10|\x18)\x04(.)0MIE/) {
                # this is a MIE document -- increment document count
                unless ($numDocs) {
                    $exifTool->SetFileType();   # this is a valid MIE file
                    $exifTool->{NO_LIST} = 1;   # handle lists ourself
                    $exifTool->{MIE_COUNT} = { };
                    undef $hasZlib;
                }
                SetByteOrder($1 eq "\x10" ? 'MM' : 'II');
                my $len = ord($2);
                # skip extended DataLength if it exists
                if ($len > 252 and not $raf->Seek(1 << (256 - $len), 1)) {
                    $msg = 'Seek error';
                    last;
                }
            } else {
                return 0 unless $numDocs;   # not a MIE file
                if ($buff =~ /^~/) {
                    $msg = 'Non-standard file-level MIE element';
                } else {
                    $msg = 'Invalid file-level data';
                }
            }
        } elsif ($numDocs) {
            last unless $num;   # OK, all done with file
            $msg = 'Truncated element header';
        } else {
            return 0 if $num or not $outfile;
            # we have the ability to create a MIE file from scratch
            $buff = ''; # start from nothing
            SetByteOrder('MM'); # write big-endian
        }
        if ($msg) {
            if ($outfile) {
                $exifTool->Error($msg);
            } else {
                $exifTool->Warn($msg);
            }
            last;
        }
        ++$numDocs;

        # process the MIE groups recursively, beginning with the main MIE group
        my $tagTablePtr = GetTagTable('Image::ExifTool::MIE::Main');

        my %subdirInfo = (
            DirName => 'MIE',
            RAF => $raf,
            OutFile => $outfile,
            # don't define Parent so WriteMIEGroup() writes extended terminator
        );
        if ($outfile) {

            if ($VERSION < 1) {
                $exifTool->Error("MIE format still in development (version $VERSION)",1);
            }

            # generate lookup for MIE format codes if not done already
            unless (%mieCode) {
                foreach (keys %mieFormat) {
                    $mieCode{$mieFormat{$_}} = $_;
                }
            }
            $exifTool->InitWriteDirs(\%mieMap);
            $subdirInfo{ToWrite} = '~' . MIEGroupFormat(1) . "\x04\xfe0MIE\0\0\0\0";
            $msg = WriteMIEGroup($exifTool, \%subdirInfo, $tagTablePtr);
            if ($msg) {
                $exifTool->Error($msg);
                $err = 1;
                last;
            } elsif (defined $msg) {
                $exifTool->Error('Nothing to write');
                last;
            }
        } else {
            $msg = ProcessMIEGroup($exifTool, \%subdirInfo, $tagTablePtr);
            if ($msg) {
                $exifTool->Warn($msg);
                last;
            }
        }
    }
    delete $exifTool->{NO_LIST};
    delete $exifTool->{MIE_COUNT};
    delete $exifTool->{SET_GROUP1};
    return $err ? -1 : 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MIE - Read/write MIE meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read and write
information in MIE files.

=head1 WHAT IS MIE?

MIE stands for Meta Information Encapsulation.  The MIE format is an
extensible, dedicated meta information format which supports storage of
binary as well as textual meta information.  MIE can be used to encapsulate
meta information from many sources and bundle it together with any type of
file.

=head2 Features

Below is very subjective score card comparing the features of a number of
common file and meta information formats, and comparing them to MIE.  The
following features are rated for each format with a score of 0 to 10:

  1) Extensible (can incorporate user-defined information).
  2) Tag ID's meaningful (hints to meaning of unknown information).
  3) Sequential read/written ability (streamable).
  4) Hierarchical information structure.
  5) Easy to implement reader/writer/editor.
  6) Data order well defined.
  7) Large data lengths supported: >64kB (+5) and >4GB (+5).
  8) Localized text strings.
  9) Multiple documents in a single file.
 10) Compact format doesn't squander disk space or bandwidth.
 11) Compressed meta information supported.
 12) Relocatable data elements.
 13) Binary meta information (+7) with variable byte order (+3).
 14) Mandatory tags not required (because that would be stupid).
 15) Append information to end of file without editing.

                          Feature number                   Total
     Format  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15   Score
     ------ ---------------------------------------------  -----
     MIE    10 10 10 10 10 10 10 10 10 10 10 10 10 10 10    150
     PDF    10 10  0 10  0  0 10  0 10 10 10  0  7 10 10     97
     PNG    10 10 10  0  8  0  5 10  0 10 10 10  0 10  0     93
     XMP    10 10 10 10  2  0 10 10 10  0  0 10  0 10  0     92
     AIFF    0  5 10 10 10  0  5  0  0 10  0 10  7 10  0     77
     RIFF    0  5 10 10 10  0  5  0  0 10  0 10  7 10  0     77
     JPEG   10  0 10  0 10  0  0  0  0 10  0 10  7 10  0     67
     EPS    10 10 10  0  0  0 10  0 10  0  0  5  0 10  0     65
     TIFF    0  0  0 10  5 10  5  0 10 10  0  0 10  0  0     60
     EXIF    0  0  0 10  5 10  0  0  0 10  0  0 10  0  0     45
     IPTC    0  0 10  0  8  0  0  0  0 10  0 10  7  0  0     45

By design, MIE ranks highest by a significant margin.  Other formats with
reasonable scores are PDF, PNG and XMP, but each has significant weak
points.  What may be surprising is that TIFF, EXIF and IPTC rank so low.

As well as scoring high in all these features, the MIE format has the unique
ability to encapsulate any other type of file, and provides a non-invasive
method of adding meta information to a file.  The meta information is
logically separated from the original file data, which is extremely
important because meta information is routinely lost when files are edited.

Also, the MIE format supports multiple files by simple concatination,
enabling all kinds of wonderful features such as linear databases, edit
histories or non-intrusive file updates.

=head1 MIE FORMAT SPECIFICATION

NOTE: The MIE format specification is currently under development.  Until
version 1.00 is released these specifications may be subject to changes
which may not be backwardly compatible.

=head2 File Structure

A MIE file consists of a series of MIE elements.  A MIE element may contain
either data or a group of MIE elements, providing a hierarchical format for
storing data.  Each MIE element is identified by a human-readable tag name,
and may store data from zero to 2^64-1 bytes in length.

=head2 File Signature

The first element in the MIE file must be an uncompressed MIE group element
with a tag name of "0MIE".  This restriction allows the first 8 bytes of a
MIE file to be used to identify a MIE format file.  The following tables
list these byte sequences for big-endian and little-endian MIE-format files:

    Byte Number:      0    1    2    3    4    5    6    7

    C Characters:     ~ \x10 \x04    ?    0    M    I    E
        or            ~ \x18 \x04    ?    0    M    I    E

    Hexadecimal:     7e   10   04    ?   30   4d   49   45
        or           7e   18   04    ?   30   4d   49   45

    Decimal:        126   16    4    ?   48   77   73   69
        or          126   24    4    ?   48   77   73   69

Note that byte 1 may have one of the two possible values (0x10 or 0x18), and
byte 3 may have any value (0x00 to 0xff).

=head2 Element Structure

    1 byte  SyncByte = 0x7e (decimal 126, character '~')
    1 byte  FormatCode (see below)
    1 byte  TagLength (T)
    1 byte  DataLength (gives D if DataLength < 253)
    T bytes TagName (T given by TagLength)
    2 bytes DataLength2 [exists only if DataLength == 255]
    4 bytes DataLength4 [exists only if DataLength == 254]
    8 bytes DataLength8 [exists only if DataLength == 253]
    D bytes DataBlock (D given by DataLength)

The minimum element length is 4 bytes (for a group terminator).  The maximum
DataBlock size is 2^64-1 bytes.  TagLength and DataLength are unsigned
integers, and the byte ordering for multi-byte DataLength fields is
specified by the containing MIE group element.  The SyncByte is byte
aligned, so no padding is added to align on an N-byte boundary.

=head3 FormatCode

The format code is a bitmask that defines the format of the data:

    7654 3210
    ++++ ----  FormatType
    ---- +---  TypeModifier
    ---- -+--  Compressed
    ---- --++  FormatSize

=over 4

B<FormatType> (bitmask 0xf0):

    0x00 - other (unknown) format data
    0x10 - MIE group
    0x20 - text string
    0x30 - list of null-separated text strings
    0x40 - integer
    0x50 - rational
    0x60 - fixed point
    0x70 - floating point
    0x80 - free space

B<TypeModifier> (bitmask 0x08):

Modifies the meaning of certain FormatTypes (0x00-0x50):

    0x08 - data may be byte swapped according to FormatSize
    0x18 - MIE group with little-endian byte ordering
    0x28 - UTF encoded text string
    0x38 - UTF encoded text string list
    0x48 - signed integer
    0x58 - signed rational (denominator is always unsigned)
    0x68 - signed fixed-point

B<Compressed> (bitmask 0x04):

If this bit is set, the data block is compressed using Zlib deflate.  An
entire MIE group may be compressed, with the exception of file-level groups.

B<FormatSize> (bitmask 0x03):

Gives the byte size of each data element:

    0x00 - 8 bits  (1 byte)
    0x01 - 16 bits (2 bytes)
    0x02 - 32 bits (4 bytes)
    0x03 - 64 bits (8 bytes)

The number of bytes in a single value for this format is given by
2**FormatSize (or 1 << FormatSize).  The number of values is the data length
divided by this number of bytes.  It is an error if the data length is not
an even multiple of the format size in bytes.

=back

The following is a list of all currently defined MIE FormatCode values for
uncompressed data (add 0x04 to each value for compressed data):

    0x00 - unknown data (byte order must be preserved)
    0x08 - other 8-bit data (not affected by byte swapping)
    0x09 - other 16-bit data (may be byte swapped)
    0x0a - other 32-bit data (may be byte swapped)
    0x0b - other 64-bit data (may be byte swapped)
    0x10 - MIE group with big-endian values (1)
    0x18 - MIE group with little-endian values (1)
    0x20 - ASCII string (2,3)
    0x28 - UTF-8 string (2,3)
    0x29 - UTF-16 string (2,3)
    0x2a - UTF-32 string (2,3)
    0x30 - ASCII string list (2,4)
    0x38 - UTF-8 string list (2,4)
    0x39 - UTF-16 string list (2,4)
    0x3a - UTF-32 string list (2,4)
    0x40 - unsigned 8-bit integer
    0x41 - unsigned 16-bit integer
    0x42 - unsigned 32-bit integer
    0x43 - unsigned 64-bit integer (5)
    0x48 - signed 8-bit integer
    0x49 - signed 16-bit integer
    0x4a - signed 32-bit integer
    0x4b - signed 64-bit integer (5)
    0x52 - unsigned 32-bit rational (16-bit numerator then denominator) (6)
    0x53 - unsigned 64-bit rational (32-bit numerator then denominator) (6)
    0x5a - signed 32-bit rational (denominator is unsigned) (6)
    0x5b - signed 64-bit rational (denominator is unsigned) (6)
    0x61 - unsigned 16-bit fixed-point (high 8 bits is integer part) (7)
    0x62 - unsigned 32-bit fixed-point (high 16 bits is integer part) (7)
    0x69 - signed 16-bit fixed-point (high 8 bits is signed integer) (7)
    0x6a - signed 32-bit fixed-point (high 16 bits is signed integer) (7)
    0x72 - 32-bit IEEE float (not recommended for portability reasons)
    0x73 - 64-bit IEEE double (not recommended for portability reasons) (5)
    0x80 - free space (value data does not contain useful information)

 1) The byte ordering specified by the MIE group TypeModifier applies to the
    MIE group element as well as all elements in the group.

 2) The TagName of a string element may have an 6-character suffix to
    indicate a specific locale. (ie. "Title-en_US", or "Keywords-de_DE").

 3) Text strings are not normally null terminated, however they may be
    padded with one or more null characters to the end of the data block to
    allow strings to be edited within fixed-length data blocks.

 4) A list of text strings separated by null characters.  These lists must
    not be null padded or null terminated, since this would be interpreted
    as additional zero-length strings.  For ASCII and UTF-8 strings, the
    null character is a single zero (0x00) byte.  For UTF-16 or UTF-32
    strings, the null character is 2 or 4 zero bytes respectively.

 5) 64-bit integers and doubles are subject to the specified byte ordering
    for both 32-bit words and bytes within these words.  For instance, the
    high order byte is always the first byte if big-endian, and the eighth
    byte if little-endian.  This means that some swapping is always
    necessary for these values on systems where the byte order differs from
    the word order (ie. some ARM systems), regardless of the endian-ness of
    the stored values.

 6) Rational values are treated as two separate integers.  The numerator
    always comes first regardless of the byte ordering.

 7) 32-bit fixed point values are converted to floating point by treating
    them as an integer and dividing by an appropriate value.  ie)

        16-bit fixed value = 16-bit integer value / 256.0
        32-bit fixed value = 32-bit integer value / 65536.0

=head3 TagLength

Gives the length of the TagName string.  Any value between 0 and 255 is
valid, but the TagLength of 0 is valid only for the MIE group terminator.

=head3 DataLength

DataLength is an unsigned byte that gives the number of bytes in the data
block.  A value between 0 and 252 gives the data length directly, and
numbers from 253 to 255 are reserved for special codes.  Codes of 255, 254
and 253 indicate that the element contains an additional 2, 4 or 8 byte
unsigned integer representing the data length.

    0-252 = length of data block
    255   = use DataLength2
    254   = use DataLength4
    253   = use DataLength8

A DataLength of zero is valid for any element except a compressed MIE group.
A zero DataLength for an uncompressed MIE group indicates that the group
length is unknown.  For other elements, a zero length indicates there is no
associated data.

=head3 TagName

The TagName string is 0 to 255 bytes long, and is composed of the ASCII
characters A-Z, a-z, 0-9 and underline ('_').  Also, a dash ('-') is used to
separate the language/country code in the TagName of a localized text
string.  The TagName string is NOT null terminated.  A MIE element with a
tag string of zero length is reserved for the group terminator.

MIE elements are sorted alphabetically by TagName within each group.
Multiple elements with the same TagName are allowed, even within the same
group.

Tag names for localized text strings have an 6-character suffix with the
following format:  The first character is a dash ('-'), followed by a
2-character lower case ISO 639-1 language code, then an underline ('_'), and
ending with a 2-character upper case ISO 3166-1 alpha 2 country code.  (ie.
"-en_US", "-en_GB", "-de_DE" or "-fr_FR".  Note that "GB", and not "UK" is
the code for Great Britain, although "UK" should be recognized for
compatiblity reasons.)  The suffix is included when sorting the tags
alphabetically, so the default locale (with no tag-name suffix) always comes
first.  If the country is unknown or not applicable, a country code of "XX"
should be used.

TagNames should be meaningful.  Words should be lowercase with an uppercase
first character, and acronyms should be all upper case.  The underline ("_")
is provided to allow separation of two acronyms or two numbers, but it
shouldn't be used unless necessary.  No separation is necessary between an
acronym and a word (ie. "ISOSetting").

All TagNames should start with an uppercase letter.  An exception to this
rule allows tags to begin with a digit (0-9) if they must come before other
tags in the sort order, or a lowercase letter (a-z) if they must come after.
For instance, the '0Type' element begins with a digit so it comes before,
and the 'data' element begins with a lowercase letter so that it comes after
meta information tags in the main '0MIE' group.

Sets of tags which would require a common prefix should be added in a
separate MIE instead of adding the prefix to all tag names.  For example,
instead of these TagName's:

    ExternalFlashType
    ExternalFlashSerialNumber
    ExternalFlashFired

one would instead designate a separate "ExternalFlash" MIE group to contain
the following elements:

    Type
    SerialNumber
    Fired

=head3 DataLength2/4/8

These extended DataLength fields exist only if DataLength is 255, 254 or
253, and are respectively 2, 4 or 8 byte unsigned integers giving the data
block length.  One of these values must be used if the data block is larger
than 252 bytes, but they may be used if desired for smaller blocks too
(although this may add a few unecessary bytes to the MIE element).

=head3 DataBlock

The data for the MIE element.  The format of the data is given by the
FormatCode.  For MIE group elements, the data includes all contained
elements and the group terminator.

=head2 MIE groups

All MIE data elements must be contained within a group.  A group begins with
a MIE group element, and ends with a group terminator.  Groups may be nested
in a hierarchy to arbitrary depth.

A MIE group element is identified by a format code of 0x10 (big endian byte
ordering) or 0x18 (little endian).  The group terminator is distinguished by
a zero TagLength (it is the only element allowed to have a zero TagLength),
and has a FormatCode of 0x00.

The MIE group element is permitted to have a zero DataLength only if the
data is uncompressed.  This special value indicates that the group length is
unknown (otherwise the minimum value for DataLength is 4, corresponding the
the minimum group size which includes a terminator of at least 4 bytes). If
DataLength is zero, all elements in the group must be parsed until the group
terminator is found.  If non-zero, DataLength includes the length of all
elements contained within the group, including the group terminator.  Use of
a non-zero DataLength is encouraged because it allows readers quickly skip
over entire MIE groups.  For compressed groups DataLength must be non-zero,
and is the length of the compressed group data (which includes the
compressed group terminator).

The group terminator has a FormatCode and TagLength of zero.  Terminators
usually also have a DataLength of zero.  Hence, the byte sequence for a
terminator is commonly 7e 00 00 00 (hex).  However, the terminator may also
have a DataLength of 6 or 10 bytes, and an associated data block containing
information about the length and byte ordering of the preceeding group.
This additional information is recommended for file-level groups, and is
used in multi-document MIE files to allow the file to be scanned backwards
to quickly locate the last documents in the file, and may also allow some
documents to be recovered if part of the file is corrupted.  The structure
of this optional terminator data block is as follows:

    4 or 8 bytes  GroupLength (unsigned integer)
    1 byte        FormatCode (0x10 or 0x18, same as MIE group element)
    1 byte        GroupLengthSize (0x04 or 0x08)

The FormatCode and GroupLengthSize give the byte ordering and number of
bytes in the GroupLength integer.  The GroupLength gives the total length of
the group ending with this terminator, including the lengths of the MIE
group element and the terminator itself.

=head3 File-level MIE groups

File-level MIE groups may NOT be compressed.

All elements in a MIE file are contained within a special group with a
TagName of "0MIE".  The purpose of the "OMIE" group is to provide a unique
signature at the start of the file, and to encapsulate information allowing
files to be easily combined.  The "0MIE" group must be terminated like any
other group, but it is recommended that the terminator of a file-level group
include the optional data block (defined above) to provide information about
the group length and byte order.

It is valid to have more than one "0MIE" group at the file level, allowing
multiple documents in a single MIE file.  Furthermore, the MIE structure
enables multi-document files to be generated by simply concatinating two or
more MIE files.

=head3 Scanning Backwards through a MIE File

The steps below give an algorithm to quickly locate the last document in a
MIE file:

1) Read the last 10 bytes of the file.  A valid MIE file must be a minimum
of 12 bytes long.

2) If the last byte of the file is zero, then it is not possible to scan
backward through the file, so the file must be scanned from the beginning.
Otherwise, proceed to the next step.

3) If the last byte is 4 or 8, the terminator contains information about the
byte ordering and length of the group.  Otherwise, stop here because this
isn't a valid MIE file.

4) The next-to-last byte must be either 0x10 indicating big-endian byte
ordering or 0x18 for little-endian ordering, otherwise this isn't a valid
MIE file.

5) The preceeding 4 or 8 bytes give the length of the complete file-level
MIE group, including the leading MIE group element and the terminator
element.  The value is an unsigned integer stored with the specified byte
order.  From the current file position (at the end of the 10 bytes we read
in step 1), seek backward by this number of bytes to find the start of the
MIE group element for this document.

This algorithm may be repeated again beginning at this point in the file to
locate the next-to-last document, etc.

The table below lists all 5 valid patterns for the last 10 bytes of a
file-level MIE group (numbers in hex):

  ?? ?? ?? ?? ?? ?? ?? ?? 00 00  - can not seek backwards
  ?? ?? ?? ?? GG GG GG GG 10 04  - 4 byte group length (G), big endian
  ?? ?? ?? ?? GG GG GG GG 18 04  - 4 byte group length (G), little endian
  GG GG GG GG GG GG GG GG 10 08  - 8 byte group length (G), big endian
  GG GG GG GG GG GG GG GG 18 08  - 8 byte group length (G), little endian

=head2 MIE Date/Time Format

All MIE dates are the form "YYYY:mm:dd HH:MM:SS+HH:MM".  The timezone is
recommended but not required.

=head2 MIE File MIME Type

The basic MIME type for a MIE file is "application/x-mie", however the
specific MIME type depends on the type of subfile, and is obtained by adding
"x-mie-" to the MIME type of the subfile.  For example, with a subfile of
type "image/jpeg", the MIE file MIME type is "image/x-mie-jpeg".  But note
that the "x-" is not duplicated if the subfile MIME type already starts with
"x-".  So a subfile with MIME type "image/x-raw" is contained within a MIE
file of type "image/x-mie-raw", not "image/x-mie-x-raw".  In the case of
multiple documents in a MIE file, the MIME type is taken from the first
document.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  The MIE format itself is also
copyright Phil Harvey, and is covered by the same free-use license.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MIE Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

