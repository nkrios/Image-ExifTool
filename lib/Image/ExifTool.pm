#------------------------------------------------------------------------------
# File:         ExifTool.pm
#
# Description:  Read and write meta information
#
# URL:          http://owl.phy.queensu.ca/~phil/exiftool/
#
# Revisions:    Nov. 12/03 - P. Harvey Created
#               (See html/history.html for revision history)
#
# Legal:        Copyright (c) 2003-2006 Phil Harvey (phil at owl.phy.queensu.ca)
#               This library is free software; you can redistribute it and/or
#               modify it under the same terms as Perl itself.
#------------------------------------------------------------------------------

package Image::ExifTool;

use strict;
require 5.004;  # require 5.004 for UNIVERSAL::isa (otherwise 5.002 would do)
require Exporter;
use File::RandomAccess;

use vars qw($VERSION @ISA %EXPORT_TAGS $AUTOLOAD @fileTypes %allTables @tableOrder
            $exifAPP1hdr $xmpAPP1hdr $psAPP13hdr $psAPP13old $myAPP5hdr
            @loadAllTables %UserDefined);

$VERSION = '6.29';
@ISA = qw(Exporter);
%EXPORT_TAGS = (
    Public => [ qw(
        ImageInfo Options ClearOptions ExtractInfo GetInfo WriteInfo CombineInfo
        GetTagList GetFoundTags GetRequestedTags GetValue SetNewValue
        SetNewValuesFromFile GetNewValues CountNewValues SaveNewValues
        RestoreNewValues SetFileModifyDate SetNewGroups GetNewGroups GetTagID
        GetDescription GetGroup GetGroups BuildCompositeTags GetTagName
        GetShortcuts GetAllTags GetWritableTags GetAllGroups GetFileType
        CanWrite CanCreate
    )],
    DataAccess => [qw(
        ReadValue GetByteOrder SetByteOrder ToggleByteOrder Get8u Get8s Get16u
        Get16s Get32u Get32s GetFloat GetDouble GetFixed32s Write WriteValue
        Tell Set8u Set8s Set16u Set32u
    )],
    Utils => [qw(
        GetTagTable TagTableKeys GetTagInfoList GenerateTagIDs SetFileType
        HtmlDump
    )],
    Vars => [qw(
        %allTables @tableOrder @fileTypes
    )],
);
# set all of our EXPORT_TAGS in EXPORT_OK
Exporter::export_ok_tags(keys %EXPORT_TAGS);

# The following functions defined in Image::ExifTool::Writer are declared
# here so their prototypes will be available.  The Writer routines will be
# autoloaded when any of these are called.
sub SetNewValue($;$$%);
sub SetNewValuesFromFile($$;@);
sub GetNewValues($;$$);
sub CountNewValues($);
sub SaveNewValues($);
sub RestoreNewValues($);
sub WriteInfo($$;$$);
sub SetFileModifyDate($$;$);
sub SetFileName($$;$);
sub GetAllTags(;$);
sub GetWritableTags(;$);
sub GetAllGroups($);
sub GetNewGroups($);
# non-public routines below
sub InsertTagValues($$$);
sub GetNewFileName($$);
sub LoadAllTables();
sub GetNewTagInfoList($;$);
sub GetNewTagInfoHash($$);
sub Get64s($$);
sub Get64u($$);
sub GetExtended($$);
sub DecodeBits($$);
sub EncodeBits($$);
sub HexDump($;$%);
sub VerboseInfo($$$%);
sub VerboseDir($$;$$);
sub VPrint($$@);
sub Rationalize($;$);
sub Write($@);
sub Tell($);
sub WriteValue($$;$$$$);
sub WriteDirectory($$$;$);
sub WriteBinaryData($$$);
sub CheckBinaryData($$$);
sub WriteTIFF($$$);

# list of main tag tables to load in LoadAllTables() (sub-tables are recursed
# automatically).  Note: They will appear in this order in the documentation,
# so put the Exif Table first.
@loadAllTables = qw(
    Exif CanonRaw KyoceraRaw MinoltaRaw SigmaRaw GeoTiff JFIF JFIF::Extension
    Jpeg2000 BMP BMP PICT PNG MNG MIFF PDF PostScript DICOM ID3 MPEG::Audio
    MPEG::Video Flash Real::Media Real::Audio Real::Metafile RIFF AIFF ASF
    QuickTime Sony::SR2SubIFD QuickTime::ImageFile Kodak::Meta FlashPix APP12
    APP14 AFCP Panasonic::Raw Photoshop::Header MIE
);

# recognized file types, in the order we test unknown files
# Notes: 1) There is no need to test for like types separately here
# 2) Put types with no file signature at end of list to avoid false matches
@fileTypes = qw(JPEG CRW TIFF GIF MRW RAF X3F JP2 PNG MIE MIFF PS PDF PSD XMP
                BMP PPM RIFF AIFF ASF MOV MPEG Real SWF ICC QTIF FPX PICT MP3
                DICM RAW);

# file types that we can write (edit)
my @writeTypes = qw(JPEG TIFF GIF CRW MRW PNG MIE PSD XMP PPM EPS PS ICC);

# file types that we can create from scratch
my @createTypes = qw(XMP ICC MIE);

# file type lookup for all recognized file extensions
my %fileTypeLookup = (
    ASF  => 'ASF',  # Microsoft Advanced Systems Format
    AVI  => 'RIFF', # Audio Video Interleaved (RIFF-based)
    ACR  => 'DICM', # American College of Radiology ACR-NEMA
    AI   => ['PDF','PS'], # Adobe Illustrator (PDF-like or PS-like)
    AIF  => 'AIFF', # Audio Interchange File Format (.3)
    AIFC => 'AIFF', # Audio Interchange File Format Compressed
    AIFF => 'AIFF', # Audio Interchange File Format (.4)
    BMP  => 'BMP',  # Windows BitMaP
    CR2  => 'TIFF', # Canon RAW 2 format (TIFF-like)
    CRW  => 'CRW',  # Canon RAW format
    DC3  => 'DICM', # DICOM image file
    DCM  => 'DICM', # DICOM image file
    DIB  => 'BMP',  # Device Independent Bitmap (aka. BMP)
    DIC  => 'DICM', # DICOM image file
    DICM => 'DICM', # DICOM image file
    DNG  => 'TIFF', # Digital Negative (TIFF-like)
    EPS  => 'EPS',  # Encapsulated PostScript Format (.3)
    EPSF => 'EPS',  # Encapsulated PostScript Format (.4)
    ERF  => 'TIFF', # Epson Raw Format (TIFF-like)
    FPX  => 'FPX',  # FlashPix
    GIF  => 'GIF',  # Compuserve Graphics Interchange Format
    ICC  => 'ICC',  # International Color Consortium
    ICM  => 'ICC',  # International Color Consortium
    JNG  => 'PNG',  # JPG Network Graphics (PNG-like)
    JP2  => 'JP2',  # JPEG 2000 file
    JPEG => 'JPEG', # Joint Photographic Experts Group (.4)
    JPG  => 'JPEG', # Joint Photographic Experts Group (.3)
    JPX  => 'JP2',  # JPEG 2000 file
    MIE  => 'MIE',  # Meta Information Encapsulation format
    MIF  => 'MIFF', # Magick Image File Format (.3)
    MIFF => 'MIFF', # Magick Image File Format (.4)
    MNG  => 'PNG',  # Multiple-image Network Graphics (PNG-like)
    MOS  => 'TIFF', # Creo Leaf Mosaic (TIFF-like)
    MOV  => 'MOV',  # Apple QuickTime movie
    MP3  => 'MP3',  # MPEG Layer 3 audio (uses ID3 information)
    MP4  => 'MOV',  # MPEG Layer 4 video (QuickTime-based)
    MPEG => 'MPEG', # MPEG audio/video format 1
    MPG  => 'MPEG', # MPEG audio/video format 1
    MRW  => 'MRW',  # Minolta RAW format
    NEF  => 'TIFF', # Nikon (RAW) Electronic Format (TIFF-like)
    ORF  => 'ORF',  # Olympus RAW format
    PBM  => 'PPM',  # Portable BitMap (PPM-like)
    PCT  => 'PICT', # Apple PICTure (.3)
    PDF  => 'PDF',  # Adobe Portable Document Format
    PEF  => 'TIFF', # Pentax (RAW) Electronic Format (TIFF-like)
    PGM  => 'PPM',  # Portable Gray Map (PPM-like)
    PICT => 'PICT', # Apple PICTure (.4)
    PNG  => 'PNG',  # Portable Network Graphics
    PPM  => 'PPM',  # Portable Pixel Map
    PS   => 'PS',   # PostScript
    PSD  => 'PSD',  # PhotoShop Drawing
    QIF  => 'QTIF', # QuickTime Image File (.3 alternate)
    QT   => 'MOV',  # QuickTime movie
    QTI  => 'QTIF', # QuickTime Image File (.3)
    QTIF => 'QTIF', # QuickTime Image File (.4)
    RA   => 'Real', # Real Audio
    RAF  => 'RAF',  # FujiFilm RAW Format
    RAM  => 'Real', # Real Audio Metafile
    RAW  => 'RAW',  # Kyocera Contax N Digital RAW or Panasonic RAW
    RIF  => 'RIFF', # Resource Interchange File Format (.3)
    RIFF => 'RIFF', # Resource Interchange File Format (.4)
    RM   => 'Real', # Real Media
    RMVB => 'Real', # Real Media Variable Bitrate
    RPM  => 'Real', # Real Media Plug-in Metafile
    RV   => 'Real', # Real Video
    SR2  => 'TIFF', # Sony RAW Format 2 (TIFF-like)
    SRF  => 'TIFF', # Sony RAW Format (TIFF-like)
    SWF  => 'SWF',  # Shockwave Flash
    THM  => 'JPEG', # Canon Thumbnail (aka. JPG)
    TIF  => 'TIFF', # Tagged Image File Format (.3)
    TIFF => 'TIFF', # Tagged Image File Format (.4)
    WAV  => 'RIFF', # WAVeform (Windows digital audio format)
    WDP  => 'TIFF', # Windows Media Photo (TIFF-based)
    WMA  => 'ASF',  # Windows Media Audio (ASF-based)
    WMV  => 'ASF',  # Windows Media Video (ASF-based)
    X3F  => 'X3F',  # Sigma RAW format
    XMP  => 'XMP',  # Extensible Metadata Platform data file
);

# MIME types for applicable file types above
# (missing entries default to 'application/unknown')
my %mimeType = (
    AIFF => 'audio/aiff',
    ASF  => 'video/x-ms-asf',
    AVI  => 'video/avi',
    BMP  => 'image/bmp',
    CR2  => 'image/x-raw',
    CRW  => 'image/x-raw',
    EPS  => 'application/postscript',
    ERF  => 'image/x-raw',
    DICM => 'application/dicom',
    DNG  => 'image/x-raw',
    FPX  => 'image/vnd.fpx',
    GIF  => 'image/gif',
    JNG  => 'image/jng',
    JP2  => 'image/jpeg2000',
    JPEG => 'image/jpeg',
    MIE  => 'application/x-mie',
    MIFF => 'application/x-magick-image',
    MNG  => 'video/mng',
    MOS  => 'image/x-raw',
    MOV  => 'video/quicktime',
    MP3  => 'audio/mpeg',
    MP4  => 'video/mp4',
    MPEG => 'video/mpeg',
    MRW  => 'image/x-raw',
    NEF  => 'image/x-raw',
    ORF  => 'image/x-raw',
    PBM  => 'image/x-portable-bitmap',
    PDF  => 'application/pdf',
    PEF  => 'image/x-raw',
    PGM  => 'image/x-portable-graymap',
    PICT => 'image/pict',
    PNG  => 'image/png',
    PPM  => 'image/x-portable-pixmap',
    PS   => 'application/postscript',
    PSD  => 'application/photoshop',
    QTIF => 'image/x-quicktime',
    RA   => 'audio/x-pn-realaudio',
    RAF  => 'image/x-raw',
    RAM  => 'audio/x-pn-realaudio',
    RAW  => 'image/x-raw',
    RM   => 'application/vnd.rn-realmedia',
    RMVB => 'application/vnd.rn-realmedia-vbr',
    RPM  => 'audio/x-pn-realaudio-plugin',
    RV   => 'video/vnd.rn-realvideo',
    SR2  => 'image/x-raw',
    SRF  => 'image/x-raw',
    SWF  => 'application/x-shockwave-flash',
    TIFF => 'image/tiff',
    WAV  => 'audio/x-wav',
    WDP  => 'image/vnd.ms-photo',
    WMA  => 'audio/x-ms-wma',
    WMV  => 'video/x-ms-wmv',
    X3F  => 'image/x-raw',
    XMP  => 'application/xmp',
);

# module names for each file type
# (missing entries have same module name as file type)
my %moduleName = (
    CRW  => 'CanonRaw',
    DICM => 'DICOM',
    EPS  => 'PostScript',
    ICC  => 'ICC_Profile',
    FPX  => 'FlashPix',
    JP2  => 'Jpeg2000',
    JPEG => '',     # (in the current module)
    MOV  => 'QuickTime',
    MP3  => 'ID3',
    MRW  => 'MinoltaRaw',
    ORF  => 'Olympus',
    PS   => 'PostScript',
    PSD  => 'Photoshop',
    QTIF => 'QuickTime',
    RAF  => 'FujiFilm',
    RAW  => 'KyoceraRaw',
    SWF  => 'Flash',
    TIFF => '',
    X3F  => 'SigmaRaw',
);

# default group priority for writing
my @defaultWriteGroups = qw(EXIF GPS IPTC XMP MakerNotes Photoshop ICC_Profile);

# group hash for ExifTool-generated tags
my %allGroupsExifTool = ( 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'ExifTool' );

# headers for various segment types
$exifAPP1hdr = "Exif\0\0";
$xmpAPP1hdr = "http://ns.adobe.com/xap/1.0/\0";
$psAPP13hdr = "Photoshop 3.0\0";
$psAPP13old = 'Adobe_Photoshop2.5:';

sub DummyWriteProc { return 1; }

# tag information for preview image
%Image::ExifTool::previewImageTagInfo = (
    Name => 'PreviewImage',
    Writable => 'undef',
    # a value of 'none' is ok...
    WriteCheck => '$val eq "none" ? undef : $self->CheckImage(\$val)',
    DataTag => 'PreviewImage',
    # we allow preview image to be set to '', but we don't want a zero-length value
    # in the IFD, so set it temorarily to 'none'.  Note that the length is <= 4,
    # so this value will fit in the IFD so the preview fixup won't be generated.
    ValueConv => '$self->ValidateImage(\$val,$tag)',
    ValueConvInv => '$val eq "" and $val="none"; $val',
);

# extra tags that aren't truly EXIF tags, but are generated by the script
# Note: any tag in this list with a name corresponding to a Group0 name is
#       used to write the entire corresponding directory as a block.
%Image::ExifTool::Extra = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    DID_TAG_ID => 1,   # tag ID's aren't meaningful for these tags
    WRITE_PROC => \&DummyWriteProc,
    Comment => {
        Name => 'Comment',
        Notes => 'comment embedded in JPEG, GIF89a or PPM/PGM/PBM image',
        Writable => 1,
        WriteGroup => 'Comment',
        Priority => 0,  # to preserve order of JPEG COM segments
    },
    Directory => {
        Name => 'Directory',
        Writable => 1,
        Protected => 1,
        # translate backslashes in directory names and add trailing '/'
        ValueConvInv => '$_=$val; tr/\\\\/\//; m{[^/]$} and $_ .= "/"; $_',
    },
    FileName => {
        Name => 'FileName',
        Writable => 1,
        Protected => 1,
        ValueConvInv => '$val=~tr/\\\\/\//; $val',
    },
    FileSize => {
        Name => 'FileSize',
        PrintConv => sub {
            my $val = shift;
            $val < 2048 and return "$val bytes";
            $val < 2097152 and return sprintf('%.0f kB', $val / 1024);
            return sprintf('%.0f MB', $val / 1048576);
        },
    },
    FileType    => { Name => 'FileType' },
    FileModifyDate => {
        Name => 'FileModifyDate',
        Description => 'File Modification Date/Time',
        Notes => 'the filesystem modification time',
        Groups => { 2 => 'Time' },
        Writable => 1,
        Shift => 'Time',
        ValueConv => 'ConvertUnixTime($val,"local")',
        ValueConvInv => 'GetUnixTime($val,"local")',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$val',
    },
    MIMEType    => { Name => 'MIMEType' },
    ImageWidth  => { Name => 'ImageWidth' },
    ImageHeight => { Name => 'ImageHeight' },
    XResolution => { Name => 'XResolution' },
    YResolution => { Name => 'YResolution' },
    MaxVal      => { Name => 'MaxVal' },    # max pixel value in PPM or PGM image
    EXIF => {
        Name => 'EXIF',
        Notes => 'the full EXIF data block',
        Groups => { 0 => 'EXIF' },
        ValueConv => '\$val',
    },
    ICC_Profile => {
        Name => 'ICC_Profile',
        Notes => 'the full ICC_Profile data block',
        Groups => { 0 => 'ICC_Profile' },
        Writable => 1,
        Protected => 1,
        ValueConv => '\$val',
        ValueConvInv => '$val',
        WriteCheck => q{
            require Image::ExifTool::ICC_Profile;
            return Image::ExifTool::ICC_Profile::ValidateICC(\$val);
        },
    },
    XMP => {
        Name => 'XMP',
        Notes => 'the full XMP data block',
        Groups => { 0 => 'XMP' },
        Writable => 1,
        ValueConv => '\$val',
        ValueConvInv => '$val',
        WriteCheck => q{
            require Image::ExifTool::XMP;
            return Image::ExifTool::XMP::CheckXMP($self, $tagInfo, \$val);
        },
    },
    ExifToolVersion => {
        Name        => 'ExifToolVersion',
        Description => 'ExifTool Version Number',
        Groups      => \%allGroupsExifTool
    },
    Encryption  => { Name => 'Encryption' },
    Error       => { Name => 'Error',   Priority => 0, Groups => \%allGroupsExifTool },
    Warning     => { Name => 'Warning', Priority => 0, Groups => \%allGroupsExifTool },
);

# static private ExifTool variables

%allTables = ( );   # list of all tables loaded (except composite tags)
@tableOrder = ( );  # order the tables were loaded

my $didTagID;       # flag indicating we are accessing tag ID's
my $evalWarning;    # eval warning message

# composite tags (accumulation of all Composite tag tables)
%Image::ExifTool::Composite = (
    GROUPS => { 0 => 'Composite', 1 => 'Composite' },
    DID_TAG_ID => 1,    # want empty tagID's for composite tags
    WRITE_PROC => \&DummyWriteProc,
);

# JFIF APP0 definitions
%Image::ExifTool::JFIF::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'JFIF', 1 => 'JFIF', 2 => 'Image' },
    0 => {
        Name => 'JFIFVersion',
        Format => 'int8u[2]',
        PrintConv => '$val=~tr/ /./;$val',
    },
    2 => {
        Name => 'ResolutionUnit',
        Writable => 1,
        PrintConv => {
            0 => 'None',
            1 => 'inches',
            2 => 'cm',
        },
        Priority => -1,
    },
    3 => {
        Name => 'XResolution',
        Format => 'int16u',
        Writable => 1,
        Priority => -1,
    },
    5 => {
        Name => 'YResolution',
        Format => 'int16u',
        Writable => 1,
        Priority => -1,
    },
);
%Image::ExifTool::JFIF::Extension = (
    GROUPS => { 0 => 'JFIF', 1 => 'JFIF', 2 => 'Image' },
    0x10 => {
        Name => 'ThumbnailImage',
        ValueConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# APP14 refs:
# http://partners.adobe.com/public/developer/en/ps/sdk/5116.DCT_Filter.pdf
# http://java.sun.com/j2se/1.5.0/docs/api/javax/imageio/metadata/doc-files/jpeg_metadata.html#color
%Image::ExifTool::APP14::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP14', 1 => 'APP14', 2 => 'Image' },
    NOTES => 'The "Adobe" APP14 segment stores image encoding information.',
    FORMAT => 'int16u',
    0 => 'DCTEncodeVersion',
    1 => {
        Name => 'APP14Flags0',
        PrintConv => { BITMASK => {
            15 => 'Encoded with Blend=1 downsampling'
        } },
    },
    2 => {
        Name => 'APP14Flags1',
        PrintConv => { BITMASK => { } },
    },
    3 => {
        Name => 'ColorTransform',
        Format => 'int8u',
        PrintConv => {
            0 => 'Unknown (RGB or CMYK)',
            1 => 'YCbCr',
            2 => 'YCCK',
        },
    },
);

# special tag names (not used for tag info)
my %specialTags = (
    PROCESS_PROC=>1, WRITE_PROC=>1, CHECK_PROC=>1, GROUPS=>1, FORMAT=>1,
    FIRST_ENTRY=>1, TAG_PREFIX=>1, PRINT_CONV=>1, DID_TAG_ID=>1, WRITABLE=>1,
    NOTES=>1, IS_OFFSET=>1, EXTRACT_UNKNOWN=>1, NAMESPACE=>1, PREFERRED=>1,
    PARENT=>1, PRIORITY=>1, WRITE_GROUP=>1, LANG_INFO=>1, VARS=>1,
);

#------------------------------------------------------------------------------
# New - create new ExifTool object
# Inputs: 0) reference to exiftool object or ExifTool class name
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool';
    my $self = bless {}, $class;

    # make sure our main Exif tag table has been loaded
    GetTagTable("Image::ExifTool::Exif::Main");

    $self->ClearOptions();      # create default options hash
    $self->{VALUE} = { };       # must initialize this for warning messages

    # initialize our new groups for writing
    $self->SetNewGroups(@defaultWriteGroups);

    return $self;
}

#------------------------------------------------------------------------------
# ImageInfo - return specified information from image file
# Inputs: 0) [optional] ExifTool object reference
#         1) filename, file reference, or scalar data reference
#         2-N) list of tag names to find (or tag list reference or options reference)
# Returns: reference to hash of tag/value pairs (with "Error" entry on error)
# Notes:
#   - if no tags names are specified, the values of all tags are returned
#   - tags may be specified with leading '-' to exclude
#   - can pass a reference to list of tags to find, in which case the list will
#     be updated with the tags found in the proper case and in the specified order.
#   - can pass reference to hash specifying options
#   - returned tag values may be scalar references indicating binary data
#   - see ClearOptions() below for a list of options and their default values
# Examples:
#   use Image::ExifTool 'ImageInfo';
#   my $info = ImageInfo($file, 'DateTimeOriginal', 'ImageSize');
#    - or -
#   my $exifTool = new Image::ExifTool;
#   my $info = $exifTool->ImageInfo($file, \@tagList, {Sort=>'Group0'} );
sub ImageInfo($;@)
{
    local $_;
    # get our ExifTool object ($self) or create one if necessary
    my $self;
    if (ref $_[0] and UNIVERSAL::isa($_[0],'Image::ExifTool')) {
        $self = shift;
    } else {
        $self = new Image::ExifTool;
    }
    my %saveOptions = %{$self->{OPTIONS}};  # save original options

    # initialize file information
    $self->{FILENAME} = $self->{RAF} = undef;

    $self->ParseArguments(@_);              # parse our function arguments
    $self->ExtractInfo(undef);              # extract meta information from image
    my $info = $self->GetInfo(undef);       # get requested information

    $self->{OPTIONS} = \%saveOptions;       # restore original options

    return $info;   # return requested information
}

#------------------------------------------------------------------------------
# Get/set ExifTool options
# Inputs: 0) ExifTool object reference,
#         1) Parameter name, 2) Value to set the option
#         3-N) More parameter/value pairs
# Returns: original value of last option specified
sub Options($$;@)
{
    local $_;
    my $self = shift;
    my $oldVal;

    while (@_) {
        my $param = shift;
        $oldVal = $self->{OPTIONS}->{$param};
        last unless @_;
        $self->{OPTIONS}->{$param} = shift;
    }
    return $oldVal;
}

#------------------------------------------------------------------------------
# ClearOptions - set options to default values
# Inputs: 0) ExifTool object reference
sub ClearOptions($)
{
    local $_;
    my $self = shift;

    # create options hash with default values
    # (commented out options don't need initializing)
    $self->{OPTIONS} = {
        Binary      => 0,       # flag to extract binary values even if tag not specified
    #   ByteOrder   => undef,   # default byte order when creating EXIF information
        Charset     => 'UTF8',  # character set for converting Unicode characters
    #   Compact     => undef,   # compact XMP and IPTC data
        Composite   => 1,       # flag to calculate Composite tags
    #   CoordFormat => undef,   # GPS lat/long coordinate format
    #   DateFormat  => undef,   # format for date/time
        Duplicates  => 1,       # flag to save duplicate tag values
    #   Exclude     => undef,   # tags to exclude
    #   FixBase     => undef,   # fix maker notes base offsets
    #   Group#      => undef,   # return tags for specified groups in family #
        HtmlDump    => 0,       # HTML dump (0-3, higher # = bigger limit)
    #   IgnoreMinorErrors => undef, # ignore minor errors when reading/writing
    #   List        => undef,   # extract lists of PrintConv values into arrays
    #   MakerNotes  => undef,   # extract maker notes as a block
        PrintConv   => 1,       # flag to enable print conversion
        Sort        => 'Input', # order to sort found tags (Input, File, Alpha, Group#)
    #   StrictDate  => undef,   # flag to return undef for invalid date conversions
        TextOut     => \*STDOUT,# file for Verbose/HtmlDump output
        Unknown     => 0,       # flag to get values of unknown tags (0-2)
        Verbose     => 0,       # print verbose messages (0-4, higher # = more verbose)
    };
}

#------------------------------------------------------------------------------
# Extract meta information from image
# Inputs: 0) ExifTool object reference
#         1-N) Same as ImageInfo()
# Returns: 1 if this was a valid image, 0 otherwise
# Notes: pass an undefined value to avoid parsing arguments
sub ExtractInfo($;@)
{
    local $_;
    my $self = shift;
    my $options = $self->{OPTIONS};     # pointer to current options
    my %saveOptions;

    if (defined $_[0]) {
        %saveOptions = %{$self->{OPTIONS}}; # save original options

        # only initialize filename if called with arguments
        $self->{FILENAME} = undef;      # name of file (or '' if we didn't open it)
        $self->{RAF} = undef;           # RandomAccess object reference

        $self->ParseArguments(@_);      # initialize from our arguments
    }
    # initialize ExifTool object members
    $self->Init();

    delete $self->{MAKER_NOTE_FIXUP};   # fixup information for extracted maker notes
    delete $self->{MAKER_NOTE_BYTE_ORDER};

    my $filename = $self->{FILENAME};   # image file name ('' if already open)
    my $raf = $self->{RAF};             # RandomAccess object

    # return our version number
    $self->FoundTag('ExifToolVersion', $VERSION);

    local *EXIFTOOL_FILE;   # avoid clashes with global namespace

    unless ($raf) {
        # save file name
        if (defined $filename and $filename ne '') {
            unless ($filename eq '-') {
                my $name = $filename;
                # extract file name from pipe if necessary
                $name =~ /\|$/ and $name =~ s/.*?"(.*)".*/$1/;
                $name =~ s/(.*)\///;  # remove path
                my $dir = $1;
                $self->FoundTag('FileName', $name);
                $self->FoundTag('Directory', $dir) if $dir;
            }
            # open the file
            if (open(EXIFTOOL_FILE,$filename)) {
                my $filePt = \*EXIFTOOL_FILE;
                # create random access file object
                $raf = new File::RandomAccess($filePt);
                # patch to force pipe to be buffered because seek returns success
                # in Windows cmd shell pipe even though it really failed
                $raf->{TESTED} = -1 if $filename eq '-' or $filename =~ /\|$/;
                $self->{RAF} = $raf;
            } else {
                $self->Error('Error opening file');
            }
        } else {
            $self->Error('No file specified');
        }
    }

    if ($raf) {
        # get file size and last modified time if this is a plain file
        if ($raf->{FILE_PT} and -f $raf->{FILE_PT}) {
            my $fileSize = -s _;
            my $fileTime = -M _;
            $self->FoundTag('FileSize', $fileSize) if defined $fileSize;
            $self->FoundTag('FileModifyDate', $^T - $fileTime*(24*3600)) if defined $fileTime;
        }

        # get list of file types to check
        my $tiffType;
        $self->{FILE_EXT} = GetFileExtension($filename);
        my @fileTypeList = GetFileType($filename);
        if (@fileTypeList) {
            # add remaining types to end of list so we test them all
            my $pat = join '|', @fileTypeList;
            push @fileTypeList, grep(!/^($pat)$/, @fileTypes);
            $tiffType = $self->{FILE_EXT};
        } else {
            # scan through all recognized file types
            @fileTypeList = @fileTypes;
            $tiffType = 'TIFF';
        }
        push @fileTypeList, ''; # end of list marker
        # initialize the input file for seeking in binary data
        $raf->BinMode();    # set binary mode before we start reading
        my $pos = $raf->Tell(); # get file position so we can rewind
        my %dirInfo = ( RAF => $raf, Base => $pos );
        # loop through list of file types to test
        for (;;) {
            my $type = shift @fileTypeList;
            unless ($type) {
                unless (defined $type) {
                    # if we were given a single image with a known type there
                    # must be a format error since we couldn't read it, otherwise
                    # it is likely we don't support images of this type
                    $self->Error(GetFileType($filename) ?
                        'Image format error' : 'Unknown image type');
                    last;   # all done
                }
                # last ditch effort to scan past unknown header for JPEG/TIFF
                my $buff;
                $raf->Read($buff, 1024);
                next unless $buff =~ /(\xff\xd8\xff|MM\0\x2a|II\x2a\0)/g;
                $type = ($1 eq "\xff\xd8\xff") ? 'JPEG' : 'TIFF';
                my $skip = pos($buff) - length($1);
                $dirInfo{Base} = $pos + $skip;
                $raf->Seek($pos + $skip, 0);
                $self->Warn("Skipped unknown $skip byte header");
            }
            # save file type in member variable
            $self->{FILE_TYPE} = $type;
            $dirInfo{Parent} = ($type eq 'TIFF') ? $tiffType : $type;
            my $module = $moduleName{$type};
            $module = $type unless defined $module;
            my $func = "Process$type";

            # load module if necessary
            if ($module) {
                require "Image/ExifTool/$module.pm";
                $func = "Image::ExifTool::${module}::$func";
            }
            # process the file
            no strict 'refs';
            &$func($self, \%dirInfo) and last;
            use strict 'refs';

            # seek back to try again from the same position in the file
            unless ($raf->Seek($pos, 0)) {
                $self->Error('Error seeking in file');
                last;
            }
        }
        # extract binary EXIF data block only if requested
        if (defined $self->{EXIF_DATA} and $self->{REQ_TAG_LOOKUP}->{exif}) {
            $self->FoundTag('EXIF', $self->{EXIF_DATA});
        }
        # calculate composite tags
        $self->BuildCompositeTags() if $options->{Composite};

        # do our HTML dump if requested
        if ($self->{HTML_DUMP}) {
            my $dataPt = defined $self->{EXIF_DATA} ? \$self->{EXIF_DATA} : undef;
            $self->{HTML_DUMP}->Print($raf, $dataPt, $self->{EXIF_POS},
                $self->{OPTIONS}->{TextOut}, $self->{OPTIONS}->{HtmlDump},
                $self->{FILENAME} ? "HTML Dump ($self->{FILENAME})" : 'HTML Dump');
        }

        $raf->Close() if $filename;     # close the file if we opened it
    }

    # restore original options
    %saveOptions and $self->{OPTIONS} = \%saveOptions;

    return exists $self->{VALUE}->{Error} ? 0 : 1;
}

#------------------------------------------------------------------------------
# Get hash of extracted meta information
# Inputs: 0) ExifTool object reference
#         1-N) options hash reference, tag list reference or tag names
# Returns: Reference to information hash
# Notes: - pass an undefined value to avoid parsing arguments
#        - If groups are specified, first groups take precedence if duplicate
#          tags found but Duplicates option not set.
sub GetInfo($;@)
{
    local $_;
    my $self = shift;
    my %saveOptions;

    unless (@_ and not defined $_[0]) {
        %saveOptions = %{$self->{OPTIONS}}; # save original options
        # must set FILENAME so it isn't parsed from the arguments
        $self->{FILENAME} = '' unless defined $self->{FILENAME};
        $self->ParseArguments(@_);
    }

    # get reference to list of tags for which we will return info
    my $rtnTags = $self->SetFoundTags();

    # build hash of tag information
    my (%info, %ignored);
    my $conv = $self->{OPTIONS}->{PrintConv} ? 'PrintConv' : 'ValueConv';
    foreach (@$rtnTags) {
        my $val = $self->GetValue($_, $conv);
        defined $val or $ignored{$_} = 1, next;
        $info{$_} = $val;
    }

    # remove ignored tags from the list
    my $reqTags = $self->{REQUESTED_TAGS} || [ ];
    if (%ignored and not @$reqTags) {
        my @goodTags;
        foreach (@$rtnTags) {
            push @goodTags, $_ unless $ignored{$_};
        }
        $rtnTags = $self->{FOUND_TAGS} = \@goodTags;
    }

    # return sorted tag list if provided with a list reference
    if ($self->{IO_TAG_LIST}) {
        # use file order by default if no tags specified
        # (no such thing as 'Input' order in this case)
        my $sortOrder = $self->{OPTIONS}->{Sort};
        unless (@$reqTags or ($sortOrder and $sortOrder ne 'Input')) {
            $sortOrder = 'File';
        }
        # return tags in specified sort order
        @{$self->{IO_TAG_LIST}} = $self->GetTagList($rtnTags, $sortOrder);
    }

    # restore original options
    %saveOptions and $self->{OPTIONS} = \%saveOptions;

    return \%info;
}

#------------------------------------------------------------------------------
# Combine information from a list of info hashes
# Unless Duplicates is enabled, first entry found takes priority
# Inputs: 0) ExifTool object reference, 1-N) list of info hash references
# Returns: Combined information hash reference
sub CombineInfo($;@)
{
    local $_;
    my $self = shift;
    my (%combinedInfo, $info);

    if ($self->{OPTIONS}->{Duplicates}) {
        while ($info = shift) {
            my $key;
            foreach $key (keys %$info) {
                $combinedInfo{$key} = $$info{$key};
            }
        }
    } else {
        my (%haveInfo, $tag);
        while ($info = shift) {
            foreach $tag (keys %$info) {
                my $tagName = GetTagName($tag);
                next if $haveInfo{$tagName};
                $haveInfo{$tagName} = 1;
                $combinedInfo{$tag} = $$info{$tag};
            }
        }
    }
    return \%combinedInfo;
}

#------------------------------------------------------------------------------
# Inputs: 0) ExifTool object reference
#         1) [optional] reference to info hash or tag list ref (default is found tags)
#         2) [optional] sort order ('File', 'Input', ...)
# Returns: List of tags in specified order
sub GetTagList($;$$)
{
    local $_;
    my ($self, $info, $sortOrder) = @_;

    my $foundTags;
    if (ref $info eq 'HASH') {
        my @tags = keys %$info;
        $foundTags = \@tags;
    } elsif (ref $info eq 'ARRAY') {
        $foundTags = $info;
    }
    my $fileOrder = $self->{FILE_ORDER};

    if ($foundTags) {
        # make sure a FILE_ORDER entry exists for all tags
        # (note: already generated bogus entries for FOUND_TAGS case below)
        foreach (@$foundTags) {
            next if defined $$fileOrder{$_};
            $$fileOrder{$_} = 999;
        }
    } else {
        $sortOrder = $info if $info and not $sortOrder;
        $foundTags = $self->{FOUND_TAGS} || $self->SetFoundTags() or return undef;
    }
    $sortOrder or $sortOrder = $self->{OPTIONS}->{Sort};

    # return original list if no sort order specified
    return @$foundTags unless $sortOrder and $sortOrder ne 'Input';

    if ($sortOrder eq 'Alpha') {
        return sort @$foundTags;
    } elsif ($sortOrder =~ /^Group(\d*)/) {
        my $family = $1 || 0;
        # want to maintain a basic file order with the groups
        # ordered in the way they appear in the file
        my (%groupCount, %groupOrder);
        my $numGroups = 0;
        my $tag;
        foreach $tag (sort { $$fileOrder{$a} <=> $$fileOrder{$b} } @$foundTags) {
            my $group = $self->GetGroup($tag, $family);
            my $num = $groupCount{$group};
            $num or $num = $groupCount{$group} = ++$numGroups;
            $groupOrder{$tag} = $num;
        }
        return sort { $groupOrder{$a} <=> $groupOrder{$b} or
                      $$fileOrder{$a} <=> $$fileOrder{$b} } @$foundTags;
    } else {
        return sort { $$fileOrder{$a} <=> $$fileOrder{$b} } @$foundTags;
    }
}

#------------------------------------------------------------------------------
# Get list of found tags in specified sort order
# Inputs: 0) ExifTool object reference, 1) sort order ('File', 'Input', ...)
# Returns: List of tags in specified order
# Notes: If not specified, sort order is taken from OPTIONS
sub GetFoundTags($;$)
{
    local $_;
    my ($self, $sortOrder) = @_;
    my $foundTags = $self->{FOUND_TAGS} || $self->SetFoundTags() or return undef;
    return $self->GetTagList($foundTags, $sortOrder);
}

#------------------------------------------------------------------------------
# Get list of requested tags
# Inputs: 0) ExifTool object reference
# Returns: List of requested tags
sub GetRequestedTags($)
{
    local $_;
    return @{$_[0]->{REQUESTED_TAGS}};
}

#------------------------------------------------------------------------------
# Get tag value
# Inputs: 0) ExifTool object reference, 1) tag key
#         2) [optional] Value type: PrintConv, ValueConv, Both or Raw, the default
#            is PrintConv or ValueConv, depending on the PrintConv option setting
# Returns: Scalar context: tag value or undefined
#          List context: list of values or empty list
sub GetValue($$;$)
{
    local $_;
    my ($self, $tag, $type) = @_;

    # start with the raw value
    my $value = $self->{VALUE}->{$tag};
    return wantarray ? () : undef unless defined $value;

    # figure out what conversions to do
    my (@convTypes, $tagInfo);
    $type or $type = $self->{OPTIONS}->{PrintConv} ? 'PrintConv' : 'ValueConv';
    unless ($type eq 'Raw') {
        $tagInfo = $self->{TAG_INFO}->{$tag};
        push @convTypes, 'ValueConv';
        push @convTypes, 'PrintConv' unless $type eq 'ValueConv';
    }

    # do the conversons
    my (@val, @prt, @raw, $convType, $valueConv);
    foreach $convType (@convTypes) {
        last if ref $value eq 'SCALAR'; # don't convert a scalar reference
        my $conversion = $$tagInfo{$convType};
        unless (defined $conversion) {
            next unless $convType eq 'PrintConv';
            # use PRINT_CONV from tag table if PrintConv not defined
            next unless defined($conversion = $tagInfo->{Table}->{PRINT_CONV});
        }
        # save old ValueConv value if we want Both
        $valueConv = $value if $type eq 'Both' and $convType eq 'PrintConv';
        # initialize array so we can iterate over values in list
        my ($i, $val, $vals, @values);
        if (ref $value eq 'ARRAY') {
            $i = 0;
            $vals = $value;
            $val = $$vals[0];
        } else {
            $val = $value;
        }
        # loop through all values in list
        for (;;) {
            if (ref $conversion eq 'HASH') {
                # look up converted value in hash
                unless (defined($value = $$conversion{$val})) {
                    if ($$conversion{BITMASK}) {
                        $value = DecodeBits($val, $$conversion{BITMASK});
                    } else {
                        if ($$tagInfo{PrintHex} and $val and $convType eq 'PrintConv') {
                            $val = sprintf('0x%x',$val);
                        }
                        $value = "Unknown ($val)";
                    }
                }
            } else {
                # call subroutine or do eval to convert value
                local $SIG{'__WARN__'} = sub { $evalWarning = $_[0]; };
                undef $evalWarning;
                if (ref($conversion) eq 'CODE') {
                    $value = &$conversion($val, $self);
                } else {
                    # get values of required tags if this is composite
                    if (ref $val eq 'HASH' and not @val) {
                        foreach (keys %$val) {
                            $raw[$_] = $self->{VALUE}->{$$val{$_}};
                            ($val[$_], $prt[$_]) = $self->GetValue($$val{$_}, 'Both');
                            next if defined $val[$_] or not $tagInfo->{Require}->{$_};
                            return wantarray ? () : undef;
                        }
                    }
                    #### eval ValueConv/PrintConv ($val, $self, @val, @prt, @raw)
                    $value = eval $conversion;
                    $@ and $evalWarning = $@;
                }
                if ($evalWarning) {
                    chomp $evalWarning;
                    $evalWarning =~ s/ at \(eval .*//s;
                    delete $SIG{'__WARN__'};
                    warn "$convType $tag: $evalWarning\n";
                }
            }
            last unless $vals;
            # save this converted value and step to next value in list
            push @values, $value if defined $value;
            if (++$i >= scalar(@$vals)) {
                $value = \@values if @values;
                last;
            }
            $val = $$vals[$i];
        }
        # return undefined now if no value
        return wantarray ? () : undef unless defined $value;
    }
    if ($type eq 'Both') {
        # $valueConv is undefined if there was no print conversion done
        $valueConv = $value unless defined $valueConv;
        # return Both values as a list (ValueConv, PrintConv)
        return ($valueConv, $value);
    }
    if (ref $value eq 'ARRAY') {
        # return array if requested
        return @$value if wantarray;
        # return list reference for Raw, ValueConv or if List option set
        return $value if @convTypes < 2 or $self->{OPTIONS}->{List};
        # otherwise join in comma-separated string
        $value = join ', ', @$value;
    }
    return $value;
}

#------------------------------------------------------------------------------
# Get tag identification number
# Inputs: 0) ExifTool object reference, 1) tag key
# Returns: Tag ID if available, otherwise ''
sub GetTagID($$)
{
    local $_;
    my ($self, $tag) = @_;
    my $tagInfo = $self->{TAG_INFO}->{$tag};

    if ($tagInfo) {
        GenerateAllTagIDs();    # make sure tag ID's are generated
        defined $$tagInfo{TagID} and return $$tagInfo{TagID};
    }
    # no ID for this tag (shouldn't happen)
    return '';
}

#------------------------------------------------------------------------------
# Get description for specified tag
# Inputs: 0) ExifTool object reference, 1) tag key
# Returns: Tag description
# Notes: Will always return a defined value, even if description isn't available
sub GetDescription($$)
{
    local $_;
    my ($self, $tag) = @_;
    my $tagInfo = $self->{TAG_INFO}->{$tag};
    # ($tagInfo should be defined for any extracted tag,
    # but we might as well handle the case where it isn't)
    my $desc;
    $desc = $$tagInfo{Description} if $tagInfo;
    # just make the tag more readable if description doesn't exist
    unless ($desc) {
        $desc = MakeDescription(GetTagName($tag));
        # save description in tag information
        $$tagInfo{Description} = $desc if $tagInfo;
    }
    return $desc;
}

#------------------------------------------------------------------------------
# Get group name for specified tag
# Inputs: 0) ExifTool object reference
#         1) tag key (or reference to tagInfo hash, not part of the public API)
#         2) [optional] group family number (-1 to get extended group list)
# Returns: Scalar context: Group name (for family 0 if not otherwise specified)
#          Array context: Group name if family specified, otherwise list of
#          group names for each family.
sub GetGroup($$;$)
{
    local $_;
    my ($self, $tag, $family) = @_;
    my ($tagInfo, @groups, $extra);
    if (ref $tag eq 'HASH') {
        $tagInfo = $tag;
        $tag = $tagInfo->{Name};
    } else {
        $tagInfo = $self->{TAG_INFO}->{$tag} or return '';
    }
    my $groups = $$tagInfo{Groups};
    # fill in default groups unless already done
    unless ($$tagInfo{GotGroups}) {
        my $tagTablePtr = $$tagInfo{Table};
        if ($tagTablePtr) {
            # construct our group list
            $groups or $groups = $$tagInfo{Groups} = { };
            # fill in default groups
            foreach (keys %{$$tagTablePtr{GROUPS}}) {
                $$groups{$_} or $$groups{$_} = $tagTablePtr->{GROUPS}->{$_};
            }
        }
        # set flag indicating group list was built
        $$tagInfo{GotGroups} = 1;
    }
    if (defined $family and $family >= 0) {
        return $$groups{$family} || 'Other' unless $family == 1;
        $groups[$family] = $$groups{$family};
    } else {
        return $$groups{0} unless wantarray;
        foreach (0..2) { $groups[$_] = $$groups{$_}; }
    }
    # modify family 1 group name if necessary
    if ($extra = $self->{GROUP1}->{$tag}) {
        if ($extra =~ /^\+(.*)/) {
            $groups[1] .= $1;
        } else {
            $groups[1] = $extra;
        }
    }
    if ($family) {
        return $groups[1] if $family == 1;
        # add additional matching group names to list
        # ie) for MIE-Doc, also add MIE1, MIE1-Doc, MIE-Doc1 and MIE1-Doc1
        # and for MIE2-Doc3, also add MIE2, MIE-Doc3, MIE2-Doc and MIE-Doc
        if ($groups[1] =~ /^MIE(\d*)-(.+?)(\d*)$/) {
            push @groups, 'MIE' . ($1 || '1');
            push @groups, 'MIE' . ($1 ? '' : '1') . "-$2$3";
            push @groups, "MIE$1-$2" . ($3 ? '' : '1');
            push @groups, 'MIE' . ($1 ? '' : '1') . "-$2" . ($3 ? '' : '1');
        }
    }
    return @groups;
}

#------------------------------------------------------------------------------
# Get group names for specified tags
# Inputs: 0) ExifTool object reference
#         1) [optional] information hash reference (default all extracted info)
#         2) [optional] group family number (default 0)
# Returns: List of group names in alphabetical order
sub GetGroups($;$$)
{
    local $_;
    my $self = shift;
    my $info = shift;
    my $family;

    # figure out our arguments
    if (ref $info ne 'HASH') {
        $family = $info;
        $info = $self->{VALUE};
    } else {
        $family = shift;
    }
    $family = 0 unless defined $family;

    # get a list of all groups in specified information
    my ($tag, %groups);
    foreach $tag (keys %$info) {
        $groups{ $self->GetGroup($tag, $family) } = 1;
    }
    return sort keys %groups;
}

#------------------------------------------------------------------------------
# set priority for group where new values are written
# Inputs: 0) ExifTool object reference,
#         1-N) group names (reset to default if no groups specified)
sub SetNewGroups($;@)
{
    local $_;
    my ($self, @groups) = @_;
    @groups or @groups = @defaultWriteGroups;
    my $count = @groups;
    my %priority;
    foreach (@groups) {
        $priority{lc($_)} = $count--;
    }
    $priority{file} = 10;       # 'File' group is always written (Comment)
    $priority{composite} = 10;  # 'Composite' group is always written
    # set write priority (higher # is higher priority)
    $self->{WRITE_PRIORITY} = \%priority;
    $self->{WRITE_GROUPS} = \@groups;
}

#------------------------------------------------------------------------------
# Build composite tags from required tags
# Inputs: 0) ExifTool object reference
# Note: Tag values are calculated in alphabetical order unless a tag Require's
#       or Desire's another composite tag, in which case the calculation is
#       deferred until after the other tag is calculated.
sub BuildCompositeTags($)
{
    local $_;
    my $self = shift;
    my @tagList = sort keys %Image::ExifTool::Composite;

    my $rawValue = $self->{VALUE};
    for (;;) {
        my %notBuilt;
        foreach (@tagList) {
            $notBuilt{$_} = 1;
        }
        my @deferredTags;
        my $tag;
COMPOSITE_TAG:
        foreach $tag (@tagList) {
            next if $specialTags{$tag};
            my $tagInfo = $self->GetTagInfo(\%Image::ExifTool::Composite, $tag);
            next unless $tagInfo;
            # put required tags into array and make sure they all exist
            my (%tagKey, $type, $found);
            foreach $type ('Require','Desire') {
                my $req = $$tagInfo{$type} or next;
                # save Require'd and Desire'd tag values in list
                my $index;
                foreach $index (keys %$req) {
                    my $reqTag = $$req{$index};
                    # allow tag group to be specified
                    if ($reqTag =~ /(.+?):(.+)/) {
                        my ($reqGroup, $name) = ($1, $2);
                        my $family;
                        $family = $1 if $reqGroup =~ s/^(\d+)//;
                        my $i = 0;
                        for (;;++$i) {
                            $reqTag = $name;
                            $reqTag .= " ($i)" if $i;
                            last unless defined $$rawValue{$reqTag};
                            my @groups = $self->GetGroup($reqTag, $family);
                            last if grep { $reqGroup eq $_ } @groups;
                        }
                    } elsif ($notBuilt{$reqTag}) {
                        # calculate this tag later if it relies on another
                        # Composite tag which hasn't been calculated yet
                        push @deferredTags, $tag;
                        next COMPOSITE_TAG;
                    }
                    if (defined $$rawValue{$reqTag}) {
                        $found = 1;
                    } else {
                        # don't continue if we require this tag
                        $type eq 'Require' and next COMPOSITE_TAG;
                    }
                    $tagKey{$index} = $reqTag;
                }
            }
            delete $notBuilt{$tag}; # this tag is OK to build now
            $self->FoundTag($tagInfo, \%tagKey) if $found;
        }
        last unless @deferredTags;
        if (@deferredTags == @tagList) {
            # everything was deferred in the last pass,
            # must be a circular dependency
            warn "Circular dependency in Composite tags\n";
            last;
        }
        @tagList = @deferredTags; # calculate deferred tags now
    }
}

#------------------------------------------------------------------------------
# Get tag name (removes copy index)
# Inputs: 0) Tag key
# Returns: Tag name
sub GetTagName($)
{
    local $_;
    $_[0] =~ /^(\S+)/;
    return $1;
}

#------------------------------------------------------------------------------
# Get list of shortcuts
# Returns: Shortcut list (sorted alphabetically)
sub GetShortcuts()
{
    local $_;
    require Image::ExifTool::Shortcuts;
    return sort keys %Image::ExifTool::Shortcuts::Main;
}

#------------------------------------------------------------------------------
# Get file type for specified extension
# Inputs: 1) file name or extension (case is not significant)
# Returns: File type or undef if extension not supported.  In array context,
#          may return more than one file type if the file may be different formats.
#          Returns list of all recognized extensions if no file specified
sub GetFileType(;$)
{
    local $_;
    my $file = shift;
    return sort keys %fileTypeLookup unless defined $file;
    my $fileType;
    my $fileExt = GetFileExtension($file);
    $fileExt = uc($file) unless $fileExt;
    $fileExt and $fileType = $fileTypeLookup{$fileExt}; # look up the file type
    if (wantarray) {
        return () unless $fileType;
        return @$fileType if ref $fileType eq 'ARRAY';
    } elsif ($fileType) {
        $fileType = $fileExt if ref $fileType eq 'ARRAY';
    }
    return $fileType;
}

#------------------------------------------------------------------------------
# return true if we can write the specified file type
# Inputs: 0) file name or ext,
# Returns: true if writable, 0 if not writable, undef if unrecognized
sub CanWrite($)
{
    local $_;
    my $file = shift or return undef;
    my $type = GetFileType($file) or return undef;
    return scalar(grep /^$type$/, @writeTypes);
}

#------------------------------------------------------------------------------
# return true if we can create the specified file type
# Inputs: 0) file name or ext,
# Returns: true if creatable, 0 if not writable, undef if unrecognized
sub CanCreate($)
{
    local $_;
    my $file = shift or return undef;
    my $type = GetFileType($file) or return undef;
    return scalar(grep /^$type$/, @createTypes);
}

#==============================================================================
# Functions below this are not part of the public API

# initialize member variables
# Inputs: 0) ExifTool object reference
sub Init($)
{
    my $self = shift;
    delete $self->{FOUND_TAGS};     # list of found tags
    delete $self->{EXIF_DATA};      # the EXIF data block
    delete $self->{EXIF_POS};       # EXIF position in file
    delete $self->{EXIF_BYTE_ORDER};# the EXIF byte ordering
    delete $self->{HTML_DUMP};      # html dump information
    $self->{FILE_ORDER} = { };      # hash of tag order in file
    $self->{VALUE}      = { };      # hash of raw tag values
    $self->{TAG_INFO}   = { };      # hash of tag information
    $self->{GROUP1}     = { };      # hash of family 1 group names
    $self->{PRIORITY}   = { };      # priority of current tags
    $self->{PROCESSED}  = { };      # hash of processed directory start positions
    $self->{DIR_COUNT}  = { };      # count various types of directories
    $self->{NUM_FOUND}  = 0;        # total number of tags found (incl. duplicates)
    $self->{CHANGED}    = 0;        # number of tags changed (writer only)
    $self->{INDENT}     = '  ';     # initial indent for verbose messages
    $self->{PRIORITY_DIR} = '';     # the priority directory name
    $self->{TIFF_TYPE}  = '';       # type of TIFF data (APP1, TIFF, NEF, etc...)
    $self->{CameraMake} = '';       # camera make
    $self->{CameraModel}= '';       # camera model
    $self->{CameraType} = '';       # Olympus camera type
    if ($self->Options('HtmlDump')) {
        require Image::ExifTool::HtmlDump;
        $self->{HTML_DUMP} = new Image::ExifTool::HtmlDump;
    }
    # make sure our TextOut is a file reference
    $self->{OPTIONS}->{TextOut} = \*STDOUT unless ref $self->{OPTIONS}->{TextOut};
}

#------------------------------------------------------------------------------
# parse function arguments and set member variables accordingly
# Inputs: Same as ImageInfo()
# - sets REQUESTED_TAGS, REQ_TAG_LOOKUP, IO_TAG_LIST, FILENAME, RAF, OPTIONS
sub ParseArguments($;@)
{
    my $self = shift;
    my $options = $self->{OPTIONS};
    my @exclude;
    my @oldGroupOpts = grep /^Group/, keys %{$self->{OPTIONS}};
    my $wasExcludeOpt;

    $self->{REQUESTED_TAGS} = [ ];
    $self->{REQ_TAG_LOOKUP} = { };
    $self->{IO_TAG_LIST} = undef;

    # handle our input arguments
    while (@_) {
        my $arg = shift;
        if (ref $arg) {
            if (ref $arg eq 'ARRAY') {
                $self->{IO_TAG_LIST} = $arg;
                foreach (@$arg) {
                    if (/^-(.*)/) {
                        push @exclude, $1;
                    } else {
                        push @{$self->{REQUESTED_TAGS}}, $_;
                    }
                }
            } elsif (ref $arg eq 'HASH') {
                my $opt;
                foreach $opt (keys %$arg) {
                    # a single new group option overrides all old group options
                    if (@oldGroupOpts and $opt =~ /^Group/) {
                        foreach (@oldGroupOpts) {
                            delete $options->{$_};
                        }
                        undef @oldGroupOpts;
                    }
                    $options->{$opt} = $$arg{$opt};
                    $opt eq 'Exclude' and $wasExcludeOpt = 1;
                }
            } elsif (ref $arg eq 'SCALAR' or UNIVERSAL::isa($arg,'GLOB')) {
                next if defined $self->{RAF};
                $self->{RAF} = new File::RandomAccess($arg);
                # set filename to empty string to indicate that
                # we have a file but we didn't open it
                $self->{FILENAME} = '';
            } else {
                warn "Don't understand ImageInfo argument $arg\n";
            }
        } elsif (defined $self->{FILENAME}) {
            if ($arg =~ /^-(.*)/) {
                push @exclude, $1;
            } else {
                push @{$self->{REQUESTED_TAGS}}, $arg;
            }
        } else {
            $self->{FILENAME} = $arg;
        }
    }
    # expand shortcuts in tag arguments if provided
    if (@{$self->{REQUESTED_TAGS}}) {
        ExpandShortcuts($self->{REQUESTED_TAGS});
        # initialize lookup for requested tags
        foreach (@{$self->{REQUESTED_TAGS}}) {
            $self->{REQ_TAG_LOOKUP}->{lc(/.+?:(.+)/ ? $1 : $_)} = 1;
        }
    }

    if (@exclude or $wasExcludeOpt) {
        # must add existing excluded tags
        if ($options->{Exclude}) {
            if (ref $options->{Exclude} eq 'ARRAY') {
                push @exclude, @{$options->{Exclude}};
            } else {
                push @exclude, $options->{Exclude};
            }
        }
        $options->{Exclude} = \@exclude;
        # expand shortcuts in new exclude list
        ExpandShortcuts($options->{Exclude});
    }
}

#------------------------------------------------------------------------------
# Set list of found tags
# Inputs: 0) ExifTool object reference
# Returns: Reference to found tags list (in order of requested tags)
sub SetFoundTags($)
{
    my $self = shift;
    my $options = $self->{OPTIONS};
    my $reqTags = $self->{REQUESTED_TAGS} || [ ];
    my $duplicates = $options->{Duplicates};
    my $exclude = $options->{Exclude};
    my $fileOrder = $self->{FILE_ORDER};
    my @groupOptions = sort grep /^Group/, keys %$options;
    my $doDups = $duplicates || $exclude || @groupOptions;
    my ($tag, $rtnTags);

    # only return requested tags if specified
    if (@$reqTags) {
        $rtnTags or $rtnTags = [ ];
        # scan through the requested tags and generate a list of tags we found
        my $tagHash = $self->{VALUE};
        my $reqTag;
        foreach $reqTag (@$reqTags) {
            my (@matches, $group, $family, $allGrp, $allTag);
            if ($reqTag =~ /^(\d+)?(.+?):(.+)/) {
                ($family, $group, $tag) = ($1, $2, $3);
                $allGrp = 1 if $group =~ /^(\*|all)$/i;
                $family = -1 unless defined $family
            } else {
                $tag = $reqTag;
                $family = -1;
            }
            if (defined $tagHash->{$reqTag} and not $doDups) {
                $matches[0] = $tag;
            } elsif ($tag =~ /^(\*|all)$/i) {
                # tag name of '*' or 'all' matches all tags
                if ($doDups or $allGrp) {
                    @matches = keys %$tagHash;
                } else {
                    @matches = grep(!/ /, keys %$tagHash);
                }
                next unless @matches;   # don't want entry in list for '*' tag
                $allTag = 1;
            } elsif ($doDups or defined $group) {
                # must also look for tags like "Tag (1)"
                @matches = grep(/^$tag(\s|$)/i, keys %$tagHash);
            } else {
                # find first matching value
                # (use in list context to return value instead of count)
                ($matches[0]) = grep /^$tag$/i, keys %$tagHash;
                defined $matches[0] or undef @matches;
            }
            if (defined $group and not $allGrp) {
                # keep only specified group
                my @grpMatches;
                foreach (@matches) {
                    my @groups = $self->GetGroup($_, $family);
                    next unless grep /^$group$/i, @groups;
                    push @grpMatches, $_;
                }
                @matches = @grpMatches;
                next unless @matches or not $allTag;
            }
            if (@matches > 1) {
                # maintain original file order for multiple tags
                @matches = sort { $$fileOrder{$a} <=> $$fileOrder{$b} } @matches;
                # return only the highest priority tag unless duplicates wanted
                unless ($doDups or $allTag or $allGrp) {
                    $tag = shift @matches;
                    my $oldPriority = $self->{PRIORITY}->{$tag} || 1;
                    foreach (@matches) {
                        my $priority = $self->{PRIORITY}->{$_};
                        $priority = 1 unless defined $priority;
                        next unless $priority >= $oldPriority;
                        $tag = $_;
                        $oldPriority = $priority || 1;
                    }
                    @matches = ( $tag );
                }
            } elsif (not @matches) {
                # put entry in return list even without value (value is undef)
                $matches[0] = "$tag (0)";
                # bogus file order entry to avoid warning if sorting in file order
                $self->{FILE_ORDER}->{$matches[0]} = 999;
            }
            push @$rtnTags, @matches;
        }
    } else {
        # no requested tags, so we want all tags
        my @allTags;
        if ($doDups) {
            @allTags = keys %{$self->{VALUE}};
        } else {
            foreach (keys %{$self->{VALUE}}) {
                # only include tag if it doesn't end in a copy number
                push @allTags, $_ unless / /;
            }
        }
        $rtnTags = \@allTags;
    }

    # filter excluded tags and group options
    while (($exclude or @groupOptions) and @$rtnTags) {
        if ($exclude) {
            my @filteredTags;
EX_TAG:     foreach $tag (@$rtnTags) {
                my $tagName = GetTagName($tag);
                my @matches = grep /(^|:)($tagName|\*|all)$/i, @$exclude;
                foreach (@matches) {
                    next EX_TAG unless /^(\d+)?(.+?):/;
                    my ($family, $group) = ($1, $2);
                    next EX_TAG if $group =~ /^(\*|all)$/i;
                    $family = -1 unless defined $family;
                    my @groups = $self->GetGroup($tag, $family);
                    next EX_TAG if grep /^$group$/i, @groups;
                }
                push @filteredTags, $tag;
            }
            $rtnTags = \@filteredTags;      # use new filtered tag list
            last if $duplicates and not @groupOptions;
        }
        # filter groups if requested, or to remove duplicates
        my (%keepTags, %wantGroup, $family, $groupOpt);
        my $allGroups = 1;
        # build hash of requested/excluded group names for each group family
        my $wantOrder = 0;
        foreach $groupOpt (@groupOptions) {
            $groupOpt =~ /^Group(\d*)/ or next;
            $family = $1 || 0;
            $wantGroup{$family} or $wantGroup{$family} = { };
            my $groupList;
            if (ref $options->{$groupOpt} eq 'ARRAY') {
                $groupList = $options->{$groupOpt};
            } else {
                $groupList = [ $options->{$groupOpt} ];
            }
            foreach (@$groupList) {
                # groups have priority in order they were specified
                ++$wantOrder;
                my ($groupName, $want);
                if (/^-(.*)/) {
                    # excluded group begins with '-'
                    $groupName = $1;
                    $want = 0;          # we don't want tags in this group
                } else {
                    $groupName = $_;
                    $want = $wantOrder; # we want tags in this group
                    $allGroups = 0;     # don't want all groups if we requested one
                }
                $wantGroup{$family}->{$groupName} = $want;
            }
        }
        # loop through all tags and decide which ones we want
        my (@tags, %bestTag);
GR_TAG: foreach $tag (@$rtnTags) {
            my $wantTag = $allGroups;   # want tag by default if want all groups
            foreach $family (keys %wantGroup) {
                my $group = $self->GetGroup($tag, $family);
                my $wanted = $wantGroup{$family}->{$group};
                next unless defined $wanted;
                next GR_TAG unless $wanted;     # skip tag if group excluded
                # take lowest non-zero want flag
                next if $wantTag and $wantTag < $wanted;
                $wantTag = $wanted;
            }
            next unless $wantTag;
            if ($duplicates) {
                push @tags, $tag;
            } else {
                my $tagName = GetTagName($tag);
                my $bestTag = $bestTag{$tagName};
                if (defined $bestTag) {
                    next if $wantTag > $keepTags{$bestTag};
                    if ($wantTag == $keepTags{$bestTag}) {
                        # want two tags with the same name -- keep the latest one
                        if ($tag =~ / \((\d+)\)$/) {
                            my $tagNum = $1;
                            next if $bestTag !~ / \((\d+)\)$/ or $1 > $tagNum;
                        }
                    }
                    # this tag is better, so delete old best tag
                    delete $keepTags{$bestTag};
                }
                $keepTags{$tag} = $wantTag;    # keep this tag (for now...)
                $bestTag{$tagName} = $tag;      # this is our current best tag
            }
        }
        unless ($duplicates) {
            # construct new tag list with no duplicates, preserving order
            foreach $tag (@$rtnTags) {
                push @tags, $tag if $keepTags{$tag};
            }
        }
        $rtnTags = \@tags;
        last;
    }

    # save found tags and return reference
    return $self->{FOUND_TAGS} = $rtnTags;
}

#------------------------------------------------------------------------------
# Utility to load our write routines if required (called via AUTOLOAD)
# Inputs: 0) autoload function, 1-N) function arguments
# Returns: result of function or dies if function not available
# To Do: Generalize this routine so it works on systems that don't use '/'
#        as a path name separator.
sub DoAutoLoad(@)
{
    my $autoload = shift;
    my @callInfo = split(/::/, $autoload);
    my $file = 'Image/ExifTool/Write';

    return if $callInfo[$#callInfo] eq 'DESTROY';
    if (@callInfo == 4) {
        # load Image/ExifTool/WriteMODULE.pl
        $file .= "$callInfo[2].pl";
    } else {
        # load Image/ExifTool/Writer.pl
        $file .= 'r.pl';
    }
    # attempt to load the package
    eval "require '$file'" or die "Error while attempting to call $autoload\n$@\n";
    unless (defined &$autoload) {
        my @caller = caller(0);
        # reproduce Perl's standard 'undefined subroutine' message:
        die "Undefined subroutine $autoload called at $caller[1] line $caller[2]\n";
    }
    no strict 'refs';
    return &$autoload(@_);     # call the function
}

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Add warning tag
# Inputs: 0) ExifTool object reference, 1) warning message, 2) true if minor
# Returns: true if warning tag was added
sub Warn($$;$)
{
    my ($self, $str, $ignorable) = @_;
    if ($ignorable) {
        return 0 if $self->{OPTIONS}->{IgnoreMinorErrors};
        $str = "[minor] $str";
    }
    $self->FoundTag('Warning', $str);
    return 1;
}

#------------------------------------------------------------------------------
# Add error tag
# Inputs: 0) ExifTool object reference, 1) error message, 2) true if minor
# Returns: true if error tag was added, otherwise warning was added
sub Error($$;$)
{
    my ($self, $str, $ignorable) = @_;
    if ($ignorable) {
        if ($self->{OPTIONS}->{IgnoreMinorErrors}) {
            $self->Warn($str);
            return 0;
        }
        $str = "[minor] $str";
    }
    $self->FoundTag('Error', $str);
    return 1;
}

#------------------------------------------------------------------------------
# Expand shortcuts
# Inputs: 0) reference to list of tags
# Notes: Handles leading '-' indicating excluded tag
sub ExpandShortcuts($)
{
    my $tagList = shift || return;

    require Image::ExifTool::Shortcuts;

    # expand shortcuts
    my @expandedTags;
    my ($entry, $tag);
    foreach $entry (@$tagList) {
        ($tag = $entry) =~ s/^-//;  # remove leading '-'
        my ($match) = grep /^\Q$tag\E$/i, keys %Image::ExifTool::Shortcuts::Main;
        if ($match) {
            if ($tag eq $entry) {
                push @expandedTags, @{$Image::ExifTool::Shortcuts::Main{$match}};
            } else {
                # entry starts with '-', so exclude all tags in this shortcut
                foreach (@{$Image::ExifTool::Shortcuts::Main{$match}}) {
                    /^-/ and next;  # ignore excluded exclude tags
                    push @expandedTags, "-$_";
                }
            }
        } else {
            push @expandedTags, $entry;
        }
    }
    @$tagList = @expandedTags;
}

#------------------------------------------------------------------------------
# Add hash of composite tags to our composites
# Inputs: 0) name of composite tags hash
sub AddCompositeTags($)
{
    local $_;
    my $tableName = shift;
    no strict 'refs';
    my $add = \%$tableName;
    use strict 'refs';
    my $defaultGroups = $$add{GROUPS};

    # make sure default groups are defined in families 0 and 1
    if ($defaultGroups) {
        $defaultGroups->{0} or $defaultGroups->{0} = 'Composite';
        $defaultGroups->{1} or $defaultGroups->{1} = 'Composite';
        $defaultGroups->{2} or $defaultGroups->{2} = 'Other';
    } else {
        $defaultGroups = $$add{GROUPS} = { 0 => 'Composite', 1 => 'Composite', 2 => 'Other' };
    }
    SetupTagTable($add);
    my ($tag, $t, $n);
    foreach $tag (keys %$add) {
        next if $specialTags{$tag}; # must skip special tags
        my $tagInfo = $$add{$tag};
        # allow composite tags with the same name
        while ($Image::ExifTool::Composite{$tag}) {
            $n or $n = 2, $t = $tag;
            $tag = "${t}_$n";
        }
        # add this composite tag to our main composite table
        $Image::ExifTool::Composite{$tag} = $tagInfo;
        # set all default groups in tag
        my $groups = $$tagInfo{Groups};
        $groups or $groups = $$tagInfo{Groups} = { };
        # fill in default groups
        foreach (keys %$defaultGroups) {
            $$groups{$_} or $$groups{$_} = $$defaultGroups{$_};
        }
        # set flag indicating group list was built
        $$tagInfo{GotGroups} = 1;
    }
}

#------------------------------------------------------------------------------
# Set up tag table (must be done once for each tag table used)
# Inputs: 0) Reference to tag table
# Notes: - generates 'Name' field from key if it doesn't exist
#        - stores 'Table' pointer
#        - expands 'Flags' for quick lookup
sub SetupTagTable($)
{
    my $tagTablePtr = shift;
    my $tagID;
    foreach $tagID (TagTableKeys($tagTablePtr)) {
        my @infoArray = GetTagInfoList($tagTablePtr,$tagID);
        # process conditional tagInfo arrays
        my $tagInfo;
        foreach $tagInfo (@infoArray) {
            $$tagInfo{Table} = $tagTablePtr;
            my $tag = $$tagInfo{Name};
            unless (defined $tag) {
                # generate name equal to tag ID if 'Name' doesn't exist
                $tag = $tagID;
                $$tagInfo{Name} = ucfirst($tag); # make first char uppercase
            }
            # add Flags to tagInfo hash for quick lookup
            if ($$tagInfo{Flags}) {
                my $flags = $$tagInfo{Flags};
                if (ref $flags eq 'ARRAY') {
                    foreach (@$flags) {
                        $$tagInfo{$_} = 1;
                    }
                } elsif (ref $flags eq 'HASH') {
                    my $key;
                    foreach $key (keys %$flags) {
                        $$tagInfo{$key} = $$flags{$key};
                    }
                } else {
                    $$tagInfo{$flags} = 1;
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Utilities to check for numerical types
# Inputs: 0) value;  Returns: true if value is a numerical type
# Notes: May change commas to decimals in floats for use in other locales
sub IsFloat($) {
    return 1 if $_[0] =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;
    # allow comma separators (for other locales)
    return 0 unless $_[0] =~ /^([+-]?)(?=\d|,\d)\d*(,\d*)?([Ee]([+-]?\d+))?$/;
    $_[0] =~ tr/,/./;   # but translate ',' to '.'
    return 1;
}
sub IsInt($)   { return scalar($_[0] =~ /^[+-]?\d+$/); }
sub IsHex($)   { return scalar($_[0] =~ /^(0x)?[0-9a-f]{1,8}$/i); }

# round floating point value to specified number of significant digits
# Inputs: 0) value, 1) number of sig digits;  Returns: rounded number
sub RoundFloat($$)
{
    my ($val, $sig) = @_;
    $val == 0 and return 0;
    my $sign = $val < 0 ? ($val=-$val, -1) : 1;
    my $log = log($val) / log(10);
    my $exp = int($log) - $sig + ($log > 0 ? 1 : 0);
    return $sign * int(10 ** ($log - $exp) + 0.5) * 10 ** $exp;
}

#------------------------------------------------------------------------------
# Utility routines to for reading binary data values from file

my $swapBytes;               # set if EXIF header is not native byte ordering
my $swapWords;               # swap 32-bit words in doubles (ARM quirk)
my $currentByteOrder = 'MM'; # current byte ordering ('II' or 'MM')
my %unpackMotorola = ( S => 'n', L => 'N', C => 'C', c => 'c' );
my %unpackIntel    = ( S => 'v', L => 'V', C => 'C', c => 'c' );
my %unpackStd = %unpackMotorola;

# Swap bytes in data if necessary
# Inputs: 0) data, 1) number of bytes
# Returns: swapped data
sub SwapBytes($$)
{
    return $_[0] unless $swapBytes;
    my ($val, $bytes) = @_;
    my $newVal = '';
    $newVal .= substr($val, $bytes, 1) while $bytes--;
    return $newVal;
}
# Swap words.  Inputs: 8 bytes of data, Returns: swapped data
sub SwapWords($)
{
    return $_[0] unless $swapWords and length($_[0]) == 8;
    return substr($_[0],4,4) . substr($_[0],0,4)
}

# Unpack value, letting unpack() handle byte swapping
# Inputs: 0) unpack template, 1) data reference, 2) offset
# Returns: unpacked number
# - uses value of %unpackStd to determine the unpack template
# - can only be called for 'S' or 'L' templates since these are the only
#   templates for which you can specify the byte ordering.
sub DoUnpackStd(@)
{
    $_[2] and return unpack("x$_[2] $unpackStd{$_[0]}", ${$_[1]});
    return unpack($unpackStd{$_[0]}, ${$_[1]});
}
# Pack value
# Inputs: 0) template, 1) value, 2) data ref (or undef), 3) offset (if data ref)
# Returns: packed value
sub DoPackStd(@)
{
    my $val = pack($unpackStd{$_[0]}, $_[1]);
    $_[2] and substr(${$_[2]}, $_[3], length($val)) = $val;
    return $val;
}

# Unpack value, handling the byte swapping manually
# Inputs: 0) # bytes, 1) unpack template, 2) data reference, 3) offset
# Returns: unpacked number
# - uses value of $swapBytes to determine byte ordering
sub DoUnpack(@)
{
    my ($bytes, $template, $dataPt, $pos) = @_;
    my $val;
    if ($swapBytes) {
        $val = '';
        $val .= substr($$dataPt,$pos+$bytes,1) while $bytes--;
    } else {
        $val = substr($$dataPt,$pos,$bytes);
    }
    defined($val) or return undef;
    return unpack($template,$val);
}

# Unpack double value
# Inputs: 0) unpack template, 1) data reference, 2) offset
# Returns: unpacked number
sub DoUnpackDbl(@)
{
    my ($template, $dataPt, $pos) = @_;
    my $val = substr($$dataPt,$pos,8);
    defined($val) or return undef;
    # swap bytes and 32-bit words (ARM quirk) if necessary, then unpack value
    return unpack($template, SwapWords(SwapBytes($val, 8)));
}

# Inputs: 0) data reference, 1) offset into data
sub Get8s($$)     { return DoUnpackStd('c', @_); }
sub Get8u($$)     { return DoUnpackStd('C', @_); }
sub Get16s($$)    { return DoUnpack(2, 's', @_); }
sub Get16u($$)    { return DoUnpackStd('S', @_); }
sub Get32s($$)    { return DoUnpack(4, 'l', @_); }
sub Get32u($$)    { return DoUnpackStd('L', @_); }
sub GetFloat($$)  { return DoUnpack(4, 'f', @_); }
sub GetDouble($$) { return DoUnpackDbl('d', @_); }

sub GetRational32s($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get16s($dataPt, $pos + 2) or return 'inf';
    # round off to a reasonable number of significant figures
    return RoundFloat(Get16s($dataPt,$pos) / $denom, 7);
}
sub GetRational32u($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get16u($dataPt, $pos + 2) or return 'inf';
    return RoundFloat(Get16u($dataPt,$pos) / $denom, 7);
}
sub GetRational64s($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get32s($dataPt, $pos + 4) or return 'inf';
    return RoundFloat(Get32s($dataPt,$pos) / $denom, 7);
}
sub GetRational64u($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get32u($dataPt, $pos + 4) or return 'inf';
    return RoundFloat(Get32u($dataPt,$pos) / $denom, 7);
}
sub GetFixed16s($$)
{
    my ($dataPt, $pos) = @_;
    return int((Get16s($dataPt, $pos) / 0x100) * 1000 + 0.5) / 1000;
}
sub GetFixed16u($$)
{
    my ($dataPt, $pos) = @_;
    return int((Get16u($dataPt, $pos) / 0x100) * 1000 + 0.5) / 1000;
}
sub GetFixed32s($$)
{
    my ($dataPt, $pos) = @_;
    my $val = Get32s($dataPt, $pos) / 0x10000;
    # remove insignificant digits
    return int($val * 1e5 + ($val>0 ? 0.5 : -0.5)) / 1e5;
}
sub GetFixed32u($$)
{
    my ($dataPt, $pos) = @_;
    # remove insignificant digits
    return int((Get32u($dataPt, $pos) / 0x10000) * 1e5 + 0.5) / 1e5;
}
# Inputs: 0) value, 1) data ref, 2) offset
sub Set8s($;$$)   { return DoPackStd('c', @_); }
sub Set8u($;$$)   { return DoPackStd('C', @_); }
sub Set16u($;$$)  { return DoPackStd('S', @_); }
sub Set32u($;$$)  { return DoPackStd('L', @_); }

#------------------------------------------------------------------------------
# Get current byte order ('II' or 'MM')
sub GetByteOrder() { return $currentByteOrder; }

#------------------------------------------------------------------------------
# set byte ordering
# Inputs: 0) 'II'=intel, 'MM'=motorola
# Returns: 1 on success
sub SetByteOrder($)
{
    my $order = shift;

    if ($order eq 'MM') {       # big endian (Motorola)
        %unpackStd = %unpackMotorola;
    } elsif ($order eq 'II') {  # little endian (Intel)
        %unpackStd = %unpackIntel;
    } else {
        return 0;
    }
    my $val = unpack('S','A ');
    my $nativeOrder;
    if ($val == 0x4120) {       # big endian
        $nativeOrder = 'MM';
    } elsif ($val == 0x2041) {  # little endian
        $nativeOrder = 'II';
    } else {
        warn sprintf("Unknown native byte order! (pattern %x)\n",$val);
        return 0;
    }
    $currentByteOrder = $order;  # save current byte order

    # swap bytes if our native CPU byte ordering is not the same as the EXIF
    $swapBytes = ($order ne $nativeOrder);

    # little-endian ARM has big-endian words for doubles (thanks Riku Voipio)
    # (Note: Riku's patch checked for '0ff3', but I think it should be 'f03f' since
    # 1 is '000000000000f03f' on an x86 -- so check for both, but which is correct?)
    my $pack1d = pack('d', 1);
    $swapWords = ($pack1d eq "\0\0\x0f\xf3\0\0\0\0" or
                  $pack1d eq "\0\0\xf0\x3f\0\0\0\0");
    return 1;
}

#------------------------------------------------------------------------------
# change byte order
sub ToggleByteOrder()
{
    SetByteOrder(GetByteOrder() eq 'II' ? 'MM' : 'II');
}

#------------------------------------------------------------------------------
# hash lookups for reading values from data
my %formatSize = (
    int8s => 1,
    int8u => 1,
    int16s => 2,
    int16u => 2,
    int32s => 4,
    int32u => 4,
    int64s => 8,
    int64u => 8,
    rational32s => 4,
    rational32u => 4,
    rational64s => 8,
    rational64u => 8,
    fixed16s => 2,
    fixed16u => 2,
    fixed32s => 4,
    fixed32u => 4,
    float => 4,
    double => 8,
    extended => 10,
    string => 1,
    binary => 1,
   'undef' => 1,
    ifd => 4,
);
my %readValueProc = (
    int8s => \&Get8s,
    int8u => \&Get8u,
    int16s => \&Get16s,
    int16u => \&Get16u,
    int32s => \&Get32s,
    int32u => \&Get32u,
    int64s => \&Get64s,
    int64u => \&Get64u,
    rational32s => \&GetRational32s,
    rational32u => \&GetRational32u,
    rational64s => \&GetRational64s,
    rational64u => \&GetRational64u,
    fixed16s => \&GetFixed16s,
    fixed16u => \&GetFixed16u,
    fixed32s => \&GetFixed32s,
    fixed32u => \&GetFixed32u,
    float => \&GetFloat,
    double => \&GetDouble,
    extended => \&GetExtended,
    ifd => \&Get32u,
);
sub FormatSize($) { return $formatSize{$_[0]}; }

#------------------------------------------------------------------------------
# read value from binary data (with current byte ordering)
# Inputs: 0) data reference, 1) value offset, 2) format string,
#         3) number of values (or undef to use all data)
#         4) valid data length relative to offset
# Returns: converted value, or undefined if data isn't there
#          or list of values in list context
sub ReadValue($$$$$)
{
    my ($dataPt, $offset, $format, $count, $size) = @_;

    my $len = $formatSize{$format};
    unless ($len) {
        warn "Unknown format $format";
        $len = 1;
    }
    unless ($count) {
        return '' if defined $count;
        $count = int($size / $len);
        return '' unless $count;
    }
    # make sure entry is inside data
    if ($len * $count > $size) {
        $count = int($size / $len);     # shorten count if necessary
        $count < 1 and return undef;    # return undefined if no data
    }
    my @vals;
    my $proc = $readValueProc{$format};
    if ($proc) {
        for (;;) {
            push @vals, &$proc($dataPt, $offset);
            last if --$count <= 0;
            $offset += $len;
        }
    } else {
        # handle undef/binary/string
        $vals[0] = substr($$dataPt, $offset, $count);
        # truncate string at null terminator if necessary
        $vals[0] =~ s/\0.*//s if $format eq 'string';
    }
    if (wantarray) {
        return @vals;
    } elsif (@vals > 1) {
        return join(' ', @vals);
    } else {
        return $vals[0];
    }
}

#------------------------------------------------------------------------------
# Decode bit mask
# Inputs: 0) value to decode, 1) Reference to hash for decoding
sub DecodeBits($$)
{
    my ($bits, $lookup) = @_;
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
# Validate an extracted image and repair if necessary
# Inputs: 0) ExifTool object reference, 1) image reference, 2) tag name
# Returns: image reference or undef if it wasn't valid
sub ValidateImage($$$)
{
    my ($self, $imagePt, $tag) = @_;
    return undef if $$imagePt eq 'none';
    unless ($$imagePt =~ /^(Binary data|\xff\xd8\xff)/ or
            # the first byte of the preview of some Minolta cameras is wrong,
            # so check for this and set it back to 0xff if necessary
            $$imagePt =~ s/^.(\xd8\xff\xdb)/\xff$1/ or
            $self->Options('IgnoreMinorErrors'))
    {
        # issue warning only if the tag was specifically requested
        if ($self->{REQ_TAG_LOOKUP}->{lc($tag)}) {
            $self->Warn("$tag is not a valid JPEG image",1);
            return undef;
        }
    }
    return $imagePt;
}

#------------------------------------------------------------------------------
# make description from a tag name
# Inputs: 0) tag name 1) optional tagID to add at end of description
# Returns: description
sub MakeDescription($;$)
{
    my ($tag, $tagID) = @_;
    # start with the tag name and force first letter to be upper case
    my $desc = ucfirst($tag);
    $desc =~ tr/_/ /;       # translate underlines to spaces
    # put a space between lower/UPPER case and lower/number combinations
    $desc =~ s/([a-z])([A-Z\d])/$1 $2/g;
    # put a space between acronyms and words
    $desc =~ s/([A-Z])([A-Z][a-z])/$1 $2/g;
    # put spaces after numbers (if more than one character following number)
    $desc =~ s/(\d)([A-Z]\S)/$1 $2/g;
    $desc .= ' ' . $tagID if defined $tagID;
    return $desc;
}

#------------------------------------------------------------------------------
# return printable value
# Inputs: 0) ExifTool object reference
#         1) value to print, 2) true for unlimited line length
sub Printable($;$)
{
    my ($self, $outStr, $unlimited) = @_;
    return '(undef)' unless defined $outStr;
    $outStr =~ tr/\x01-\x1f\x7f-\xff/./;
    $outStr =~ s/\x00//g;
    # limit length if verbose < 4
    if (length($outStr) > 60 and not $unlimited and $self->{OPTIONS}->{Verbose} < 4) {
        $outStr = substr($outStr,0,54) . '[snip]';
    }
    return $outStr;
}

#------------------------------------------------------------------------------
# Convert date/time from Exif format
# Inputs: 0) ExifTool object reference, 1) Date/time in EXIF format
# Returns: Formatted date/time string
sub ConvertDateTime($$)
{
    my ($self, $date) = @_;
    my $dateFormat = $self->{OPTIONS}->{DateFormat};
    # only convert date if a format was specified and the date is recognizable
    if ($dateFormat) {
        if ($date =~ /^(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)/ and eval 'require POSIX') {
            $date = POSIX::strftime($dateFormat, $6, $5, $4, $3, $2-1, $1-1900);
        } elsif ($self->{OPTIONS}->{StrictDate}) {
            undef $date;
        }
    }
    return $date;
}

#------------------------------------------------------------------------------
# Convert Unix time to EXIF date/time string
# Inputs: 0) Unix time value, 1) non-zero to use local instead of GMT time
# Returns: EXIF date/time string
sub ConvertUnixTime($;$)
{
    my $time = shift;
    return '0000:00:00 00:00:00' if $time == 0;
    my @tm = shift() ? localtime($time) : gmtime($time);
    return sprintf("%4d:%.2d:%.2d %.2d:%.2d:%.2d", $tm[5]+1900, $tm[4]+1,
                   $tm[3], $tm[2], $tm[1], $tm[0]);
}

#------------------------------------------------------------------------------
# Get Unix time from EXIF-formatted date/time string
# Inputs: 0) EXIF date/time string, 1) non-zero to use local instead of GMT time
# Returns: Unix time or undefined on error
sub GetUnixTime($;$)
{
    my $timeStr = shift;
    return 0 if $timeStr eq '0000:00:00 00:00:00';
    my @tm = ($timeStr =~ /^(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)/);
    return undef unless @tm == 6;
    return undef unless eval 'require Time::Local';
    $tm[0] -= 1900;     # convert year
    $tm[1] -= 1;        # convert month
    @tm = reverse @tm;  # change to order required by timelocal()
    return shift() ? Time::Local::timelocal(@tm) : Time::Local::timegm(@tm);
}

#------------------------------------------------------------------------------
# Save information for HTML dump
# Inputs: 0) ExifTool hash ref, 1) start offset, 2) data size
#         3) comment string, 4) tool tip, 5) flags
sub HtmlDump($$$$;$$)
{
    my $self = shift;
    $self->{HTML_DUMP} and $self->{HTML_DUMP}->Add(@_);
}

#------------------------------------------------------------------------------
# JPEG constants
my %jpegMarker = (
    0x01 => 'TEM',
    0xc0 => 'SOF0', # to SOF15, with a few exceptions below
    0xc4 => 'DHT',
    0xc8 => 'JPGA',
    0xcc => 'DAC',
    0xd0 => 'RST0',
    0xd8 => 'SOI',
    0xd9 => 'EOI',
    0xda => 'SOS',
    0xdb => 'DQT',
    0xdc => 'DNL',
    0xdd => 'DRI',
    0xde => 'DHP',
    0xdf => 'EXP',
    0xe0 => 'APP0', # to APP15
    0xf0 => 'JPG0',
    0xfe => 'COM',
);

#------------------------------------------------------------------------------
# Get JPEG marker name
# Inputs: 0) Jpeg number
# Returns: marker name
sub JpegMarkerName($)
{
    my $marker = shift;
    my $markerName = $jpegMarker{$marker};
    unless ($markerName) {
        $markerName = $jpegMarker{$marker & 0xf0};
        if ($markerName and $markerName =~ /^([A-Z]+)\d+$/) {
            $markerName = $1 . ($marker & 0x0f);
        } else {
            $markerName = sprintf("marker 0x%.2x", $marker);
        }
    }
    return $markerName;
}

#------------------------------------------------------------------------------
# Determine if the file contains AFCP information
# Inputs: 0) RAF reference
# Returns: true if file contains AFCP (and leaves file position unchanged)
sub IsAFCP($)
{
    my $raf = shift;
    my $pos = $raf->Tell();
    my ($buff, $rtnVal);
    $rtnVal = 1 if $raf->Seek(-12, 2) and
                   $raf->Read($buff, 12) == 12 and
                   $buff =~ /^AXS(!|\*)/;
    $raf->Seek($pos, 0);
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Extract EXIF information from a jpg image
# Inputs: 0) ExifTool object reference, 1) directory information ref
# Returns: 1 on success, 0 if this wasn't a valid JPEG file
sub ProcessJPEG($$)
{
    my ($self, $dirInfo) = @_;
    my ($ch,$s,$length);
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $out = $self->{OPTIONS}->{TextOut};
    my $raf = $$dirInfo{RAF};
    my $icc_profile;
    my $rtnVal = 0;
    my ($wantPreview, $wantAFCP);
    my %dumpParms = ( Out => $out );

    # check to be sure this is a valid JPG file
    return 0 unless $raf->Read($s, 2) == 2 and $s eq "\xff\xd8";
    $dumpParms{MaxLen} = 128 if $verbose < 4;
    $self->SetFileType();   # set FileType tag

    # set input record separator to 0xff (the JPEG marker) to make reading quicker
    my $oldsep = $/;
    $/ = "\xff";

    my ($nextMarker, $nextSegDataPt, $nextSegPos, $combinedSegData);

    # read file until we reach an end of image (EOI) or start of scan (SOS)
    Marker: for (;;) {
        # set marker and data pointer for current segment
        my $marker = $nextMarker;
        my $segDataPt = $nextSegDataPt;
        my $segPos = $nextSegPos;
        undef $nextMarker;
        undef $nextSegDataPt;
#
# read ahead to the next segment unless we have reached EOI or SOS
#
        unless ($marker and ($marker==0xd9 or ($marker==0xda and not $wantPreview))) {
            # read up to next marker (JPEG markers begin with 0xff)
            my $buff;
            $raf->ReadLine($buff) or last;
            # JPEG markers can be padded with unlimited 0xff's
            for (;;) {
                $raf->Read($ch, 1) or last Marker;
                $nextMarker = ord($ch);
                last unless $nextMarker == 0xff;
            }
            # read the next segment
            # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
            if (($nextMarker & 0xf0) == 0xc0 and
                ($nextMarker == 0xc0 or $nextMarker & 0x03))
            {
                last unless $raf->Read($buff, 7) == 7;
                $nextSegDataPt = \$buff;
            # read data for all markers except 0xd9 (EOI) and stand-alone
            # markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            } elsif ($nextMarker!=0xd9 and $nextMarker!=0x00 and $nextMarker!=0x01 and
                    ($nextMarker<0xd0 or $nextMarker>0xd7))
            {
                # read record length word
                last unless $raf->Read($s, 2) == 2;
                my $len = unpack('n',$s);   # get data length
                last unless defined($len) and $len >= 2;
                $nextSegPos = $raf->Tell();
                $len -= 2;  # subtract size of length word
                last unless $raf->Read($buff, $len) == $len;
                $nextSegDataPt = \$buff;    # set pointer to our next data
            }
            # read second segment too if this was the first
            next unless defined $marker;
        }
        # set some useful variables for the current segment
        my $hdr = "\xff" . chr($marker);    # header for this segment
        my $markerName = JpegMarkerName($marker);
#
# parse the current segment
#
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            $verbose and print $out "JPEG $markerName:\n";
            # get the image size;
            my ($h, $w) = unpack('n'x2, substr($$segDataPt, 3));
            $self->FoundTag('ImageWidth', $w);
            $self->FoundTag('ImageHeight', $h);
            next;
        } elsif ($marker == 0xd9) {         # EOI
            $verbose and print $out "JPEG EOI\n";
            $rtnVal = 1;
            # we are here because we are looking for either AFCP or a PreviewImage
            if ($wantPreview and $self->{VALUE}->{PreviewImageStart}) {
                my $buff;
                my $pos = $raf->Tell();
                # most previews start right after the JPEG EOI, but the
                # Olympus E-20 preview is 508 bytes into the trailer...
                if ($raf->Read($buff, 1024) and $buff =~ /\xff\xd8\xff/g) {
                    # adjust PreviewImageStart to this location
                    my $start = $self->{VALUE}->{PreviewImageStart};
                    my $actual = $pos + pos($buff) - 3;
                    if ($start ne $actual and $verbose > 1) {
                        print $out "(Fixed PreviewImage location: $start -> $actual)\n";
                    }
                    $self->{VALUE}->{PreviewImageStart} = $actual;
                }
                $raf->Seek($pos, 0);
            }
            if ($wantAFCP) {
                # scan for AFCP header starting here
                Image::ExifTool::AFCP::ProcessAFCP($self, {RAF => $raf, ScanForAFCP => 1});
            }
            last;       # all done parsing file
        } elsif ($marker == 0xda) {         # SOS
            # all done with meta information unless we have a AFCP or PreviewImage trailer
            unless ($self->Options('FastScan')) {
                if (IsAFCP($raf)) {
                    require Image::ExifTool::AFCP;
                    $wantAFCP = 1 if Image::ExifTool::AFCP::ProcessAFCP($self, {RAF => $raf}) < 0;
                }
                if ($wantPreview) {
                    # seek ahead and validate preview image
                    my $buff;
                    my $curPos = $raf->Tell();
                    if ($raf->Seek($self->GetValue('PreviewImageStart'), 0) and
                        $raf->Read($buff, 4) == 4 and
                        $buff =~ /^.\xd8\xff[\xc4\xdb\xe0-\xef]/)
                    {
                        undef $wantPreview;
                    }
                    $raf->Seek($curPos, 0) or last;
                }
                if ($wantAFCP or $wantPreview) {
                    if ($verbose) {
                        my $for = $wantPreview ? (($wantAFCP ? 'AFCP and ' : '') . 'PreviewImage') : 'AFCP';
                        print $out "JPEG SOS (continue parsing for $for)\n";
                    }
                    next;
                }
            }
            $verbose and print $out "JPEG SOS (end of parsing)\n";
            # nothing interesting to parse after start of scan (SOS)
            $rtnVal = 1;
            last;   # all done parsing file
        } elsif ($marker==0x00 or $marker==0x01 or ($marker>=0xd0 and $marker<=0xd7)) {
            # handle stand-alone markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            $verbose and $marker and print $out "JPEG $markerName:\n";
            next;
        }
        # handle all other markers
        $length = length($$segDataPt);
        if ($verbose) {
            print $out "JPEG $markerName ($length bytes):\n";
            if ($verbose > 2) {
                my %extraParms = ( Addr => $segPos );
                $extraParms{MaxLen} = 128 if $verbose == 4;
                HexDump($segDataPt, undef, %dumpParms, %extraParms);
            }
        }
        if ($marker == 0xe0) {              # APP0 (JFIF)
            if ($$segDataPt =~ /^JFIF\0/) {
                $self->HtmlDump($segPos-4, $length+4, "JFIF segment",
                         'Size: ' . ($length + 4) . ' bytes', 0);
                my %dirInfo = (
                    DataPt => $segDataPt,
                    DataPos  => $segPos,
                    DirStart => 5,
                    DirLen => $length - 5,
                );
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Main');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^JFXX\0\x10/) {
                my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Extension');
                my $tagInfo = $self->GetTagInfo($tagTablePtr, 0x10);
                $self->FoundTag($tagInfo, substr($$segDataPt, 6));
            }
        } elsif ($marker == 0xe1) {         # APP1 (EXIF, XMP)
            if ($$segDataPt =~ /^Exif\0/) { # (some Kodak cameras don't put a second \0)
                # this is EXIF data --
                # get the data block (into a common variable)
                my $hdrLen = length($exifAPP1hdr);
                my %dirInfo = (
                    Parent => $markerName,
                    DataPt => $segDataPt,
                    DataPos => $segPos,
                    DirStart => $hdrLen,
                    Base => $segPos + $hdrLen,
                );
                if ($self->{HTML_DUMP}) {
                    $self->HtmlDump(0, 2, 'JPEG header','SOI Marker');
                    $self->HtmlDump($segPos-4, 4, 'APP1 header',
                             "APP1 Header\\nData size: $length bytes");
                    $self->HtmlDump($segPos, $hdrLen, "APP1 ID",
                             'APP1 Identifier\nData type: Exif');
                    # add marker at end of APP1
                    $self->HtmlDump($segPos + $length, 2, 'Next JPEG segment...');
                }
                # extract the EXIF information (it is in standard TIFF format)
                $self->ProcessTIFF(\%dirInfo);
                # avoid looking for preview unless necessary because it really slows
                # us down -- only look for it if we found pointer, and preview is
                # outside EXIF, and PreviewImage is specifically requested
                my $start = $self->GetValue('PreviewImageStart');
                my $length = $self->GetValue('PreviewImageLength');
                if ($start and $length and
                    $start + $length > $self->{EXIF_POS} + length($self->{EXIF_DATA}) and
                    $self->{REQ_TAG_LOOKUP}->{previewimage})
                {
                    $wantPreview = 1;
                }
            } else {
                # Hmmm.  Could be XMP, let's see
                my $processed;
                if ($$segDataPt =~ /^http/ or $$segDataPt =~ /<exif:/) {
                    my $start = ($$segDataPt =~ /^$xmpAPP1hdr/) ? length($xmpAPP1hdr) : 0;
                    my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                    my %dirInfo = (
                        Base     => 0,
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => $start,
                        DirLen   => $length - $start,
                        Parent   => $markerName,
                    );
                    $processed = $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                }
                if ($verbose and not $processed) {
                    $self->Warn("Ignored EXIF block length $length (bad header)");
                }
            }
        } elsif ($marker == 0xe2) {         # APP2 (ICC Profile, FPXR)
            if ($$segDataPt =~ /^ICC_PROFILE\0/) {
                # must concatenate blocks of profile
                my $block_num = ord(substr($$segDataPt, 12, 1));
                my $blocks_tot = ord(substr($$segDataPt, 13, 1));
                $icc_profile = '' if $block_num == 1;
                if (defined $icc_profile) {
                    $icc_profile .= substr($$segDataPt, 14);
                    if ($block_num == $blocks_tot) {
                        my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                        my %dirInfo = (
                            DataPt   => \$icc_profile,
                            DataPos  => $segPos + 14,
                            DataLen  => length($icc_profile),
                            DirStart => 0,
                            DirLen   => length($icc_profile),
                            Parent   => $markerName,
                        );
                        $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                        undef $icc_profile;
                    }
                }
            } elsif ($$segDataPt =~ /^FPXR\0/) {
                my $tagTablePtr = GetTagTable('Image::ExifTool::FlashPix::Main');
                my %dirInfo = (
                    DataPt   => $segDataPt,
                    DataPos  => $segPos,
                    DataLen  => $length,
                    DirStart => 0,
                    DirLen   => $length,
                    Parent   => $markerName,
                    # set flag if this is the last FPXR segment
                    LastFPXR => not ($nextMarker==$marker and $$nextSegDataPt=~/^FPXR\0/),
                );
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xe3) {         # APP3 (Kodak "Meta")
            if ($$segDataPt =~ /^(Meta|META|Exif)\0\0/) {
                my %dirInfo = (
                    Parent => $markerName,
                    DataPt => $segDataPt,
                    DataPos => $segPos,
                    DirStart => 6,
                    Base => $segPos + 6,
                );
                my $tagTablePtr = GetTagTable('Image::ExifTool::Kodak::Meta');
                $self->ProcessTIFF(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xec) {         # APP12 (ASCII meta information)
            my $tagTablePtr = GetTagTable('Image::ExifTool::APP12::Main');
            my %dirInfo = ( DataPt => $segDataPt );
            $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } elsif ($marker == 0xed) {         # APP13 (Photoshop)
            my $isOld;
            if ($$segDataPt =~ /^$psAPP13hdr/ or ($$segDataPt =~ /$psAPP13old/ and $isOld=1)) {
                # add this data to the combined data if it exists
                if (defined $combinedSegData) {
                    $combinedSegData .= substr($$segDataPt,length($psAPP13hdr));
                    $segDataPt = \$combinedSegData;
                    $length = length $combinedSegData;  # update length
                }
                # peek ahead to see if the next segment is photoshop data too
                if ($nextMarker == $marker and $$nextSegDataPt =~ /^$psAPP13hdr/) {
                    # initialize combined data if necessary
                    $combinedSegData = $$segDataPt unless defined $combinedSegData;
                    next;   # will handle the combined data the next time around
                }
                my $hdrlen = $isOld ? 27 : 14;
                # process Photoshop APP13 record
                my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                my %dirInfo = (
                    DataPt   => $segDataPt,
                    DataPos  => $segPos,
                    DataLen  => $length,
                    DirStart => $hdrlen,    # directory starts after identifier
                    DirLen   => $length - $hdrlen,
                    Parent   => $markerName,
                );
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                undef $combinedSegData;
            } elsif ($$segDataPt =~ /^\x1c\x02/) {
                # this is written in IPTC format by photoshop, but is
                # all messed up, so we ignore it
            } else {
                $self->Warn('Unknown APP13 data');
            }
        } elsif ($marker == 0xee) {         # APP14 (Adobe)
            if ($$segDataPt =~ /^Adobe/) {
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable('Image::ExifTool::APP14::Main');
                my %dirInfo = (
                    DataPt   => $segDataPt,
                    DataPos  => $segPos,
                    DirStart => 5,
                    DirLen   => $length - 5,
                );
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xfe) {         # COM (JPEG comment)
            $self->FoundTag('Comment', $$segDataPt);
        }
        undef $$segDataPt;
    }
    $/ = $oldsep;     # restore separator to original value
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Process TIFF data
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) optional tag table reference
# Returns: 1 if this looked like a valid EXIF block, 0 otherwise, or -1 on write error
sub ProcessTIFF($$;$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $fileType = $$dirInfo{Parent} || '';
    my $raf = $$dirInfo{RAF};
    my $base = $$dirInfo{Base} || 0;
    my $outfile = $$dirInfo{OutFile};
    my ($length, $err, $canonSig);

    # read the image file header and offset to 0th IFD if necessary
    if ($raf) {
        if ($outfile) {
            $raf->Seek(0, 0) or return 0;
            if ($base) {
                $raf->Read($$dataPt, $base) == $base or return 0;
                Write($outfile, $$dataPt) or $err = 1;
            }
        } else {
            $raf->Seek($base, 0) or return 0;
        }
        $raf->Read($self->{EXIF_DATA}, 8) == 8 or return 0;
    } elsif ($dataPt) {
        # save a copy of the EXIF data
        my $dirStart = $$dirInfo{DirStart} || 0;
        $self->{EXIF_DATA} = substr(${$$dirInfo{DataPt}}, $dirStart);
    } elsif ($outfile) {
        # create TIFF information from scratch
        $self->{EXIF_DATA} = "MM\0\x2a\0\0\0\x08";
    } else {
        $self->{EXIF_DATA} = '';
    }
    $self->{EXIF_POS} = $base;
    $dataPt = \$self->{EXIF_DATA};

    # set byte ordering
    SetByteOrder(substr($$dataPt,0,2)) or return 0;
    # save EXIF byte ordering
    $self->{EXIF_BYTE_ORDER} = GetByteOrder();

    # verify the byte ordering
    my $identifier = Get16u($dataPt, 2);
    # identifier is 0x2a for TIFF (but 0x4f52, 0x5352 or ?? for ORF)
  # no longer do this because ORF files use different values
  #  return 0 unless $identifier == 0x2a;

    # get offset to IFD0
    my $offset = Get32u($dataPt, 4);
    $offset >= 8 or return 0;

    if ($self->{HTML_DUMP}) {
        my $o = (GetByteOrder() eq 'II') ? 'Little' : 'Big';
        $self->HtmlDump($base, 4, "TIFF header", "TIFF Header\\nByte order: $o endian", 0);
        $self->HtmlDump($base+4, 4, "IFD0 pointer",
                 sprintf("IFD0 offset: 0x%.4x",$offset), 0);
    }
    if ($raf) {
        # Canon CR2 images usually have an offset of 16, but it may be
        # greater if edited by PhotoMechanic, so check the 4-byte signature
        if ($identifier == 0x2a and $offset >= 16) {
            $raf->Read($canonSig, 8) == 8 or return 0;
            $$dataPt .= $canonSig;
            if ($canonSig =~ /^CR\x02\0/) {
                $fileType = 'CR2';
            } else {
                undef $canonSig;
            }
        } elsif ($identifier == 0x55 and $fileType =~ /^(RAW|TIFF)$/) {
            $fileType = 'RAW';  # Panasonic RAW file
            $tagTablePtr = GetTagTable('Image::ExifTool::Panasonic::Raw');
        } elsif (Get8u($dataPt, 2) == 0xbc and $fileType eq 'TIFF') {
            $fileType = 'WDP';  # Windows Media Photo file
        }
        # we have a valid TIFF (or whatever) file
        if ($fileType and not $self->{VALUE}->{FileType}) {
            $self->SetFileType($fileType);
        }
    }
    # remember where we found the TIFF data (APP1, APP3, TIFF, NEF, etc...)
    $self->{TIFF_TYPE} = $fileType;

    # get reference to the main EXIF table
    $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');

    # build directory information hash
    my %dirInfo = (
        Base     => $base,
        DataPt   => $dataPt,
        DataLen  => length $$dataPt,
        DataPos  => 0,
        DirStart => $offset,
        DirLen   => length $$dataPt,
        RAF      => $raf,
        Multi    => 1,
        DirName  => 'IFD0',
        Parent   => $fileType,
        ImageData=> 1, # set flag to get information to copy image data later
    );
    if ($outfile) {
        if ($$dirInfo{NoTiffEnd}) {
            delete $self->{TIFF_END};
        } else {
            # initialize TIFF_END so it will be updated by WriteExif()
            $self->{TIFF_END} = 0;
        }
        if ($canonSig) {
            # write Canon CR2 specially because it has a header we want to preserve,
            # and possibly trailers added by the Canon utilities and/or PhotoMechanic
            $dirInfo{OutFile} = $outfile;
            require Image::ExifTool::CanonRaw;
            Image::ExifTool::CanonRaw::WriteCR2($self, \%dirInfo, $tagTablePtr) or $err = 1;
        } else {
            # write TIFF header (8 bytes to be immediately followed by IFD)
            $dirInfo{NewDataPos} = 8;
            my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
            if (not defined $newData) {
                $err = 1;
            } elsif (length($newData)) {
                my $offset = 8;
                my $header = substr($$dataPt, 0, 4) . Set32u($offset);
                Write($outfile, $header, $newData) or $err = 1;
                undef $newData; # free memory
                if ($raf and $self->{TIFF_END}) {
                    $raf->Seek(0, 2) or $err = 1;
                    my $extra = $raf->Tell() - $self->{TIFF_END};
                    # we may expect 4 unreferenced bytes due to next IFD pointer
                    # which we don't always read, but allow up to 6 because PS CS adds
                    # an extra 2 for some reason.  These bytes should be all zero
                    if ($extra > 0 and $extra <= 6) {
                        my $buf;
                        $raf->Seek(-$extra, 2) or $err = 1;
                        $raf->Read($buf, $extra) == $extra or $err = 1;
                        $extra = 0 if not $err and $buf eq "\0" x $extra;
                    }
                    if ($extra > 0) {
                        $self->Error("$extra unreferenced bytes at end of file not copied", 1);
                    }
                }
            }
        }
        # copy over image data now if necessary
        if (ref $dirInfo{ImageData} and not $err) {
            $self->CopyImageData($dirInfo{ImageData}, $outfile) or $err = 1;
            delete $dirInfo{ImageData};
        }
        delete $self->{TIFF_END};
        return $err ? -1 : 1;
    }
    # process the directory
    $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
    # process GeoTiff information if available
    if ($self->{VALUE}->{GeoTiffDirectory}) {
        require Image::ExifTool::GeoTiff;
        Image::ExifTool::GeoTiff::ProcessGeoTiff($self);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Return list of tag table keys (ignoring special keys)
# Inputs: 0) reference to tag table
# Returns: List of table keys
sub TagTableKeys($)
{
    local $_;
    my $tagTablePtr = shift;
    my @keyList;
    foreach (keys %$tagTablePtr) {
        push(@keyList, $_) unless $specialTags{$_};
    }
    return @keyList;
}

#------------------------------------------------------------------------------
# GetTagTable
# Inputs: 0) table name
# Returns: tag table reference, or undefined if not found
# Notes: Always use this function instead of requiring module and using table
# directly since this function also does the following the first time the table
# is loaded:
# - requires new module if necessary
# - generates default GROUPS hash and Group 0 name from module name
# - registers Composite tags if Composite table found
# - saves descriptions for tags in specified table
# - generates default TAG_PREFIX to be used for unknown tags
sub GetTagTable($)
{
    my $tableName = shift or return undef;

    my $table = $allTables{$tableName};

    unless ($table) {
        no strict 'refs';
        unless (defined %$tableName) {
            # try to load module for this table
            if ($tableName =~ /(.*)::/) {
                my $module = $1;
                unless (eval "require $module") {
                    $@ and warn $@;
                }
            }
            unless (defined %$tableName) {
                warn "Can't find table $tableName\n";
                return undef;
            }
        }
        no strict 'refs';
        $table = \%$tableName;
        use strict 'refs';
        # set default group 0 and 1 from module name unless already specified
        my $defaultGroups = $$table{GROUPS};
        $defaultGroups or $defaultGroups = $$table{GROUPS} = { };
        unless ($$defaultGroups{0} and $$defaultGroups{1}) {
            if ($tableName =~ /Image::.*?::([^:]*)/) {
                $$defaultGroups{0} = $1 unless $$defaultGroups{0};
                $$defaultGroups{1} = $1 unless $$defaultGroups{1};
            } else {
                $$defaultGroups{0} = $tableName unless $$defaultGroups{0};
                $$defaultGroups{1} = $tableName unless $$defaultGroups{1};
            }
        }
        $$defaultGroups{2} = 'Other' unless $$defaultGroups{2};
        # generate a tag prefix for unknown tags if necessary
        unless ($$table{TAG_PREFIX}) {
            my $tagPrefix;
            if ($tableName =~ /Image::.*?::(.*)::Main/ || $tableName =~ /Image::.*?::(.*)/) {
                ($tagPrefix = $1) =~ s/::/_/g;
            } else {
                $tagPrefix = $tableName;
            }
            $$table{TAG_PREFIX} = $tagPrefix;
        }
        # set up the new table
        SetupTagTable($table);
        # add any user-defined tags
        if (defined %UserDefined and $UserDefined{$tableName}) {
            my $tagID;
            foreach $tagID (TagTableKeys($UserDefined{$tableName})) {
                my $tagInfo = $UserDefined{$tableName}->{$tagID};
                if (ref $tagInfo eq 'HASH') {
                    $$tagInfo{Name} or $$tagInfo{Name} = ucfirst($tagID);
                } else {
                    $tagInfo = { Name => $tagInfo };
                }
                if ($$table{WRITABLE} and not defined $$tagInfo{Writable} and
                    not $$tagInfo{SubDirectory})
                {
                    $$tagInfo{Writable} = $$table{WRITABLE};
                }
                delete $$table{$tagID}; # replace any existing entry
                AddTagToTable($table, $tagID, $tagInfo);
            }
        }
        # generate tag ID's if necessary
        GenerateTagIDs($table) if $didTagID;
        # remember order we loaded the tables in
        push @tableOrder, $tableName;
        # insert newly loaded table into list
        $allTables{$tableName} = $table;
    }
    return $table;
}

#------------------------------------------------------------------------------
# Process an image directory
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference, 3) optional reference to processing procedure
# Returns: Result from processing (1=success)
sub ProcessDirectory($$$;$)
{
    my ($self, $dirInfo, $tagTablePtr, $processProc) = @_;

    return 0 unless $tagTablePtr and $dirInfo;
    # use default proc from tag table if no proc specified
    $processProc or $processProc = $$tagTablePtr{PROCESS_PROC};
    # set directory name from default group0 name if not done already
    $$dirInfo{DirName} or $$dirInfo{DirName} = $tagTablePtr->{GROUPS}->{0};
    # guard against cyclical recursion into the same directory
    if (defined $$dirInfo{DirStart} and defined $$dirInfo{DataPos}) {
        my $addr = $$dirInfo{DirStart} + $$dirInfo{DataPos} + ($$dirInfo{Base}||0);
        if ($self->{PROCESSED}->{$addr}) {
            $self->Warn("$$dirInfo{DirName} pointer references previous $self->{PROCESSED}->{$addr} directory");
            return 0;
        }
        $self->{PROCESSED}->{$addr} = $$dirInfo{DirName};
    }
    # otherwise process as an EXIF directory
    $processProc or $processProc = \&Image::ExifTool::Exif::ProcessExif;
    my $oldOrder = GetByteOrder();
    my $oldIndent = $self->{INDENT};
    my $oldDir = $self->{DIR_NAME};
    $self->{INDENT} .= '| ';
    $self->{DIR_NAME} = $$dirInfo{DirName};
    my $rtnVal = &$processProc($self, $dirInfo, $tagTablePtr);
    $self->{INDENT} = $oldIndent;
    $self->{DIR_NAME} = $oldDir;
    SetByteOrder($oldOrder);
    return $rtnVal;
}

#------------------------------------------------------------------------------
# get standardized file extension
# Inputs: 0) file name
# Returns: standardized extension (all uppercase)
sub GetFileExtension($)
{
    my $filename = shift;
    my $fileExt;
    if ($filename and $filename =~ /.*\.(.+)$/) {
        $fileExt = uc($1);   # change extension to upper case
        # convert TIF extension to TIFF because we use the
        # extension for the file type tag of TIFF images
        $fileExt eq 'TIF' and $fileExt = 'TIFF';
    }
    return $fileExt;
}

#------------------------------------------------------------------------------
# Get list of tag information hashes for given tag ID
# Inputs: 0) Tag table reference, 1) tag ID
# Returns: Array of tag information references
# Notes: Generates tagInfo hash if necessary
sub GetTagInfoList($$)
{
    my ($tagTablePtr, $tagID) = @_;
    my $tagInfo = $$tagTablePtr{$tagID};

    if (ref $tagInfo eq 'HASH') {
        return ($tagInfo);
    } elsif (ref $tagInfo eq 'ARRAY') {
        return @$tagInfo;
    } elsif ($tagInfo) {
        # create hash with name
        $tagInfo = $$tagTablePtr{$tagID} = { Name => $tagInfo };
        return ($tagInfo);
    }
    return ();
}

#------------------------------------------------------------------------------
# Find tag information, processing conditional tags
# Inputs: 0) ExifTool object reference, 1) tagTable pointer, 2) tag ID
#         3) optional value reference
# Returns: pointer to tagInfo hash, undefined if none found, or '' if $valPt needed
# Notes: You should always call this routine to find a tag in a table because
# this routine will evaluate conditional tags.
# Argument 3 is only required if the information type allows $valPt in a Condition
# and if not given when needed, this routine returns ''.
sub GetTagInfo($$$;$)
{
    my ($self, $tagTablePtr, $tagID, $valPt) = @_;

    my @infoArray = GetTagInfoList($tagTablePtr, $tagID);
    # evaluate condition
    my $tagInfo;
    foreach $tagInfo (@infoArray) {
        my $condition = $$tagInfo{Condition};
        if ($condition) {
            return '' if $condition =~ /\$valPt\b/ and not $valPt;
            # set old value for use in condition if needed
            my $oldVal = $self->{VALUE}->{$$tagInfo{Name}};
            #### eval Condition ($self, $oldVal, [$valPt])
            unless (eval $condition) {
                $@ and warn "Condition $$tagInfo{Name}: $@";
                next;
            }
        }
        if ($$tagInfo{Unknown} and not $self->{OPTIONS}->{Unknown}) {
            # don't return Unknown tags unless that option is set
            return undef;
        }
        # return the tag information we found
        return $tagInfo;
    }
    # generate information for unknown tags (numerical only) if required
    if (not $tagInfo and $self->{OPTIONS}->{Unknown} and $tagID =~ /^\d+$/) {
        my $printConv;
        if (defined $$tagTablePtr{PRINT_CONV}) {
            $printConv = $$tagTablePtr{PRINT_CONV};
        } else {
            # limit length of printout (can be very long)
            $printConv = 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val';
        }
        my $hex = sprintf("0x%.4x", $tagID);
        my $prefix = $$tagTablePtr{TAG_PREFIX};
        $tagInfo = {
            Name => "${prefix}_$hex",
            Description => MakeDescription($prefix, $hex),
            Unknown => 1,
            Writable => 0,  # can't write unknown tags
            PrintConv => $printConv,
        };
        # add tag information to table
        AddTagToTable($tagTablePtr, $tagID, $tagInfo);
    } else {
        undef $tagInfo;
    }
    return $tagInfo;
}

#------------------------------------------------------------------------------
# add new tag to table (must use this routine to add new tags to a table)
# Inputs: 0) reference to tag table, 1) tag ID
#         2) reference to tag information hash
# Notes: - will not overwrite existing entry in table
# - info need contain no entries when this routine is called
sub AddTagToTable($$$)
{
    my ($tagTablePtr, $tagID, $tagInfo) = @_;

    # define necessary entries in information hash
    if ($$tagInfo{Groups}) {
        # fill in default groups from table GROUPS
        foreach (keys %{$$tagTablePtr{GROUPS}}) {
            next if $tagInfo->{Groups}->{$_};
            $tagInfo->{Groups}->{$_} = $tagTablePtr->{GROUPS}->{$_};
        }
    } else {
        $$tagInfo{Groups} = $$tagTablePtr{GROUPS};
    }
    $$tagInfo{GotGroups} = 1,
    $$tagInfo{Table} = $tagTablePtr;
    $$tagInfo{TagID} = $tagID;

    unless ($$tagInfo{Name}) {
        my $prefix = $$tagTablePtr{TAG_PREFIX};
        $$tagInfo{Name} = "${prefix}_$tagID";
        # make description to prevent tagID from getting mangled by MakeDescription()
        $$tagInfo{Description} = MakeDescription($prefix, $tagID);
    }
    # add tag to table, but never overwrite existing entries (could potentially happen
    # if someone thinks there isn't any tagInfo because a condition wasn't satisfied)
    $$tagTablePtr{$tagID} = $tagInfo unless defined $$tagTablePtr{$tagID};
}

#------------------------------------------------------------------------------
# handle simple extraction of new tag information
# Inputs: 0) ExifTool object ref, 1) tag table reference, 2) tagID, 3) value,
#         4-N) parameters hash: Index, DataPt, DataPos, Start, Size, Parent, TagInfo
# Returns: tag key or undef if tag not found
sub HandleTag($$$$;%)
{
    my ($self, $tagTablePtr, $tag, $val, %parms) = @_;
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $tagInfo = $parms{TagInfo} || $self->GetTagInfo($tagTablePtr, $tag);
    my $dataPt = $parms{DataPt};
    my $subdir;

    if ($tagInfo) {
        $subdir = $$tagInfo{SubDirectory}
    } else {
        return undef unless $verbose;
    }
    # read value if not done already (not necessary for subdir)
    unless (defined $val or $subdir) {
        my $start = $parms{Start} || 0;
        my $size = $parms{Size} || 0;
        # read from data in memory if possible
        if ($dataPt and $start >= 0 and $start + $size <= length($$dataPt)) {
            $val = substr($$dataPt, $start, $size);
        } else {
            my $name = $tagInfo ? $$tagInfo{Name} : "tag $tag";
            $self->Warn("Error extracting value for $name");
            return undef;
        }
    }
    # do verbose print if necessary
    if ($verbose) {
        $parms{Value} = $val;
        $parms{Table} = $tagTablePtr;
        $self->VerboseInfo($tag, $tagInfo, %parms);
    }
    if ($tagInfo) {
        if ($subdir) {
            # process subdirectory information
            my %dirInfo = (
                DirName  => $$tagInfo{Name},
                DataPt   => $dataPt,
                DataLen  => length $$dataPt,
                DataPos  => $parms{DataPos},
                DirStart => $parms{Start},
                DirLen   => $parms{Size},
                Parent   => $parms{Parent},
            );
            my $subTablePtr = GetTagTable($$subdir{TagTable}) || $tagTablePtr;
            $self->ProcessDirectory(\%dirInfo, $subTablePtr, $$subdir{ProcessProc});
        } else {
            return $self->FoundTag($tagInfo, $val);
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# found specified tag
# Inputs: 0) reference to ExifTool object
#         1) reference to tagInfo hash or tag name
#         2) data value (or reference to require hash if composite)
# Returns: tag key or undef if no value
sub FoundTag($$$)
{
    local $_;
    my ($self, $tagInfo, $value) = @_;
    my $tag;

    if (ref $tagInfo eq 'HASH') {
        $tag = $$tagInfo{Name} or warn("No tag name\n"), return undef;
    } else {
        $tag = $tagInfo;
        # look for tag in Extra
        $tagInfo = $self->GetTagInfo(GetTagTable('Image::ExifTool::Extra'), $tag);
        # make temporary hash if tag doesn't exist in Extra
        # (not advised to do this since the tag won't show in list)
        $tagInfo or $tagInfo = { Name => $tag, Groups => \%allGroupsExifTool };
        $self->{OPTIONS}->{Verbose} and $self->VerboseInfo(undef, $tagInfo, Value => $value);
    }
    my $rawValueHash = $self->{VALUE};
    if ($$tagInfo{RawConv}) {
        my $conv = $$tagInfo{RawConv};
        my $val = $value;   # must do this in case eval references $val
        # initialize @val for use in Composite RawConv expressions
        my @val;
        if (ref $val eq 'HASH') {
            foreach (keys %$val) { $val[$_] = $$rawValueHash{$$val{$_}}; }
        }
        if (ref($conv) eq 'CODE') {
            $value = &$conv($val, $self);
        } else {
            #### eval RawConv ($self, $val)
            $value = eval $conv;
            $@ and warn "RawConv: $@\n";
        }
        return undef unless defined $value;
    }
    # get tag priority
    my $priority = $$tagInfo{Priority};
    defined $priority or $priority = $tagInfo->{Table}->{PRIORITY};
    # handle duplicate tag names
    if (defined $rawValueHash->{$tag}) {
        if ($$tagInfo{List} and $tagInfo eq $self->{TAG_INFO}->{$tag} and
            not $self->{NO_LIST})
        {
            # use a list reference for multiple values
            if (ref $rawValueHash->{$tag} ne 'ARRAY') {
                $rawValueHash->{$tag} = [ $rawValueHash->{$tag} ];
            }
            push @{$rawValueHash->{$tag}}, $value;
            return $tag;    # return without creating a new entry
        }
        # rename existing tag to make room for duplicate values
        my $nextTag;  # next available copy number for this tag
        my $i;
        for ($i=1; ; ++$i) {
            $nextTag = "$tag ($i)";
            last unless exists $rawValueHash->{$nextTag};
        }
#
# take tag with highest priority
#
        # promote existing 0-priority tag so it takes precedence over a new 0-tag
        my $oldPriority = $self->{PRIORITY}->{$tag} || 1;
        # set priority for this tag (default is 1)
        $priority = 1 if not defined $priority or
            # increase 0-priority tags if this is the priority directory
            ($priority == 0 and $self->{DIR_NAME} and $self->{PRIORITY_DIR} and
            $self->{DIR_NAME} eq $self->{PRIORITY_DIR});
        if ($priority >= $oldPriority) {
            $self->{PRIORITY}->{$nextTag} = $self->{PRIORITY}->{$tag};
            $rawValueHash->{$nextTag} = $rawValueHash->{$tag};
            $self->{FILE_ORDER}->{$nextTag} = $self->{FILE_ORDER}->{$tag};
            $self->{TAG_INFO}->{$nextTag} = $self->{TAG_INFO}->{$tag};
            if ($self->{GROUP1}->{$tag}) {
                $self->{GROUP1}->{$nextTag} = $self->{GROUP1}->{$tag};
                delete $self->{GROUP1}->{$tag};
            }
        } else {
            $tag = $nextTag;        # don't override the existing tag
        }
        $self->{PRIORITY}->{$tag} = $priority;
    } elsif ($priority) {
        # set tag priority (only if exists and non-zero)
        $self->{PRIORITY}->{$tag} = $priority;
    }

    # save the converted values, file order, and tag groups
    $rawValueHash->{$tag} = $value;
    $self->{FILE_ORDER}->{$tag} = ++$self->{NUM_FOUND};
    $self->{TAG_INFO}->{$tag} = $tagInfo;
    $self->{GROUP1}->{$tag} = $self->{SET_GROUP1} if $self->{SET_GROUP1};

    return $tag;
}

#------------------------------------------------------------------------------
# make current directory the priority directory if not set already
# Inputs: 0) reference to ExifTool object
sub SetPriorityDir($)
{
    my $self = shift;
    $self->{PRIORITY_DIR} = $self->{DIR_NAME} unless $self->{PRIORITY_DIR};
}

#------------------------------------------------------------------------------
# set family 1 group name specific to this tag instance
# Inputs: 0) reference to ExifTool object, 1) tag key, 2) group name
sub SetGroup1($$$)
{
    my ($self, $tagKey, $extra) = @_;
    $self->{GROUP1}->{$tagKey} = $extra;
}

#------------------------------------------------------------------------------
# set ID's for all tags in specified table
# Inputs: 0) tag table reference
sub GenerateTagIDs($)
{
    my $table = shift;

    unless ($$table{DID_TAG_ID}) {
        $$table{DID_TAG_ID} = 1;    # set flag so we won't do this table again
        my ($tagID, $tagInfo);
        foreach $tagID (keys %$table) {
            next if $specialTags{$tagID};
            # define tag ID in each element of conditional array
            my @infoArray = GetTagInfoList($table,$tagID);
            foreach $tagInfo (@infoArray) {
                # define tag ID's in info hash
                $$tagInfo{TagID} = $tagID;
            }
        }
    }
}

#------------------------------------------------------------------------------
# Generate TagID's for all loaded tables
# Inputs: None
# Notes: Causes subsequently loaded tables to automatically generate TagID's too
sub GenerateAllTagIDs()
{
    unless ($didTagID) {
        my $tableName;
        foreach $tableName (keys %allTables) {
            # generate tag ID's for all tags in this table
            GenerateTagIDs($allTables{$tableName});
        }
        $didTagID = 1;
    }
}

#------------------------------------------------------------------------------
# delete specified tag
# Inputs: 0) reference to ExifTool object
#         1) tag key
sub DeleteTag($$)
{
    my ($self, $tag) = @_;
    delete $self->{VALUE}->{$tag};
    delete $self->{FILE_ORDER}->{$tag};
    delete $self->{TAG_INFO}->{$tag};
    delete $self->{GROUP1}->{$tag};
}

#------------------------------------------------------------------------------
# Set the FileType and MIMEType tags
# Inputs: 0) ExifTool object reference
#         1) Optional file type (uses FILE_TYPE if not specified)
sub SetFileType($;$)
{
    my $self = shift;
    my $baseType = $self->{FILE_TYPE};
    my $fileType = shift || $baseType;
    my $mimeType = $mimeType{$fileType};
    # use base file type if necessary (except if 'TIFF', which is a special case)
    $mimeType = $mimeType{$baseType} unless $mimeType or $baseType eq 'TIFF';
    $self->FoundTag('FileType', $fileType);
    $self->FoundTag('MIMEType', $mimeType || 'application/unknown');
}

#------------------------------------------------------------------------------
# Modify the value of the MIMEType tag
# Inputs: 0) ExifTool object reference, 1) file or MIME type
# Notes: combines existing type with new type: ie) a/b + c/d => c/b-d
sub ModifyMimeType($;$)
{
    my ($self, $mime) = @_;
    $mime =~ m{/} or $mime = $mimeType{$mime} or return;
    my $old = $self->{VALUE}->{MIMEType};
    if (defined $old) {
        my ($a, $b) = split '/', $old;
        my ($c, $d) = split '/', $mime;
        $d =~ s/^x-//;
        $self->{VALUE}->{MIMEType} = "$c/$b-$d";
        $self->VPrint(0, "  Modified MIMEType = $c/$b-$d\n");
    } else {
        $self->FoundTag('MIMEType', $mime);
    }
}

#------------------------------------------------------------------------------
# Print verbose output
# Inputs: 0) ExifTool ref, 1) verbose level (prints if level > this), 2-N) print args
sub VPrint($$@)
{
    my $self = shift;
    my $level = shift;
    if ($self->{OPTIONS}->{Verbose} and $self->{OPTIONS}->{Verbose} > $level) {
        my $out = $self->{OPTIONS}->{TextOut};
        print $out @_;
    }
}

#------------------------------------------------------------------------------
# extract binary data from file
# 0) ExifTool object reference, 1) offset, 2) length, 3) tag name if conditional
# Returns: binary data, or undef on error
# Notes: Returns "Binary data #### bytes" instead of data unless tag is
#        specifically requested or the Binary option is set
sub ExtractBinary($$$;$)
{
    my ($self, $offset, $length, $tag) = @_;

    if ($tag and not $self->{OPTIONS}->{Binary} and
        not $self->{REQ_TAG_LOOKUP}->{lc($tag)})
    {
        return "Binary data $length bytes";
    }
    my $buff;
    unless ($self->{RAF}->Seek($offset,0)
        and $self->{RAF}->Read($buff, $length) == $length)
    {
        $tag or $tag = 'binary data';
        $self->Warn("Error reading $tag from file");
        return undef;
    }
    return $buff;
}

#------------------------------------------------------------------------------
# process binary data
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference
# Returns: 1 on success
sub ProcessBinaryData($$$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $base = $$dirInfo{Base} || 0;
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $unknown = $self->{OPTIONS}->{Unknown};
    my $dataPos;

    if ($verbose) {
        $self->VerboseDir('BinaryData', undef, $size);
        $dataPos = $$dirInfo{DataPos} || 0;
    }
    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';
    my $increment = $formatSize{$defaultFormat};
    unless ($increment) {
        warn "Unknown format $defaultFormat\n";
        $defaultFormat = 'int8u';
        $increment = $formatSize{$defaultFormat};
    }
    # prepare list of tag numbers to extract
    my @tags;
    if ($unknown > 1 and defined $$tagTablePtr{FIRST_ENTRY}) {
        # scan through entire binary table
        @tags = ($$tagTablePtr{FIRST_ENTRY}..(int($size/$increment) - 1));
    } else {
        # extract known tags in numerical order
        @tags = sort { $a <=> $b } TagTableKeys($tagTablePtr);
    }
    my $index;
    my $nextIndex = 0;
    my %val;
    foreach $index (@tags) {
        my $tagInfo;
        if ($$tagTablePtr{$index}) {
            $tagInfo = $self->GetTagInfo($tagTablePtr, $index) or next;
            next if $$tagInfo{Unknown} and $$tagInfo{Unknown} > $unknown;
        } else {
            # don't generate unknown tags in binary tables unless Unknown > 1
            next unless $unknown > 1;
            next if $index < $nextIndex;    # skip if data already used
            $tagInfo = $self->GetTagInfo($tagTablePtr, $index) or next;
            $$tagInfo{Unknown} = 2;    # set unknown to 2 for binary unknowns
        }
        my $count = 1;
        my $format = $$tagInfo{Format};
        my $entry = $index * $increment;        # relative offset of this entry
        if ($format) {
            if ($format =~ /(.*)\[(.*)\]/) {
                $format = $1;
                $count = $2;
                # evaluate count to allow count to be based on previous values
                #### eval Format (%val, $size)
                $count = eval $count;
                $@ and warn("Format $$tagInfo{Name}: $@"), next;
            } elsif ($format eq 'string') {
                # allow string with no specified count to run to end of block
                $count = ($size > $entry) ? $size - $entry : 0;
            }
        } else {
            $format = $defaultFormat;
        }
        if ($unknown > 1) {
            # calculate next valid index for unknown tag
            $nextIndex = $index + ($formatSize{$format} * $count) / $increment;
        }
        my $val = ReadValue($dataPt, $entry+$offset, $format, $count, $size-$entry);
        next unless defined $val;
        if ($verbose) {
            my $len = $count * ($formatSize{$format} || 1);
            $len > $size - $entry and $len = $size - $entry;
            $self->VerboseInfo($index, $tagInfo,
                Table  => $tagTablePtr,
                Value  => $val,
                DataPt => $dataPt,
                Size   => $len,
                Start  => $entry+$offset,
                Addr   => $entry+$offset+$base+$dataPos,
                Format => $format,
                Count  => $count,
            );
        }
        $val += $base if $$tagInfo{IsOffset};
        $val{$index} = $val;
        $self->FoundTag($tagInfo,$val);
    }
    return 1;
}

#..............................................................................
# Load .ExifTool_config file from user's home directory (unless 'noConfig' set)
unless ($Image::ExifTool::noConfig) {
    # load config file if it exists
    my $configFile = ($ENV{EXIFTOOL_HOME} || $ENV{HOME} || '.') . '/.ExifTool_config';
    -r $configFile and eval("require '$configFile'");
}

#------------------------------------------------------------------------------
1;  # end
