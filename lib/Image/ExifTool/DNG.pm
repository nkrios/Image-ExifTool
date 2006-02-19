#------------------------------------------------------------------------------
# File:         DNG.pm
#
# Description:  Extract DNG-specific information
#
# Revisions:    01/09/2006 - P. Harvey Created
#
# References:   1) http://www.adobe.com/products/dng/pdfs/dng_spec.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::DNG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

sub ProcessOriginalRaw($$$);

# data in OriginalRawFileData
%Image::ExifTool::DNG::OriginalRaw = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessOriginalRaw,
    NOTES => q{
        This table defines tags extracted from the DNG OriginalRawFileData
        information.  All other DNG tags are defined in the EXIF table.
    },
    0 => { Name => 'OriginalRawImage',    ValueConv => '\$val' },
    1 => { Name => 'OriginalRawResource', ValueConv => '\$val' },
    2 => 'OriginalRawFileType',
    3 => 'OriginalRawCreator',
    4 => { Name => 'OriginalTHMImage',    ValueConv => '\$val' },
    5 => { Name => 'OriginalTHMResource', ValueConv => '\$val' },
    6 => 'OriginalTHMFileType',
    7 => 'OriginalTHMCreator',
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

1; # end

__END__

=head1 NAME

Image::ExifTool::DNG.pm - Extract DNG-specific information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains main definitions required by Image::ExifTool to
interpret DNG meta information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=item L<http://www.adobe.com/products/dng/pdfs/dng_spec.pdf>

=cut
