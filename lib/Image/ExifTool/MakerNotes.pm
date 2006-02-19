#------------------------------------------------------------------------------
# File:         MakerNotes.pm
#
# Description:  Read and write EXIF maker notes
#
# Revisions:    11/11/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MakerNotes;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

sub ProcessUnknown($$$);

$VERSION = '1.19';

# conditional list of maker notes
# Notes:
# - This is NOT a normal tag table!
# - All byte orders are now specified because we can now
#   write maker notes into a file with different byte ordering!
# - Put these in alphabetical order to make TagNames documentation nicer.
@Image::ExifTool::MakerNotes::Main = (
    # decide which MakerNotes to use (based on camera make/model)
    {
        Name => 'MakerNoteCanon',
        # (starts with an IFD)
        Condition => '$self->{CameraMake} =~ /^Canon/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Main',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteCasio',
        # do negative lookahead assertion just to get tags
        # in a nice order for documentation
        # (starts with an IFD)
        Condition => '$self->{CameraMake}=~/^CASIO(?! COMPUTER CO.,LTD)/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::Main',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteCasio2',
        # (starts with "QVC\0")
        Condition => '$self->{CameraMake}=~/^CASIO COMPUTER CO.,LTD/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::Type2',
            Start => '$valuePtr + 6',
            ByteOrder => 'Unknown',
        },
    },
    {
        # The Fuji programmers really botched this one up,
        # but with a bit of work we can still read this directory
        Name => 'MakerNoteFujiFilm',
        # (starts with "FUJIFILM")
        Condition => '$self->{CameraMake} =~ /^FUJIFILM/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FujiFilm::Main',
            # there is an 8-byte maker tag (FUJIFILM) we must skip over
            OffsetPt => '$valuePtr+8',
            ByteOrder => 'LittleEndian',
            # the pointers are relative to the subdirectory start
            # (before adding the offsetPt) - PH
            Base => '$start',
        },
    },
    {
        Name => 'MakerNoteJVC',
        Condition => '$self->{CameraMake}=~/^JVC/ and $$valPt=~/^JVC /',
        SubDirectory => {
            TagTable => 'Image::ExifTool::JVC::Main',
            Start => '$valuePtr + 4',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteJVCText',
        Condition => '$self->{CameraMake}=~/^(JVC|Victor)/ and $$valPt=~/^VER:/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::JVC::Text',
        },
    },
    {
        Name => 'MakerNoteKodak1a',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/ and $$valPt=~/^KDK INFO/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak1b',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/ and $$valPt=~/^KDK/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        Name => 'MakerNoteKodak2',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/i and $$valPt=~/^.{8}Eastman/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type2',
            ByteOrder => 'BigEndian',
        },
    },
    {
        # not much to key on here, but we know the
        # upper byte of the year should be 0x07:
        Name => 'MakerNoteKodak3',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/ and $$valPt=~/^.{12}\x07/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type3',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak4',
        Condition => '$self->{CameraMake}=~/^Eastman Kodak/ and $$valPt=~/^.{41}JPG/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type4',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak5',
        Condition => q{
            $self->{CameraMake}=~/^EASTMAN KODAK/ and
            ($self->{CameraModel}=~/CX(4200|4230|4300|4310|6200|6230)/ or
            # try to pick up similar models we haven't tested yet
            $$valPt=~/^\0(\x1a\x18|\x3a\x08|\x59\xf8|\x14\x80)\0/)
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type5',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak6a',
        Condition => q{
            $self->{CameraMake}=~/^EASTMAN KODAK/ and
            $self->{CameraModel}=~/DX3215/
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type6',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak6b',
        Condition => q{
            $self->{CameraMake}=~/^EASTMAN KODAK/ and
            $self->{CameraModel}=~/DX3700/
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type6',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        Name => 'MakerNoteKodakUnknown',
        Condition => '$self->{CameraMake}=~/Kodak/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Unknown',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKyocera',
        # (starts with "KYOCERA")
        Condition => '$self->{CameraMake}=~/^KYOCERA/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Unknown::Main',
            Start => '$valuePtr + 22',
            Base => '$start + 14',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteMinolta',
        Condition => '$self->{CameraMake}=~/^(Konica Minolta|Minolta)/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            ByteOrder => 'Unknown',
        },
    },
    {
        # this maker notes starts with a standard TIFF header at offset 0x0a
        Name => 'MakerNoteNikon',
        Condition => '$self->{CameraMake}=~/^NIKON/i and $$valPt=~/^Nikon\x00\x02/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Main',
            Start => '$valuePtr + 18',
            ByteOrder => 'Unknown',
            Base => '$start - 8',
        },
    },
    {
        # older Nikon maker notes
        Name => 'MakerNoteNikon2',
        Condition => '$self->{CameraMake}=~/^NIKON/ and $$valPt=~/^Nikon\x00\x01/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Type2',
            Start => '$valuePtr + 8',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        # Headerless Nikon maker notes
        Name => 'MakerNoteNikon3',
        Condition => '$self->{CameraMake}=~/^NIKON/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Main',
            ByteOrder => 'Unknown', # most are little-endian, but D1 is big
        },
    },
    {
        Name => 'MakerNoteOlympus',
        # (if Make is 'SEIKO EPSON CORP.', starts with "EPSON\0")
        # (if Make is 'OLYMPUS OPTICAL CO.,LTD' or 'OLYMPUS CORPORATION',
        #  starts with "OLYMP\0")
        Condition => '$self->{CameraMake} =~ /^(OLYMPUS|SEIKO EPSON|AGFA )/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Main',
            Start => '$valuePtr+8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteLeica',
        # (starts with "LEICA\0")
        Condition => '$self->{CameraMake} =~ /^LEICA/',
        SubDirectory => {
            # Leica uses the same format as Panasonic
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNotePanasonic',
        # (starts with "Panasonic\0")
        Condition => '$self->{CameraMake} =~ /^Panasonic/ and $$valPt!~/^MKE/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+12',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNotePanasonic2',
        # (starts with "Panasonic\0")
        Condition => '$self->{CameraMake} =~ /^Panasonic/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Panasonic::Type2',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        Name => 'MakerNotePentax',
        # (if Make is 'PENTAX Corporation', starts with "AOC\0" (also Samsung DX-1S))
        # (if Make is 'Asahi Optical Co.,Ltd', starts with an IFD)
        Condition => '$self->{CameraMake}=~/^(PENTAX|AOC|Asahi)/ or $$valPt=~/^AOC\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::Main',
            # process as Unknown maker notes because the start offset and
            # byte ordering are so variable
            ProcessProc => \&ProcessUnknown,
            ByteOrder => 'Unknown',
            # offsets can be totally whacky for Pentax maker notes,
            # so attempt to fix the offset base if possible
            FixBase => 1,
        },
    },
    {
        Name => 'MakerNoteRicoh',
        Condition => '$self->{CameraMake}=~/^RICOH/ and $$valPt=~/^Ricoh/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Ricoh::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteRicohText',
        Condition => '$self->{CameraMake}=~/^RICOH/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Ricoh::Text',
            ByteOrder => 'Unknown',
        },
    },
    {
        # Samsung PreviewImage
        %Image::ExifTool::previewImageTagInfo,
        Condition => '$self->{CameraMake}=~/^Samsung/ and $self->{CameraModel}=~/^<Digimax/',
        Notes => 'Samsung preview image',
    },
    {
        Name => 'MakerNoteSanyo',
        # (starts with "SANYO\0")
        Condition => '$self->{CameraMake}=~/^SANYO/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sanyo::Main',
            Validate => '$val =~ /^SANYO/',
            Start => '$valuePtr + 8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSigma',
        # (starts with "SIGMA\0")
        Condition => '$self->{CameraMake}=~/^(SIGMA|FOVEON)/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sigma::Main',
            Validate => '$val =~ /^(SIGMA|FOVEON)/',
            Start => '$valuePtr + 10',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSony',
        # (starts with "SONY DSC \0")
        Condition => '$self->{CameraMake}=~/^SONY/ and $self->{TIFF_TYPE}!~/^(SRF|SR2)$/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::Main',
            # validate the maker note because this is sometimes garbage
            Validate => 'defined($val) and $val =~ /^SONY DSC/',
            Start => '$valuePtr + 12',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSonySRF',
        Condition => '$self->{CameraMake}=~/^SONY/ and $self->{TIFF_TYPE} eq "SRF"',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::SRF',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSonySR2',
        Condition => '$self->{CameraMake}=~/^SONY/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::Main',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteUnknown',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Unknown::Main',
            ProcessProc => \&ProcessUnknown,
            ByteOrder => 'Unknown',
        },
    },
);

# insert writable properties so we can write our maker notes
my $tagInfo;
foreach $tagInfo (@Image::ExifTool::MakerNotes::Main) {
    $$tagInfo{Writable} = 'undef';
    $$tagInfo{WriteGroup} = 'ExifIFD';
    next unless $$tagInfo{SubDirectory};
    # set up this tag so we can write it
    $$tagInfo{ValueConv} = '\$val';
    $$tagInfo{ValueConvInv} = '$val';
    $$tagInfo{MakerNotes} = 1;
}

#------------------------------------------------------------------------------
# Get normal offset (absolute) of value data from end of maker note IFD
# Inputs: 0) ExifTool object reference
# Returns: (array) 0) expected offset, 1) relative flag (undef for no change)
# Notes: Directory size should be validated before calling this routine
sub GetMakerNoteOffset($)
{
    my $exifTool = shift;
    # figure out where we expect the value data based on camera type
    my $make = $exifTool->{CameraMake};
    my $model = $exifTool->{CameraModel};
    my ($offset, $relative);
    if ($make =~ /^Canon/ and $model =~ /\b(20D|350D|REBEL XT)\b/) {
        $offset = 6;
    } elsif ($make =~ /^KYOCERA/) {
        $offset = 12;
    } elsif ($make =~ /^OLYMPUS/ and $model =~ /^E-(1|300)\b/) {
        $offset = 16;
    } elsif ($make =~ /^OLYMPUS/ and $model =~ /^C2500L\b/) {
        $offset = undef;   # these are just weird
    } elsif ($make =~ /^(Panasonic|SONY|JVC|TOSHIBA)\b/) {
        $offset = 0;
    } elsif ($make =~ /^PENTAX/) {
        $offset = 4;
        # the Pentax addressing mode is determined automatically, but
        # sometimes the algorithm gets it wrong, but Pentax always uses
        # absolute addressing, so force it to be absolute
        $relative = 0;
    } else {
        # normally, value data starts 4 bytes after end of directory
        $offset = 4;
    }
    return ($offset, $relative);
}

#------------------------------------------------------------------------------
# Find start of IFD in unknown maker notes
# Inputs: 0) reference to directory information
# Returns: offset to IFD on success, undefined otherwise
# - dirInfo may contain TagInfo reference for tag associated with directory
# - on success, updates DirStart, DirLen, Base and DataPos in dirInfo
# - also sets Relative flag in dirInfo if offsets are relative to IFD
# Note: Changes byte ordering!
sub LocateIFD($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $size = $$dirInfo{DirLen} || ($$dirInfo{DataLen} - $dirStart);
    my $tagInfo = $$dirInfo{TagInfo};
    my $ifdOffsetPos;
    # the IFD should be within the first 32 bytes
    # (Kyocera sets the current record at 22 bytes)
    my ($firstTry, $lastTry) = (0, 32);

    # make sure Base and DataPos are defined
    $$dirInfo{Base} or $$dirInfo{Base} = 0;
    $$dirInfo{DataPos} or $$dirInfo{DataPos} = 0;
#
# use tag information (if provided) to determine directory location
#
    if ($tagInfo and $$tagInfo{SubDirectory}) {
        my $subdir = $$tagInfo{SubDirectory};
        unless ($$subdir{ProcessProc} and $$subdir{ProcessProc} eq \&ProcessUnknown) {
            # look for the IFD at the "Start" specified in our SubDirectory information
            my $valuePtr = $dirStart;
            my $newStart = $dirStart;
            if (defined $$subdir{Start}) {
                #### eval Start ($valuePtr)
                $newStart = eval($$subdir{Start});
            }
            if ($$subdir{Base}) {
                # calculate subdirectory start relative to $base for eval
                my $start = $newStart + $$dirInfo{DataPos};
                #### eval Base ($start)
                my $baseShift = eval($$subdir{Base});
                # shift directory base (note: we may do this again below
                # if an OffsetPt is defined, but that doesn't matter since
                # the base shift is relative to DataPos, which we set too)
                $$dirInfo{Base} += $baseShift;
                $$dirInfo{DataPos} -= $baseShift;
                # this is a relative directory if Base depends on $start
                $$dirInfo{Relative} = 1 if $$subdir{Base} =~ /\$start\b/;
            }
            # add offset to the start of the directory if necessary
            if ($$subdir{OffsetPt}) {
                if ($$subdir{ByteOrder} =~ /^Little/i) {
                    SetByteOrder('II');
                } elsif ($$subdir{ByteOrder} =~ /^Big/i) {
                    SetByteOrder('MM');
                } else {
                    warn "Can't have variable byte ordering for SubDirectories using OffsetPt\n";
                    return undef;
                }
                #### eval OffsetPt ($valuePtr)
                $ifdOffsetPos = eval($$subdir{OffsetPt}) - $dirStart;
            }
            # pinpoint position to look for this IFD
            $firstTry = $lastTry = $newStart - $dirStart;
        }
    }
#
# scan for something that looks like an IFD
#
    if ($size >= 14 + $firstTry) {  # minimum size for an IFD
        my $offset;
IFD_TRY: for ($offset=$firstTry; $offset<=$lastTry; $offset+=2) {
            last if $offset + 14 > $size;    # 14 bytes is minimum size for an IFD
            my $pos = $dirStart + $offset;
#
# look for a standard TIFF header (Nikon uses it, others may as well),
#
            if (SetByteOrder(substr($$dataPt, $pos, 2)) and
                Get16u($dataPt, $pos + 2) == 0x2a)
            {
                $ifdOffsetPos = 4;
            }
            if (defined $ifdOffsetPos) {
                # get pointer to IFD
                my $ptr = Get32u($dataPt, $pos + $ifdOffsetPos);
                if ($ptr >= $ifdOffsetPos + 4 and $ptr + $offset + 14 <= $size) {
                    # shift directory start and shorten dirLen accordingly
                    $$dirInfo{DirStart} += $ptr + $offset;
                    $$dirInfo{DirLen} -= $ptr + $offset;
                    # shift pointer base to the start of the TIFF header
                    my $shift = $$dirInfo{DataPos} + $dirStart + $offset;
                    $$dirInfo{Base} += $shift;
                    $$dirInfo{DataPos} -= $shift;
                    $$dirInfo{Relative} = 1;   # set "relative offsets" flag
                    return $ptr + $offset;
                }
                undef $ifdOffsetPos;
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
                next IFD_TRY if $format < 1 or $format > 13;
                # count must be reasonable
                next IFD_TRY if $count == 0 or $count > 0x10000;
            }
            $$dirInfo{DirStart} += $offset;    # update directory start
            $$dirInfo{DirLen} -= $offset;
            return $offset;   # success!!
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Process unknown maker notes assuming it is in EXIF IFD format
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success, and updates $dirInfo if necessary for new directory
sub ProcessUnknown($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $success = 0;

    my $loc = LocateIFD($exifTool,$dirInfo);
    if (defined $loc) {
        if ($exifTool->Options('Verbose') > 1) {
            my $out = $exifTool->Options('TextOut');
            my $indent = $exifTool->{INDENT};
            $indent =~ s/\| $/  /;
            printf $out "${indent}Found IFD at offset 0x%.4x in maker notes:\n",
                    $$dirInfo{DirStart} + $$dirInfo{DataPos} + $$dirInfo{Base};
        }
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
    } else {
        $exifTool->Warn("Unrecognized $$dirInfo{DirName}");
    }
    return $success;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::MakerNotes - Read and write EXIF maker notes

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames(3pm)|Image::ExifTool::TagNames>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
