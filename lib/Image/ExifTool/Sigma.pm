#------------------------------------------------------------------------------
# File:         Sigma.pm
#
# Description:  Definitions for Sigma/Foveon EXIF Maker Notes
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# Reference:    http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html
#------------------------------------------------------------------------------

package Image::ExifTool::Sigma;

use strict;
use vars qw($VERSION);

$VERSION = '1.02';

%Image::ExifTool::Sigma::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0002 => 'SerialNumber',
    0x0003 => 'DriveMode',
    0x0004 => 'ResolutionMode',
    0x0005 => 'AFMode',
    0x0006 => 'FocusSetting',
    0x0007 => 'WhiteBalance',
    0x0008 => 'ExposureMode',
    0x0009 => 'MeteringMode',
    0x000a => 'Lens',
    0x000b => 'ColorSpace',
    0x000c => {
        Name => 'ExposureCompensation',
        ValueConv => '$val =~ s/Expo:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("Expo:%+.1f",$val) : undef',
    },
    0x000d => {
        Name => 'Contrast',
        ValueConv => '$val =~ s/Cont:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("Cont:%+.1f",$val) : undef',
    },
    0x000e => {
        Name => 'Shadow',
        ValueConv => '$val =~ s/Shad:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("Shad:%+.1f",$val) : undef',
    },
    0x000f => {
        Name => 'Highlight',
        ValueConv => '$val =~ s/High:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("High:%+.1f",$val) : undef',
    },
    0x0010 => {
        Name => 'Saturation',
        ValueConv => '$val =~ s/Satu:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("Satu:%+.1f",$val) : undef',
    },
    0x0011 => {
        Name => 'Sharpness',
        ValueConv => '$val =~ s/Shar:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("Shar:%+.1f",$val) : undef',
    },
    0x0012 => {
        Name => 'X3FillLight',
        ValueConv => '$val =~ s/Fill:\s*//, $val',
        ValueConvInv => 'IsFloat($val) ? sprintf("Fill:%+.1f",$val) : undef',
    },
    0x0014 => {
        Name => 'ColorAdjustment',
        ValueConv => '$val =~ s/CC:\s*//, $val',
        ValueConvInv => 'IsInt($val) ? "CC:$val" : undef',
    },
    0x0015 => 'AdjustmentMode',
    0x0016 => {
        Name => 'Quality',
        ValueConv => '$val =~ s/Qual:\s*//, $val',
        ValueConvInv => 'IsInt($val) ? "Qual:$val" : undef',
    },
    0x0017 => 'Firmware',
    0x0018 => 'Software',
    0x0019 => 'AutoBracket',
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Sigma - Definitions for Sigma/Foveon EXIF maker notes

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sigma and Foveon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sigma Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
