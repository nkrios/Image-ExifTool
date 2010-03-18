#------------------------------------------------------------------------------
# File:         Samsung.pm
#
# Description:  Samsung EXIF maker notes tags
#
# Revisions:    2010/03/01 - P. Harvey Created
#
# References:   1) Tae-Sun Park private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Samsung;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.00';

# Samsung maker notes (ref PH)
%Image::ExifTool::Samsung::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        These tags used in the maker notes of cameras such as the NX10, ST500, ST550,
        ST1000 and WB5000.
    },
    0x0001 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x0021 => { #1
        Name => 'PictureWizard',
        Writable => 'int16u',
        Count => 5,
        PrintConv => q{
            my @a = split ' ', $val;
            return $val unless @a == 5;
            sprintf("Mode: %d, Col: %d, Sat: %d, Sha: %d, Con: %d",
                    $a[0], $a[1], $a[2]-4, $a[3]-4, $a[4]-4);
        },
        PrintConvInv => q{
            my @a = ($val =~ /[+-]?\d+/g);
            return $val unless @a >= 5;
            sprintf("%d %d %d %d %d", $a[0], $a[1], $a[2]+4, $a[3]+4, $a[4]+4);
        },
    },
    # 0x0023 - string: "0123456789" (PH)
    0x0035 => {
        Name => 'PreviewIFD',
        Condition => '$$self{TIFF_TYPE} eq "SRW"', # (not an IFD in JPEG images)
        Groups => { 1 => 'PreviewIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewIFD',
            ByteOrder => 'Unknown',
            Start => '$val',
        },
    },
    0x0043 => { #1 (NC)
        Name => 'CameraTemperature',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        # (DPreview samples all 0.2 C --> pre-production model)
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    # 0x00a0 - undef[8192]: white balance information (ref 1):
    #   At byte 5788, the WBAdjust: "Adjust\0\X\0\Y\0\Z\xee\xea\xce\xab", where
    #   Y = BA adjust (0=Blue7, 7=0, 14=Amber7), Z = MG (0=Magenta7, 7=0, 14=Green7)
#
# the following tags found only in SRW images
#
    # 0xa000 - DigitalZoomRatio? #1
    0xa001 => { #1
        Name => 'FirmwareName',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    0xa003 => { #1
        Name => 'LensType',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            1 => 'Samsung 30mm F2',
            2 => 'Samsung Zoom 18-55mm F3.5-5.6 OIS',
            3 => 'Samsung Zoom 50-200mm F4-5.6 ED OIS',
        },
    },
    # 0xa004 - lens firmware version? #1
    # 0xa005 - or maybe this is a SerialNumber? (PH)
    0xa010 => { #1
        Name => 'SensorAreas',
        Groups => { 2 => 'Camera' },
        Notes => 'full and valid sensor areas',
        Writable => 'int32u',
        Count => 8,
    },
    0xa013 => { #1
        Name => 'ExposureCompensation',
        Writable => 'rational64s',
    },
    0xa014 => { #1
        Name => 'ISO',
        Writable => 'int32u',
    },
    0xa018 => { #1
        Name => 'ExposureTime',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'eval $val',
    },
    0xa019 => { #1
        Name => 'FNumber',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0xa01a => { #1
        Name => 'FocalLengthIn35mmFormat',
        Groups => { 2 => 'Camera' },
        Format => 'int32u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0xa021 => { #1
        Name => 'WB_RGGBLevels',
        Writable => 'int32u',
        Count => 4,
    },
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Samsung - Samsung EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Samsung maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2010, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Tae-Sun Park for decoding some tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Samsung Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
