#------------------------------------------------------------------------------
# File:         WritePhotoshop.pl
#
# Description:  Definitions for writing Photoshop IRB resource
#
# Revisions:    12/17/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Photoshop;

use strict;


#------------------------------------------------------------------------------
# Write Photoshop IRB resource
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) source dirInfo reference
# Returns: IRB resource data (may be empty if no Photoshop data)
# Notes: Increments ExifTool CHANGED flag for each tag changed
sub WritePhotoshop($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dataPt = $dirInfo->{DataPt};
    unless ($dataPt) {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
    my $start = $dirInfo->{DirStart} || 0;
    my $dirLen = $dirInfo->{DirLen} || (length($$dataPt) - $start);
    my $dirEnd = $start + $dirLen;
    my $verbose = $exifTool->Options('Verbose');
    my $newData = '';

    my @tagInfoList = $exifTool->GetNewTagInfoList($tagTablePtr);
    # make a hash of new tag info, keyed on tagID
    my (%newTagInfo, $tagInfo, $tagID);
    Image::ExifTool::GenerateTagIDs($tagTablePtr);  # make sure IDs are generated
    foreach $tagInfo (@tagInfoList) {
        $newTagInfo{$tagInfo->{TagID}} = $tagInfo;
    }
    my ($addDirs, $editDirs) = $exifTool->GetAddDirHash($tagTablePtr);

    my $saveOrder = GetByteOrder();
    SetByteOrder('MM');     # Photoshop is always big-endian
#
# rewrite existing tags in the old directory, deleting ones as necessary
# (the Photoshop directory entries aren't in any particular order)
#
    # Format: 0) Type, 4 bytes - "8BIM"
    #         1) TagID,2 bytes
    #         2) Name, null terminated string padded to even no. bytes
    #         3) Size, 4 bytes - N
    #         4) Data, N bytes
    my ($pos, $value, $size);
    for ($pos=$start; $pos+8<$dirEnd; $pos+=$size) {
        # each entry must be on same even byte boundary as directory start
        ++$pos if ($pos ^ $start) & 0x01;
        my $type = substr($$dataPt, $pos, 4);
        if ($type ne '8BIM') {
            $exifTool->Error("Bad IRB resource: $type");
            undef $newData;
            last;
        }
        $tagID = Get16u($dataPt, $pos + 4);
        $pos += 6;
        # get resource block name (null-terminated, padded to an even # of bytes)
        my $name = '';
        my $bytes;
        while ($pos + 2 < $dirEnd) {
            $bytes = substr($$dataPt, $pos, 2);
            $pos += 2;
            $name .= $bytes;
            last if $bytes =~ /\0/;
        }
        if ($pos + 4 > $dirEnd) {
            $exifTool->Error("Bad APP13 resource block");
            undef $newData;
            last;
        }
        $size = Get32u($dataPt, $pos);
        $pos += 4;
        if ($size + $pos > $dirEnd) {
            # hack necessary because earlier versions of photoshop
            # sometimes don't put null terminator on string if it
            # ends at an even word boundary - PH 02/25/04
            if (defined($bytes) and $bytes eq "\0\0") {
                $pos -= 2;
                $size = Get32u($dataPt, $pos-4);
            }
            if ($size + $pos > $dirEnd) {
                $exifTool->Error("Bad APP13 resource data size $size");
                undef $newData;
                last;
            }
        }
        if ($newTagInfo{$tagID}) {
            $tagInfo = $newTagInfo{$tagID};
            delete $newTagInfo{$tagID};
            # check to see if we are overwriting this tag
            $value = substr($$dataPt, $pos, $size);
            if ($exifTool->IsOverwriting($tagInfo, $value)) {
                $verbose > 1 and print "    - Photoshop:$$tagInfo{Name} = '$value'\n";
                $value = $exifTool->GetNewValues($tagInfo);
                ++$exifTool->{CHANGED};
                next unless defined $value;     # next if tag is being deleted
            }
        } elsif ($$editDirs{$tagID}) {
            $tagInfo = $$editDirs{$tagID};
            $$addDirs{$tagID} and delete $$addDirs{$tagID};
            my %subdirInfo = (
                DataPt => $dataPt,
                DirStart => $pos,
                DataLen => $dirLen,
                DirLen => $size,
                Parent => $dirInfo->{DirName},
            );
            my $subTable = Image::ExifTool::GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            my $newValue = $exifTool->WriteTagTable($subTable, \%subdirInfo);
            if (defined $newValue) {
                next unless length $newValue;   # remove subdirectory entry
                $value = $newValue;
            }
        } else {
            $value = substr($$dataPt, $pos, $size);
        }
        my $newSize = length $value;
        # write this directory entry
        $newData .= $type . Set16u($tagID) . $name . Set32u($newSize) . $value;
        $newData .= "\0" if $newSize & 0x01;    # must null pad to even byte
    }
#
# write any remaining entries we didn't find in the old directory
# (might as well write them in numerical tag order)
#
    my @tagsLeft = sort { $a <=> $b } keys(%newTagInfo), keys(%$addDirs);
    foreach $tagID (@tagsLeft) {
        if ($newTagInfo{$tagID}) {
            $tagInfo = $newTagInfo{$tagID};
            $value = $exifTool->GetNewValues($tagInfo);
            next unless defined $value;     # next if tag is being deleted
            # don't add this tag unless specified
            next unless $exifTool->IsCreating($tagInfo);
            $verbose > 1 and print "    + Photoshop:$$tagInfo{Name} = '$value'\n";
            ++$exifTool->{CHANGED};
        } else {
            $tagInfo = $$addDirs{$tagID};
            # create new directory
            my %subdirInfo = (
                Parent => $dirInfo->{DirName},
            );
            my $subTable = Image::ExifTool::GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            $value = $exifTool->WriteTagTable($subTable, \%subdirInfo);
            next unless $value;
        }
        $size = length($value);
        # write the new directory entry
        $newData .= '8BIM' . Set16u($tagID) . "\0\0" . Set32u($size) . $value;
        $newData .= "\0" if $size & 0x01;   # must null pad to even numbered byte
        ++$exifTool->{CHANGED};
    }
    SetByteOrder($saveOrder);               # restore original byte ordering
    return $newData;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WritePhotoshop.pl - Routines to write Photoshop IRB resource

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::Photoshop.

=head1 DESCRIPTION

This file contains routines to write Photoshop metadata.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
