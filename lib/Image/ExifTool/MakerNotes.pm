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
use Image::ExifTool qw(Get16u Get16s Get32u Get32s GetFloat GetDouble
                       GetByteOrder SetByteOrder ToggleByteOrder);

sub ProcessUnknown($$$);

$VERSION = '1.00';

# conditional list of maker notes
# (Note: This is NOT a normal tag table)
@Image::ExifTool::MakerNotes::Main = (
    # decide which MakerNotes to use (based on camera make/model)
    {
        Condition => '$self->{CameraMake} =~ /^Canon/',
        Name => 'MakerNoteCanon',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Main',
            Start => '$valuePtr',
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
            # (before adding the offsetPt).  Weird - PH
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
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^(OLYMPUS|SEIKO EPSON)/',
        Name => 'MakerNoteOlympus',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Main',
            Start => '$valuePtr+8',
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^Panasonic/',
        Name => 'MakerNotePanasonic',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+12',
        },
    },
    {
        Condition => '$self->{CameraMake} =~ /^LEICA/',
        Name => 'MakerNoteLeica',
        SubDirectory => {
            # Leica uses the same format as Panasonic
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+8',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^NIKON/',
        Name => 'MakerNoteNikon',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Main',
            Start => '$valuePtr',
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
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^Minolta/',
        Name => 'MakerNoteMinolta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            Start => '$valuePtr',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^SANYO/',
        Name => 'MakerNoteSanyo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sanyo::Main',
            Validate => '$val =~ /^SANYO/',
            Start => '$valuePtr + 8',
        },
    },
    {
        Condition => '$self->{CameraMake}=~/^(SIGMA|FOVEON)/',
        Name => 'MakerNoteSigma',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sigma::Main',
            Validate => '$val =~ /^(SIGMA|FOVEON)/',
            Start => '$valuePtr + 10',
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
        },
    },
    {
        Name => 'MakerNoteUnknown',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Unknown::Main',
            ProcessProc => \&ProcessUnknown,
            Start => '$valuePtr',
        },
    },
);

#------------------------------------------------------------------------------
# Process unknown maker notes assuming it is in EXIF IFD format
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
sub ProcessUnknown($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $offset = $dirInfo->{DirStart};
    my $size = $dirInfo->{DirLen};
    my $success = 0;
    
    # scan for something that looks like an IFD
    if ($size >= 14) {  # minimum size for an IFD
        my $saveOrder = GetByteOrder();
        my $i;
IFD_TRY: for ($i=0; $i<=20; $i+=2) {
            last if $i + 14 > $size;
            my $num = Get16u($dataPt, $offset + $i);
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
            my $bytesFromEnd = $size - ($i + 2 + 12 * $num);
            if ($bytesFromEnd < 4) {
                next unless $bytesFromEnd==2 or $bytesFromEnd==0;
            }
            # do a quick validation of all format types
            my $index;
            for ($index=0; $index<$num; ++$index) {
                my $entry = $offset + $i + 2 + 12 * $index;
                my $format = Get16u($dataPt, $entry+2);
                if ($format < 1 or $format > 12) {
                    # allow a 0 format (for null padding) unless first entry
                    next IFD_TRY unless $format == 0 and $index;
                }
            }
            if ($exifTool->Options('Verbose') > 1) {
                print "Found IFD at offset $i in unknown maker notes\n";
            }
            # looks like we found an IFD
            $dirInfo->{DirStart} = $offset + $i;
            $dirInfo->{DirLen} = $size - $i;
            # process like a standard EXIF directory
            $success = Image::ExifTool::Exif::ProcessExif($exifTool, $tagTablePtr, $dirInfo);
            last;
        }
        SetByteOrder($saveOrder);
    }
    # this makernote doesn't appear to be in standard IFD format
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

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
