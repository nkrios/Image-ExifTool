#------------------------------------------------------------------------------
# File:         MakerNotes.pm
#
# Description:  Logic to decode EXIF maker notes
#
# Revisions:    11/11/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MakerNotes;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

sub ProcessUnknown($$$);

$VERSION = '1.04';

# conditional list of maker notes
# (Note: This is NOT a normal tag table)
# Another note: All byte orders are now specified because we can now
# write maker notes into a file with different byte ordering!
@Image::ExifTool::MakerNotes::Main = (
    # decide which MakerNotes to use (based on camera make/model)
    {
        Condition => '$self->{CameraMake} =~ /^Canon/',
        Name => 'MakerNoteCanon',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Main',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        # The Fuji programmers really botched this one up,
        # but with a bit of work we can still read this directory
        Condition => '$self->{CameraMake} =~ /^FUJIFILM/',
        Name => 'MakerNoteFujiFilm',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FujiFilm::Main',
            Start => '$valuePtr',
            # there is an 8-byte maker tag (FUJIFILM) we must skip over
            OffsetPt => '$valuePtr+8',
            ByteOrder => 'LittleEndian',
            # the pointers are relative to the subdirectory start
            # (before adding the offsetPt) - PH
            Base => '$start',
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^(PENTAX|AOC|Asahi)/',
        Name => 'MakerNotePentax',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::Main',
            # process as Unknown maker notes because the start offset and
            # byte ordering are so variable
            ProcessProc => \&ProcessUnknown,
            # only need to set Start pointer for processing unknown
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^(OLYMPUS|SEIKO EPSON)/',
        Name => 'MakerNoteOlympus',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Main',
            Start => '$valuePtr+8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^Panasonic/',
        Name => 'MakerNotePanasonic',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+12',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^LEICA/',
        Name => 'MakerNoteLeica',
        SubDirectory => {
            # Leica uses the same format as Panasonic
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^NIKON/',
        Name => 'MakerNoteNikon',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Main',
            Start => '$valuePtr',
            # (note: ProcessNikon sets ByteOrder, so we don't need to do it here)
        },
    },
    {
        Condition => q{
            $self->{CameraMake}=~/^CASIO COMPUTER CO.,LTD/ and 
            $self->{CameraModel}=~/^EX-Z3/
        },
        Name => 'MakerNoteCasio2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::MakerNote2',
            Start => '$valuePtr + 6',
            # Casio really messed this up for the EX-Z3, and made the
            # offsets relative to somewhere in the APP0 JFIF segment... doh!
            Base => '-20',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^CASIO COMPUTER CO.,LTD/',
        Name => 'MakerNoteCasio2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::MakerNote2',
            Start => '$valuePtr + 6',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^CASIO/',
        Name => 'MakerNoteCasio',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::MakerNote1',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^(Konica Minolta|Minolta)/',
        Name => 'MakerNoteMinolta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^SANYO/',
        Name => 'MakerNoteSanyo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sanyo::Main',
            Validate => '$val =~ /^SANYO/',
            Start => '$valuePtr + 8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^(SIGMA|FOVEON)/',
        Name => 'MakerNoteSigma',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sigma::Main',
            Validate => '$val =~ /^(SIGMA|FOVEON)/',
            Start => '$valuePtr + 10',
            ByteOrder => 'Unknown',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^SONY/',
        Name => 'MakerNoteSony',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::Main',
            # validate the maker note because this is sometimes garbage
            Validate => 'defined($val) and $val =~ /^SONY DSC/',
            Start => '$valuePtr + 12',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteUnknown',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Unknown::Main',
            ProcessProc => \&ProcessUnknown,
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
);

# insert writable properties so we can write our maker notes
my $tagInfo;
foreach $tagInfo (@Image::ExifTool::MakerNotes::Main) {
    # set up this tag so we can write it
    $$tagInfo{Writable} = 'undef';
    $$tagInfo{WriteGroup} = 'ExifIFD';
    $$tagInfo{PrintConv} = '\$val';
    $$tagInfo{PrintConvInv} = '$val';
    $$tagInfo{MakerNotes} = 1;
}

#------------------------------------------------------------------------------
# Find start of IFD in unknown maker notes
# Inputs: 0) reference to directory information
# Returns: offset to IFD on success, undefined otherwise
# - on success, updates DirStart, DirLen, Base and DataPos in dirInfo
# - also sets Relative flag in dirInfo if offsets are relative to IFD
# Note: Changes byte ordering!
sub LocateIFD($)
{
    my $dirInfo = shift;
    my $dataPt = $dirInfo->{DataPt};
    my $dirStart = $dirInfo->{DirStart} || 0;
    my $size = $dirInfo->{DirLen} || ($dirInfo->{DataLen} - $dirStart);

    # scan for something that looks like an IFD
    if ($size >= 14) {  # minimum size for an IFD
        my $offset;
        # the IFD should be within the first 32 bytes
        # (Kyocera sets the current record at 22 bytes)
IFD_TRY: for ($offset=0; $offset<=32; $offset+=2) {
            last if $offset + 14 > $size;    # 14 bytes is minimum size for an IFD
            my $pos = $dirStart + $offset;
#
# look for a standard TIFF header (used by some Nikon maker notes),
# or a FUJIFILM mess (which is similar to a TIFF, except that the 4-byte TIFF
# header is replaced by 'FUJIFILM' and the byte order is always little endian)
#
            my $ifdOffsetPos;
            if (SetByteOrder(substr($$dataPt, $pos, 2)) and
                Get16u($dataPt, $pos + 2) == 0x2a)
            {
                $ifdOffsetPos = 4;
            } elsif ($offset == 0 and substr($$dataPt, $dirStart, 8) eq 'FUJIFILM') {
                SetByteOrder('II');
                $ifdOffsetPos = 8;
            }
            if (defined $ifdOffsetPos) {
                # get pointer to IFD
                my $ptr = Get32u($dataPt, $pos + $ifdOffsetPos);
                if ($ptr >= $ifdOffsetPos + 4 and $ptr + $offset + 14 <= $size) {
                    # shift directory start and shorten dirLen accordingly
                    $dirInfo->{DirStart} += $ptr + $offset;
                    $dirInfo->{DirLen} -= $ptr + $offset;
                    # make sure Base and DataPos are defined
                    $dirInfo->{Base} or $dirInfo->{Base} = 0;
                    $dirInfo->{DataPos} or $dirInfo->{DataPos} = 0;
                    # shift pointer base to the start of the TIFF header
                    my $shift = $dirInfo->{DataPos} + $dirStart + $offset;
                    $dirInfo->{Base} += $shift;
                    $dirInfo->{DataPos} -= $shift;
                    $dirInfo->{Relative} = 1;   # set "relative offsets" flag
                    return $ptr + $offset;
                }
            }
#
# look for a standard IFD (starts with 2-byte entry count)
#
            my $num = Get16u($dataPt, $pos);
            next unless $num;
            # number of entries in an IFD should be between 1 and 255
            if (!($num & 0xff)) {
                # lower byte is zero -- byte order could be wrong
                ToggleByteOrder();
                $num >>= 8;
            } elsif ($num & 0xff00) {
                # upper byte isn't zero -- not an IFD
                next;
            }
            my $bytesFromEnd = $size - ($offset + 2 + 12 * $num);
            if ($bytesFromEnd < 4) {
                next unless $bytesFromEnd == 2 or $bytesFromEnd == 0;
            }
            # do a quick validation of all format types
            my $index;
            for ($index=0; $index<$num; ++$index) {
                my $entry = $pos + 2 + 12 * $index;
                my $format = Get16u($dataPt, $entry+2);
                my $count = Get32u($dataPt, $entry+4);
                # allow everything to be zero if not first entry
                # because some manufacturers pad with null entries
                next unless $format or $count or $index == 0;
                # (would like to verify tag ID, but some manufactures don't
                #  sort entries in order of tag ID so we don't have much of
                #  a handle to verify this field)
                # verify format
                next IFD_TRY if $format < 1 or $format > 12;
                # count must be reasonable
                next IFD_TRY if $count == 0 or $count > 0x10000;
            }
            $dirInfo->{DirStart} += $offset;    # update directory start
            $dirInfo->{DirLen} -= $offset;
            # patch for Casio EX-Z3.  silly Casio programmers...
            if ($offset == 6 and substr($$dataPt, $dirStart, 4) eq "QVC\0") {
                $dirInfo->{Base} or $dirInfo->{Base} = 0;
                $dirInfo->{DataPos} or $dirInfo->{DataPos} = 0;
                $dirInfo->{Base} -= 20;
                $dirInfo->{DataPos} += 20;
            }
            return $offset;   # success!!
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Process unknown maker notes assuming it is in EXIF IFD format
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success, and updates $dirInfo if necessary for new directory
sub ProcessUnknown($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $success = 0;

    my $saveOrder = GetByteOrder();
    my $loc = LocateIFD($dirInfo);
    if (defined $loc) {
        if ($exifTool->Options('Verbose') > 1) {
            my $indent = $exifTool->{INDENT};
            $indent =~ s/\| $/  /;
            print "${indent}Found IFD at offset $$dirInfo{DirStart} in Unknown maker notes:\n";
        }
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $tagTablePtr, $dirInfo);
    } else {
        $exifTool->Warn("Bad $$dirInfo{DirName} SubDirectory");
    }
    SetByteOrder($saveOrder);
    return $success;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::MakerNotes - Logic to decode EXIF maker notes

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
