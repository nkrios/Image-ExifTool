#------------------------------------------------------------------------------
# File:         ExifTool.pm
#
# Description:  Utility to read EXIF information from image files
#
# URL:          http://owl.phy.queensu.ca/~phil/exiftool/
#
# Revisions:    Nov. 12/03 - P. Harvey Created
#               (See html/history.html for revision history)
#
# Legal:        Copyright (c) 2003-2005 Phil Harvey (phil at owl.phy.queensu.ca)
#               This library is free software; you can redistribute it and/or
#               modify it under the same terms as Perl itself.
#------------------------------------------------------------------------------

package Image::ExifTool;

use strict;
require 5.004;  # require 5.004 for UNIVERSAL::isa (otherwise 5.002 would do)
require Exporter;
use File::RandomAccess;

use vars qw($VERSION @ISA %EXPORT_TAGS $AUTOLOAD @fileTypes %allTables @tableOrder
            $exifAPP1hdr $xmpAPP1hdr $psAPP13hdr $myAPP5hdr @loadAllTables);
$VERSION = '5.46';
@ISA = qw(Exporter);
%EXPORT_TAGS = (
    Public => [ qw(
        ImageInfo Options ClearOptions ExtractInfo GetInfo WriteInfo
        CombineInfo GetTagList GetFoundTags GetRequestedTags GetValue
        SetNewValue SetNewValuesFromFile GetNewValues SaveNewValues
        RestoreNewValues SetNewGroups GetNewGroups GetTagID GetDescription
        GetGroup GetGroups BuildCompositeTags GetTagName GetShortcuts
        GetAllTags GetWritableTags GetAllGroups GetFileType
    )],
    DataAccess => [qw(
        ReadValue GetByteOrder SetByteOrder ToggleByteOrder Get8u Get8s Get16u
        Get16s Get32u Get32s GetFloat GetDouble WriteValue Set8u Set8s Set16u
        Set32u
    )],
    Utils => [qw(
        GetTagTable TagTableKeys GetTagInfoList GenerateTagIDs SetFileType
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
sub SaveNewValues($);
sub RestoreNewValues($);
sub GetAllTags();
sub GetWritableTags();
sub GetAllGroups($);
# non-public routines below
sub LoadAllTables();
sub GetNewTagInfoList($;$);
sub GetNewTagInfoHash($$);
sub Get64s($$);
sub Get64u($$);
sub HexDump($;$%);
sub VerboseInfo($$$%);
sub VerboseDir($$;$);
sub Rationalize($;$);
sub WriteValue($$;$$$$);
sub WriteTagTable($$;$$);
sub WriteInfo($$$);
sub WriteBinaryData($$$);
sub CheckBinaryData($$$);

# recognized file types, in the order we test unknown files
# (Note: There is no need to test for MNG, JNG, PS or AI separately here
# because they are parsed by the PNG and EPS code.)
@fileTypes = qw(JPEG CRW TIFF MRW ORF GIF JP2 PNG MIFF EPS PDF PSD BMP);

# file type lookup for all recognized file extensions
my %fileTypeLookup = (
    AI   => 'AI',   # Adobe Illustrator (PS-like)
    BMP  => 'BMP',  # Windows BitMaP
    CR2  => 'TIFF', # Canon RAW 2 format (tiff-like)
    CRW  => 'CRW',  # Canon RAW format
    DIB  => 'BMP',  # Device Independent Bitmap (aka. BMP)
    DNG  => 'TIFF', # Digital Negative (TIFF-like)
    EPS  => 'EPS',  # Encapsulated PostScript Format (.3)
    EPSF => 'EPS',  # Encapsulated PostScript Format (.4)
    GIF  => 'GIF',  # Compuserve Graphics Interchange Format
    JNG  => 'JNG',  # JPG Network Graphics
    JP2  => 'JP2',  # JPEG 2000 file
    JPEG => 'JPEG', # Joint Photographic Experts Group (.4)
    JPG  => 'JPEG', # Joint Photographic Experts Group (.3)
    JPX  => 'JP2',  # JPEG 2000 file
    MIF  => 'MIFF', # Magick Image File Format (.3)
    MIFF => 'MIFF', # Magick Image File Format (.4)
    MNG  => 'MNG',  # Multiple-image Network Graphics
    MRW  => 'MRW',  # Minolta RAW format
    NEF  => 'TIFF', # Nikon (RAW) Electronic Format (TIFF-like)
    ORF  => 'ORF',  # Olympus RAW format
    PDF  => 'PDF',  # Adobe Portable Document Format
    PEF  => 'TIFF', # Pentax (RAW) Electronic Format (TIFF-like)
    PNG  => 'PNG',  # Portable Network Graphics
    PS   => 'PS',   # PostScript
    PSD  => 'PSD',  # PhotoShop Drawing
    THM  => 'JPEG', # Canon Thumbnail (aka. JPG)
    TIF  => 'TIFF', # Tagged Image File Format (.3)
    TIFF => 'TIFF', # Tagged Image File Format (.4)
);

# list of main tag tables to load in LoadAllTables() (sub-tables are recursed
# automatically).  Note: They will appear in this order in the documentation,
# so put the Exif Table first.
@loadAllTables = qw(Exif CanonRaw Photoshop GeoTiff Jpeg2000 BMP PNG MNG MIFF
                    PDF PostScript);

# default group priority for writing
my @defaultWriteGroups = ('EXIF','GPS','IPTC','XMP','MakerNotes','Photoshop');

# group hash for ExifTool-generated tags
my %allGroupsExifTool = ( 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'ExifTool' );

# headers for various segment types
$exifAPP1hdr = "Exif\0\0";
$xmpAPP1hdr = "http://ns.adobe.com/xap/1.0/\0";
$psAPP13hdr = "Photoshop 3.0\0";

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
    ValueConv => '$self->ValidateImage(\$val)',
    ValueConvInv => '$val eq "" and $val="none"; $val',
);

# extra tags that aren't truly EXIF tags, but are generated by the script
# Note: any tag in this list with a name corresponding to a Group0 name is
#       used to write the entire corresponding directory as a block.
%Image::ExifTool::extraTags = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    DID_TAG_ID => 1,   # tag ID's aren't meaningful for these tags
    WRITE_PROC => \&DummyWriteProc,
    Comment => {
        Name => 'Comment',
        Notes => 'comment embedded in JPEG or GIF89a image', 
        Flags => 'Writable',
        WriteGroup => 'Comment',
        Priority => 0,  # to preserve order of JPEG COM segments
    },
    FileName    => { Name => 'FileName' },
    Directory   => { Name => 'Directory' },
    FileSize    => { Name => 'FileSize',  PrintConv => 'sprintf("%.0fKB",$val/1024)' },
    FileType    => { Name => 'FileType' },
    FileModifyDate => {
        Name => 'FileModifyDate',
        Description => 'File Modification Date/Time',
        Notes => 'the filesystem modification time',
        Groups => { 2 => 'Time' },
        Writable => 1,
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$val',
    },
    ImageWidth  => { Name => 'ImageWidth' },
    ImageHeight => { Name => 'ImageHeight' },
    EXIF => {
        Name => 'EXIF',
        Notes => 'the full EXIF data block',
        Groups => { 0 => 'EXIF' },
        ValueConv => '\$val',
    },
    XMP => {
        Name => 'XMP', 
        Notes => 'the full XMP data block',
        Groups => { 0 => 'XMP' },
        Writable => 1,
        ValueConv => '\$val',
        ValueConvInv => '$val',
        WriteCheck => '$val =~ /^\0*<\0*\?\0*x\0*p\0*a\0*c\0*k\0*e\0*t/ ? undef : "Invalid XMP data"',
    },
    ExifToolVersion => {
        Name        => 'ExifToolVersion',
        Description => 'ExifTool Version Number',
        Groups      => \%allGroupsExifTool
    },
    Error       => { Name => 'Error',   Priority => 0, Groups => \%allGroupsExifTool },
    Warning     => { Name => 'Warning', Priority => 0, Groups => \%allGroupsExifTool },
);

# static private ExifTool variables

%allTables = ( );   # list of all tables loaded (except composite tags)
@tableOrder = ( );  # order the tables were loaded

my $didTagID;       # flag indicating we are accessing tag ID's
my $evalWarning;    # eval warning message

# composite tags (accumulation of all Composite tag tables)
%Image::ExifTool::compositeTags = (
    GROUPS => { 0 => 'Composite', 1 => 'Composite' },
    DID_TAG_ID => 1,    # want empty tagID's for composite tags
    WRITE_PROC => \&DummyWriteProc,
);

# empty hash to receive APP12 tags
%Image::ExifTool::APP12 = (
    GROUPS => { 0 => 'APP12', 1 => 'APP12', 2 => 'Image' },
);

# special tag names (not used for tag info)
my %specialTags = (
    PROCESS_PROC=>1, WRITE_PROC=>1, CHECK_PROC=>1, GROUPS=>1, FORMAT=>1,
    FIRST_ENTRY=>1, TAG_PREFIX=>1, PRINT_CONV=>1, DID_TAG_ID=>1,
    WRITABLE=>1, NOTES=>1, IS_OFFSET=>1,
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
    $self->{INDENT} = '  ';     # initial indent for verbose messages
    
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
        my $value = shift;
        $oldVal = $self->{OPTIONS}->{$param};
        $self->{OPTIONS}->{$param} = $value if defined $value;
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
        Composite   => 1,       # flag to calculate Composite tags
        Charset     => 'UTF8',  # character set for converting XP characters
    #   DateFormat  => undef,   # format for date/time
        Duplicates  => 1,       # flag to save duplicate tag values
    #   Exclude     => undef,   # tags to exclude
    #   Group#      => undef,   # return tags for specified groups in family #
        PrintConv   => 1,       # flag to enable print conversion
        Sort        => 'Input', # order to sort found tags (Input, File, Alpha, Group#)
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
                # (note: disable buffering for a normal file -- $filename ne '-')
                $raf = new File::RandomAccess($filePt, $filename ne '-');
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
        # process the image
        $raf->BinMode();    # set binary mode before we start reading

        # read tags from the file
        my (@fileTypeList, $tiffType, $pos);
        my $fileType = GetFileType($filename);
        if ($fileType) {
            # only test type specified by file extension
            @fileTypeList = ( $fileType );
            $tiffType = GetFileExtension($filename);
        } else {
            # scan through all recognized file types
            @fileTypeList = @fileTypes;
            # must test our input file for the ability to seek
            # since we will be testing multiple file types
            $raf->SeekTest();
            $pos = $raf->Tell();    # get file position so we can rewind
            $tiffType = 'TIFF';
        }
        # loop through list of extensions to test
        for (;;) {
            my $type = shift @fileTypeList;
            # save file type in member variable
            $self->{FILE_TYPE} = $type;
            # extract information from our file
            # Note: be sure to load modules using GetTagTable() if they contain tables!
            if ($type eq 'JPEG') {
                $self->JpegInfo() and last;
            } elsif ($type eq 'JP2') {
                GetTagTable('Image::ExifTool::Jpeg2000::Main');
                Image::ExifTool::Jpeg2000::Jpeg2000Info($self) and last;
            } elsif ($type eq 'GIF') {
                $self->GifInfo() and last;
            } elsif ($type eq 'CRW') {
                GetTagTable('Image::ExifTool::CanonRaw::Main');
                Image::ExifTool::CanonRaw::CrwInfo($self) and last;
            } elsif ($type eq 'MRW') {
                GetTagTable('Image::ExifTool::Minolta::Main');
                Image::ExifTool::Minolta::MrwInfo($self) and last;
            } elsif ($type =~ /^(PNG|MNG|JNG)$/) {
                GetTagTable('Image::ExifTool::PNG::Main');
                Image::ExifTool::PNG::PngInfo($self) and last;
                # 'convert' can produce JNG images in regular JPEG format...
                $type eq 'JNG' and $self->JpegInfo() and last;
            } elsif ($type eq 'MIFF') {
                GetTagTable('Image::ExifTool::MIFF::Main');
                Image::ExifTool::MIFF::MiffInfo($self) and last;
            } elsif ($type =~ /^(PS|EPS|AI)$/) {
                GetTagTable('Image::ExifTool::PostScript::Main');
                Image::ExifTool::PostScript::PostScriptInfo($self) and last;
            } elsif ($type eq 'PDF') {
                GetTagTable('Image::ExifTool::PDF::Main');
                Image::ExifTool::PDF::PdfInfo($self) and last;
            } elsif ($type eq 'PSD') {
                GetTagTable('Image::ExifTool::Photoshop::Main');
                Image::ExifTool::Photoshop::PsdInfo($self) and last;
            } elsif ($type eq 'BMP') {
                GetTagTable('Image::ExifTool::BMP::Main');
                Image::ExifTool::BMP::BmpInfo($self) and last;
            } else {
                # assume anything else is TIFF format (or else we can't read it)
                $self->TiffInfo($tiffType, $raf) and last;
            }
            if (@fileTypeList) {
                # seek back to try again from the same position in the file
                $raf->Seek($pos, 0) and next;
                $self->Error('Error seeking in file');
                last;
            }
            # if we were given a single image with a known type there
            # must be a format error since we couldn't read it, otherwise
            # it is likely we don't support images of this type
            $self->Error($fileType ? 'Image format error' : 'Unknown image type');
            last;     # all done since no more types
        }
        # extract binary EXIF data block only if requested
        if (defined $self->{EXIF_DATA} and $self->{REQ_TAG_LOOKUP}->{exif}) {
            $self->FoundTag('EXIF', $self->{EXIF_DATA});
        }
        # calculate composite tags
        $self->BuildCompositeTags() if $options->{Composite};

        $raf->Close() if $filename;     # close the file if we opened it
    }

    # restore original options
    %saveOptions and $self->{OPTIONS} = \%saveOptions;

    return exists $self->{PRINT_CONV}->{Error} ? 0 : 1;
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
    my %info;
    my $conv = $self->{OPTIONS}->{PrintConv} ? 'PRINT_CONV' : 'VALUE_CONV';
    foreach (@$rtnTags) {
        my $val = $self->{$conv}->{$_};
        next unless defined $val;
        $info{$_} = $val;
    }

    # return sorted tag list if provided with a list reference
    if ($self->{IO_TAG_LIST}) {
        # use file order by default if no tags specified
        # (no such thing as 'Input' order in this case)
        my $sortOrder = $self->{OPTIONS}->{Sort};
        my $reqTags = $self->{REQUESTED_TAGS} || [ ];
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
            my $group = $self->GetGroup($tag,$family);
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
#         2) Value type (PrintConv or ValueConv, defaults to PrintConv)
# Returns: Tag value, or list of all values in list context (ValueConv only)
sub GetValue($$;$)
{
    local $_;
    my ($self, $tag, $type) = @_;
    my $value;

    if ($type and $type eq 'ValueConv') {
        $value = $self->{VALUE_CONV}->{$tag};
    } else {
        $value = $self->{PRINT_CONV}->{$tag};
    }
    if (wantarray and ref $value eq 'ARRAY') {
        return @$value;
    } else {
        return $value;
    }
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

    # search through all loaded tables for reference to tag information
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
#         2) [optional] group family number
# Returns: Scalar context: Group name (for family 0 if not otherwise specified)
#          Array context: Group name if family specified, otherwise list of
#          group names for each family.
sub GetGroup($$;$)
{
    local $_;
    my ($self, $tag, $family) = @_;
    my $tagInfo;
    if (ref $tag eq 'HASH') {
        $tagInfo = $tag;
        $tag = $tagInfo->{Name};
    } else {
        $tagInfo = $self->{TAG_INFO}->{$tag} or return '';
    }
    # fill in default groups unless already done
    unless ($$tagInfo{GotGroups}) {
        my $tagTablePtr = $$tagInfo{Table};
        if ($tagTablePtr) {
            # construct our group list
            my $groups = $$tagInfo{Groups};
            $groups or $groups = $$tagInfo{Groups} = { };
            # fill in default groups
            my $defaultGroups = $$tagTablePtr{GROUPS};
            foreach (keys %$defaultGroups) {
                $$groups{$_} or $$groups{$_} = $$defaultGroups{$_};
            }
        }
        # set flag indicating group list was built
        $$tagInfo{GotGroups} = 1;
    }
    unless (defined $family) {
        if (wantarray) {
            # return all groups in array context
            my @groups;
            my $tagGroups = $$tagInfo{Groups};
            foreach (keys %$tagGroups) { $groups[$_] = $tagGroups->{$_}; }
            # make sure all groups are defined
            foreach (@groups) { defined or $_ = 'Other'; }
            # substitute family 1 group name if necessary
            if ($groups[1] =~ /^XMP\b/) {
                # add XMP namespace prefix to XMP group name
                my $ns = $self->{TAG_EXTRA}->{$tag};
                $groups[1] = $ns ? "XMP-$ns" : ($tagInfo->{Groups}->{1} || 'XMP');
            } elsif ($groups[1] =~ /^IFD\d+$/) {
                # get actual IFD name for family 1 if group has name like 'IFD#'
                $groups[1] = ($self->{TAG_EXTRA}->{$tag} || 'UnknownIFD');
            }
            return @groups;
        } else {
            $family = 0;
        }
    }
    my $group = $tagInfo->{Groups}->{$family} || 'Other';
    if ($family == 1) {
        # substitute family 1 group name if necessary
        if ($group =~ /^XMP\b/) {
            # add XMP namespace prefix to XMP group name
            my $ns = $self->{TAG_EXTRA}->{$tag};
            $group = $ns ? "XMP-$ns" : ($tagInfo->{Groups}->{1} || 'XMP');
        } elsif ($group =~ /^IFD\d+$/) {
            # get actual IFD name for family 1 if group has name like 'IFD#'
            $group = ($self->{TAG_EXTRA}->{$tag} || 'UnknownIFD');
        }
    }
    return $group;
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
        $info = $self->{PRINT_CONV};
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
    my @tagList = sort keys %Image::ExifTool::compositeTags;

    my $valueConv = $self->{VALUE_CONV};
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
            my $tagInfo = $self->GetTagInfo(\%Image::ExifTool::compositeTags, $tag);
            next unless $tagInfo;
            # put required tags into array and make sure they all exist
            my (@val, @valPrint, $type);
            foreach $type ('Require','Desire') {
                my $req = $$tagInfo{$type};
                $req or next;
                # save Require'd and Desire'd tag values in list
                my $index;
                foreach $index (keys %$req) {
                    my $reqTag = $$req{$index};
                    # allow tag group to be specified
                    if ($reqTag =~ /(.+?):(.+)/) {
                        my ($reqGroup, $name) = ($1, $2);
                        my $i = 0;
                        for (;;++$i) {
                            $reqTag = $name;
                            $reqTag .= " ($i)" if $i;
                            last unless defined $valueConv->{$reqTag};
                            last if $reqGroup eq $self->GetGroup($reqTag,0) or
                                    $reqGroup eq $self->GetGroup($reqTag,1);
                        }
                    }
                    # calculate this tag later if it relies on another
                    # Composite tag which hasn't been calculated yet
                    if ($notBuilt{$reqTag}) {
                        push @deferredTags, $tag;
                        next COMPOSITE_TAG;
                    }
                    unless (defined $valueConv->{$reqTag}) {
                        # don't continue if we require this tag
                        $type eq 'Require' and next COMPOSITE_TAG;
                    }
                    $val[$index] = $valueConv->{$reqTag};
                    $valPrint[$index] = $self->{PRINT_CONV}->{$reqTag};
                }
            }
            delete $notBuilt{$tag}; # this tag is OK to build now
            unless ($$tagInfo{ValueConv}) {
                warn "Can't build composite tag $tag (no ValueConv)\n";
                next;
            }
            $self->FoundTag($tagInfo, undef, \@val, \@valPrint);
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
# Returns: File type or undef if extension not supported
sub GetFileType($)
{
    local $_;
    my $file = shift;
    my $fileExt = GetFileExtension($file) or return undef;
    return $fileTypeLookup{$fileExt};   # look up the file type
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
    $self->{FILE_ORDER} = { };      # hash of tag order in file
    $self->{VALUE_CONV} = { };      # hash of converted tag values
    $self->{PRINT_CONV} = { };      # hash of print-converted values
    $self->{TAG_INFO}   = { };      # hash of tag information
    $self->{TAG_EXTRA}  = { };      # hash of extra information about tag
    $self->{PRIORITY}   = { };      # priority of current tags
    $self->{PROCESSED}  = { };      # hash of processed directory start positions
    $self->{NUM_FOUND}  = 0;        # total number of tags found (incl. duplicates)
    $self->{CHANGED}    = 0;        # number of tags changed (writer only)
    $self->{PRIORITY_DIR} = '';     # the priority directory name
    $self->{TIFF_TYPE}  = '';       # type of TIFF data (APP1, TIFF, NEF, etc...)
    $self->{CameraMake} = '';       # camera make
    $self->{CameraModel}= '';       # camera model
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
            $self->{REQ_TAG_LOOKUP}->{lc($_)} = 1;
        }
    }

    if (@exclude or $wasExcludeOpt) {
        # must make a copy of exclude list so we can modify it
        if ($options->{Exclude}) {
            if (ref $options->{Exclude} eq 'ARRAY') {
                # make copy of list so we can modify it below
                $options->{Exclude} = [ @{$options->{Exclude}} ];
            } else {
                # turn single exclude into list reference
                $options->{Exclude} = [ $options->{Exclude} ];
            }
            # add our new exclusions
            push @{$options->{Exclude}}, @exclude;
        } else {
            $options->{Exclude} = \@exclude;
        }
        # expand shortcuts in new exclude list
        ExpandShortcuts($options->{Exclude});
    }
}

#------------------------------------------------------------------------------
# Set list of found tags
# Inputs: 0) ExifTool object reference
# Returns: Reference to found tags list
sub SetFoundTags($)
{
    my $self = shift;
    my $options = $self->{OPTIONS};
    my $reqTags = $self->{REQUESTED_TAGS} || [ ];
    my $duplicates = $options->{Duplicates};
    my ($tag, $rtnTags, @allTags);

    # get information for requested groups
    my @groupOptions = sort grep /^Group/, keys %$options;
    if (@groupOptions) {
        # get list of all existing tags
        @allTags = keys %{$self->{PRINT_CONV}};
        my %wantGroup;
        my $family;
        my $allGroups = 1;
        # build hash of requested/excluded group names for each group family
        my $wantOrder = 0;
        my $groupOpt;
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
        my (%groupTags, %bestTag);
G_TAG:  foreach $tag (@allTags) {
            my $wantTag = $allGroups;   # want tag by default if want all groups
            foreach $family (keys %wantGroup) {
                my $group = $self->GetGroup($tag, $family);
                my $wanted = $wantGroup{$family}->{$group};
                next unless defined $wanted;
                next G_TAG unless $wanted;      # skip tag if group excluded
                # take lowest non-zero want flag
                next if $wantTag and $wantTag < $wanted;
                $wantTag = $wanted;
            }
            next unless $wantTag;
            if ($duplicates) {
                $groupTags{$tag} = $wantTag;
            } else {
                my $tagName = GetTagName($tag);
                my $bestTag = $bestTag{$tagName};
                if (defined $bestTag) {
                    next if $wantTag > $groupTags{$bestTag};
                    if ($wantTag == $groupTags{$bestTag}) {
                        # want two tags with the same name -- keep the latest one
                        if ($tag =~ / \((\d+)\)$/) {
                            my $tagNum = $1;
                            next if $bestTag !~ / \((\d+)\)$/ or $1 > $tagNum;
                        }
                    }
                    # this tag is better, so delete old best tag
                    delete $groupTags{$bestTag};
                }
                $groupTags{$tag} = $wantTag;    # keep this tag (for now...)
                $bestTag{$tagName} = $tag;      # this is our current best tag
            }
        }
        my @tags = keys %groupTags;
        $rtnTags = \@tags;
    } elsif (not @$reqTags) {
        # no requested tags, so we want all tags
        if ($duplicates) {
            @allTags = keys %{$self->{PRINT_CONV}};
        } else {
            foreach (keys %{$self->{PRINT_CONV}}) {
                # only include tag if it doesn't end in a copy number
                / \(\d+\)$/ or push @allTags, $_;
            }
        }
        $rtnTags = \@allTags;
    }

    # exclude specified tags if requested
    if ($rtnTags and $options->{Exclude}) {
        my $exclude = $options->{Exclude};
        my @filteredTags;
        foreach $tag (@$rtnTags) {
            my $tagName = GetTagName($tag);
            next if grep /^$tagName$/i, @$exclude;
            push @filteredTags, $tag;
        }
        $rtnTags = \@filteredTags;      # use new filtered tag list
    }

    # only return requested tags if specified
    if (@$reqTags) {
        $rtnTags or $rtnTags = [ ];
        # scan through the requested tags and generate a list of tags we found
        my $tagHash = $self->{PRINT_CONV};
        foreach $tag (@$reqTags) {
            my @matches;
            if (defined $tagHash->{$tag} and not $duplicates) {
                $matches[0] = $tag;
            } else {
                # do case-insensitive check
                if ($duplicates) {
                    # must also look for tags like "Tag (1)"
                    @matches = sort grep(/^$tag(\s|$)/i, keys %$tagHash);
                } else {
                    # find first matching value
                    # (use in list context to return value instead of count)
                    ($matches[0]) = grep /^$tag$/i, keys %$tagHash;
                    defined $matches[0] or undef @matches;
                }
                unless (@matches) {
                    # put entry in return list even without value (value is undef)
                    $matches[0] = $tag;
                    # bogus file order entry to avoid warning if sorting in file order
                    $self->{FILE_ORDER}->{$tag} = 999;
                }
            }
            push @$rtnTags, @matches;
        }
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
# Inputs: 0) ExifTool object reference, 1) warning message
sub Warn($$)
{
    $_[0]->FoundTag('Warning', $_[1]);
}

#------------------------------------------------------------------------------
# Add error tag
# Inputs: 0) ExifTool object reference, 1) error message
sub Error($$)
{
    $_[0]->FoundTag('Error', $_[1]);
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
EXPAND_TAG:
    foreach $entry (@$tagList) {
        ($tag = $entry) =~ s/^-//;  # remove leading '-'
        foreach (keys %Image::ExifTool::Shortcuts::Main) {
            /^\Q$tag\E$/i or next;
            if ($tag eq $entry) {
                push @expandedTags, @{$Image::ExifTool::Shortcuts::Main{$_}};
            } else {
                # entry starts with '-', so exclude all tags in this shortcut
                foreach (@{$Image::ExifTool::Shortcuts::Main{$_}}) {
                    /^-/ and next;  # ignore excluded exclude tags
                    push @expandedTags, "-$_";
                }
            }
            next EXPAND_TAG;
        }
        push @expandedTags, $entry;
    }
    @$tagList = @expandedTags;
}

#------------------------------------------------------------------------------
# Add hash of composite tags to our composites
# Inputs: 0) reference to hash of composite tags
sub AddCompositeTags($)
{
    local $_;
    my $add = shift;
    my $defaultGroups = $$add{GROUPS};

    # make sure default groups are defined in families 0 and 1
    if ($defaultGroups) {
        $defaultGroups->{0} or $defaultGroups->{0} = 'Composite';
        $defaultGroups->{1} or $defaultGroups->{1} = 'Composite';
    } else {
        $defaultGroups = $$add{GROUPS} = { 0 => 'Composite', 1 => 'Composite' };
    }
    SetupTagTable($add);

    my $tag;
    foreach $tag (keys %$add) {
        next if $specialTags{$tag}; # must skip special tags
        # ignore duplicate composite tags
        next if $Image::ExifTool::compositeTags{$tag};
        # add this composite tag to our main composite table
        my $tagInfo = $$add{$tag};
        $Image::ExifTool::compositeTags{$tag} = $tagInfo;
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
                $$tagInfo{Name} = $tag;
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
sub IsFloat($) {
    return scalar($_[0] =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/);
}
sub IsInt($)   { return scalar($_[0] =~ /^[+-]?\d+$/); }

#------------------------------------------------------------------------------
# Utility to convert a string to a to floating point number
# Inputs: 0) string;  Returns: floating point value (or undef if no float found)
sub ToFloat($)
{
    my $val = shift;
    return undef unless defined $val;
    return $val if IsFloat($val);
    # extract the first float we find
    return $& if $val =~ /([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?/;
    return undef;
}

#------------------------------------------------------------------------------
# Utility routines to for reading binary data values from file

my $swapBytes;               # set if EXIF header is not native byte ordering
my $currentByteOrder = 'MM'; # current byte ordering ('II' or 'MM')
my %unpackMotorola = ( S => 'n', L => 'N', C => 'C', c => 'c' );
my %unpackIntel    = ( S => 'v', L => 'V', C => 'C', c => 'c' );
my %unpackStd = %unpackMotorola;

# Unpack value, letting unpack() handle byte swapping
# Inputs: 0) unpack template, 1) data reference, 2) offset (default 0)
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
# Inputs: 0) # bytes, 1) unpack template, 2) data reference, 3) offset (default 0)
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

# Swap bytes in data if necessary
# Inputs: 0) data
# Returns: swapped data
sub SwapBytes($$)
{
    return $_[0] unless $swapBytes;
    my ($val, $bytes) = @_;
    my $newVal = '';
    $newVal .= substr($val, $bytes, 1) while $bytes--;
    return $newVal;
}

# Inputs: 0) data reference, 1) offset into data
sub Get8s($$)     { return DoUnpackStd('c', @_); }
sub Get8u($$)     { return DoUnpackStd('C', @_); }
sub Get16s($$)    { return DoUnpack(2, 's', @_); }
sub Get16u($$)    { return DoUnpackStd('S', @_); }
sub Get32s($$)    { return DoUnpack(4, 'l', @_); }
sub Get32u($$)    { return DoUnpackStd('L', @_); }
sub GetFloat($$)  { return DoUnpack(4, 'f', @_); }
sub GetDouble($$) { return DoUnpack(8, 'd', @_); }

sub GetRational16s($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get16s($dataPt, $pos + 2) or return 'inf';
    return sprintf("%.6g",Get16s($dataPt,$pos)/$denom);
}
sub GetRational16u($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get16u($dataPt, $pos + 2) or return 'inf';
    return sprintf("%.6g",Get16u($dataPt,$pos)/$denom);
}
sub GetRational32s($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get32s($dataPt, $pos + 4) or return 'inf';
    return sprintf("%.6g",Get32s($dataPt,$pos)/$denom);
}
sub GetRational32u($$)
{
    my ($dataPt, $pos) = @_;
    my $denom = Get32u($dataPt, $pos + 4) or return 'inf';
    return sprintf("%.6g",Get32u($dataPt,$pos)/$denom);
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
    # swap bytes if our native CPU byte ordering is not the same as the EXIF
    $swapBytes = ($order ne $nativeOrder);
    $currentByteOrder = $order;  # save current byte order

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
    rational16s => 4,
    rational16u => 4,
    rational32s => 8,
    rational32u => 8,
    fixed16s => 2,
    fixed16u => 2,
    fixed32s => 4,
    fixed32u => 4,
    float => 4,
    double => 8,
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
    rational16s => \&GetRational16s,
    rational16u => \&GetRational16u,
    rational32s => \&GetRational32s,
    rational32u => \&GetRational32u,
    fixed16s => \&GetFixed16s,
    fixed16u => \&GetFixed16u,
    fixed32s => \&GetFixed32s,
    fixed32u => \&GetFixed32u,
    float => \&GetFloat,
    double => \&GetDouble,
    ifd => \&Get32u,
);
sub FormatSize($) { return $formatSize{$_[0]}; }

#------------------------------------------------------------------------------
# read value from binary data (with current byte ordering)
# Inputs: 1) data reference, 2) value offset, 3) format string,
#         4) number of values (or undef to use all data)
#         5) valid data length relative to offset
# Returns: converted value, or undefined if data isn't there
sub ReadValue($$$$$)
{
    my ($dataPt, $offset, $format, $count, $size) = @_;

    my $len = $formatSize{$format};
    unless ($len) {
        warn "Unknown format $format";
        $len = 1;
    }
    $count = int($size / $len) unless defined $count;
    # make sure entry is inside data
    if ($len * $count > $size) {
        $count = int($size / $len);     # shorten count if necessary
        $count < 1 and return undef;    # return undefined if no data
    }
    my $val;
    my $proc = $readValueProc{$format};
    if ($proc) {
        $val = '';
        for (;;) {
            $val .= &$proc($dataPt, $offset);
            last if --$count <= 0;
            $offset += $len;
            $val .= ' ';
        }
    } else {
        # treat as binary/string if no proc
        $val = substr($$dataPt, $offset, $count);
        # truncate string at null terminator if necessary
        $val =~ s/\0.*//s if $format eq 'string';
    }
    return $val;
}

#------------------------------------------------------------------------------
# Validate an extracted image and repair if necessary
# Inputs: 0) ExifTool object reference, 1) image reference,
#         2) optional tag name (defaults to 'PreviewImage')
# Returns: image reference or undef if it wasn't valid
sub ValidateImage($$$)
{
    my ($self, $imagePt, $tag) = @_;
    return undef if $$imagePt eq 'none';
    unless ($$imagePt =~ /^(Binary data|\xff\xd8)/ or
            # the first byte of the preview of some Minolta cameras is wrong,
            # so check for this and set it back to 0xff if necessary
            $$imagePt =~ s/^.\xd8\xff\xdb/\xff\xd8\xff\xdb/ or
            $self->Options('IgnoreMinorErrors'))
    {
        # issue warning only if the tag was specifically requested
        $tag or $tag = 'PreviewImage';
        if ($self->{REQ_TAG_LOOKUP}->{lc($tag)}) {
            $self->Warn("$tag is not a valid image");
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
    # put a space between lower-UPPER case combinations
    $desc =~ s/([a-z])([A-Z\d])/$1 $2/g;
    # put a space between acronyms and words
    $desc =~ s/([A-Z])([A-Z][a-z])/$1 $2/g;
    # put spaces after numbers
    $desc =~ s/(\d)([A-Z])/$1 $2/g;
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
    if ($dateFormat and $date =~ /^(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)/) {
        if (eval 'require POSIX') {
            $date = POSIX::strftime($dateFormat, $6, $5, $4, $3, $2-1, $1-1900);
        }
    }
    return $date;
}

#------------------------------------------------------------------------------
# Convert Unix time to EXIF date/time string
# Inputs: 0) Unix time value, 1) non-zero to use GMT instead of local time
# Returns: EXIF date/time string
sub ConvertUnixTime($;$)
{
    my $time = shift;
    my @tm = shift() ? gmtime($time) : localtime($time);
    return sprintf("%4d:%.2d:%.2d %.2d:%.2d:%.2d", $tm[5]+1900, $tm[4]+1,
                   $tm[3], $tm[2], $tm[1], $tm[0]);
}

#------------------------------------------------------------------------------
# Get Unix time from EXIF-formatted date/time string
# Inputs: 0) EXIF date/time string, 1) non-zero to use GMT instead of local time
# Returns: Unix time or undefined on error
sub GetUnixTime($;$)
{
    my $timeStr = shift;
    my @tm = ($timeStr =~ /^(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)/);
    return undef unless @tm == 6;
    return undef unless eval 'require Time::Local';
    $tm[0] -= 1900;     # convert year
    $tm[1] -= 1;        # convert month
    @tm = reverse @tm;  # change to order required by timelocal()
    return shift() ? Time::Local::timegm(@tm) : Time::Local::timelocal(@tm);
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
# JpegInfo : extract EXIF information from a jpg image
# Inputs: 0) ExifTool object reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG file
sub JpegInfo($)
{
    my $self = shift;
    my ($ch,$s,$length);
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $raf = $self->{RAF};
    my $icc_profile;
    my $rtnVal = 0;
    my $wantPreview;
    my %dumpParms;

    # check to be sure this is a valid JPG file
    return 0 unless $raf->Read($s,2) == 2 and $s eq "\xff\xd8";
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
            $verbose and print "JPEG $markerName:\n";
            # get the image size;
            my ($h, $w) = unpack('n'x2, substr($$segDataPt, 3));
            $self->FoundTag('ImageWidth', $w);
            $self->FoundTag('ImageHeight', $h);
            next;
        } elsif ($marker == 0xd9) {         # EOI
            $verbose and print "JPEG EOI\n";
            $rtnVal = 1;
            my $buff;
            $raf->Read($buff, 2) == 2 or last;
            if ($buff eq "\xff\xd8") {
                # adjust PreviewImageStart to this location
                my $start = $self->{PRINT_CONV}->{PreviewImageStart};
                if ($start) {
                    my $actual = $raf->Tell() - 2;
                    if ($start ne $actual) {
                        $verbose>1 and print "(Fixed PreviewImage location: $start -> $actual)\n";
                        $self->{PRINT_CONV}->{PreviewImageStart} = $actual;
                        $self->{VALUE_CONV}->{PreviewImageStart} = $actual;
                    }
                }
            }
            last;   # all done parsing file
        } elsif ($marker == 0xda) {         # SOS
            if ($wantPreview) {
                $verbose and print "JPEG SOS (continue parsing for PreviewImage)\n";
                next;
            } else {
                $verbose and print "JPEG SOS (end of parsing)\n";
            }
            # nothing interesting to parse after start of scan (SOS)
            $rtnVal = 1;
            last;   # all done parsing file
        } elsif ($marker==0x00 or $marker==0x01 or ($marker>=0xd0 and $marker<=0xd7)) {
            # handle stand-alone markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            $verbose and $marker and print "JPEG $markerName:\n";
            next;
        }
        # handle all other markers
        $length = length($$segDataPt);
        if ($verbose) {
            print "JPEG $markerName ($length bytes):\n";
            if ($verbose > 2) {
                my %extraParms;
                $extraParms{MaxLen} = 128 if $verbose == 4;
                HexDump($segDataPt, undef, %dumpParms, %extraParms);
            }
        }
        if ($marker == 0xe1) {             # APP1 (EXIF, XMP)
            if ($$segDataPt =~ /^Exif\0/) { # (some Kodak cameras don't put a second \0)
                # this is EXIF data --
                # get the data block (into a common variable)
                my $hdrLen = length($exifAPP1hdr);
                $self->{EXIF_DATA} = substr($$segDataPt, $hdrLen);
                $self->{EXIF_POS} = $segPos + $hdrLen;
                # extract the EXIF information (it is in standard TIFF format)
                $self->TiffInfo($markerName, undef, $segPos+$hdrLen);
                # avoid looking for preview unless necessary because it really slows
                # us down -- only look for it if we found pointer, and preview is
                # outside EXIF, and PreviewImage is specifically requested
                if ($self->{PRINT_CONV}->{PreviewImageStart} and
                    $self->{PRINT_CONV}->{PreviewImageLength} and
                    $self->{PRINT_CONV}->{PreviewImageStart} +
                    $self->{PRINT_CONV}->{PreviewImageLength} >
                    $self->{EXIF_POS} + length($self->{EXIF_DATA}) and
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
                    $processed = $self->ProcessTagTable($tagTablePtr, \%dirInfo);
                }
                if ($verbose and not $processed) {
                    $self->Warn("Ignored EXIF block length $length (bad header)");
                }
            }
        } elsif ($marker == 0xe2) {        # APP2 (ICC Profile)
            if ($$segDataPt =~ /^ICC_PROFILE\0/) {
                # must concatinate blocks of profile
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
                        $self->ProcessTagTable($tagTablePtr, \%dirInfo);
                        undef $icc_profile;
                    }
                }
            }
        } elsif ($marker == 0xe3) {         # APP3 (other EXIF info)
            if ($$segDataPt =~ /^(Exif|Meta|META)\0\0/) {
                $self->{EXIF_DATA} = substr($$segDataPt, 6);
                $self->{EXIF_POS} = $segPos + 6;
                $self->TiffInfo($markerName,undef,$segPos+6);
            }
        } elsif ($marker == 0xec) {         # APP12 (ASCII meta information)
            my @lines = split /[\x0d\x0a]+/, $$segDataPt;
            my $tagTablePtr = GetTagTable('Image::ExifTool::APP12');
            foreach (@lines) {
                /(\w+)=(.+)/ or next;
                my ($tag, $val) = ($1, $2);
                my $tagInfo = $self->GetTagInfo($tagTablePtr, $tag);
                unless ($tagInfo) {
                    $tagInfo = { Name => $tag };
                    AddTagToTable($tagTablePtr, $tag, $tagInfo);
                }
                $self->FoundTag($tagInfo, $val);
            }
        } elsif ($marker == 0xed) {         # APP13 (Photoshop)
            if ($$segDataPt =~ /^$psAPP13hdr/) {
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
                # process Photoshop APP13 record
                my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                my %dirInfo = (
                    DataPt   => $segDataPt,
                    DataPos  => $segPos,
                    DataLen  => $length,
                    DirStart => 14,     # directory starts after identifier
                    DirLen   => $length-14,
                    Parent   => $markerName,
                );
                $self->ProcessTagTable($tagTablePtr, \%dirInfo);
                undef $combinedSegData;
            } elsif ($$segDataPt =~ /^\x1c\x02/) {
                # this is written in IPTC format by photoshop, but is
                # all messed up, so we ignore it
            } else {
                $self->Warn('Unknown APP13 data');
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
# get GIF size and comments (no EXIF blocks in GIF files though)
# Inputs: 0) ExifTool object reference, 1) Optional output file or scalar reference
# Returns: 1 on success, 0 if this wasn't a valid GIF file, or -1 if
#          an output file was specified and a write error occurred
sub GifInfo($;$)
{
    my ($self, $outfile) = @_;
    my ($type, $a, $s, $ch, $length, $buff);
    my $raf = $self->{RAF};
    my $rtnVal = 0;
    my $verbose = $self->{Options}->{Verbose};
    my ($err, $newComment, $setComment);

    # verify this is a valid GIF file
    # (must do a RAF read until we know the file is ours)
    return 0 unless $self->{RAF}->Read($type, 6) == 6
        and $type =~ /^GIF8[79]a$/
        and $self->{RAF}->Read($s, 4) == 4;

    $verbose and print "GIF file version $type\n";
    if ($outfile) {
        Write($outfile, $type, $s) or $err = 1;
        if ($self->{DEL_GROUP} and $self->{DEL_GROUP}->{File}) {
            $setComment = 1;
        } else {
            my $newValueHash;
            $newComment = $self->GetNewValues('Comment', \$newValueHash);
            $setComment = 1 if $newValueHash;
        }
    }
    $self->FoundTag('FileType','GIF');     # set file type
    my ($w, $h) = unpack("v"x2, $s);
    $self->FoundTag('ImageWidth', $w);
    $self->FoundTag('ImageHeight', $h);
    if ($raf->Read($s, 3) == 3) {
        Write($outfile, $s) or $err = 1 if $outfile;
        if (ord($s) & 0x80) { # does this image contain a color table?
            # calculate color table size
            $length = 3 * (2 << (ord($s) & 0x07));
            $raf->Read($buff, $length) == $length or return 0; # skip color table
            Write($outfile, $buff) or $err = 1 if $outfile;
            # write the comment first if necessary
            if ($outfile and defined $newComment) {
                if ($type ne 'GIF87a') {
                    # write comment marker
                    Write($outfile, "\x21\xfe") or $err = 1;
                    my $len = length($newComment);
                    # write out the comment in 255-byte chunks, each
                    # chunk beginning with a length byte
                    my $n;
                    for ($n=0; $n<$len; $n+=255) {
                        my $size = $len - $n;
                        $size > 255 and $size = 255;
                        my $str = substr($newComment,$n,$size);
                        Write($outfile, pack('C',$size), $str) or $err = 1;
                    }
                    Write($outfile, "\0") or $err = 1;  # empty chunk as terminator
                    undef $newComment;
                    ++$self->{CHANGED};     # increment file changed flag
                } else {
                    $self->Warn("The GIF87a format doesn't support comments");
                }
            }
            my $comment;
            for (;;) {
                last unless $raf->Read($ch, 1);
                if (ord($ch) == 0x2c) {
                    Write($outfile, $ch) or $err = 1 if $outfile;
                    # image descriptor
                    last unless $raf->Read($buff, 8) == 8;
                    last unless $raf->Read($ch, 1);
                    Write($outfile, $buff, $ch) or $err = 1 if $outfile;
                    if (ord($ch) & 0x80) { # does color table exist?
                        $length = 3 * (2 << (ord($ch) & 0x07));
                        # skip the color table
                        last unless $raf->Read($buff, $length) == $length;
                        Write($outfile, $buff) or $err = 1 if $outfile;
                    }
                    # skip "LZW Minimum Code Size" byte
                    last unless $raf->Read($buff, 1);
                    Write($outfile,$buff) or $err = 1 if $outfile;
                    # skip image blocks
                    for (;;) {
                        last unless $raf->Read($ch, 1);
                        Write($outfile, $ch) or $err = 1 if $outfile;
                        last unless ord($ch);
                        last unless $raf->Read($buff, ord($ch));
                        Write($outfile,$buff) or $err = 1 if $outfile;
                    }
                    next;  # continue with next field
                }
#               last if ord($ch) == 0x3b;  # normal end of GIF marker
                unless (ord($ch) == 0x21) {
                    if ($outfile) {
                        Write($outfile, $ch) or $err = 1;
                        # copy the rest of the file
                        while ($raf->Read($buff, 65536)) {
                            Write($outfile, $buff) or $err = 1;
                        }
                    }
                    $rtnVal = 1;
                    last;
                }
                # get extension block type/size
                last unless $raf->Read($s, 2) == 2;
                # get marker and block size
                ($a,$length) = unpack("C"x2, $s);
                if ($a == 0xfe) {  # is this a comment?
                    if ($setComment) {
                        ++$self->{CHANGED};     # increment the changed flag
                    } else {
                        Write($outfile, $ch, $s) or $err = 1 if $outfile;
                    }
                    while ($length) {
                        last unless $raf->Read($buff, $length) == $length;
                        $self->{OPTIONS}->{Verbose} > 2 and HexDump(\$buff);
                        if (defined $comment) {
                            $comment .= $buff;  # add to comment string
                        } else {
                            $comment = $buff;
                        }
                        last unless $raf->Read($ch, 1);  # read next block header
                        unless ($setComment) {
                            Write($outfile, $buff, $ch) or $err = 1 if $outfile;
                        }
                        $length = ord($ch);  # get next block size
                    }
                    last if $length;    # was a read error if length isn't zero
                    # all done once we have found the comment unless writing file
                    unless ($outfile) {
                        $rtnVal = 1;
                        last;
                    }
                } else {
                    Write($outfile, $ch, $s) or $err = 1 if $outfile;
                    # skip the block
                    while ($length) {
                        last unless $raf->Read($buff, $length) == $length;
                        Write($outfile, $buff) or $err = 1 if $outfile;
                        last unless $raf->Read($ch, 1);  # read next block header
                        Write($outfile, $ch) or $err = 1 if $outfile;
                        $length = ord($ch);  # get next block size
                    }
                }
            }
            $self->FoundTag('Comment', $comment) if $comment;
        }
    }
    # set return value to -1 if we only had a write error
    $rtnVal = -1 if $rtnVal and $err;
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Process TIFF data
# Inputs: 0) ExifTool object reference,
#         1) file type or directory name
#         2) RAF pointer if we must read the data ourself
#         3) base offset to start of TIFF inside file if no RAF specfied
#         4) Optional output file
# Returns: 1 if this looked like a valid EXIF block, 0 otherwise
sub TiffInfo($$;$$$)
{
    my ($self, $fileType, $raf, $base, $outfile) = @_;
    my $dataPt = \$self->{EXIF_DATA};
    my ($length, $err);

    $base = 0 unless defined $base;

    # read the image file header and offset to 0th IFD if necessary
    if ($raf) {
        $self->{EXIF_POS} = $base;
        if ($outfile) {
            $raf->Seek(0, 0) or return 0;
            if ($base) {
                $raf->Read($$dataPt,$base) == $base or return 0;
                Write($outfile, $$dataPt) or $err = 1;
            }
        } else {
            $raf->Seek($base, 0) or return 0;
        }
        $raf->Read($$dataPt,8) == 8 or return 0;
    }
    # set byte ordering
    SetByteOrder(substr($$dataPt,0,2)) or return 0;
    # save EXIF byte ordering
    $self->{EXIF_BYTE_ORDER} = GetByteOrder();

    # verify the byte ordering
  # no longer do this because ORF files use different values
  #  my $identifier = Get16u($dataPt, 2);
    # identifier is 0x2a for TIFF and 0x4f52 or 0x5352 or ?? for ORF
  #  return 0 unless $identifier == 0x2a;

    # get offset to IFD0
    my $offset = Get32u($dataPt, 4);
    $offset >= 8 or return 0;
    if ($raf) {
        # we have a valid TIFF (or whatever) file
        $self->FoundTag('FileType', $fileType);
        $length = 8;    # read 8 bytes so far
    } else {
        # no RAF pointer, so get length from data
        $length = length $$dataPt;
    }
    # remember where we found the TIFF data (APP1, APP3, TIFF, NEF, etc...)
    $self->{TIFF_TYPE} = $fileType;

    # get reference to the main EXIF table
    my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');

    # build directory information hash
    my %dirInfo = (
        Base     => $base,
        DataPt   => $dataPt,
        DataLen  => $length,
        DataPos  => 0,
        DirStart => $offset,
        DirLen   => $length,
        RAF      => $raf,
        Multi    => 1,
        DirName  => 'IFD0',
        Parent   => $fileType,
    );
    if ($outfile) {
        if ($offset == 16 and not $self->Options('IgnoreMinorErrors')) {
            $self->Warn("Possibly a Canon RAW file; may lose RAW data if rewritten");
            return -1;
        }
        # write TIFF header (8 bytes to be immediately followed by IFD)
        my $header = substr($$dataPt, 0, 4) . Set32u(8);
        $dirInfo{NewDataPos} = 8;
        my $newData = $self->WriteTagTable($tagTablePtr, \%dirInfo);
        return 0 unless defined $newData;
        Write($outfile, $header, $newData) or $err = 1 if length($newData);
        return $err ? -1 : 1;
    }
    # process the directory
    $self->ProcessTagTable($tagTablePtr, \%dirInfo);

    return 1;
}

#------------------------------------------------------------------------------
# Load .ExifTool_config file from user's home directory
# Returns: true if config file existed
my $configLoaded;
sub LoadConfig()
{
    unless (defined $configLoaded) {
        $configLoaded = 0;
        # load config file if it exists
        my $configFile = ($ENV{HOME} || '.') . '/.ExifTool_config';
        -r $configFile and eval("require '$configFile'"), ++$configLoaded;
    }
    return $configLoaded;
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
        # save all descriptions in the new table
        SetupTagTable($table);
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
# Process specified tag table
# Inputs: 0) ExifTool object reference
#         1) tag table reference
#         2) directory information reference
#         3) optional reference to processing procedure
# Returns: Result from processing (1=success)
sub ProcessTagTable($$$;$)
{
    my ($self, $tagTablePtr, $dirInfo, $processProc) = @_;

    return 0 unless $tagTablePtr and $dirInfo;
    # use default proc from tag table if no proc specified
    $processProc or $processProc = $$tagTablePtr{PROCESS_PROC};
    # set directory name from default group0 name if not done already
    $dirInfo->{DirName} or $dirInfo->{DirName} = $tagTablePtr->{GROUPS}->{0};
    # guard against cyclical recursion into the same directory
    if (defined $dirInfo->{DirStart} and defined $dirInfo->{DataPos}) {
        my $processed = $dirInfo->{DirStart} + $dirInfo->{DataPos} + ($dirInfo->{Base}||0);
        if ($self->{PROCESSED}->{$processed}) {
            $self->Warn("$$dirInfo{DirName} pointer references previous $self->{PROCESSED}->{$processed} directory");
            return 0;
        } else {
            $self->{PROCESSED}->{$processed} = $dirInfo->{DirName};
        }
    }
    # otherwise process as an EXIF directory
    $processProc or $processProc = \&Image::ExifTool::Exif::ProcessExif;
    my $oldIndent = $self->{INDENT};
    my $oldDir = $self->{DIR_NAME};
    $self->{INDENT} .= '| ';
    $self->{DIR_NAME} = $dirInfo->{DirName};
    my $rtnVal = &$processProc($self, $tagTablePtr, $dirInfo);
    $self->{INDENT} = $oldIndent;
    $self->{DIR_NAME} = $oldDir;
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
# Return special tag
# Inputs: 0) Tag name
sub GetSpecialTag($)
{
    return $specialTags{$_[0]};
}

#------------------------------------------------------------------------------
# Get list of tag information hashes for given tag ID
# Inputs: 0) Tag table reference, 1) tag ID
# Returns: Array of tag information references
# Notes: Generates tagInfo hash if necessary
sub GetTagInfoList($$)
{
    my $tagTablePtr = shift;
    my $tagID = shift;
    my $tagInfo = $$tagTablePtr{$tagID};

    my @infoArray;
    if (ref $tagInfo eq 'ARRAY') {
        @infoArray = @$tagInfo;
    } elsif ($tagInfo) {
        if (ref $tagInfo ne 'HASH') {
            # create hash with name
            $tagInfo = $$tagTablePtr{$tagID} = { Name => $tagInfo };
        }
        push @infoArray, $tagInfo;
    }
    return @infoArray;
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
            my $oldVal = $self->{VALUE_CONV}->{$$tagInfo{Name}};
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
    $$tagInfo{Groups} or $$tagInfo{Groups} = $$tagTablePtr{GROUPS};
    $$tagInfo{GotGroups} = 1,
    $$tagInfo{Table} = $tagTablePtr;
    $$tagInfo{TagID} = $tagID if $didTagID;
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
# found specified tag
# Inputs: 0) reference to ExifTool object
#         1) reference to tagInfo hash or tag name
#         2) data value (may be undefined if building composite tag)
#         3) optional reference to list of values used to build composite tags
#         4) optional reference to list of print values for composite tags
# Returns: tag key or undef if no value
sub FoundTag($$$$;$$)
{
    local $_;
    my ($self, $tagInfo, $val, $valListPt, $valPrintPt) = @_;
    my ($tag, @val, @valPrint);

    if (ref($tagInfo) eq 'HASH') {
        $tag = $$tagInfo{Name} or warn("No tag name\n"), return undef;
    } else {
        $tag = $tagInfo;
        # look for tag in extraTags
        $tagInfo = $self->GetTagInfo(GetTagTable('Image::ExifTool::extraTags'), $tag);
        # make temporary hash if tag doesn't exist in extraTags
        # (not advised to do this since the tag won't show in list)
        $tagInfo or $tagInfo = { Name => $tag, Groups => \%allGroupsExifTool };
        $self->{OPTIONS}->{Verbose} and $self->VerboseInfo(undef, $tagInfo, Value => $val);
    }
    # initialize arrays used to build composite tags if necessary
    if ($valListPt) {
        @val = @$valListPt;
        @valPrint = @$valPrintPt;
    }
    # convert the value into a usable form
    # (always do this conversion even if we don't want to return
    #  the value because the conversion may have side-effects)
    my $valueConv;
    if ($$tagInfo{ValueConv}) {
        my $valueConversion = $$tagInfo{ValueConv};
        if (ref($valueConversion) eq 'HASH') {
            $valueConv = $$valueConversion{$val};
            defined $valueConv or $valueConv = "Unknown ($val)";
        } else {
            #### eval ValueConv ($val, $self, @val, @valPrint)
            $valueConv = eval $valueConversion;
            $@ and warn "ValueConv $tag: $@";
            # treat it as if the tag doesn't exist if ValueConv returns undef
            return undef unless defined $valueConv;
            # WARNING: $valueConv may now be a reference to $val
        }
    } elsif (defined $val) {
        $valueConv = $val;
    } else {
        # this is a composite tag that could not be calculated
        $self->{OPTIONS}->{Verbose} and warn "Can't get value for $tag\n";
        return undef;
    }
    # do the print conversion if required (and if not a binary value)
    my $printConv;
    if ($self->{OPTIONS}->{PrintConv}) {
        my $printConversion = $$tagInfo{PrintConv};
        unless (defined $printConversion) {
            my $tagTablePtr = $$tagInfo{Table};
            $printConversion = $$tagTablePtr{PRINT_CONV};
        }
        if (defined $printConversion and ref($valueConv) ne 'SCALAR') {
            $val = $valueConv;
            if (ref($printConversion) eq 'HASH') {
                $printConv = $$printConversion{$val};
                unless (defined $printConv) {
                    $$tagInfo{PrintHex} and $val and $val = sprintf('0x%x',$val);
                    $printConv = "Unknown ($val)";
                }
            } else {
                local $SIG{__WARN__} = sub { $evalWarning = $_[0]; };
                undef $evalWarning;
                #### eval PrintConv ($val, $self, @val, @valPrint)
                $printConv = eval $printConversion;
                if ($@ or $evalWarning) {
                    $@ and $evalWarning = $@;
                    chomp $evalWarning;
                    $evalWarning =~ s/ at \(eval .*//s;
                    delete $SIG{__WARN__};
                    warn "PrintConv $tag: $evalWarning\n";
                }
                $printConv = 'Undefined' unless defined $printConv;
                # WARNING: do not change $val after this (because $printConv
                # could be a reference to $val for binary data types)
            }
        } else {
            $printConv = $valueConv;
        }
    } else {
        $printConv = $valueConv;
    }
    # handle duplicate tag names
    if (defined $self->{PRINT_CONV}->{$tag}) {
        my $valueConvHash = $self->{VALUE_CONV};
        my $printConvHash = $self->{PRINT_CONV};
        if ($$tagInfo{List} and $tagInfo eq $self->{TAG_INFO}->{$tag} and
            not $self->{NO_LIST})
        {
            # make lists from adjacent tags with the same information:
            # PrintConv: a comma separated list unless 'List' option set
            if ($self->{OPTIONS}->{List}) {
                if (ref $printConvHash->{$tag} ne 'ARRAY') {
                    $printConvHash->{$tag} = [ $printConvHash->{$tag} ];
                }
                push @{$printConvHash->{$tag}}, $printConv;
            } else {
                $printConvHash->{$tag} .= ", $printConv";
            }
            # ValueConv: a reference to an array of values
            if (ref $valueConvHash->{$tag} ne 'ARRAY') {
                $valueConvHash->{$tag} = [ $valueConvHash->{$tag} ];
            }
            push @{$valueConvHash->{$tag}}, $valueConv;
            return $tag;    # return without creating a new entry
        } else {
            # rename existing tag to make room for duplicate values
            my $nextTag;  # next available copy number for this tag
            my $i;
            for ($i=1; ; ++$i) {
                $nextTag = "$tag ($i)";
                last unless exists $printConvHash->{$nextTag};
            }
            # take tag with highest priority
            my $priority = $$tagInfo{Priority};
            if (defined $priority) {
                # increase priority for zero priority tags if this is the priority dir
                $priority = 1 if $priority == 0 and $self->{DIR_NAME} and
                    $self->{PRIORITY_DIR} and $self->{DIR_NAME} eq $self->{PRIORITY_DIR};
                my $oldPriority = $self->{PRIORITY}->{$tag} || 1;
                if ($priority >= $oldPriority) {
                    $self->{PRIORITY}->{$tag} = $priority;
                } else {
                    $priority = 0;  # existing tag takes priority
                }
            } elsif ($self->{PRIORITY}->{$tag}) {
                $priority = 0;      # existing tag takes priority
            } else {
                $priority = 1;      # this tag takes priority
            }
            if ($priority) {
                # change the name of existing tags in all hashes
                $valueConvHash->{$nextTag} = $valueConvHash->{$tag};
                $printConvHash->{$nextTag} = $printConvHash->{$tag};
                $self->{FILE_ORDER}->{$nextTag} = $self->{FILE_ORDER}->{$tag};
                $self->{TAG_INFO}->{$nextTag} = $self->{TAG_INFO}->{$tag};
                $self->{TAG_EXTRA}->{$nextTag} = $self->{TAG_EXTRA}->{$tag};
            } else {
                $tag = $nextTag;    # don't override the previous tag
            }
        }
    } elsif ($$tagInfo{Priority}) {
        # set tag priority
        $self->{PRIORITY}->{$tag} = $$tagInfo{Priority};
    }

    # save the converted values, file order, and tag groups
    $self->{VALUE_CONV}->{$tag} = $valueConv;
    $self->{PRINT_CONV}->{$tag} = $printConv;
    $self->{FILE_ORDER}->{$tag} = ++$self->{NUM_FOUND};
    $self->{TAG_INFO}->{$tag} = $tagInfo;

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
# set extra information specific to this tag instance
# Inputs: 0) reference to ExifTool object
#         1) tag key
#         2) extra information
sub SetTagExtra($$$)
{
    my ($self, $tagKey, $extra) = @_;
    $self->{TAG_EXTRA}->{$tagKey} = $extra;
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
    delete $self->{VALUE_CONV}->{$tag};
    delete $self->{PRINT_CONV}->{$tag};
    delete $self->{FILE_ORDER}->{$tag};
    delete $self->{TAG_INFO}->{$tag};
    delete $self->{TAG_EXTRA}->{$tag} if exists $self->{TAG_EXTRA}->{$tag};
}

#------------------------------------------------------------------------------
# Set the FileType tag
# Inputs: 0) ExifTool object reference
#         1) Optional file type (uses FILE_TYPE if not specified)
sub SetFileType()
{
    my ($self, $fileType) = @_;
    $self->FoundTag('FileType', $fileType || $self->{FILE_TYPE});
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
        and $self->{RAF}->Read($buff,$length) == $length)
    {
        $tag or $tag = 'binary data';
        $self->Warn("Error reading $tag from file");
        return undef;
    }
    return $buff;
}

#------------------------------------------------------------------------------
# process binary data
# Inputs: 0) ExifTool object reference, 1) tag table reference
#         2) directory information reference
# Returns: 1 on success
sub ProcessBinaryData($$$)
{
    my ($self, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $offset = $dirInfo->{DirStart};
    my $size = $dirInfo->{DirLen};
    my $base = $dirInfo->{Base} || 0;
    my $verbose = $self->{OPTIONS}->{Verbose};
    my $unknown = $self->{OPTIONS}->{Unknown};

    $verbose and $self->VerboseDir('BinaryData', undef, $size);

    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';
    my $increment = $formatSize{$defaultFormat};
    unless ($increment) {
        warn "Unknown format $defaultFormat\n";
        $defaultFormat = 'int8u';
        $increment = $formatSize{$defaultFormat};
    }
    # prepare list of tag number to extract
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
                #### eval Format size (%val, $size)
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

#------------------------------------------------------------------------------
1;  # end
