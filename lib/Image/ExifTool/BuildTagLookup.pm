#------------------------------------------------------------------------------
# File:         BuildTagLookup.pm
#
# Description:  Utility to build tag lookup tables in Image::ExifTool::TagLookup.pm
#
# Revisions:    12/31/2004 - P. Harvey Created
#               02/15/2005 - PH Added ability to write TagNames documentation 
#------------------------------------------------------------------------------

package Image::ExifTool::BuildTagLookup;

use strict;
require Exporter;

use vars qw($VERSION @ISA);
use Image::ExifTool qw(:Utils :Vars);
use Image::ExifTool::XMP qw(EscapeHTML);

$VERSION = '1.02';
@ISA = qw(Exporter);

# Descriptions for the TagNames documentation
my %docs = (
    Header => q{
The tables below list the names of all tags recognized by ExifTool
(excluding shortcut and unknown tags).  Case is not significant for tag
names.  Where applicable, the corresponding B<Tag ID> or B<Index> is also
given.  A B<Tag ID> is the computer-readable equivalent of a tag name, and
is the identifier that is actually stored in the file.  B<Index> gives the
location of the information if it is located at a fixed position in a
record.  In some instances, more than one tag name may correspond to a
single ID.  In these cases, the actual tag name depends on the context in
which the information is found.

The B<Writable> column indicates whether the tag is writable by ExifTool.
Anything but an B<N> in this column means the tag is writable.  A B<Y>
indicates writable information that is either unformatted or written using
the existing format.  Other expressions give details about the information
format, and vary depending on the general type of information.  An asterisk
(*) indicates that the information is not writable directly, but is set via
a composite tag.  The HTML version of this document also lists all B<Values>
for tags which have a discreet set of values.

B<Note>: If you are familiar with common meta-information tag names, you may
be surprised to find that some ExifTool tags have different names than you
expect.  The usual reason for this is to make the tag names more consistent
across different types of meta information.  To determine a tag name, either
consult this documentation or run B<exiftool> with the B<-S> option on a
file containing the information in question.
},
    EXIF => q{
This is the type of meta information that gave ExifTool its name, although
subsequently ExifTool has evolved to read may other types.
},
    IPTC => q{
The IPTC specification dictates a length for most ASCII (string or digits)
and integer (binary) values.  These lengths are given in square brackets
after the B<Writable> format name.  Where a minimum and maximum length are
specified, both values are given, separated by a comma.

IPTC information is separated into different records, each of which has its
own set of tags.
},
    CanonRaw => q{
When writing CanonRaw information, the length of the information is
preserved (and the new information is truncated or padded as required)
unless B<Writable> is 'resize'.  Currently, only JpgFromRaw is allowed to
change size.
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
    Trailer => q{
=head1 NOTES

This document generated automatically by
L<Image::ExifTool::BuildTagLookup|Image::ExifTool::BuildTagLookup>.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
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
        } elsif ($short ne 'Composite') {
            $id{$tableName} = 'Tag ID';
        }
        my @keys = TagTableKeys($table);
        if (grep /[^0-9]/, @keys) {
            @keys = sort @keys;
        } else {
            @keys = sort { $a <=> $b } @keys;
        }
        foreach $tagID (@keys) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my ($tagInfo, @tagNames, $subdir, $format, @values, @require);
            my $writable = $$table{WRITABLE};
            my $protected = '';
            foreach $tagInfo (@infoArray) {
                $writable = $$tagInfo{Writable} if defined $$tagInfo{Writable};
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
                $protected = '*' if $$tagInfo{Protected};
                my $name = $$tagInfo{Name};
                unless (@tagNames and $tagNames[-1] eq $name) {
                    push @tagNames, $name;
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
                if ($binaryTable) {
                    $tagIDstr = $tagID;
                } else {
                    $tagIDstr = sprintf("0x%.4x",$tagID);
                }
            } else {
                # ignore tags with non-printable characters in ID
                next if $tagID =~ /[\x00-\x1f\x80-\xff]/;
                $tagIDstr = "'$tagID'";
            }
            if ($writable) {
                if ($writable eq '1') {
                    if ($format) {
                        $writable = $format;
                    } else {
                        $writable = 'Y';
                    }
                }
            } else {
                $writable = 'N';
            }
            $writable .= $protected;
            $writable = '-' if $subdir;
            push @$info, [ $tagIDstr, \@tagNames, $writable, \@values, \@require ];
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
    my $err;
    -e $file or $err = 'File not found';
    open(INFILE,$file) or $err = "Can't open $file";
    open(OUTFILE,">$tmpFile") or $err = "Can't create temporary file $tmpFile";
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
        $err or $err = 'Error rewriting file';
        warn "$err\n";
    }
    return $success;
}

#------------------------------------------------------------------------------
# Convert pod documentation to html
# Inputs: 0) string
sub DocToHtml($)
{
    my $doc = EscapeHTML(shift);
    $doc =~ s/\n\n/\n\n<p>/g;
    $doc =~ s/B&lt;(.*?)&gt;/<b>$1<\/b>/sg;
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
# Write the TagName HTML documentation
# Inputs: 0) BuildTagLookup object reference
#         1) output pod file (ie. 'lib/Image/ExifTool/TagNames.pod')
#         2) output html file (ie. 'html/TagNames.html')
# Returns: true on success
sub WriteTagNames($$)
{
    my ($self, $podFile, $htmlFile) = @_;
    my ($tableName, $short, $url);
    my $tagNameInfo = $self->{TAG_NAME_INFO} or return 0;
    my $idTitle = $self->{TAG_ID};
    my $shortName = $self->{SHORT_NAME};
    my $success = 1;
#
# write the TagName documentation
#
    # open the file and write the header
    open(PODFILE,">$podFile") or return 0;
    print PODFILE "=head1 ExifTool Tag Names\n", $docs{Header};
    open(HTMLFILE,">$htmlFile") or return 0;
    print HTMLFILE "<html>\n<head>\n<title>ExifTool Tag Names</title>\n</head>\n";
    print HTMLFILE "<body text='#000000' bgcolor='#ffffff'>\n";
    print HTMLFILE "<h1>ExifTool Tag Names</h1>\n", DocToHtml($docs{Header}),"\n";
    print HTMLFILE "<h3>Tag Table Index</h3>\n<table><tr><td>\n";
    # write the index
    my @tableNames = GetTableOrder();
    my $count = 0;
    my $lines = int((scalar(@tableNames) + 2) / 3);
    foreach $tableName (@tableNames) {
        $short = $$shortName{$tableName};
        ($url = $short) =~ tr/ /_/;
        print HTMLFILE "<a href='#$url'>$short</a>\n";
        if (++$count % $lines) {
            print HTMLFILE '<br>';
        } else {
            print HTMLFILE "</td><td>\n";
        }
    }
    print HTMLFILE "</td></tr></table>\n\n";
    foreach $tableName (@tableNames) {
        $short = $$shortName{$tableName};
        ($url = $short) =~ tr/ /_/;
        my $info = $$tagNameInfo{$tableName};
        my $id = $$idTitle{$tableName};
        my ($hid, $derived);
        my ($wID,$wTag,$wVal,$wReq) = (8,33,0,24);
        if ($id) {
            $hid = "<th>$id</th>";
            $derived = '';
        } else {
            $hid = '';
            $derived = '<th>Derived From</th>';
            $wTag = 18;
        }
        print PODFILE "\n=head2 $short Tags\n";
        print PODFILE $docs{$short} if $docs{$short};
        my $line = "\n";
        $line .= sprintf "  %6s  ", $id if $id;
        $line .= sprintf "  %-${wTag}s", 'Tag Name';
        $line .= sprintf " %-${wReq}s", 'Derived From' unless $id;
        $line .= ' Writable';
        print PODFILE $line;
        $line =~ s/\S/-/g;
        $line =~ s/- -/---/g;
        print PODFILE $line,"\n";
        print HTMLFILE "<h3><a name='$url'>$short Tags</a></h3>\n";
        print HTMLFILE DocToHtml($docs{$short}) if $docs{$short};
        print HTMLFILE "<blockquote><table border=1 cellspacing=0 cellpadding=2>\n";
        print HTMLFILE "<tr bgcolor='#dddddd'>$hid<th>Tag Name</th>\n";
        print HTMLFILE "<th>Writable</th>$derived<th>Values</th></tr>\n";
        my $infoList;
        foreach $infoList (@$info) {
            my ($tagIDstr, $tagNames, $format, $values, $require) = @$infoList;
            my ($align, $fmt);
            if ($tagIDstr =~ /^\d+$/) {
                $fmt = sprintf "%dd  ",$wID-2;
                $align = " align='right'";
            } else {
                $tagIDstr = '-' if $short eq 'XMP' or $short eq 'Extra';
                $fmt = "-${wID}s";
                $align = '';
            }
            my @tags = @$tagNames;
            my (@reqs, @vals);
            my $forStr = $format;
            if ($forStr eq '-') {
                @vals = @$values;
                $forStr = shift @vals;
            }
            printf PODFILE "  %$fmt", $tagIDstr if $id;
            printf PODFILE "  %-${wTag}s", shift(@tags);
            unless ($id) {
                @reqs = @$require;
                printf PODFILE " %-${wReq}s", shift(@reqs) || '';
            }
            printf PODFILE " $forStr\n";
            while (@tags or @reqs or @vals) {
                $line = '  ';
                $line .= ' 'x($wID+2) if $id;
                $line .= sprintf("%-${wTag}s", shift(@tags) || '');
                $line .= sprintf(" %-${wReq}s", shift(@reqs) || '') unless $id;
                $line .= sprintf(" %s", shift(@vals)) if @vals;
                $line =~ s/\s+$//;  # trim trailing white space
                print PODFILE "$line\n";
            }
            my @htmlTags;
            foreach (@$tagNames) {
                push @htmlTags, EscapeHTML($_);
            }
            print HTMLFILE "<tr valign='top'>\n";
            print HTMLFILE "<td$align>$tagIDstr</td>\n" if $id;
            print HTMLFILE "<td>", join("\n  <br>",@htmlTags), "</td>\n";
            print HTMLFILE "<td align='center'>$format</td>\n";
            print HTMLFILE '<td>',join("\n  <br>",@$require),"</td>\n" unless $id;
            print HTMLFILE "<td>";
            my $close = '';
            my @values;
            if (@$values) {
                if ($format eq '-') {
                    foreach (@$values) {
                        ($url = $_) =~ tr/ /_/;
                        push @values, "--&gt; <a href='#$url'>$_ Tags</a>";
                    }
                } else {
                    foreach (@$values) {
                        push @values, EscapeHTML($_);
                    }
                    print HTMLFILE "<font size='-1'>";
                    $close = '</font>';
                }
            } else {
                push @values, '&nbsp;';
            }
            print HTMLFILE join("\n  <br>",@values),"$close</td></tr>\n";
        }
        print HTMLFILE "</table></blockquote>\n\n";
    }
    my ($sec,$min,$hr,$day,$mon,$yr) = localtime;
    my @month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
    $yr += 1900;
    my $date = "$month[$mon] $day, $yr";
    print HTMLFILE "<hr>\n";
    print HTMLFILE "(This document generated automatically by Image::ExifTool::BuildTagLookup)\n";
    print HTMLFILE "<br><i>Last revised $date</i>\n</body>\n</html>\n" or $success = 0;
    print PODFILE $docs{Trailer} or $success = 0;
    close(PODFILE) or $success = 0;
    close(HTMLFILE) or $success = 0;
    return $success;
}

1;  # end


__END__

=head1 NAME

Image::ExifTool::BuildTagLookup - Utility to build tag lookup tables

=head1 DESCRIPTION

This module is used to generate the tag lookup tables and tag name
documentation for Image::ExifTool::TagLookup.pm.  It is run before each new
ExifTool release to update the lookup tables and documentation.

=head1 SYNOPSIS

  use Image::ExifTool::BuildTagLookup;

  $builder = new Image::ExifTool::BuildTagLookup;

  $ok = $builder->WriteTagLookup('lib/Image/ExifTool/TagLookup.pm');

  $ok = $builder->WriteTagNames('lib/Image/ExifTool/TagNames.pod',
                                'html/TagNames.html');

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>,
L<Image::ExifTool::TagLookup|Image::ExifTool::TagLookup>,
L<ExifTool tag names|Image::ExifTool::TagNames>

=cut
