#------------------------------------------------------------------------------
# File:         BuildTagLookup.pm
#
# Description:  Utility to build tag lookup tables in Image::ExifTool::TagLookup.pm
#
# Revisions:    12/31/2004 - P. Harvey Created
#               02/15/2005 - PH Added ability to generate TagNames documentation
#
# Notes:        Documentation for the tag tables may either be placed in the
#               %docs hash below or in a NOTES entry in the table itself, and
#               individual tags may have their own Notes entry.
#------------------------------------------------------------------------------

package Image::ExifTool::BuildTagLookup;

use strict;
require Exporter;

BEGIN {
    # prevent ExifTool from loading the user config file
    $Image::ExifTool::noConfig = 1;
}

use vars qw($VERSION @ISA);
use Image::ExifTool qw(:Utils :Vars);
use Image::ExifTool::XMP qw(EscapeHTML);

$VERSION = '1.21';
@ISA = qw(Exporter);

sub NumbersFirst;

# colors for html pages
my $noteFont = '<font color="#666666">';
my $bgHeading = q{bgcolor='#ffbb77'};
my $bgBody = q{bgcolor='#ffffff'};
my $bgRow = q{bgcolor='#ffeebb'};

my $caseInsensitive;    # flag to ignore case when sorting tag names

# Descriptions for the TagNames documentation
# Note: POD headers in these descriptions start with '~' instead of '=' to keep
# from confusing POD parsers which apparently parse inside quoted strings.
my %docs = (
    PodHeader => q{
~head1 NAME

Image::ExifTool::TagNames - ExifTool tag name documentation

~head1 DESCRIPTION

This document contains a complete list of ExifTool tag names, organized into
tables based on information type.  Tag names are used to indicate the
specific meta information that is extracted or written in an image.

~head1 TAG TABLES
},
    ExifTool => q{
The tables listed below give the names of all tags recognized by ExifTool,
excluding shortcut and unknown tags.

A B<Tag ID> or B<Index> is given in the first column of each table.  A
B<Tag ID> is the computer-readable equivalent of a tag name, and is the
identifier that is actually stored in the file.  An B<Index> refers to the
location of the information, and is used if the information is stored at a
fixed position in a data block.

A B<Tag Name> is the handle by which the information is accessed.  In some
instances, more than one name may correspond to a single tag ID.  In these
cases, the actual name used depends on the context in which the information
is found.  Case is not significant for tag names.  A question mark after a
tag name indicates that the information is either not understood, not
verified, or not very useful -- these tags are not extracted by ExifTool
unless the Unknown (-u) option is enabled.  Be aware that some tag names are
different than the descriptions printed out by default when extracting
information with "exiftool".  To see the tag names instead of the
descriptions, use "exiftool -S".

The B<Writable> column indicates whether the tag is writable by ExifTool.
Anything but an "N" in this column means the tag is writable.  A "Y"
indicates writable information that is either unformatted or written using
the existing format.  Other expressions give details about the information
format, and vary depending on the general type of information.  The format
name may be followed by a number in square brackets to indicate the number
of values written, or the number of characters in a fixed-length string
(including a null terminator which is added if required).

An asterisk (C<*>) in the B<Writable> column indicates a 'protected' tag
which is not writable directly, but is set via a Composite tag.  A tilde
(C<~>) indicates a tag this is only writable when print conversion is
disabled (by setting PrintConv to 0, or using the -n option).  An
exclamation point (C<!>) indicates a tag that is considered unsafe to write
under normal circumstances.  These 'unsafe' tags are not set when calling
SetNewValuesFromFile() or when using the exiftool -TagsFromFile option, and
care should be taken when editing them manually since they may affect the
way an image is rendered.

The HTML version of this document also lists possible B<Values> for all tags
which have a discrete set of values, and gives B<Notes> for some tags.

B<Note>: If you are familiar with common meta-information tag names, you may
find that some ExifTool tag names are different than expected.  The usual
reason for this is to make the tag names more consistent across different
types of meta information.  To determine a tag name, either consult this
documentation or run "exiftool -S" on a file containing the information in
question.
},
    EXIF => q{
EXIF stands for 'Exchangeable Image File Format'.  This type of information
may be found in JPG, TIFF, PNG, MIFF and DNG images.

The EXIF meta information is organized into different Image File Directories
(IFD's) within an image.  The names of these IFD's correspond to the
ExifTool family 1 group names.  When writing EXIF information, the default
B<Group> listed below is used unless another group is specified.
},
    GPS => q{
These GPS tags are part of the EXIF standard, and are stored in a separate
IFD within the EXIF information.

ExifTool is very flexible about the input format for lat/long coordinates,
and will accept 3 floating point numbers (for degrees, minutes and seconds)
separated by just about anything.  Many other GPS tags have values which are
fixed-length strings.  For these, the indicated string lengths include a
null terminator which is added automatically by ExifTool.
},
    XMP => q{
XMP stands for 'Extensible Metadata Platform', an XML/RDF-based metadata
format which is being pushed by Adobe.  Information in this format can be
embedded in many different image file types including JPG, JP2, TIFF, PNG,
MIFF, PS, PDF, PSD and DNG.

The XMP B<Tag ID>'s aren't listed because in most cases they are identical
to the B<Tag Name>.

All XMP information is stored as character strings.  The B<Writable> column
specifies the information format:  C<integer> is a string of digits
(possibly beginning with a '+' or '-'), C<real> is a floating point number,
C<rational> is two C<integer> strings separated by a '/' character, C<date>
is a date/time string in the format 'YYYY:MM:DD HH:MM:SS[+/-HH:MM]',
C<boolean> is either 'True' or 'False', and C<lang-alt> is a list of string
alternatives in different languages. Currently, ExifTool only writes the
'x-default' language in C<lang-alt> lists.

The XMP tags are organized according to schema namespace in the following
tables. The table names correspond to the XMP namespace prefixes, which are
used to generate the family 1 group names by adding the prefix 'XMP-'.  If
the same XMP tag name exists in more than one group, all groups are written
unless a family 1 group name is specified. ie) If XMP:Contrast is specified,
information will be written to both XMP-crs:Contrast and XMP-exif:Contrast.

ExifTool will extract XMP information even if it is not listed in these
tables.  For example, the C<pdfx> namespace doesn't have a predefined set of
tag names because it is used to store application-defined PDF information,
but this information is extracted by ExifTool anyway.
},
    IPTC => q{
IPTC stands for 'International Press Telecommunications Council'.  This is
an older meta information format that is slowly being phased out in favor of
XMP. IPTC information may be embedded in JPG, TIFF, PNG, MIFF, PS, PDF, PSD
and DNG images.

The IPTC specification dictates a length for ASCII (C<string> or C<digits>)
values.  These lengths are given in square brackets after the B<Writable>
format name.  For tags where a range of lengths is allowed, the minimum and
maximum lengths are separated by a comma within the brackets.  IPTC strings
are not null terminated.

IPTC information is separated into different records, each of which has its
own set of tags.
},
    Photoshop => q{
Photoshop tags are found in PSD files, as well as inside embedded Photoshop
information in many other file types (JPEG, TIFF, PDF, PNG to name a few).

Many Photoshop tags are marked as Unknown (indicated by a question mark
after the tag name) because the information they provide is not very useful
under normal circumstances.  Unknown tags are not extracted unless the
Unknown (-u) option is used.
},
    PrintIM => q{
The format of the PrintIM information is known, however no PrintIM tags have
been decoded.  Use the Unknown (-u) option to extract PrintIM information.
},
    Kodak => q{
The Kodak maker notes aren't in standard IFD format, and the format varies
frequently with different models.  Some information has been decoded, but
much of the Kodak information remains unknown.
},
    'Kodak SpecialEffects' => q{
The Kodak SpecialEffects and Borders tags are found in sub-IFD's within
the Kodak "Meta" JPEG APP3 segment.
},
    Minolta => q{
These tags are used by Minolta and Konica/Minolta cameras.  Minolta doesn't
make things easy for decoders because the meaning of some tags and the
location where some information is stored is different for different camera
models.  (Take MinoltaQuality for example, which may be located in 3
different places.)
},
    Olympus => q{
Tags 0x0000 through 0x0103 are used by some older Olympus cameras, and are
the same as Konica/Minolta tags.  The Olympus tags are also used for Epson
and Agfa cameras.
},
    Panasonic => q{
Panasonic tags are also used for Leica cameras.
},
    Pentax => q{
The Pentax tags are also used in Asahi cameras.
},
    Sigma => q{
These tags are used in Sigma/Foveon cameras.
},
    Sony => q{
The maker notes in images from current Sony camera models contain a wealth
of information, but very little is known about these tags.  Use the ExifTool
Unknown (-u) or Verbose (-v) options to see information about the unknown
tags.
},
    CanonRaw => q{
These tags apply only to CRW-format Canon RAW files.  When writing CanonRaw
information, the length of the information is preserved (and the new
information is truncated or padded as required) unless B<Writable> is
C<resize>.  Currently, only JpgFromRaw and ThumbnailImage are allowed to
change size.
},
    Unknown => q{
The following tags are decoded in unsupported maker notes.  Use the Unknown
(-u) option to display other unknown tags.
},
    PDF => q{
The tags listed in the PDF tables below are those which are used by ExifTool
to extract meta information, but they are only a small fraction of the total
number of available PDF tags.
},
    APP12 => q{
The JPEG APP12 segment may contain ASCI-based meta information.  ExifTool
does not pre-define the names of these tags, but will extract the
information for any tags found in this segment.
},
    Extra => q{
The extra tags represent information found in the image but not associated
with any other tag group.
},
    Composite => q{
The values of the composite tags are derived from the values of other tags.
These are convenience tags which are calculated after all other information
is extracted.
},
    PodTrailer => q{
~head1 NOTES

This document generated automatically by
L<Image::ExifTool::BuildTagLookup|Image::ExifTool::BuildTagLookup>.

~head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

~head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

~cut
},
);


#------------------------------------------------------------------------------
# New - create new BuildTagLookup object
# Inputs: 0) reference to BuildTagLookup object or BuildTagLookup class name
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool::BuildTagLookup';
    my $self = bless {}, $class;
    my %subdirs;
    my %count = (
        'unique tag names' => 0,
        'total tags' => 0,
    );
#
# loop through all tables, accumulating TagLookup and TagName information
#
    my (%tagNameInfo, %id, %longID, %shortName, %tableNum,
        %tagLookup, %tagExists, %tableWritable);
    $self->{TAG_NAME_INFO} = \%tagNameInfo;
    $self->{TAG_ID} = \%id;
    $self->{LONG_ID} = \%longID;
    $self->{SHORT_NAME} = \%shortName;
    $self->{TABLE_NUM} = \%tableNum;
    $self->{TAG_LOOKUP} = \%tagLookup;
    $self->{TAG_EXISTS} = \%tagExists;
    $self->{TABLE_WRITABLE} = \%tableWritable;

    Image::ExifTool::LoadAllTables();
    my @tableNames = sort keys %allTables;
    my $tableNum = 0;
    my $tableName;
    # create lookup for short table names
    foreach $tableName (@tableNames) {
        my $short = $tableName;
        $short =~ s/^Image::ExifTool:://;
        $short =~ s/::Main$//;
        $short =~ s/::/ /;
        $short =~ s/(.*)Tags$/\u$1/;
        $short =~ s/^Exif\b/EXIF/;
        $shortName{$tableName} = $short;    # remember short name
        $tableNum{$tableName} = $tableNum++;
    }
    foreach $tableName (@tableNames) {
        # create short table name
        my $short = $shortName{$tableName};
        my $info = $tagNameInfo{$tableName} = [ ];
        my $table = GetTagTable($tableName);
        my $tableNum = $tableNum{$tableName};
        $longID{$tableName} = 0;
        # call write proc if it exists in case it adds tags to the table
        my $writeProc = $table->{WRITE_PROC};
        $writeProc and &$writeProc();
        # save all tag names
        my ($tagID, $binaryTable);
        if ($table->{PROCESS_PROC} and
            $table->{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData)
        {
            $binaryTable = 1;
            $id{$tableName} = 'Index';
        } elsif ($short eq 'IPTC') {
            $id{$tableName} = 'Record';
        } elsif ($short !~ /^(Composite|XMP|Extra)$/) {
            $id{$tableName} = 'Tag ID';
        }
        $caseInsensitive = ($tableName =~ /::XMP::/);
        my @keys = sort NumbersFirst TagTableKeys($table);
        my $defFormat = $table->{FORMAT};
        if (not $defFormat and $table->{PROCESS_PROC} and
            $table->{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData)
        {
            $defFormat = 'int8u';   # use default format for binary data tables
        }
TagID:  foreach $tagID (@keys) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my ($tagInfo, @tagNames, $subdir, $format, @values);
            my (@require, @writeGroup, @writable);
            $format = $defFormat;
            foreach $tagInfo (@infoArray) {
                if ($$tagInfo{Notes}) {
                    my $note = $$tagInfo{Notes};
                    $note =~ s/(^\s+|\s+$)//sg;
                    push @values, "($note)";
                }
                my $writeGroup;
                $writeGroup = $$tagInfo{WriteGroup} || '-';
                $format = $$tagInfo{Format} if defined $$tagInfo{Format};
                if ($$tagInfo{SubDirectory}) {
                    # don't show XMP structure tags
                    next TagID if $short =~ /^XMP /;
                    $subdir = 1;
                    my $subTable = $tagInfo->{SubDirectory}->{TagTable} || $tableName;
                    push @values, $shortName{$subTable}
                } else {
                    $subdir = 0;
                }
                my $type;
                foreach $type ('Require','Desire') {
                    my $require = $$tagInfo{$type};
                    if ($require) {
                        foreach (sort { $a <=> $b } keys %$require) {
                            push @require, $$require{$_};
                        }
                    }
                }
                my $printConv = $$tagInfo{PrintConv};
                if (ref $printConv eq 'HASH') {
                    $caseInsensitive = 0;
                    my @pk = sort NumbersFirst keys %$printConv;
                    foreach (@pk) {
                        next if $_ eq '';
                        my $index;
                        if ($$tagInfo{PrintHex}) {
                            $index = sprintf('0x%x',$_);
                        } elsif (/^[-+]?\d+$/) {
                            $index = $_;
                        } else {
                            # ignore unprintable values
                            next if /[\x00-\x1f\x80-\xff]/;
                            $index = "'$_'";
                        }
                        push @values, "$index = " . $$printConv{$_};
                    }
                }
                my $writable;
                if ($subdir) {
                    # flag a subdirectory by setting writable to '-'
                    # (if this is a writable subdirectory, prefix writable by '-')
                    $writable = '-' . ($$tagInfo{Writable} || '');
                } else {
                    if (defined $$tagInfo{Writable}) {
                        $writable = $$tagInfo{Writable};
                    } else {
                        $writable = $$table{WRITABLE};
                    }
                    $writable = $$tagInfo{Format} if $writable and $$tagInfo{Format};
                    # not writable if we can't do the inverse conversions
                    my $noPrintConvInv;
                    if ($writable) {
                        foreach ('PrintConv','ValueConv') {
                            next unless $$tagInfo{$_};
                            next if $$tagInfo{$_ . 'Inv'};
                            next if ref $$tagInfo{$_} eq 'HASH';
                            if ($_ eq 'ValueConv') {
                                undef $writable;
                            } else {
                                $noPrintConvInv = 1;
                            }
                            last;
                        }
                    }
                    if (not $writable) {
                        $writable = 'N';
                    } else {
                        $writable eq '1' and $writable = $format ? $format : 'Y';
                        my $count = $$tagInfo{Count};
                        if ($count) {
                            $count = 'n' if $count < 0;
                            $writable .= "[$count]";
                        }
                        $writable .= '~' if $noPrintConvInv;
                    }
                    # add a '*' if this tag is protected or a '~' for unsafe tags
                    if ($$tagInfo{Protected}) {
                        $writable .= '*' if $$tagInfo{Protected} & 0x02;
                        $writable .= '!' if $$tagInfo{Protected} & 0x01;
                    }
                }
                # don't duplicate a tag name unless an entry is different
                my $name = $$tagInfo{Name};
                my $lcName = lc($name);
                $name .= '?' if $$tagInfo{Unknown};
                unless (@tagNames and $tagNames[-1] eq $name and
                    $writeGroup[-1] eq $writeGroup and $writable[-1] eq $writable)
                {
                    push @tagNames, $name;
                    push @writeGroup, $writeGroup;
                    push @writable, $writable;
                }
#
# add this tag to the tag lookup unless PROCESS_PROC is 0
#
                next if defined $$table{PROCESS_PROC} and not $$table{PROCESS_PROC};
                # count our tags
                if ($$tagInfo{SubDirectory}) {
                    $subdirs{$lcName} or $subdirs{$lcName} = 0;
                    ++$subdirs{$lcName};
                } else {
                    ++$count{'total tags'};
                    unless ($tagExists{$lcName} and (not $subdirs{$lcName} or $subdirs{$lcName} == $tagExists{$lcName})) {
                        ++$count{'unique tag names'};
                    }
                }
                $tagExists{$lcName} or $tagExists{$lcName} = 0;
                ++$tagExists{$lcName};
                # only add writable tags to lookup table (for speed)
                my $wflag = $$tagInfo{Writable};
                next unless $writeProc and ($wflag or ($$table{WRITABLE} and not defined $wflag));
                $tagLookup{$lcName} or $tagLookup{$lcName} = { };
                # remember number for this table
                my $tagIDs = $tagLookup{$lcName}->{$tableNum};
                # must allow for duplicate tags with the same name in a single table!
                if ($tagIDs) {
                    if (ref $tagIDs eq 'HASH') {
                        $$tagIDs{$tagID} = 1;
                        next;
                    } elsif ($tagID eq $tagIDs) {
                        next;
                    } else {
                        $tagIDs = { $tagIDs => 1, $tagID => 1 };
                    }
                } else {
                    $tagIDs = $tagID;
                }
                $tableWritable{$tableName} = 1;
                $tagLookup{$lcName}->{$tableNum} = $tagIDs;
            }
#
# save TagName information
#
            my $tagIDstr;
            if ($tagID =~ /^\d+$/) {
                if ($binaryTable or $short =~ /^IPTC\b/) {
                    $tagIDstr = $tagID;
                } else {
                    $tagIDstr = sprintf("0x%.4x",$tagID);
                }
            } else {
                # convert non-printable characters to hex escape sequences
                if ($tagID =~ s/([\x00-\x1f\x7f-\xff])/'\x'.unpack('H*',$1)/eg) {
                    next if $tagID eq 'jP\x1a\x1a'; # ignore abnormal JP2 signature tag
                    $tagIDstr = qq{"$tagID"};
                } else {
                    $tagIDstr = "'$tagID'";
                }
            }
            my $len = length $tagIDstr;
            $longID{$tableName} = $len if $longID{$tableName} < $len;
            push @$info, [ $tagIDstr, \@tagNames, \@writable, \@values, \@require, \@writeGroup ];
        }
    }
    $self->{COUNT} = \%count;
    return $self;
}

#------------------------------------------------------------------------------
# Rewrite this file to build the lookup tables
# Inputs: 0) BuildTagLookup object reference
#         1) output tag lookup module name (ie. 'lib/Image/ExifTool/TagLookup.pm')
# Returns: true on success
sub WriteTagLookup($$)
{
    local $_;
    my ($self, $file) = @_;
    my $tagLookup = $self->{TAG_LOOKUP};
    my $tagExists = $self->{TAG_EXISTS};
    my $tableWritable = $self->{TABLE_WRITABLE};
#
# open/create necessary files and transfer file headers
#
    my $tmpFile = "${file}_tmp";
    open(INFILE,$file) or warn("Can't open $file\n"), return 0;
    unless (open(OUTFILE,">$tmpFile")) {
        warn "Can't create temporary file $tmpFile\n";
        close(INFILE);
        return 0;
    }
    my $success;
    while (<INFILE>) {
        print OUTFILE $_ or last;
        if (/^#\+{4} Begin/) {
            $success = 1;
            last;
        }
    }
    print OUTFILE "\n# list of tables containing writable tags\n";
    print OUTFILE "my \@tableList = (\n";
#
# write table list
#
    my @tableNames = sort keys %allTables;
    my $tableName;
    my %wrNum;      # translate from allTables index to writable tables index
    my $count = 0;
    my $num = 0;
    foreach $tableName (@tableNames) {
        if ($$tableWritable{$tableName}) {
            print OUTFILE "\t'$tableName',\n";
            $wrNum{$count} = $num++;
        }
        $count++;
    }
#
# write the tag lookup table
#
    my $tag;
    print OUTFILE ");\n\n# lookup for all writable tags\nmy \%tagLookup = (\n";
    foreach $tag (sort keys %$tagLookup) {
        print OUTFILE "\t'$tag' => { ";
        my @tableNums = sort { $a <=> $b } keys %{$$tagLookup{$tag}};
        my (@entries, $tableNum);
        foreach $tableNum (@tableNums) {
            my $tagID = $$tagLookup{$tag}->{$tableNum};
            my $entry;
            if (ref $tagID eq 'HASH') {
                my @tagIDs = sort keys %$tagID;
                foreach (@tagIDs) {
                    if (/^\d+$/) {
                        $_ = sprintf("0x%x",$_);
                    } else {
                        my $quot = "'";
                        # escape non-printable characters in tag ID if necessary
                        $quot = '"' if s/[\x00-\x1f,\x7f-\xff]/sprintf('\\x%.2x',ord($&))/ge;
                        $_ = $quot . $_ . $quot;
                    }
                }
                $entry = '[' . join(',', @tagIDs) . ']';
            } elsif ($tagID =~ /^\d+$/) {
                $entry = sprintf("0x%x",$tagID);
            } else {
                $entry = "'$tagID'";
            }
            my $wrNum = $wrNum{$tableNum};
            push @entries, "$wrNum => $entry";
        }
        print OUTFILE join(', ', @entries);
        print OUTFILE " },\n";
    }
#
# write tag exists lookup
#
    print OUTFILE ");\n\n# lookup for non-writable tags to check if the name exists\n";
    print OUTFILE "my \%tagExists = (\n";
    foreach $tag (sort keys %$tagExists) {
        next if $$tagLookup{$tag};
        print OUTFILE "\t'$tag' => 1,\n";
    }
    print OUTFILE ");\n\n";
#
# finish writing TagLookup.pm and clean up
#
    if ($success) {
        $success = 0;
        while (<INFILE>) {
            $success or /^#\+{4} End/ or next;
            print OUTFILE $_;
            $success = 1;
        }
    }
    close(INFILE);
    close(OUTFILE) or $success = 0;
#
# return success code
#
    if ($success) {
        rename($tmpFile, $file);
    } else {
        unlink($tmpFile);
        warn "Error rewriting file\n";
    }
    return $success;
}

#------------------------------------------------------------------------------
# sort numbers first numerically, then strings alphabetically (case insensitive)
sub NumbersFirst
{
    my $rtnVal;
    my $bNum = ($b =~ /^-?[0-9]+$/);
    if ($a =~ /^-?[0-9]+$/) {
        $rtnVal = ($bNum ? $a <=> $b : -1);
    } elsif ($bNum) {
        $rtnVal = 1;
    } else {
        $caseInsensitive and $rtnVal = (lc($a) cmp lc($b));
        $rtnVal or $rtnVal = ($a cmp $b);
    }
}

#------------------------------------------------------------------------------
# Convert pod documentation to pod
# (funny, I know, but the pod headings must be hidden to prevent confusing
#  the pod parser)
# Inputs: 0) string
sub Doc2Pod($)
{
    my $doc = shift;
    $doc =~ s/\n~/\n=/g;
    return $doc;
}

#------------------------------------------------------------------------------
# Convert pod documentation to html
# Inputs: 0) string
sub Doc2Html($)
{
    my $doc = EscapeHTML(shift);
    $doc =~ s/\n\n/\n\n<p>/g;
    $doc =~ s/B&lt;(.*?)&gt;/<b>$1<\/b>/sg;
    $doc =~ s/C&lt;(.*?)&gt;/<code>$1<\/code>/sg;
    return $doc;
}

#------------------------------------------------------------------------------
# Get the order that we want to print the tables in the documentation
# Returns: tables in the order we want
sub GetTableOrder()
{
    my %gotTable;
    my $count = 0;
    my @tableNames = @tableOrder;
    my (@orderedTables, %mainTables, @outOfOrder);
    my $lastTable = '';

    while (@tableNames) {
        my $tableName = shift @tableNames;
        next if $gotTable{$tableName};
        if ($tableName =~ /^Image::ExifTool::(\w+)::Main/) {
            $mainTables{$1} = 1;
        } elsif ($lastTable and not $tableName =~ /^${lastTable}::/) {
            push @outOfOrder, $tableName;
        }
        ($lastTable) = ($tableName =~ /^(Image::ExifTool::\w+)/);
        push @orderedTables, $tableName;
        $gotTable{$tableName} = 1;
        my $table = GetTagTable($tableName);
        # recursively scan through tables in subdirectories
        my @moreTables;
        $caseInsensitive = ($tableName =~ /::XMP::/);
        my @keys = sort NumbersFirst TagTableKeys($table);
        foreach (@keys) {
            my @infoArray = GetTagInfoList($table,$_);
            my $tagInfo;
            foreach $tagInfo (@infoArray) {
                my $subdir = $$tagInfo{SubDirectory} or next;
                $tableName = $$subdir{TagTable} or next;
                next if $gotTable{$tableName};  # next if table already loaded
                push @moreTables, $tableName;   # must scan this one too
            }
        }
        unshift @tableNames, @moreTables;
    }
    # clean up the order for tables which are out of order
    # (groups all Canon and Kodak tables together)
    my %fixOrder;
    foreach (@outOfOrder) {
        next unless /^Image::ExifTool::(\w+)/;
        # only re-order tables which have a corresponding main table
        next unless $mainTables{$1};
        $fixOrder{$1} = [];     # fix the order of these tables
    }
    my (@sortedTables, %fixPos);
    foreach (@orderedTables) {
        if (/^Image::ExifTool::(\w+)/ and $fixOrder{$1}) {
            my $fix = $fixOrder{$1};
            @$fix or $fixPos{scalar(@sortedTables)} = $1;
            push @{$fix}, $_;
        } else {
            push @sortedTables, $_;
        }
    }
    # insert back in better order
    foreach (reverse sort { $a <=> $b } keys %fixPos) {
        splice(@sortedTables, $_, 0, @{$fixOrder{$fixPos{$_}}});
    }
    return @sortedTables
}

#------------------------------------------------------------------------------
# Open HTMLFILE and print header and description
# Inputs: 0) Filename, 1) optional category
# Returns: True on success
my %createdFiles;
sub OpenHtmlFile($;$)
{
    my ($htmldir, $category) = @_;
    my ($htmlFile, $title, $url);

    if ($category) {
        my @names = split ' ', $category;
        my $class = shift @names;
        $htmlFile = "$htmldir/TagNames/$class.html";
        $title = "$category Tags";
        @names and $url = join '_', @names;
    } else {
        $htmlFile = "$htmldir/TagNames/index.html";
        $category = 'ExifTool';
        $title = 'ExifTool Tag Names';
    }
    if ($createdFiles{$htmlFile}) {
        open(HTMLFILE,">>${htmlFile}_tmp") or return 0;
    } else {
        open(HTMLFILE,">${htmlFile}_tmp") or return 0;
        print HTMLFILE "<html>\n<head>\n<title>$title</title>\n</head>\n";
        print HTMLFILE "<body text='#000000' $bgBody>\n";
    }
    $title = "<a name='$url'>$title</a>" if $url;
    print HTMLFILE "<h2>$title</h2>\n" or return 0;
    print HTMLFILE Doc2Html($docs{$category}),"\n" if $docs{$category};
    $createdFiles{$htmlFile} = 1;
    return 1;
}

#------------------------------------------------------------------------------
# Close all html files and write trailers
# Returns: true on success
sub CloseHtmlFiles()
{
    my $success = 1;
    # get the date
    my ($sec,$min,$hr,$day,$mon,$yr) = localtime;
    my @month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
    $yr += 1900;
    my $date = "$month[$mon] $day, $yr";
    my $htmlFile;
    foreach $htmlFile (keys %createdFiles) {
        my $tmpFile = $htmlFile . '_tmp';
        open(HTMLFILE,">>$tmpFile") or $success = 0, next;
        # write the trailers
        print HTMLFILE "<p><a href='index.html'>&lt;-- ExifTool Tag Names</a>\n" unless $htmlFile =~ /index/;
        print HTMLFILE "<hr>\n";
        print HTMLFILE "(This document generated automatically by Image::ExifTool::BuildTagLookup)\n";
        print HTMLFILE "<br><i>Last revised $date</i>\n</body>\n</html>\n" or $success = 0;
        close HTMLFILE or $success = 0;
        # check for differences and only use new file if it was changed
        # (so the date only gets updated if changes were really made)
        my $useNewFile;
        if ($success) {
            open (TEMPFILE, $tmpFile) or $success = 0, last;
            if (open (HTMLFILE, $htmlFile)) {
                while (<HTMLFILE>) {
                    my $newLine = <TEMPFILE>;
                    if (defined $newLine) {
                        next if /^<br><i>Last revised/;
                        next if $_ eq $newLine;
                    }
                    # files are different -- use the new file
                    $useNewFile = 1;
                    last;
                }
                $useNewFile = 1 if <TEMPFILE>;
                close HTMLFILE;
            } else {
                $useNewFile = 1;
            }
            close TEMPFILE;
            if ($useNewFile) {
                rename $tmpFile, $htmlFile or warn("Error renaming temporary file\n"), $success = 0;
            } else {
                unlink $tmpFile;   # erase new file and use existing file
            }
        }
        last unless $success;
    }
    return $success;
}

#------------------------------------------------------------------------------
# Write the TagName HTML and POD documentation
# Inputs: 0) BuildTagLookup object reference
#         1) output pod file (ie. 'lib/Image/ExifTool/TagNames.pod')
#         2) output html directory (ie. 'html')
# Returns: true on success
sub WriteTagNames($$)
{
    my ($self, $podFile, $htmldir) = @_;
    my ($tableName, $short, $url);
    my $tagNameInfo = $self->{TAG_NAME_INFO} or return 0;
    my $idTitle = $self->{TAG_ID};
    my $shortName = $self->{SHORT_NAME};
    my $success = 1;
    my %htmlFiles;

    # open the file and write the header
    open(PODFILE,">$podFile") or return 0;
    print PODFILE Doc2Pod($docs{PodHeader}), $docs{ExifTool};
    mkdir "$htmldir/TagNames";
    OpenHtmlFile($htmldir) or return 0;
    print HTMLFILE "<blockquote>\n";
    print HTMLFILE "<table width='100%' $bgHeading cellspacing=2 cellpadding=0>\n";
    print HTMLFILE "<tr $bgBody><td><table width='100%' cellspacing=1 cellpadding=2>\n";
    print HTMLFILE "<tr $bgHeading><th colspan=3><font size='+1'>Tag Table Index</font></th></tr>\n";
    print HTMLFILE "<tr $bgRow valign='top'><td>\n";
    # write the index
    my @tableNames = GetTableOrder();
    my $count = 0;
    my $lines = int((scalar(@tableNames) + 2) / 3);
    foreach $tableName (@tableNames) {
        if ($count) {
            if ($count % $lines) {
                print HTMLFILE '<br>';
            } else {
                print HTMLFILE "</td><td>\n";
            }
        }
        $short = $$shortName{$tableName};
        my @names = split ' ', $short;
        my $class = shift @names;
        $url = "$class.html";
        my $indent = '';
        if (@names) {
            $url .= '#' . join '_', @names;
            $indent = '&nbsp; &nbsp; ';
        }
        print HTMLFILE "$indent<a href='$url'>$short</a>\n";
        ++$count;
    }
    print HTMLFILE "</td></tr></table></td></tr></table></blockquote>\n\n";
    # write all the tag tables
    foreach $tableName (@tableNames) {
        $short = $$shortName{$tableName};
        my $info = $$tagNameInfo{$tableName};
        my $id = $$idTitle{$tableName};
        my ($hid, $showGrp);
        # widths of the different columns in the POD documentation
        my ($wID,$wTag,$wReq,$wGrp) = (8,36,24,10);
        my $composite = $short eq 'Composite';
        my $derived = $composite ? '<th>Derived From</th>' : '';
        my $podIdLen = $self->{LONG_ID}->{$tableName};
        my $table = GetTagTable($tableName);
        my $notes = $$table{NOTES};
        my $prefix;
        if ($notes and $notes =~ /leading '(.*?_)' which/) {
            $prefix = $1;
            $podIdLen -= length $prefix;
        }
        if ($podIdLen <= $wID) {
            $podIdLen = $wID;
        } else {
            # align tag names at the secondary column if possible
            my $col = 20;
            $podIdLen = $col if $podIdLen < $col;
        }
        $id = '' if $short =~ /^XMP/;
        if ($id) {
            $hid = "<th>$id</th>";
            $wTag -= $podIdLen - $wID;
            $wID = $podIdLen;
        } elsif ($short eq 'Extra' or $short =~ /^XMP/) {
            $wTag += 9;
            $hid = '';
        } else {
            $hid = '';
            $wTag += $wID - $wReq if $composite;
        }
        if ($short eq 'EXIF') {
            $derived = '<th>Group</th>';
            $showGrp = 1;
            $wTag -= $wGrp + 1;
        }
        my $head = ($short =~ / /) ? 'head3' : 'head2';
        print PODFILE "\n=$head $short Tags\n";
        print PODFILE $docs{$short} if $docs{$short};
        if ($notes) {
            $notes =~ s/(^\s+|\s+$)//sg;
            print PODFILE "\n$notes\n";
        }
        my $line = "\n";
        if ($id) {
            # shift over 'Index' heading by one character for a bit more balance
            $id = " $id" if $id eq 'Index';
            $line .= sprintf "  %-${wID}s", $id;
        } else {
            $line .= ' ';
        }
        my $tagNameHeading = ($short eq 'XMP') ? 'Namespace' : 'Tag Name';
        $line .= sprintf " %-${wTag}s", $tagNameHeading;
        $line .= sprintf " %-${wReq}s", 'Derived From' if $composite;
        $line .= sprintf " %-${wGrp}s", 'Group' if $showGrp;
        $line .= ' Writable';
        print PODFILE $line;
        $line =~ s/\S/-/g;
        $line =~ s/- -/---/g;
        print PODFILE $line,"\n";
        close HTMLFILE;
        OpenHtmlFile($htmldir, $short) or $success = 0;
        if ($notes) {
            print HTMLFILE "<p>" if $docs{$short};
            print HTMLFILE Doc2Html($notes), "\n";
        }
        print HTMLFILE "<blockquote>\n";
        print HTMLFILE "<table $bgHeading cellspacing=2 cellpadding=0><tr $bgBody><td>\n";
        print HTMLFILE "<table cellspacing=1 cellpadding=2><tr $bgHeading>$hid<th>$tagNameHeading</th>\n";
        print HTMLFILE "<th>Writable</th>$derived<th>Values / ${noteFont}Notes</font></th></tr>\n";
        my $rowCol = 1;
        my $infoCount = 0;
        my $infoList;
        foreach $infoList (@$info) {
            ++$infoCount;
            my ($tagIDstr, $tagNames, $writable, $values, $require, $writeGroup) = @$infoList;
            my ($align, $idStr, $w);
            if (not $id) {
                $idStr = '  ';
            } elsif ($tagIDstr =~ /^\d+$/) {
                $w = $wID - 3;
                $idStr = sprintf "  %${w}d    ", $tagIDstr;
                $align = " align='right'";
            } else {
                $tagIDstr =~ s/^'$prefix/'/ if $prefix;
                $w = $wID;
                $idStr = sprintf "  %-${w}s ", $tagIDstr;
                $align = '';
            }
            my @reqs;
            my @tags = @$tagNames;
            my @wGrp = @$writeGroup;
            my @vals = @$writable;
            my $wrStr = shift @vals;
            my $subdir;
            # if this is a subdirectory, print subdir name (from values) instead of writable
            if ($wrStr =~ /^-/) {
                $subdir = 1;
                @vals = @$values;
                $wrStr = shift @vals;
            }
            my $tag = shift @tags;
            printf PODFILE "%s%-${wTag}s", $idStr, $tag;
            warn "Warning: Pushed $tag\n" if $id and length($tag) > $wTag;
            printf PODFILE " %-${wGrp}s", shift(@wGrp) || '-' if $showGrp;
            if ($composite) {
                @reqs = @$require;
                $w = $wReq; # Keep writable columun in line
                length($tag) > $wTag and $w -= length($tag) - $wTag;
                printf PODFILE " %-${w}s", shift(@reqs) || '';
            }
            printf PODFILE " $wrStr\n";
            my $n = 0;
            while (@tags or @reqs or @vals) {
                my $more = (@tags or @reqs);
                $line = '  ';
                $line .= ' 'x($wID+1) if $id;
                $line .= sprintf("%-${wTag}s", shift(@tags) || '');
                $line .= sprintf(" %-${wReq}s", shift(@reqs) || '') if $composite;
                $line .= sprintf(" %-${wGrp}s", shift(@wGrp) || '-') if $showGrp;
                ++$n;
                if (@vals) {
                    my $val = shift @vals;
                    # use writable if this is a note
                    my $wrStr = $$writable[$n];
                    if ($subdir and ($val =~ /^\(/ or $val =~ /=/ or ($wrStr and $wrStr !~ /^-/))) {
                        $val = $wrStr;
                        if (defined $val) {
                            $val =~ s/^-//;
                        } else {
                            # done with tag if nothing else to print
                            last unless $more;
                        }
                    }
                    $line .= " $val" if defined $val;
                }
                $line =~ s/\s+$//;  # trim trailing white space
                print PODFILE "$line\n";
            }
            my @htmlTags;
            foreach (@$tagNames) {
                push @htmlTags, EscapeHTML($_);
            }
            $rowCol = $rowCol ? '' : " $bgRow";
            my $isSubdir;
            if ($$writable[0] =~ /^-/) {
                $isSubdir = 1;
                foreach (@$writable) {
                    s/^-(.+)/$1/;
                }
            }
            print HTMLFILE "<tr$rowCol valign='top'>\n";
            print HTMLFILE "<td$align>$tagIDstr</td>\n" if $id;
            print HTMLFILE "<td>", join("\n  <br>",@htmlTags), "</td>\n";
            print HTMLFILE "<td align='center'>",join('<br>',@$writable),"</td>\n";
            print HTMLFILE '<td>',join("\n  <br>",@$require),"</td>\n" if $composite;
            print HTMLFILE "<td align='center'>",join('<br>',@$writeGroup),"</td>\n" if $showGrp;
            print HTMLFILE "<td>";
            my $close = '';
            my @values;
            if (@$values) {
                if ($isSubdir) {
                    foreach (@$values) {
                        /^\(/ and push(@values,"$noteFont$_</font>"), next;
                        /=/ and push(@values, $_), next;
                        my @names = split;
                        $url = (shift @names) . '.html';
                        @names and $url .= '#' . join '_', @names;
                        push @values, "--&gt; <a href='$url'>$_ Tags</a>";
                    }
                } else {
                    foreach (@$values) {
                        $_ = EscapeHTML($_);
                        /^\(/ and $_ = "$noteFont$_</font>";
                        push @values, $_;
                    }
                    print HTMLFILE "<font size='-1'>";
                    $close = '</font>';
                }
            } else {
                push @values, '&nbsp;';
            }
            print HTMLFILE join("\n  <br>",@values),"$close</td></tr>\n";
        }
        unless ($infoCount) {
            printf PODFILE "  [no tags defined]\n";
            my $cols = 3;
            ++$cols if $hid;
            ++$cols if $derived;
            print HTMLFILE "<tr><td colspan=$cols align='center'>[no tags defined]</td></tr>\n";
        }
        print HTMLFILE "</table></td></tr></table></blockquote>\n\n";
    }
    close(HTMLFILE) or $success = 0;
    CloseHtmlFiles() or $success = 0;
    print PODFILE Doc2Pod($docs{PodTrailer}) or $success = 0;
    close(PODFILE) or $success = 0;
    return $success;
}

1;  # end


__END__

=head1 NAME

Image::ExifTool::BuildTagLookup - Utility to build tag lookup tables

=head1 DESCRIPTION

This module is used to generate the tag lookup tables in
Image::ExifTool::TagLookup.pm and tag name documentation in
Image::ExifTool::TagNames.pod, as well as HTML tag name documentation.  It
is used before each new ExifTool release to update the lookup tables and
documentation.

=head1 SYNOPSIS

  use Image::ExifTool::BuildTagLookup;

  $builder = new Image::ExifTool::BuildTagLookup;

  $ok = $builder->WriteTagLookup('lib/Image/ExifTool/TagLookup.pm');

  $ok = $builder->WriteTagNames('lib/Image/ExifTool/TagNames.pod','html');

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::ExifTool::TagLookup(3pm)|Image::ExifTool::TagLookup>,
L<Image::ExifTool::TagNames(3pm)|Image::ExifTool::TagNames>

=cut
