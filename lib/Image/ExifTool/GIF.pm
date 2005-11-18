#------------------------------------------------------------------------------
# File:         GIF.pm
#
# Description:  Read and write GIF meta information
#
# Revisions:    10/18/2005 - P. Harvey Separated from ExifTool.pm
#
# Notes:        GIF really doesn't have much meta information, except for comments
#------------------------------------------------------------------------------

package Image::ExifTool::GIF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.00';

#------------------------------------------------------------------------------
# Process meta information in GIF image
# Inputs: 0) ExifTool object reference, 1) Directory information ref
# Returns: 1 on success, 0 if this wasn't a valid GIF file, or -1 if
#          an output file was specified and a write error occurred
sub ProcessGIF($$)
{
    my ($exifTool, $dirInfo) = @_;
    my ($type, $a, $s, $ch, $length, $buff);
    my ($err, $newComment, $setComment);
    my $verbose = $exifTool->Options('Verbose');
    my $outfile = $$dirInfo{OutFile};
    my $raf = $$dirInfo{RAF};
    my $rtnVal = 0;

    # verify this is a valid GIF file
    # (must do a RAF read until we know the file is ours)
    return 0 unless $raf->Read($type, 6) == 6
        and $type =~ /^GIF8[79]a$/
        and $raf->Read($s, 4) == 4;

    $verbose and print "GIF file version $type\n";
    if ($outfile) {
        Write($outfile, $type, $s) or $err = 1;
        if ($exifTool->{DEL_GROUP} and $exifTool->{DEL_GROUP}->{File}) {
            $setComment = 1;
        } else {
            my $newValueHash;
            $newComment = $exifTool->GetNewValues('Comment', \$newValueHash);
            $setComment = 1 if $newValueHash;
        }
    }
    $exifTool->SetFileType();   # set file type
    my ($w, $h) = unpack("v"x2, $s);
    $exifTool->FoundTag('ImageWidth', $w);
    $exifTool->FoundTag('ImageHeight', $h);
    if ($raf->Read($s, 3) == 3) {
        Write($outfile, $s) or $err = 1 if $outfile;
        if (ord($s) & 0x80) { # does this image contain a color table?
            # calculate color table size
            $length = 3 * (2 << (ord($s) & 0x07));
            $raf->Read($buff, $length) == $length or return 0; # skip color table
            Write($outfile, $buff) or $err = 1 if $outfile;
            # write the comment first if necessary
            if ($outfile and defined $newComment) {
                if ($type ne 'GIF87a') {
                    # write comment marker
                    Write($outfile, "\x21\xfe") or $err = 1;
                    my $len = length($newComment);
                    # write out the comment in 255-byte chunks, each
                    # chunk beginning with a length byte
                    my $n;
                    for ($n=0; $n<$len; $n+=255) {
                        my $size = $len - $n;
                        $size > 255 and $size = 255;
                        my $str = substr($newComment,$n,$size);
                        Write($outfile, pack('C',$size), $str) or $err = 1;
                    }
                    Write($outfile, "\0") or $err = 1;  # empty chunk as terminator
                    undef $newComment;
                    ++$exifTool->{CHANGED};     # increment file changed flag
                } else {
                    $exifTool->Warn("The GIF87a format doesn't support comments");
                }
            }
            my $comment;
            for (;;) {
                last unless $raf->Read($ch, 1);
                if (ord($ch) == 0x2c) {
                    Write($outfile, $ch) or $err = 1 if $outfile;
                    # image descriptor
                    last unless $raf->Read($buff, 8) == 8;
                    last unless $raf->Read($ch, 1);
                    Write($outfile, $buff, $ch) or $err = 1 if $outfile;
                    if (ord($ch) & 0x80) { # does color table exist?
                        $length = 3 * (2 << (ord($ch) & 0x07));
                        # skip the color table
                        last unless $raf->Read($buff, $length) == $length;
                        Write($outfile, $buff) or $err = 1 if $outfile;
                    }
                    # skip "LZW Minimum Code Size" byte
                    last unless $raf->Read($buff, 1);
                    Write($outfile,$buff) or $err = 1 if $outfile;
                    # skip image blocks
                    for (;;) {
                        last unless $raf->Read($ch, 1);
                        Write($outfile, $ch) or $err = 1 if $outfile;
                        last unless ord($ch);
                        last unless $raf->Read($buff, ord($ch));
                        Write($outfile,$buff) or $err = 1 if $outfile;
                    }
                    next;  # continue with next field
                }
#               last if ord($ch) == 0x3b;  # normal end of GIF marker
                unless (ord($ch) == 0x21) {
                    if ($outfile) {
                        Write($outfile, $ch) or $err = 1;
                        # copy the rest of the file
                        while ($raf->Read($buff, 65536)) {
                            Write($outfile, $buff) or $err = 1;
                        }
                    }
                    $rtnVal = 1;
                    last;
                }
                # get extension block type/size
                last unless $raf->Read($s, 2) == 2;
                # get marker and block size
                ($a,$length) = unpack("C"x2, $s);
                if ($a == 0xfe) {  # is this a comment?
                    if ($setComment) {
                        ++$exifTool->{CHANGED}; # increment the changed flag
                    } else {
                        Write($outfile, $ch, $s) or $err = 1 if $outfile;
                    }
                    while ($length) {
                        last unless $raf->Read($buff, $length) == $length;
                        $exifTool->{OPTIONS}->{Verbose} > 2 and HexDump(\$buff);
                        if (defined $comment) {
                            $comment .= $buff;  # add to comment string
                        } else {
                            $comment = $buff;
                        }
                        last unless $raf->Read($ch, 1);  # read next block header
                        unless ($setComment) {
                            Write($outfile, $buff, $ch) or $err = 1 if $outfile;
                        }
                        $length = ord($ch);  # get next block size
                    }
                    last if $length;    # was a read error if length isn't zero
                    # all done once we have found the comment unless writing file
                    unless ($outfile) {
                        $rtnVal = 1;
                        last;
                    }
                } else {
                    Write($outfile, $ch, $s) or $err = 1 if $outfile;
                    # skip the block
                    while ($length) {
                        last unless $raf->Read($buff, $length) == $length;
                        Write($outfile, $buff) or $err = 1 if $outfile;
                        last unless $raf->Read($ch, 1);  # read next block header
                        Write($outfile, $ch) or $err = 1 if $outfile;
                        $length = ord($ch);  # get next block size
                    }
                }
            }
            $exifTool->FoundTag('Comment', $comment) if $comment;
        }
    }
    # set return value to -1 if we only had a write error
    $rtnVal = -1 if $rtnVal and $err;
    return $rtnVal;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::GIF - Read and write GIF meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write GIF meta information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
