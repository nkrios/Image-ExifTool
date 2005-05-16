#------------------------------------------------------------------------------
# File:         BuildTagLookup.pm
#
# Description:  Utility to build tag lookup tables in Image::ExifTool::TagLookup.pm
#
# Revisions:    12/31/2004 - P. Harvey Created
#               02/15/2005 - PH Added ability to generate TagNames documentation
#------------------------------------------------------------------------------

package Image::ExifTool::BuildTagLookup;

use strict;
require Exporter;

use vars qw($VERSION @ISA);
use Image::ExifTool qw(:Utils :Vars);
use Image::ExifTool::XMP qw(EscapeHTML);

$VERSION = '1.12';
@ISA = qw(Exporter);

# colors for html pages
my $noteFont = '<font color="#666666">';
my $bgHeading = q{bgcolor='#ffbb77'};
my $bgBody = q{bgcolor='#ffffff'};
my $bgRow = q{bgcolor='#ffeebb'};

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
tag name indicates that the information is either not understood or not
verified -- these tags are not extracted by ExifTool unless the Unknown (-u)
option is enabled.

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

The HTML version of these tables also list possible B<Values> for all tags
which have a discrete set of values, and give B<Notes> for some tags.

B<Note>: If you are familiar with common meta-information tag names, you may
find that some ExifTool tag names are different than expected.  The usual
reason for this is to make the tag names more consistent across different
types of meta information.  To determine a tag name, either consult this
documentation or run C<exiftool -S> on a file containing the information in
question.
},
    EXIF => q{
EXIF meta information may exist within different Image File Directories
(IFD's) of an image.  The names of these IFD's correspond to the
ExifTool family 1 group names.  When writing EXIF information, the
default B<Group> listed below is used unless another group is specified.
},
    GPS => q{
ExifTool is very flexible about the input format for lat/long coordinates,
and will accept 3 floating point numbers separated by just about anything.
Many other GPS tags have values which are fixed-length strings.  For these,
the indicated string lengths include a null terminator which is added
automatically by ExifTool.
},
    XMP => q{
All XMP information is stored as character strings.  An C<integer> in this
format is a string of digits, possibly beginning with a '+' or '-', and a
C<rational> is composed of two C<integer> strings separated by a '/'
character.  A C<date> is a date and/or time string in the format 'YYYY:MM:DD
HH:MM:SS[+/-HH:MM]'.  A C<boolean> is either 'True' or 'False', and
C<lang-alt> is a list of string alternatives in different languages.
Currently, ExifTool only writes the 'x-default' language in C<lang-alt>
lists.

The B<Group> column below gives the XMP schema namespace prefix for each
tag.  The family 1 group names are composed from these schema names with a
leading "XMP-" added.  If the same XMP tag name exists in more than one
group, all groups are written unless a family 1 group name is specified.
ie) If XMP:Contrast is specified, information will be written to both
XMP-crs:Contrast and XMP-exif:Contrast.

Note: that the actual IPTC Core namespace schema prefix is C<Iptc4xmpCore>,
which is the name used in the file, but ExifTool uses C<iptcCore> to
generate the family 1 group name because C<Iptc4xmpCore> is a bit lengthy.
},
    IPTC => q{
The IPTC specification dictates a length for ASCII (C<string> or C<digits>)
values.  These lengths are given in square brackets after the B<Writable>
format name.  For tags where a range of lengths is allowed, the minimum and
maximum lengths are separated by a comma within the brackets.  IPTC strings
are not null terminated.

IPTC information is separated into different records, each of which has its
own set of tags.
},
    Photoshop => q{
The meanings of many Photoshop tags are known, however very few provide useful
information about the image, so many are not decoded by ExifTool.  The tags
listed below are those which are decoded by ExifTool.
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
These tags are used by Minolta and Konica/Minolta cameras.
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
While current Sony camera models contain a wealth of information, very
little is known about the Sony tags.
},
    CanonRaw => q{
These tags apply to Canon CRW-format RAW files.  When writing CanonRaw
information, the length of the information is preserved (and the new
information is truncated or padded as required) unless B<Writable> is
C<resize>.  Currently, only JpgFromRaw and ThumbnailImage are allowed to
change size.
},
    Unknown => q{
The following tags are decoded in unsupported maker notes.  Use the Unknown
(-u) option to display other unknown tags.
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
#
# loop through all tables, accumulating TagLookup and TagName information
#
    my (%tagNameInfo, %id, %shortName, %tableNum, %tagLookup);
    $self->{TAG_NAME_INFO} = \%tagNameInfo;
    $self->{TAG_ID} = \%id;
    $self->{SHORT_NAME} = \%shortName;
    $self->{TABLE_NUM} = \%tableNum;
    $self->{TAG_LOOKUP} = \%tagLookup;

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
        $short = 'EXIF' if $short eq 'Exif';
        $shortName{$tableName} = $short;    # remember short name
        $tableNum{$tableName} = $tableNum++;
    }
    foreach $tableName (@tableNames) {
        # create short table name
        my $short = $shortName{$tableName};
        my $info = $tagNameInfo{$tableName} = [ ];
        my $table = GetTagTable($tableName);
        my $tableNum = $tableNum{$tableName};
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
        } elsif ($short !~ /^(Composite|Extra|XMP)$/) {
            $id{$tableName} = 'Tag ID';
        }
        my @keys = TagTableKeys($table);
        if (grep /[^0-9]/, @keys) {
            @keys = sort @keys;
        } else {
            @keys = sort { $a <=> $b } @keys;
        }
        my $defFormat = $table->{FORMAT};
        if (not $defFormat and $table->{PROCESS_PROC} and
            $table->{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData)
        {
            $defFormat = 'int8u';   # use default format for binary data tables
        }
        foreach $tagID (@keys) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my ($tagInfo, @tagNames, $subdir, $format, @values);
            my (@require, @writeGroup, @writable);
            $format = $defFormat;
            foreach $tagInfo (@infoArray) {
                push @values, "($$tagInfo{Notes})" if $$tagInfo{Notes};
                my $writeGroup;
                if ($short eq 'XMP') {
                    ($writeGroup = $tagInfo->{Groups}->{1}) =~ s/XMP-//;
                } else {
                    $writeGroup = $$tagInfo{WriteGroup} || '-';
                }
                $format = $$tagInfo{Format} if defined $$tagInfo{Format};
                if ($$tagInfo{SubDirectory}) {
                    $subdir = 1;
                    my $subTable = $tagInfo->{SubDirectory}->{TagTable} || $tableName;
                    push @values, $shortName{$subTable}
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
                    my @pk;
                    if (grep(!/^\d+$/, keys %$printConv)) {
                        @pk = sort keys %$printConv;
                    } else {
                        @pk = sort { $a <=> $b } keys %$printConv;
                    }
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
                        $writable .= "[$$tagInfo{Count}]" if $$tagInfo{Count};
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
                $name .= '?' if $$tagInfo{Unknown};
                unless (@tagNames and $tagNames[-1] eq $name and
                    $writeGroup[-1] eq $writeGroup and $writable[-1] eq $writable)
                {
                    push @tagNames, $name;
                    push @writeGroup, $writeGroup;
                    push @writable, $writable;
                }
                my $lcName = lc($name);
                $tagLookup{$lcName} = { } unless $tagLookup{$lcName};
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
                # ignore tags with non-printable characters in ID
                next if $tagID =~ /[\x00-\x1f\x80-\xff]/;
                $tagIDstr = "'$tagID'";
            }
            push @$info, [ $tagIDstr, \@tagNames, \@writable, \@values, \@require, \@writeGroup ];
        }
    }
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
    print OUTFILE "\nmy \@tableList = (\n";
#
# write table list
#
    my @tableNames = sort keys %allTables;
    my $tableName;
    foreach $tableName (@tableNames) {
        print OUTFILE "    '$tableName',\n";
    }
#
# write the tag lookup table
#
    print OUTFILE ");\n\nmy \%tagLookup = (\n";
    my $tag;
    foreach $tag (sort keys %$tagLookup) {
        print OUTFILE "    '$tag' => { ";
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
                        $_ = "'$_'";
                    }
                }
                $entry = '[' . join(',', @tagIDs) . ']';
            } elsif ($tagID =~ /^\d+$/) {
                $entry = sprintf("0x%x",$tagID);
            } else {
                $entry = "'$tagID'";
            }
            push @entries, "$tableNum => $entry";
        }
        print OUTFILE join(', ', @entries);
        print OUTFILE " },\n";
    }
    print OUTFILE ");\n\n";
#
# finish writing TagLookup and clean up
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
    my @orderedTables;

    while (@tableNames) {
        my $tableName = shift @tableNames;
        next if $gotTable{$tableName};
        push @orderedTables, $tableName;
        $gotTable{$tableName} = 1;
        my $table = GetTagTable($tableName);
        # recursively scan through tables in subdirectories
        my @moreTables;
        my @keys = TagTableKeys($table);
        if (grep /[^0-9]/, @keys) {
            @keys = sort @keys;
        } else {
            @keys = sort { $a <=> $b } @keys;
        }
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
    return @orderedTables
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
        my @names = split /\s+/, $category;
        my $class = shift @names;
        $htmlFile = "$htmldir/TagNames/$class.html";
        $title = "$category Tags";
        $url = @names ? join '_', @names : $class;
    } else {
        $htmlFile = "$htmldir/TagNames/index.html";
        $category = 'ExifTool';
        $title = 'ExifTool Tag Names';
        $url = "ExifTool";
    }
    if ($createdFiles{$htmlFile}) {
        open(HTMLFILE,">>${htmlFile}_tmp") or return 0;
    } else {
        open(HTMLFILE,">${htmlFile}_tmp") or return 0;
        print HTMLFILE "<html>\n<head>\n<title>$title</title>\n</head>\n";
        print HTMLFILE "<body text='#000000' $bgBody>\n";
    }
    print HTMLFILE "<h2><a name='$url'>$title</a></h2>\n" or return 0;
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
# Write the TagName HTML documentation
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
        my @names = split /\s+/, $short;
        my $class = shift @names;
        $url = "$class.html";
        @names and $url .= '#' . join '_', @names;
        print HTMLFILE "<a href='$url'>$short</a>\n";
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
        my ($wID,$wTag,$wReq,$wGrp) = (7,36,24,10);
        my $composite = $short eq 'Composite';
        my $derived = $composite ? '<th>Derived From</th>' : '';
        if ($id) {
            $hid = "<th>$id</th>";
        } elsif ($short eq 'Extra') {
            $wTag += 9;
            $hid = '';
        } else {
            $hid = '';
            $wTag += $wID - $wReq + 1 if $composite;
        }
        if ($short eq 'EXIF' or $short eq 'XMP') {
            $derived = '<th>Group</th>';
            $showGrp = 1;
            if ($short eq 'XMP') {
                $wTag -= 2;
            } else {
                $wTag -= $wGrp + 1;
            }
        }
        print PODFILE "\n=head2 $short Tags\n";
        print PODFILE $docs{$short} if $docs{$short};
        my $table = GetTagTable($tableName);
        my $notes = $$table{NOTES};
        if ($notes) {
            $notes =~ s/\s+$//s;
            print PODFILE $notes, "\n";
        }
        my $line = "\n";
        $line .= sprintf " %${wID}s ", $id if $id;
        $line .= sprintf "  %-${wTag}s", 'Tag Name';
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
        print HTMLFILE "<table cellspacing=1 cellpadding=2><tr $bgHeading>$hid<th>Tag Name</th>\n";
        print HTMLFILE "<th>Writable</th>$derived<th>Values / ${noteFont}Notes</font></th></tr>\n";
        my $rowCol = 1;
        my $infoList;
        foreach $infoList (@$info) {
            my ($tagIDstr, $tagNames, $writable, $values, $require, $writeGroup) = @$infoList;
            my ($align, $idStr, $w);
            if (not $id) {
                $idStr = '  ';
            } elsif ($tagIDstr =~ /^\d+$/) {
                $w = $wID - 2;
                $idStr = sprintf "  %${w}d    ", $tagIDstr;
                $align = " align='right'";
            } else {
                $w = $wID + 1;
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
            printf PODFILE " %-${wGrp}s", shift(@wGrp) || '-' if $showGrp;
            if ($composite) {
                @reqs = @$require;
                $w = $wReq; # Keep writable columun in line
                length($tag) > $wTag and $w -= length($tag) - $wTag;
                printf PODFILE " %-${w}s", shift(@reqs) || '';
            }
            printf PODFILE " $wrStr\n";
            while (@tags or @reqs or @vals) {
                $line = '  ';
                $line .= ' 'x($wID+2) if $id;
                $line .= sprintf("%-${wTag}s", shift(@tags) || '');
                $line .= sprintf(" %-${wReq}s", shift(@reqs) || '') if $composite;
                $line .= sprintf(" %-${wGrp}s", shift(@wGrp) || '-') if $showGrp;
                $line .= sprintf(" %s", shift(@vals)) if @vals;
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
                $$writable[0] = substr($$writable[0], 1) unless $$writable[0] eq '-';
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
                        my @names = split /\s+/;
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
