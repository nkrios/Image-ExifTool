#------------------------------------------------------------------------------
# File:         BuildTagLookup.pm
#
# Description:  Utility to build tag lookup tables in Image::ExifTool::TagLookup.pm
#
# Revisions:    12/31/2004  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::BuildTagLookup;

use strict;
require Exporter;

use vars qw($VERSION @ISA @EXPORT_OK);
use Image::ExifTool qw(:Utils :Vars);

$VERSION = '1.00';
@ISA = qw(Exporter);
@EXPORT_OK = qw(BuildTagLookup);


#------------------------------------------------------------------------------
# Rewrite this file to build the lookup tables
# Inputs: 0) output file name (ie. 'lib/Image/ExifTool/TagLookup.pm')
# Returns: true on success
sub BuildTagLookup($)
{
    local $_;
    my $file = shift;
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
    $success or $err = 'Error rewriting file';
    print OUTFILE "\nmy \@tableList = (\n";

    # iterate through all tag tables, saving lookup information for all tags
    Image::ExifTool::LoadAllTables();
    my @tableNames = ( sort keys %allTables );
    my (%newLookup, $tableName, @tagInfoList);
    my $tableNum = 0;
    foreach $tableName (@tableNames) {
        print OUTFILE "    '$tableName',\n";
        my $table = GetTagTable($tableName);
        # save all tag names and look for any SubDirectory tables
        my $tagID;
        foreach $tagID (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my $tagInfo;
            foreach $tagInfo (@infoArray) {
                my $name = $$tagInfo{Name};
                my $lcName = lc($name);
                $newLookup{$lcName} = { } unless $newLookup{$lcName};
                # remember number for this table
                my $tagIDs = $newLookup{$lcName}->{$tableNum};
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
                $newLookup{$lcName}->{$tableNum} = $tagIDs;
            }
        }
        ++$tableNum;
    }
    # print out lookup table
    print OUTFILE ");\n\nmy \%tagLookup = (\n";
    my $tag;
    foreach $tag (sort keys %newLookup) {
        print OUTFILE "    '$tag' => { ";
        my @tableNums = sort { $a <=> $b } keys %{$newLookup{$tag}};
        my (@entries, $tableNum);
        foreach $tableNum (@tableNums) {
            my $tagID = $newLookup{$tag}->{$tableNum};
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
    
    # transfer the rest of the file
    $success = 0;
    while (<INFILE>) {
        $success or /^#\+{4} End/ or next;
        print OUTFILE $_;
        $success = 1;
    }
    close(INFILE);
    close(OUTFILE) or $success = 0;
    if ($success) {
        rename($tmpFile, $file);
    } else {
        unlink($tmpFile);
        warn "Error rewriting file\n";
    }
    return $success;
}

1;  # end


__END__

=head1 NAME

Image::ExifTool::BuildTagLookup - Utility to build tag lookup tables

=head1 DESCRIPTION

This module is used to generate the tag lookup tables in
Image::ExifTool::TagLookup.pm.  It is run before a new ExifTool
release to update the lookup tables.

=head1 SYNOPSIS

    use Image::ExifTool::BuildTagLookup qw(BuildTagLookup);

    $success = BuildTagLookup('lib/Image/ExifTool/TagLookup.pm');

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>
L<Image::ExifTool::TagLookup|Image::ExifTool::TagLookup>

=cut
