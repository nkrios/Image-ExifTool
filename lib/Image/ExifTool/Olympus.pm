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
#               3) http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html
#               4) Markku HŠnninen private communication (tests with E-1)
#               5) RŽmi Guyomarch from http://forums.dpreview.com/forums/read.asp?forum=1022&message=12790396
#------------------------------------------------------------------------------

package Image::ExifTool::Olympus;

use strict;
use vars qw($VERSION);

$VERSION = '1.13';

%Image::ExifTool::Olympus::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
#
# Tags 0x0000 through 0x0103 are the same as Konica/Minolta cameras (ref 3)
#
    0x0000 => 'MakerNoteVersion',
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        Name => 'PreviewImageData',
        Writable => 0,
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 0,
        Protected => 2,
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 0,
        Protected => 2,
    },
    0x0100 => {
        Name => 'ThumbnailImage',
        ValueConv => '\$val',
        ValueConvInv => '$val',
    },
    0x0101 => {
        Name => 'ColorMode',
        PrintConv => {
            0 => 'Natural color',
            1 => 'Black&white',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
        },
    },
    0x0102 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'Raw',
            1 => 'Superfine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    # (0x0103 is the same as 0x0102 above)
    0x0103 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'Raw',
            1 => 'Superfine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
#
# end Konica/Minolta tags
#
    0x0200 => {
        Name => 'SpecialMode',
        Writable => 'int32u',
        Count => 3,
        Notes => q{3 numbers: 1) Shooting mode: 0=Normal, 2=Fast, 3=Panorama;
                   2) Sequence Number; 3) Panorama Direction: 1=Left-Right,
                   2=Right-Left, 3=Bottom-Top, 4=Top-Bottom},
        PrintConv => q{ #3
            my @v = split /\s+/, $val;
            return $val unless @v >= 3;
            my @v0 = ('Normal','Unknown (1)','Fast','Panorama');
            my @v2 = ('(none)','Left to Right','Right to Left','Bottom to Top','Top to Bottom');
            $val = $v0[$v[0]] || "Unknown ($v[0])";
            $val .= ", Sequence: $v[1]";
            $val .= ', Panorama: ' . ($v2[$v[2]] || "Unknown ($v[2])");
            return $val;
        },
    },
    0x0201 => [
        {
            # for some reason, the values for the E-1/E-300 start at 1 instead of 0
            Condition => '$self->{CameraModel} =~ /^(E-1|E-300)/',
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
            # 6 = RAW for C5060WZ
            PrintConv => { 0 => 'SQ', 1 => 'HQ', 2 => 'SHQ', 6 => 'RAW' },
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
    0x0207 => 'FirmwareVersion',
    0x0208 => 'PictureInfo',
    0x0209 => {
        Name => 'CameraID',
        Format => 'string', # this really should have been a string
    },
    0x020b => {
        Name => 'EpsonImageWidth', #PH
        Writable => 'int16u',
    },
    0x020c => {
        Name => 'EpsonImageHeight', #PH
        Writable => 'int16u',
    },
    0x020d => 'EpsonSoftware', #PH
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x0f00 => {
        Name => 'DataDump',
        Writable => 0,
        ValueConv => '\$val',
    },
    0x1004 => 'FlashMode', #3
    0x1006 => 'Bracket', #3
    0x100b => 'FocusMode', #3
    0x100c => 'FocusDistance', #3
    0x100d => 'Zoom', #3
    0x100e => 'MacroFocus', #3
    0x100f => 'SharpnessFactor', #3
    0x1011 => 'ColorMatrix', #3
    0x1012 => 'BlackLevel', #3
    0x1015 => 'WhiteBalance', #3
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
    0x101a => 'SerialNumber', #3
    0x1023 => 'FlashBias', #3
    0x1029 => 'Contrast', #3
    0x102a => 'SharpnessFactor', #3
    0x102b => 'ColorControl', #3
    0x102c => 'ValidBits', #3
    0x102d => 'CoringFilter', #3
    0x102e => 'OlympusImageWidth',  #PH
    0x102f => 'OlympusImageHeight', #PH
    0x1034 => 'CompressionRatio', #3
# 
# Olympus really screwed up the format of the following subdirectories (for the
# E-1 and E-300 anyway). Not only is the subdirectory value data not included in
# the size, but also the count is 2 bytes short for the subdirectory itself
# (presumably the Olympus programmers forgot about the 2-byte entry count at the
# start of the subdirectory).  This mess is straightened out and these subdirs
# are written properly when ExifTool rewrites the file. - PH
# 
    0x2010 => { #PH
        Name => 'Equipment',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Equipment',
            ByteOrder => 'Unknown',
        },
    },
    0x2020 => { #PH
        Name => 'CameraSettings',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::CameraSettings',
            ByteOrder => 'Unknown',
        },
    },
    0x2030 => { #PH
        Name => 'Subdir3',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Subdir3',
            ByteOrder => 'Unknown',
        },
    },
    0x2040 => { #PH
        Name => 'ImageProcessing',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::ImageProcessing',
            ByteOrder => 'Unknown',
        },
    },
    0x2050 => { #PH
        Name => 'FocusInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::FocusInfo',
            ByteOrder => 'Unknown',
        },
    },
);

# Subdir 1
%Image::ExifTool::Olympus::Equipment = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => 'EquipmentVersion', #PH
    0x100 => 'FirmwareVersion2', #PH
    0x101 => { #PH
        Name => 'SerialNumber',
        PrintConv => '$val=~s/\s+$//;$val',
        PrintConvInv => 'pack("A31",$val)', # pad with spaces to 31 chars
    },
    # apparently the first 3 digits of the lens s/n give the type (ref 4):
    # 010 = 50macro
    # 040 = EC-14
    # 050 = 14-54
    # 060 = 50-200
    # 080 = EX-25
    # 101 = FL-50
    0x202 => { #PH
        Name => 'LensSerialNumber',
        PrintConv => '$val=~s/\s+$//;$val',
        PrintConvInv => 'pack("A31",$val)', # pad with spaces to 31 chars
    },
    0x0206 => { #5
        Name => 'MaxApertureAtMaxFocal',
        ValueConv => '$val ? sqrt(2)**($val/256) : 0',
        ValueConvInv => '$val>0 ? int(512*log($val)/log(2)+0.5) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x207 => 'MinFocalLength', #PH
    0x208 => 'MaxFocalLength', #PH
    0x302 => 'ExtenderSerialNumber', #4
    0x1003 => 'FlashSerialNumber', #4
);

# Subdir 2
%Image::ExifTool::Olympus::CameraSettings = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => 'CameraSettingsVersion', #PH
    0x101 => { #PH
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x102,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x102 => { #PH
        Name => 'PreviewImageLength',
        OffsetPair => 0x101,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x200 => { #4
        Name => 'ExposureMode',
        PrintConv => {
            1 => 'Manual',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Program AE',
        }
    },
    0x202 => { #PH/4
        Name => 'MeteringMode',
        PrintConv => {
            2 => 'Center Weighted',
            3 => 'Spot',
            5 => 'ESP',
        },
    },
    0x0301 => { #4
        Name => 'ContinuousAutoFocus',
        PrintConv => '$val==2 ? "On" : "Off"',
    },
    0x304 => { #PH/4
        Name => 'AFAreas',
        PrintConv => 'Image::ExifTool::Olympus::PrintAFAreas($val)',
    },
    0x501 => { #PH/4
        Name => 'WhiteBalanceTemperature',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/^\d+$/ ? $val : 0',
    },
    0x502 => 'WhiteBalanceBracket', #PH/4
    0x503 => { #PH/4
        Name => 'CustomSaturation',
        PrintConv => 'my ($a,$b,$c)=split /\s+/,$val; $a-=$b; $c-=$b; "CS$a (min CS0, max CS$c)"',
    },
    0x504 => { #PH/4
        Name => 'ModifiedSaturation',
        PrintConv => {
            0 => 'Off',
            1 => 'CM1 (Red Enhance)',
            2 => 'CM2 (Green Enhance)',
            3 => 'CM3 (Blue Enhance)',
            4 => 'CM4 (Skin Tones)',
        },
    },
    0x505 => { #PH/4
        Name => 'ContrastSetting',
        PrintConv => 'my @v=split /\s+/,$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=$tr/-0-9 //dc;$val',
    },
    0x506 => { #PH/4
        Name => 'SharpnessSetting',
        PrintConv => 'my @v=split /\s+/,$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=$tr/-0-9 //dc;$val',
    },
    0x507 => { #PH/4
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'Adobe RGB',
            1 => 'sRGB',
        },
    },
    0x50a => { #PH/4
        Name => 'NoiseFilter',
        PrintConv => {
            0 => 'Off',
            1 => 'Noise Filter',
            2 => 'Noise Reduction',
        },
    },
    0x50c => { #PH/4
        Name => 'ShadingCompensation',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x50d => 'CompressionFactor', #PH/4
    0x600 => { #PH/4
        Name => 'Sequence',
        PrintConv => q{
            my ($a,$b) = split /\s+/,$val;
            return 'Single Shot' unless $a;
            my %a = (
                1 => 'Continuous Shooting',
                2 => 'Exposure Bracketing',
                3 => 'White Balance Bracketing',
            );
            return ($a{$a} || "Unknown ($a)") . ', Shot ' . $b;
        },
    },
    0x603 => { #PH/4
        Name => 'ImageQuality2',
        PrintConv => {
            1 => 'SQ',
            2 => 'HQ',
            3 => 'SHQ',
            4 => 'RAW',
        },
    },
);

# Subdir 3
%Image::ExifTool::Olympus::Subdir3 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => 'Subdir3Version', #PH
);

# Subdir 4
%Image::ExifTool::Olympus::ImageProcessing = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => 'ImageProcessingVersion', #PH
    0x300 => 'SmoothingParameter1', #PH/4
    0x310 => 'SmoothingParameter2', #PH/4
    0x600 => 'SmoothingThresholds', #PH/4
    0x610 => 'SmoothingThreshold2', #PH/4
    #0x611 => 'BitsPerPixel', #4 ?
    0x614 => 'OlympusImageWidth2', #PH
    0x615 => 'OlympusImageHeight2', #PH
    0x1010 => { #PH/4
        Name => 'NoiseFilter2',
        PrintConv => {
            0 => 'Off',
            1 => 'Noise Filter',
            2 => 'Noise Reduction',
        },
    },
    0x1012 => { #PH/4
        Name => 'ShadingCompensation2',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# Subdir 5
%Image::ExifTool::Olympus::FocusInfo = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => 'FocusInfoVersion', #PH
    0x209 => { #PH/4
        Name => 'AutoFocus',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    # 0x301 Related to inverse of focus distance
    0x305 => { #4
        Name => 'FocusDistance',
        # this rational value looks like it is in mm when the denominator is
        # 1 (E-1), and cm when denominator is 10 (E-300), so if we ignore the
        # denominator we are consistently in mm - PH
        Format => 'int32u',
        Count => 2,
        PrintConv => q{
            my ($a,$b) = split /\s+/,$val;
            return "inf" if $a == 0xffffffff;
            return $a / 1000 . ' m';
        },
        PrintConvInv => q{
            return '4294967295 1' if $val =~ /inf/i;
            $val =~ s/\s.*//;
            $val = int($val * 1000 + 0.5);
            return "$val 1";
        },
    },
    # 0x31a Continuous AF parameters?
    # 0x102a same as Subdir4-0x300
);

#------------------------------------------------------------------------------
# Print AF points
# Inputs: 0) AF point data (string of integers)
# Notes: I'm just guessing that the 2nd and 4th bytes are the Y coordinates,
# and that more AF points will show up in the future (derived from E-1 images,
# and the E-1 uses just one of 3 possible AF points, all centered in Y) - PH
sub PrintAFAreas($)
{
    my $val = shift;
    my @points = split /\s+/, $val;
    my %afPointNames = (
        0x36794285 => 'Left',
        0x79798585 => 'Center',
        0xBD79C985 => 'Right',
    );
    $val = '';
    my $pt;
    foreach $pt (@points) {
        next unless $pt;
        $val and $val .= ', ';
        $afPointNames{$pt} and $val .= $afPointNames{$pt} . ' ';
        my @coords = unpack('C4',pack('N',$pt));
        $val .= "($coords[0],$coords[1])-($coords[2],$coords[3])";
    }
    $val or $val = 'none';
    return $val;
}


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

=item http://www.cybercom.net/~dcoffin/dcraw/

=item http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
