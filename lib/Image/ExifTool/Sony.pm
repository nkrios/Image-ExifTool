#------------------------------------------------------------------------------
# File:         Sony.pm
#
# Description:  Definitions for Sony EXIF Maker Notes
#
# Revisions:    04/06/2004  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Sony;

use strict;
use vars qw($VERSION);

$VERSION = '1.02';

%Image::ExifTool::Sony::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },

    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Sony - Definitions for Sony EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Sony maker notes EXIF meta information.

=head1 NOTES

The Sony maker notes use the standard EXIF IFD structure, but unfortunately
the entries are large blocks of binary data for which I can find no
documentation.  You can use "exiftool -v3" to dump these blocks in hex.  I
suspect they are encrypted, possibly using the same encryption algorithm as
used for the RAW image data which has been broken in dcraw by Dave Coffin.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sony Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
