#------------------------------------------------------------------------------
# File:         Panasonic.pm
#
# Description:  Panasonic/Leica maker notes tags
#
# Revisions:    11/10/2004 - P. Harvey Created
#
# References:   1) http://www.compton.nu/panasonic.html (based on FZ10)
#               2) Derived from DMC-FZ3 samples from dpreview.com
#               3) http://johnst.org/sw/exiftags/
#               4) Tels (http://bloodgate.com/) private communication (tests with FZ5)
#               5) CPAN forum post by 'hardloaf' (http://www.cpanforum.com/threads/2183)
#               6) http://www.cybercom.net/~dcoffin/dcraw/
#               7) http://homepage3.nifty.com/kamisaka/makernote/makernote_pana.htm
#               8) Marcel Coenen private communication (DMC-FZ50)
#------------------------------------------------------------------------------

package Image::ExifTool::Panasonic;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.16';

sub ProcessPanasonicType2($$$);

%Image::ExifTool::Panasonic::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    0x01 => {
        Name => 'ImageQuality',
        Writable => 'int16u',
        PrintConv => {
            2 => 'High',
            3 => 'Normal',
            6 => 'Very High', #3 (Leica)
            7 => 'Raw', #3 (Leica)
        },
    },
    0x02 => {
        Name => 'FirmwareVersion',
        Format => 'int8u',  # (format type is 'undef', but it should really be int8u)
        Writable => 'int8u',
        Count => 4,
        PrintConv => '$_=$val; tr/ /./; $_',
        PrintConvInv => '$_=$val; tr/./ /; $_',
    },
    0x03 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto',
            2 => 'Daylight',
            3 => 'Cloudy',
            4 => 'Halogen',
            5 => 'Manual',
            8 => 'Flash',
            10 => 'Black & White', #3 (Leica)
        },
    },
    0x07 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto',
            2 => 'Manual',
            4 => 'Auto, Focus button', #4
            5 => 'Auto, Continuous', #4
        },
    },
    0x0f => {
        Name => 'SpotMode',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {
            '0 1'  => 'Spot Mode On',
            '0 16' => 'Spot Mode Off',
        },
    },
    0x1a => {
        Name => 'ImageStabilizer',
        Writable => 'int16u',
        PrintConv => {
            2 => 'On, Mode 1',
            3 => 'Off',
            4 => 'On, Mode 2',
        },
    },
    0x1c => {
        Name => 'MacroMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'On',
            2 => 'Off',
            0x101 => 'Tele-Macro', #7
        },
    },
    0x1f => {
        Name => 'ShootingMode',
        Writable => 'int16u',
        PrintConv => {
            1  => 'Normal',
            2  => 'Portrait',
            3  => 'Scenery',
            4  => 'Sports',
            5  => 'Night Portrait',
            6  => 'Program',
            7  => 'Aperture Priority',
            8  => 'Shutter Priority',
            9  => 'Macro',
            11 => 'Manual',
            13 => 'Panning',
            18 => 'Fireworks',
            19 => 'Party',
            20 => 'Snow',
            21 => 'Night Scenery',
            22 => 'Food', #7
        },
    },
    0x20 => {
        Name => 'Audio',
        Writable => 'int16u',
        PrintConv => { 1 => 'Yes', 2 => 'No' },
    },
    0x21 => { #2
        Name => 'DataDump',
        Writable => 0,
        Binary => 1,
    },
    0x23 => {
        Name => 'WhiteBalanceBias',
        Format => 'int16s',
        Writable => 'int16s',
        ValueConv => '$val / 3',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        ValueConvInv => '$val * 3',
        PrintConvInv => 'eval $val',
    },
    0x24 => {
        Name => 'FlashBias',
        Format => 'int16s',
        Writable => 'int16s',
    },
    0x25 => { #PH
        Name => 'InternalSerialNumber',
        Writable => 'undef',
        Count => 16,
        Notes => q{
            this number is unique, and contains the date of manufacture, but is not the
            same as the number printed on the camera body
        },
        PrintConv => q{
            return $val unless $val=~/^([A-Z]\d{2})(\d{2})(\d{2})(\d{2})(\d{4})/;
            my $yr = $2 + ($2 < 70 ? 2000 : 1900);
            return "($1) $yr:$3:$4 no. $5";
        },
        PrintConvInv => '$_=$val; tr/A-Z0-9//dc; s/(.{3})(19|20)/$1/; $_',
    },
    0x28 => {
        Name => 'ColorEffect',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Off',
            2 => 'Warm',
            3 => 'Cool',
            4 => 'Black & White',
            5 => 'Sepia',
        },
    },
    # 0x29 => 'SubjectDistance?',
    0x2a => { #4
        Name => 'BurstMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low/High Quality',
            2 => 'Infinite',
        },
    },
    0x2b => { #4
        Name => 'SequenceNumber',
        Writable => 'int32u',
    },
    0x2e => { #4
        Name => 'SelfTimer',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Off',
            2 => '10s',
            3 => '2s',
        },
    },
    0x2c => [
        {
            Name => 'Contrast',
            Condition => '$self->{CameraMake} =~ /^Panasonic/i',
            Notes => 'Panasonic models',
            Flags => 'PrintHex',
            Writable => 'int16u',
            PrintConv => {
                0 => 'Normal',
                1 => 'Low',
                2 => 'High',
            }
        },
        {
            Name => 'Contrast',
            Notes => 'Leica models',
            Flags => 'PrintHex',
            Writable => 'int16u',
            PrintConv => {
                #3 (Leica)
                0x100 => 'Low',
                0x110 => 'Normal',
                0x120 => 'High',
            }
        },
    ],
    0x2d => {
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x30 => { #7
        Name => 'Rotation',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Horizontal (normal)',
            6 => 'Rotate 90 CW', #PH (ref 7 gives 270 CW)
            8 => 'Rotate 270 CW', #PH (ref 7 gives 90 CW)
        },
    },
    0x32 => { #7
        Name => 'ColorMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Natural',
        },
    },
    # 0x33 - RedModeBirthday? (ref 7)
    0x36 => { #8
        Name => 'TravelDay',
        Writable => 'int16u',
        PrintConv => '$val == 65535 ? "n/a" : $val',
        PrintConvInv => '$val =~ /(\d+)/ ? $1 : $val',
    },
    0x51 => {
        Name => 'LensType',
        Writable => 'string',
    },
    # 0x53 - string "NO_ACCESSORY" on DMC-L1
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);

# Type 2 tags (ref PH)
%Image::ExifTool::Panasonic::Type2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    NOTES => q{
        This type of maker notes is used by models such as the NV-DS65, PV-D2002,
        PV-DC3000, PV-L2001 and PV-SD4090.
    },
    0 => {
        Name => 'MakerNoteVersion',
        Format => 'string[4]',
    },
    # seems to vary inversely with amount of light, so I'll call it 'Gain' - PH
    # (minimum is 16, maximum is 136.  Value is 0 for pictures captured from video)
    3 => 'Gain',
);

# Tags found in Panasonic RAW images
%Image::ExifTool::Panasonic::Raw = (
    GROUPS => { 0 => 'EXIF', 1 => 'IFD0', 2 => 'Image'},
    NOTES => 'These tags are found in IFD0 of Panasonic RAW images.',
    0x01 => 'PanasonicRawVersion',
    0x02 => 'SensorWidth', #5/PH
    0x03 => 'SensorHeight', #5/PH
    0x06 => 'ImageHeight', #5/PH
    0x07 => 'ImageWidth', #5/PH
    0x17 => 'ISO', #5
    0x24 => 'WB_RedLevel', #6
    0x25 => 'WB_GreenLevel', #6
    0x26 => 'WB_BlueLevel', #6
    0x10f => {
        Name => 'Make',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraMake',
        # save this value as an ExifTool member variable
        RawConv => '$self->{CameraMake} = $val',
    },
    0x110 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraModel',
        # save this value as an ExifTool member variable
        RawConv => '$self->{CameraModel} = $val',
    },
    0x111 => {
        Name => 'StripOffsets',
        Flags => 'IsOffset',
        OffsetPair => 0x117,  # point to associated byte counts
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x112 => {
        Name => 'Orientation',
        PrintConv => \%Image::ExifTool::Exif::orientation,
        Priority => 0,  # so IFD1 doesn't take precedence
    },
    0x116 => {
        Name => 'RowsPerStrip',
        Priority => 0,
    },
    0x117 => {
        Name => 'StripByteCounts',
        OffsetPair => 0x111,   # point to associated offset
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x8769 => {
        Name => 'ExifOffset',
        Groups => { 1 => 'ExifIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            DirName => 'ExifIFD',
            Start => '$val',
        },
    },
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Panasonic - Panasonic/Leica maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Panasonic and Leica maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.compton.nu/panasonic.html>

=item L<http://johnst.org/sw/exiftags/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Tels for the information he provided on decoding some tags, and to
Marcel Coenen for decoding the TravelDay tag.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Panasonic Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
