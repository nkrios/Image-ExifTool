#------------------------------------------------------------------------------
# File:         Olympus.pm
#
# Description:  Definitions for Olympus/Epson EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#               11/11/2004 - P. Harvey Added Epson support
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) http://www.cybercom.net/~dcoffin/dcraw/
#------------------------------------------------------------------------------

package Image::ExifTool::Olympus;

use strict;
use vars qw($VERSION);

$VERSION = '1.06';

%Image::ExifTool::Olympus::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0200 => {
        Name => 'SpecialMode',
        Writable => 'int32u',
        Count => 3,
    },
    0x0201 => [
        {
            # for some reason, the values for the E-1 start at 1 instead of 0
            Condition => '$self->{CameraModel} =~ /^E-1/',
            Name => 'Quality',
            Description => 'Image Quality',
            Writable => 'int16u',
            PrintConv => { 1 => 'SQ', 2 => 'HQ', 3 => 'SHQ', 4 => 'RAW' },
        },
        {
            # all other models...
            Name => 'Quality',
            Description => 'Image Quality',
            Writable => 'int16u',
            PrintConv => { 0 => 'SQ', 1 => 'HQ', 2 => 'SHQ' },
        },
    ],
    0x0202 => {
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x0204 => {
        Name => 'DigitalZoom',
        Writable => 'rational32u',
    },
    0x0207 => 'SoftwareRelease',
    0x0208 => 'PictInfo',
    0x0209 => 'CameraID',
    0x020b => {
        Name => 'EpsonImageWidth', #PH
        Writable => 'int16u',
    },
    0x020c => {
        Name => 'EpsonImageHeight', #PH
        Writable => 'int16u',
    },
    0x020d => 'EpsonSoftware', #PH
    0x0f00 => {
        Name => 'DataDump',
        Writable => 0,
        PrintConv => '\$val',
    },
    0x1017 => { #2
        Name => 'RedBalance',
        Writable => 'int16u',
        Count => 2,
        ValueConv => '$val=~s/ .*//; $val / 256',
        ValueConvInv => '$val*=256;"$val 64"',
    },
    0x1018 => { #2
        Name => 'BlueBalance',
        Writable => 'int16u',
        Count => 2,
        ValueConv => '$val=~s/ .*//; $val / 256',
        ValueConvInv => '$val*=256;"$val 64"',
    },
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

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
