#------------------------------------------------------------------------------
# File:         WriteIPTC.pl
#
# Description:  Definitions for writing IPTC meta information
#
# Revisions:    12/15/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::IPTC;

use strict;


#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and possibly changes value) on success
sub CheckIPTC($$$)
{
    my ($exifTool, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format};
    if ($format =~ /^binary\[?(\d*)\]?/) {
        my $val = $$valPtr;
        my $bytes = $1 || 0;
        return 'Not an integer' unless Image::ExifTool::IsInt($val);
        my $n;
        for ($n=0; $n<$bytes; ++$n) { $val >>= 8; }
        return "Value too large for $bytes-byte format" if $val;
    } elsif ($format =~ /^(string|digits)\[?(\d+),?(\d*)\]?$/) {
        my ($fmt, $minlen, $maxlen) = ($1, $2, $3);
        my $len = length $$valPtr;
        if ($fmt eq 'digits') {
            return 'Non-numeric characters in value' unless $$valPtr =~ /^\d+$/;
            # left pad with zeros if necessary
            $$valPtr = ('0' x ($len - $minlen)) . $$valPtr if $len < $minlen;
        }
        if ($minlen) {
            $maxlen or $maxlen = $minlen;
            return "String too short (minlen is $minlen)" if $len < $minlen;
            return "String too long (maxlen is $maxlen)" if $len > $maxlen;
        }
    } else {
        return "Bad IPTC Format ($format)";
    }
    return undef;
}

#------------------------------------------------------------------------------
# format IPTC data
# Inputs: 0) tagInfo pointer, 1) value reference (changed if necessary)
sub FormatIPTC($$)
{
    my ($tagInfo, $valPtr) = @_;
    if ($$tagInfo{Format} and $$tagInfo{Format} =~ /^binary\[?(\d*)\]?/) {
        my $len = $1 || 0;
        if ($1 == 1) {  # 1 byte
            $$valPtr = ord($$valPtr);
        } elsif ($1 == 2) { # 2-byte integer
            $$valPtr = pack('n', $$valPtr);
        } elsif ($1 == 4) { # 4-byte integer
            $$valPtr = pack('N', $$valPtr);
        } else {
            $$valPtr = pack('n', $$valPtr);   # pack as 2-byte by default
            warn "Bad format for $$tagInfo{Name}\n";
        }
    }
}

#------------------------------------------------------------------------------
# generate IPTC-format date
# Inputs: 0) EXIF-format date string (YYYY:MM:DD)
# Returns: IPTC-format date string (YYYYMMDD), or undef on error
sub IptcDate($)
{
    my $val = shift;
    $val =~ s/.*(\d{4}):(\d{2}):(\d{2}).*/$1$2$3/ or undef $val;
    return $val;
}

#------------------------------------------------------------------------------
# generate IPTC-format time
# Inputs: 0) EXIF-format time string (HH:MM:SS[+/-HH:MM])
# Returns: IPTC-format time string (HHMMSS+HHMM), or undef on error
sub IptcTime($)
{
    my $val = shift;
    if ($val =~ /\s*\b(\d{2}):(\d{2}):(\d{2})(\S*)/) {
        $val = "$1$2$3";
        my $tz = $4;
        if ($tz =~ /([+-]\d{2}:\d{2})/) {
            $val .= $tz;
        } else {
            $val .= '+00:00';    # don't know the time zone
        }
    } else {
        undef $val;     # time format error
    }
    return $val;
}

#------------------------------------------------------------------------------
# Write IPTC data record
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) source dirInfo reference
# Returns: IPTC data block (may be empty if no IPTC data)
# Notes: Increments ExifTool CHANGED flag for each tag changed
sub WriteIPTC($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dataPt = $dirInfo->{DataPt};
    unless ($dataPt) {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
    my $start = $dirInfo->{DirStart} || 0;
    my $dirLen = $dirInfo->{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my ($tagInfo, %iptcInfo, $tag);

    # make sure our dataLen is defined (note: allow zero length directory)
    unless (defined $dirLen) {
        my $dataLen = $dirInfo->{DataLen};
        $dataLen = length($$dataPt) unless defined $dataLen;
        $dirLen = $dataLen - $start;
    }
    # generate lookup so we can find the record numbers
    my %recordNum;
    foreach $tag (Image::ExifTool::TagTableKeys($tagTablePtr)) {
        $tagInfo = $tagTablePtr->{$tag};
        $tagInfo->{SubDirectory} or next;
        my $table = $tagInfo->{SubDirectory}->{TagTable} or next;
        my $subTablePtr = Image::ExifTool::GetTagTable($table);
        $recordNum{$subTablePtr} = $tag;
        Image::ExifTool::GenerateTagIDs($subTablePtr);
    }

    # loop through new values and accumulate all IPTC information
    # into lists based on their IPTC record type
    foreach $tagInfo ($exifTool->GetNewTagInfoList()) {
        next unless $exifTool->GetGroup($tagInfo, 0) eq 'IPTC';
        my $table = $tagInfo->{Table};
        my $record = $recordNum{$table};
        next unless defined $record; # shouldn't happen
        $iptcInfo{$record} = [] unless defined $iptcInfo{$record};
        push @{$iptcInfo{$record}}, $tagInfo;
    }

    # get sorted list of records used.  Might as well be organized and
    # write our records in order of record number first, then tag number
    my @recordList = sort { $a <=> $b } keys %iptcInfo;
    my ($record, %set);
    foreach $record (@recordList) {
        # sort tagInfo lists by tagID
        @{$iptcInfo{$record}} = sort { $$a{TagID} <=> $$b{TagID} } @{$iptcInfo{$record}};
        # build hash of all tagIDs to set
        foreach $tagInfo (@{$iptcInfo{$record}}) {
            $set{$record}->{$tagInfo->{TagID}} = $tagInfo;
        }
    }

    # run through the old IPTC data, inserting our records in
    # sequence and deleting existing records where necessary
    # (the IPTC specification states that records must occur in
    # numerical order, but tags within records need not be ordered)
    my $pos = $start;
    my $tail = $pos;   # old data written up to this point
    my $dirEnd = $start + $dirLen;
    my $newData = '';
    my $lastRec = -1;
    my %foundRec;
    for (;;$tail=$pos) {
        # get next IPTC record from input directory
        my ($id, $rec, $tag, $len, $valuePtr);
        if ($pos + 5 <= $dirEnd) {
            my $buff = substr($$dataPt, $pos, 5);
            ($id, $rec, $tag, $len) = unpack("CCCn", $buff);
            if ($id == 0x1c) {
                if ($rec < $lastRec) {
                    $exifTool->Warn("IPTC doesn't conform to spec: Records out of sequence");
                    return undef unless $exifTool->Options('IgnoreMinorErrors');
                }
                $lastRec = $rec;
                # handle extended IPTC entry if necessary
                $pos += 5;      # step to after field header
                if ($len & 0x8000) {
                    my $n = $len & 0x7fff;  # get num bytes in length field
                    if ($pos + $n <= $dirEnd and $n <= 8) {
                        # determine length (a big-endian, variable sized binary number)
                        for ($len = 0; $n; ++$pos, --$n) {
                            $len = $len * 256 + ord(substr($$dataPt, $pos, 1));
                        }
                    } else {
                        $len = $dirEnd;     # invalid length
                    }
                }
                $valuePtr = $pos;
                $pos += $len;   # step $pos to next entry
                # make sure we don't go past the end of data
                # (this can only happen if original data is bad)
                $pos = $dirEnd if $pos > $dirEnd;
            } else {
                undef $rec;
            }
        }
        # write out all our records that come before this one
        for (;;) {
            last unless @recordList;
            my $newRec = $recordList[0];
            $tagInfo = ${$iptcInfo{$newRec}}[0];
            my $newTag = $tagInfo->{TagID};
            # compare current entry with entry next in line to write out
            # (write out our tags in numberical order even though
            # this isn't required by the IPTC spec)
            last if defined $rec and $rec <= $newRec;
            # only add new values if tag existed before or IsCreating is true
            my @values;
            if ($foundRec{$newRec}->{$newTag} or $exifTool->IsCreating($tagInfo)) {
                @values = $exifTool->GetNewValues($tagInfo);
            }
            # write tags for each value in list
            my $value;
            foreach $value (@values) {
                $verbose > 1 and print "    + IPTC:$$tagInfo{Name} = '$value'\n";
                # convert to binary if necessary
                FormatIPTC($tagInfo, \$value);
                # (note: IPTC string values are NOT null terminated)
                $len = length $value;
                # generate our new entry
                my $entry = pack("CCC", 0x1c, $newRec, $newTag);
                if ($len <= 0x7fff) {
                    $entry .= pack("n", $len);
                } else {
                    # extended dataset tag
                    $entry .= pack("nN", 0x8004, $len);
                }
                $entry .= $value;
                ++$exifTool->{CHANGED};
                $newData .= $entry; # add entry to new IPTC data
            }
            # remove this tagID from the sorted write list
            shift @{$iptcInfo{$newRec}};
            shift @recordList unless @{$iptcInfo{$newRec}};
        }
        # all done if no more records to write
        last unless defined $rec;

        # write out this record unless we are setting it with a new value
        $tagInfo = $set{$rec}->{$tag};
        if ($tagInfo) {
            $foundRec{$rec}->{$tag} = 1;
            $len = $pos - $valuePtr;
            my $val = substr($$dataPt, $valuePtr, $len);
            if ($tagInfo->{Format} and $tagInfo->{Format} =~ /^binary/) {
                $val = 0;
                my $i;
                for ($i=0; $i<$len; ++$i) {
                    $val = $val * 256 + ord(substr($$dataPt, $valuePtr+$i, 1));
                }
            }
            if ($exifTool->IsOverwriting($tagInfo, $val)) {
                $verbose > 1 and print "    - IPTC:$$tagInfo{Name} = '$val'\n";
                ++$exifTool->{CHANGED};
                next;
            }
        }
        # write out the record
        $newData .= substr($$dataPt, $tail, $pos-$tail);
    }
    # make sure the rest of the data is zero
    if ($tail < $dirEnd) {
        my $trailer = substr($$dataPt, $tail, $dirEnd-$tail);
        if ($trailer =~ /[^\0]/) {
            $exifTool->Warn('Unrecognized data in IPTC trailer');
            return undef unless $exifTool->Options('IgnoreMinorErrors');
        }
        # add back a bit of zero padding ourselves
        $newData .= "\0" x 100;
    }
    return $newData;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WriteIPTC.pl - Definitions for writing IPTC meta information

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::IPTC.

=head1 DESCRIPTION

This file contains routines to write IPTC metadata.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
