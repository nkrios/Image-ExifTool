#------------------------------------------------------------------------------
# File:         Olympus.pm
#
# Description:  Definitions for Olympus/Epson EXIF Maker Notes
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#
# Revisions:    12/09/2003 - P. Harvey Created
#               11/11/2004 - P. Harvey Added Epson support
#------------------------------------------------------------------------------

package Image::ExifTool::Olympus;

use strict;
use vars qw($VERSION);

$VERSION = '1.02';

%Image::ExifTool::Olympus::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0200 => 'SpecialMode',
    0x0201 => { 
        Name => 'Quality', 
        Description => 'Image Quality',
        PrintConv => { 0 => 'SQ', 1 => 'HQ', 2 => 'SHQ' },
    },
    0x0202 => { 
        Name => 'Macro', 
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x0204 => 'DigitalZoom',
    0x0207 => 'SoftwareRelease',
    0x0208 => 'PictInfo',
    0x0209 => 'CameraID',
    0x020b => 'EpsonImageWidth', #PH
    0x020c => 'EpsonImageHeight', #PH
    0x020d => 'EpsonSoftware', #PH
    0x0f00 => 'DataDump',
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Olympus - Definitions for Olympus/Epson maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Olympus or Epson maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
