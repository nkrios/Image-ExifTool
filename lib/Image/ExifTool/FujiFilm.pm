#------------------------------------------------------------------------------
# File:         FujiFilm.pm
#
# Description:  FujiFilm EXIF maker notes tags
#
# Revisions:    11/25/2003  - P. Harvey Created
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) http://homepage3.nifty.com/kamisaka/makernote/makernote_fuji.htm
#               3) Michael Meissner private communication
#------------------------------------------------------------------------------

package Image::ExifTool::FujiFilm;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

$VERSION = '1.12';

%Image::ExifTool::FujiFilm::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0 => {
        Name => 'Version',
        Writable => 'undef',
    },
    0x0010 => { #PH (how does this compare to actual serial number?)
        Name => 'InternalSerialNumber',
        Writable => 'string',
        Notes => q{
            this number is unique, and contains the date of manufacture, but doesn't
            necessarily correspond to the camera body number -- this needs to be checked
        },
        # ie)  "FPX20017035 592D31313034060427796060110384"
        # "FPX 20495643     592D313335310701318AD010110047" (F40fd)
        #                               yymmdd
        PrintConv => q{
            return $val unless $val=~/^(.*)(\d{2})(\d{2})(\d{2})(.{12})$/;
            my $yr = $2 + ($2 < 70 ? 2000 : 1900);
            return "$1 $yr:$3:$4 $5";
        },
        PrintConvInv => '$_=$val; s/ (19|20)(\d{2}):(\d{2}):(\d{2}) /$2$3$4/; $_',
    },
    0x1000 => {
        Name => 'Quality',
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
            0xf00 => 'Custom',
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
            0x300 => 'None (B&W)', #2
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
    0x1023 => { #2
        Name => 'FocusPixel',
        Writable => 'int16u',
        Count => 2,
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
            0x5 => 'Night Scene',
            0x6 => 'Program AE',
            0x7 => 'Natural Light', #3
            0x8 => 'Anti-blur', #3
            0xa => 'Sunset', #3
            0xb => 'Museum', #3
            0xc => 'Party', #3
            0xd => 'Flower', #3
            0xe => 'Text', #3
            0xf => 'Natural Light & Flash', #3
            0x10 => 'Beach', #3
            0x11 => 'Snow', #3
            0x12 => 'Fireworks', #3
            0x13 => 'Underwater', #3
            0x100 => 'Aperture-priority AE',
            0x200 => 'Shutter speed priority AE',
            0x300 => 'Manual',
        },
    },
# this usually has a value of 1
#    0x1032 => { #2
#        Name => 'ShutterCount',
#        Writable => 'int16u',
#    },
    0x1100 => {
        Name => 'AutoBracketing',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'No flash & flash', #3
        },
    },
    0x1101 => {
        Name => 'SequenceNumber',
        Writable => 'int16u',
    },
    0x1210 => { #2
        Name => 'ColorMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Standard',
            0x10 => 'Chrome',
            0x30 => 'B & W',
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
    0x1400 => { #2
        Name => 'DynamicRange',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Standard',
            3 => 'Wide',
        },
    },
    0x1401 => { #2
        Name => 'FilmMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'F0/Standard',
            0x100 => 'F1/Studio Portrait',
            0x200 => 'F2/Fujichrome',
            0x300 => 'F3/Studio Portrait Ex',
            0x400 => 'F4/Velvia',
        },
    },
    0x1402 => { #2
        Name => 'DynamicRangeSetting',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'Auto (100-400%)',
            0x001 => 'RAW',
            0x100 => 'Standard (100%)',
            0x200 => 'Wide1 (230%)',
            0x201 => 'Wide2 (400%)',
            0x8000 => 'Film Simulation Mode',
        },
    },
    0x1403 => { #2
        Name => 'DevelopmentDynamicRange',
        Writable => 'int16u',
    },
    0x1404 => { #2
        Name => 'MinFocalLength',
        Writable => 'rational64s',
    },
    0x1405 => { #2
        Name => 'MaxFocalLength',
        Writable => 'rational64s',
    },
    0x1406 => { #2
        Name => 'MaxApertureAtMinFocal',
        Writable => 'rational64s',
    },
    0x1407 => { #2
        Name => 'MaxApertureAtMaxFocal',
        Writable => 'rational64s',
    },
    0x8000 => { #2
        Name => 'FileSource',
        Writable => 'string',
    },
    0x8002 => { #2
        Name => 'OrderNumber',
        Writable => 'int32u',
    },
    0x8003 => { #2
        Name => 'FrameNumber',
        Writable => 'int16u',
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

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item (...plus testing with my own FinePix 2400 Zoom)

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Michael Meissner for decoding some new PictureMode and
AutoBracketing values.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FujiFilm Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
