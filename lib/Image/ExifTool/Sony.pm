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

$VERSION = '1.01';

%Image::ExifTool::Sony::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
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
documentation.  The only one I recognize is the PrintIM block.  To figure
them out will require someone with a Sony camera who is willing to
systematically change all the settings and determine where they are stored
in these blocks.  You can use "exiftool -v3" to dump these blocks in hex.
Please send me any information you may collect about the format of the Sony
maker notes.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
