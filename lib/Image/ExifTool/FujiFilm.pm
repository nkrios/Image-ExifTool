#------------------------------------------------------------------------------
# File:         FujiFilm.pm
#
# Description:  FujiFilm EXIF maker notes tags
#
# Revisions:    11/25/2003  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::FujiFilm;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

$VERSION = '1.06';

%Image::ExifTool::FujiFilm::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0 => {
        Name => 'Version',
        Writable => 'undef',
    },
    0x1000 => {
        Name => 'Quality',
        Description => 'Image Quality',
        Writable => 'string',
    },
    0x1001 => {
        Name => 'Sharpness',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Soft',
            2 => 'Soft2',
            3 => 'Normal',
            4 => 'Hard',
            5 => 'Hard2',
        },
    },
    0x1002 => {
        Name => 'WhiteBalance',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => 'Auto',
            0x100 => 'Daylight',
            0x200 => 'Cloudy',
            0x300 => 'Daylight Fluorescent',
            0x301 => 'Day White Fluorescent',
            0x302 => 'White Fluorescent',
            0x400 => 'Incandescent',
            0xF00 => 'Custom',
        },
    },
    0x1003 => {
        Name => 'Saturation',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => 'Normal',
            0x100 => 'High',
            0x200 => 'Low',
        },
    },
    0x1004 => {
        Name => 'Contrast',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => 'Normal',
            0x100 => 'High',
            0x200 => 'Low',
        },
    },
    0x1010 => {
        Name => 'FujiFlashMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
            3 => 'Red-eye reduction',
        },
    },
    0x1011 => {
        Name => 'FlashStrength',
        Writable => 'rational64s',
    },
    0x1020 => {
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x1021 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0x1030 => {
        Name => 'SlowSync',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x1031 => {
        Name => 'PictureMode',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0 => 'Auto',
            0x1 => 'Portrait',
            0x2 => 'Landscape',
            0x4 => 'Sports',
            0x5 => 'Night',
            0x6 => 'Program AE',
            0x100 => 'Aperture-priority AE',
            0x200 => 'Shutter speed priority AE',
            0x300 => 'Manual',
        },
    },
    0x1100 => {
        Name => 'AutoBracketing',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x1300 => {
        Name => 'BlurWarning',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'Blur Warning',
        },
    },
    0x1301 => {
        Name => 'FocusWarning',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Good',
            1 => 'Out of focus',
        },
    },
    0x1302 => {
        Name => 'ExposureWarning',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Good',
            1 => 'Bad exposure',
        },
    },
);

#------------------------------------------------------------------------------
# get information from FujiFilm RAW file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid FujiFilm RAW file
sub ProcessRAF($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $buff;
    my $raf = $$dirInfo{RAF};
    $raf->Read($buff,8) == 8    or return 0;
    $buff eq 'FUJIFILM'         or return 0;
    $raf->Seek(84, 0)           or return 0;
    $raf->Read($buff, 4) == 4   or return 0;
    SetByteOrder('MM');
    my $base = Get32u(\$buff, 0) + 12;
    my %dirInfo = (
        Parent => 'RAF',
        RAF    => $raf,
        Base   => $base,
    );
    return $exifTool->ProcessTIFF(\%dirInfo);
}

1; # end

__END__

=head1 NAME

Image::ExifTool::FujiFilm - FujiFilm EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
FujiFilm maker notes in EXIF information, and to read FujiFilm RAW (RAF)
images.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item (...plus testing with my own FinePix 2400 Zoom)

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FujiFilm Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
