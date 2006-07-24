#------------------------------------------------------------------------------
# File:         Flash.pm
#
# Description:  Read Shockwave Flash meta information
#
# Revisions:    05/16/2006 - P. Harvey Created
#
# References:   1) http://www.the-labs.com/MacromediaFlash/SWF-Spec/SWFfileformat.html
#               2) http://sswf.sourceforge.net/SWFalexref.html
#------------------------------------------------------------------------------

package Image::ExifTool::Flash;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

%Image::ExifTool::Flash::Main = (
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        The information below is extracted from the header of SWF (Shockwave Flash)
        files.
    },
    FlashVersion => { },
    Compressed => { PrintConv => { 0 => 'False', 1 => 'True' } },
    ImageWidth => { },
    ImageHeight => { },
    FrameRate => { },
    FrameCount => { },
    Duration => {
        Notes => 'calculated from FrameRate and FrameCount',
        PrintConv => 'sprintf("%.2f sec",$val)',
    },
);

#------------------------------------------------------------------------------
# Found a Flash tag
# Inputs: 0) ExifTool object ref, 1) tag name, 2) tag value
sub FoundFlashTag($$$)
{
    my ($exifTool, $tag, $val) = @_;
    $exifTool->HandleTag(\%Image::ExifTool::Flash::Main, $tag, $val);
}

#------------------------------------------------------------------------------
# Read information frame a Flash file
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid Flash file
sub ProcessSWF($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $verbose = $exifTool->Options('Verbose');
    my $raf = $$dirInfo{RAF};
    my $buff;

    $raf->Read($buff, 8) == 8 or return 0;
    $buff =~ /^(F|C)WS([^\0])/ or return 0;
    my ($compressed, $vers) = ($1 eq 'C' ? 1 : 0, ord($2));

    # read the first bit of the file
    $raf->Read($buff, 64) or return 0;

    $exifTool->SetFileType();
    GetTagTable('Image::ExifTool::Flash::Main');  # make sure table is initialized

    FoundFlashTag($exifTool, FlashVersion => $vers);
    FoundFlashTag($exifTool, Compressed => $compressed);

    # uncompress if necessary
    if ($compressed) {
        unless (eval 'require Compress::Zlib') {
            $exifTool->Warn('Install Compress::Zlib to extract compressed information');
            return 1;
        }
        my $inflate = Compress::Zlib::inflateInit();
        my $tmp = $buff;
        $buff = '';
        # read file 64 bytes at a time and inflate until we get enough uncompressed data
        for (;;) {
            unless ($inflate) {
                $exifTool->Warn('Error inflating compressed Flash data');
                return 1;
            }
            my ($dat, $stat) = $inflate->inflate($tmp);
            if ($stat == Compress::Zlib::Z_STREAM_END() or
                $stat == Compress::Zlib::Z_OK())
            {
                $buff .= $dat;  # add inflated data to buffer
                last if length $buff >= 64 or $stat == Compress::Zlib::Z_STREAM_END();
                $raf->Read($tmp,64) or last;    # read some more data
            } else {
                undef $inflate; # issue warning the next time around
            }
        }
    }
    # unpack elements of bit-packed Flash Rect structure
    my ($nBits, $totBits, $nBytes);
    for (;;) {
        if (length($buff)) {
            $nBits = unpack('C', $buff) >> 3;    # bits in x1,x2,y1,y2 elements
            $totBits = 5 + $nBits * 4;           # total bits in Rect structure
            $nBytes = int(($totBits + 7) / 8);   # byte length of Rect structure
            last if length $buff >= $nBytes + 4; # make sure header is long enough
        }
        $exifTool->Warn('Truncated Flash file');
        return 1;
    }
    my $bits = unpack("B$totBits", $buff);
    # isolate Rect elements and convert from ASCII bit strings to integers
    my @vals = unpack('x5' . "a$nBits" x 4, $bits);
    # (do conversion the hard way because oct("0b$val") requires Perl 5.6)
    map { $_ = unpack('N', pack('B32', '0' x (32 - length $_) . $_)) } @vals;

    # calculate and store ImageWidth/Height
    FoundFlashTag($exifTool, ImageWidth  => ($vals[1] - $vals[0]) / 20);
    FoundFlashTag($exifTool, ImageHeight => ($vals[3] - $vals[2]) / 20);

    # get frame rate and count
    @vals = unpack("x${nBytes}v2", $buff);
    FoundFlashTag($exifTool, FrameRate => $vals[0] / 256);
    FoundFlashTag($exifTool, FrameCount => $vals[1]);
    FoundFlashTag($exifTool, Duration => $vals[1] * 256 / $vals[0]) if $vals[0];

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Flash - Read Shockwave Flash meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read SWF
(Shockwave Flash) files.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.the-labs.com/MacromediaFlash/SWF-Spec/SWFfileformat.html>

=item L<http://sswf.sourceforge.net/SWFalexref.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Flash Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

