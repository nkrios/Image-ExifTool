#------------------------------------------------------------------------------
# File:         DNG.pm
#
# Description:  Read DNG-specific information
#
# Revisions:    01/09/2006 - P. Harvey Created
#
# References:   1) http://www.adobe.com/products/dng/pdfs/dng_spec.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::DNG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

sub ProcessOriginalRaw($$$);
sub ProcessDNGMakerNotes($$$);

# data in OriginalRawFileData
%Image::ExifTool::DNG::OriginalRaw = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessOriginalRaw,
    NOTES => q{
        This table defines tags extracted from the DNG OriginalRawFileData
        information.  All other DNG tags are defined in the EXIF table.
    },
    0 => { Name => 'OriginalRawImage',    Binary => 1 },
    1 => { Name => 'OriginalRawResource', Binary => 1 },
    2 => 'OriginalRawFileType',
    3 => 'OriginalRawCreator',
    4 => { Name => 'OriginalTHMImage',    Binary => 1 },
    5 => { Name => 'OriginalTHMResource', Binary => 1 },
    6 => 'OriginalTHMFileType',
    7 => 'OriginalTHMCreator',
);

# data in DNG Adobe maker notes
%Image::ExifTool::DNG::MakerNotes = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessDNGMakerNotes,
    NOTES => q{
        This information is always big-endian, and is found in the DNGPrivateData
        with a prefix of "Adobe\0MakN".  Following OriginalMakerNoteOffset is a copy
        of the maker notes from the original raw file.  These notes are processed by
        ExifTool, but some information may have been lost by the Adobe DNG Converter
        during conversion.  The reason is that DNG Converter (version 3.3) doesn't
        realize that the maker notes may reference information outside the maker
        note block, and this information is lost when only the maker note block is
        copied to the DNG image.   While this isn't a big problem for most Canon,
        Nikon or Pentax camera models, it is serious for some Olympus models.
    },
    10 => {
        Name => 'MakerNoteLength',
        Format => 'int32u',
        ValueConv => '$val - 6',
    },
    14 => {
        Name => 'MakerNoteByteOrder',
        Format => 'string[2]',
    },
    16 => {
        Name => 'OriginalMakerNoteOffset',
        Format => 'int32u',
    },
);

#------------------------------------------------------------------------------
# Process DNG OriginalRawFileData information
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessOriginalRaw($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $end = $start + $$dirInfo{DirLen};
    my $pos = $start;
    my ($index, $err);
    SetByteOrder('MM'); # pointers are always big-endian in this structure
    for ($index=0; $index<8; ++$index) {
        last if $pos + 4 > $end;
        my $val = Get32u($dataPt, $pos);
        $val or $pos += 4, next; # ignore zero values
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $index);
        $tagInfo or $err = "Missing DNG tag $index", last;
        if ($index & 0x02) {
            # extract a simple file type (tags 2, 3, 6 and 7)
            $val = substr($$dataPt, $pos, 4);
            $pos += 4;
        } else {
            # extract a compressed data block (tags 0, 1, 4 and 5)
            my $n = int(($val + 65535) / 65536);
            my $hdrLen = 4 * ($n + 2);
            $pos + $hdrLen > $end and $err = '', last;
            my $tag = $$tagInfo{Name};
            # only extract this information if requested (because it takes time)
            if ($exifTool->{OPTIONS}->{Binary} or
                $exifTool->{REQ_TAG_LOOKUP}->{lc($tag)})
            {
                unless (eval 'require Compress::Zlib') {
                    $err = 'Install Compress::Zlib to extract compressed images';
                    last;
                }
                my $i;
                $val = '';
                my $p2 = $pos + Get32u($dataPt, $pos + 4);
                for ($i=0; $i<$n; ++$i) {
                    # inflate this compressed block
                    my $p1 = $p2;
                    $p2 = $pos + Get32u($dataPt, $pos + ($i + 2) * 4);
                    if ($p1 >= $p2 or $p2 > $end) {
                        $err = 'Bad compressed RAW image';
                        last;
                    }
                    my $buff = substr($$dataPt, $p1, $p2 - $p1);
                    my ($v2, $stat);
                    my $inflate = Compress::Zlib::inflateInit();
                    $inflate and ($v2, $stat) = $inflate->inflate($buff);
                    if ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                        $val .= $v2;
                    } else {
                        $err = 'Error inflating compressed RAW image';
                        last;
                    }
                }
                $pos = $p2;
            } else {
                $pos + $hdrLen > $end and $err = '', last;
                my $len = Get32u($dataPt, $pos + $hdrLen - 4);
                $pos + $len > $end and $err = '', last;
                $val = substr($$dataPt, $pos + $hdrLen, $len - $hdrLen);
                $val = "Binary data $len bytes";
                $pos += $len;   # skip over this block
            }
        }
        $exifTool->FoundTag($tagInfo, $val);
    }
    $exifTool->Warn($err || 'Bad OriginalRawFileData') if defined $err;
    return 1;
}

#------------------------------------------------------------------------------
# Process DNG Adobe maker notes information
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessDNGMakerNotes($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $len = $$dirInfo{DirLen};
    my $success = 0;
    # extract the binary data tags
    SetByteOrder('MM'); # always big endian
    Image::ExifTool::ProcessBinaryData($exifTool, $dirInfo, $tagTablePtr);
    for (;;) {
        last unless $len > 20;
        my $originalPos = Get32u($dataPt, $start + 16);
        last unless SetByteOrder(substr($$dataPt, $start+14,2));
        $success = 1;
        my $dataPos = $$dirInfo{DataPos};
        my $exifTable = GetTagTable('Image::ExifTool::Exif::Main');
        my $dirStart = $start + 20; # pointer to maker note directory
        my $dirLen = $len - 20;
        my $hdr = substr($$dataPt, $dirStart, $dirLen < 48 ? $dirLen : 48);
        my $tagInfo = $exifTool->GetTagInfo($exifTable, 0x927c, \$hdr);
        last unless $tagInfo and $$tagInfo{SubDirectory};
        my $subdir = $$tagInfo{SubDirectory};
        my $subTable = GetTagTable($$subdir{TagTable}) || $exifTable;
        my $fix = $dataPos + $dirStart - $originalPos;
        if (defined $$subdir{Start}) {
            # set local $valuePtr relative to file $base for eval
            my $valuePtr = $dirStart + $dataPos;
            #### eval Start ($valuePtr)
            $dirStart = eval($$subdir{Start});
            # convert back to relative to $dataPt
            $dirStart -= $dataPos;
        }
        # initialize subdirectory information
        my %subdirInfo = (
            DirName   => $$tagInfo{Name},
            Base      => $$dirInfo{Base},
            DataPt    => $dataPt,
            DataPos   => $dataPos,
            DataLen   => $$dirInfo{DataLen},
            DirStart  => $dirStart,
            DirLen    => $len - $dirStart,
            TagInfo   => $tagInfo,
            FixBase   => $$subdir{FixBase},
            EntryBased=> $$subdir{EntryBased},
            Parent    => $$dirInfo{DirName},
        );
        # set base offset if necessary
        if ($$subdir{Base}) {
            # calculate subdirectory start relative to $base for eval
            my $start = $dirStart + $dataPos;
            my $baseShift = eval($$subdir{Base});
            #### eval Base ($start)
            $subdirInfo{Base} += $baseShift;
            $subdirInfo{DataPos} -= $baseShift;
        } else {
            # adjust base offset for current maker note position
            $subdirInfo{Base} += $fix;
            $subdirInfo{DataPos} -= $fix;
        }
        # add offset to the start of the directory if necessary
        if ($$subdir{OffsetPt}) {
            my $valuePtr = $dirStart;
            #### eval OffsetPt ($valuePtr)
            my $offset = Get32u($dataPt, eval $$subdir{OffsetPt});
            $subdirInfo{DirStart} += $offset;
            $subdirInfo{DirLen} -= $offset;
        }
        $exifTool->ProcessDirectory(\%subdirInfo, $subTable, $$subdir{ProcessProc});
        last;
    }
    $success or $exifTool->Warn('Bad DNG Adobe maker notes');
    return $success;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::DNG.pm - Read DNG-specific information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains main definitions required by Image::ExifTool to
interpret DNG meta information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.adobe.com/products/dng/pdfs/dng_spec.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DNG Tags>,
L<Image::ExifTool::TagNames/EXIF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
