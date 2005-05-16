#------------------------------------------------------------------------------
# File:         GPS.pm
#
# Description:  Definitions for EXIF GPS tags
#
# Revisions:    12/09/2003  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::GPS;

use strict;
use vars qw($VERSION);

$VERSION = '1.06';

%Image::ExifTool::GPS::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 2 => 'Location' },
    0x0000 => {
        Name => 'GPSVersionID',
        Writable => 'int8u',
        Count => 4,
        PrintConv => '$val =~ tr/ /./; $val',
        PrintConvInv => '$val =~ tr/./ /; $val',
    },
    0x0001 => {
        Name => 'GPSLatitudeRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x0002 => {
        Name => 'GPSLatitude',
        Writable => 'rational32u',
        Count => 3,
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
        PrintConvInv => '$_=$val;tr/-+0-9.\t/ /c;$_',
    },
    0x0003 => {
        Name => 'GPSLongitudeRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0x0004 => {
        Name => 'GPSLongitude',
        Writable => 'rational32u',
        Count => 3,
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
        PrintConvInv => '$_=$val;tr/-+0-9.\t/ /c;$_',
    },
    0x0005 => {
        Name => 'GPSAltitudeRef',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    0x0006 => {
        Name => 'GPSAltitude',
        Writable => 'rational32u',
        PrintConv => '"$val metres"',
        PrintConvInv => '$val=~s/\s*m.*//;$val',
    },
    0x0007 => {
        Name => 'GPSTimeStamp',
        Writable => 'rational32u',
        Count => 3,
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => '$val=~tr/:/ /;$val',
    },
    0x0008 => {
        Name => 'GPSSatellites',
        Writable => 'string',
    },
    0x0009 => {
        Name => 'GPSStatus',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            A => 'Measurement In Progress',
            V => 'Measurement Interoperability',
        },
    },
    0x000A => {
        Name => 'GPSMeasureMode',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0x000B => {
        Name => 'GPSDOP',
        Writable => 'rational32u',
    },
    0x000C => {
        Name => 'GPSSpeedRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    0x000D => {
        Name => 'GPSSpeed',
        Writable => 'rational32u',
    },
    0x000E => {
        Name => 'GPSTrackRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x000F => {
        Name => 'GPSTrack',
        Writable => 'rational32u',
    },
    0x0010 => {
        Name => 'GPSImgDirectionRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x0011 => {
        Name => 'GPSImgDirection',
        Writable => 'rational32u',
    },
    0x0012 => {
        Name => 'GPSMapDatum',
        Writable => 'string',
    },
    0x0013 => {
        Name => 'GPSDestLatitudeRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x0014 => {
        Name => 'GPSDestLatitude',
        Writable => 'rational32u',
        Count => 3,
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
        PrintConvInv => '$_=$val;tr/-+0-9.\t/ /c;$_',
    },
    0x0015 => {
        Name => 'GPSDestLongitudeRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0x0016 => {
        Name => 'GPSDestLongitude',
        Writable => 'rational32u',
        Count => 3,
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
        PrintConvInv => '$_=$val;tr/-+0-9.\t/ /c;$_',
    },
    0x0017 => {
        Name => 'GPSDestBearingRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x0018 => {
        Name => 'GPSDestBearing',
        Writable => 'rational32u',
    },
    0x0019 => {
        Name => 'GPSDestDistanceRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            K => 'Kilometers',
            M => 'Miles',
            N => 'Nautical Miles',
        },
    },
    0x001A => {
        Name => 'GPSDestDistance',
        Writable => 'rational32u',
    },
    0x001B => {
        Name => 'GPSProcessingMethod',
        Writable => 'undef',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
        PrintConvInv => '"ASCII\0\0\0$val"',
    },
    0x001C => {
        Name => 'GPSAreaInformation',
        Writable => 'undef',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val)',
        PrintConvInv => '"ASCII\0\0\0$val"',
    },
    0x001D => {
        Name => 'GPSDateStamp',
        Writable => 'string',
        Count => 11,
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => '$val',
    },
    0x001E => {
        Name => 'GPSDifferential',
        Writable => 'int16u',
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
);

# Composite GPS tags
%Image::ExifTool::GPS::Composite = (
    GPSDateTime => {
        Description => 'GPS Date/Time',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'GPSDateStamp',
            1 => 'GPSTimeStamp',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::GPS::Composite);

# Convert to DMS format
sub DMS($)
{
    my $val = shift;
    $val =~ s/^(\S+) (\S+) (.*)/$1 deg $2' $3"/;
    return $val;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::GPS - Definitions for GPS meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
GPS (Global Positioning System) meta information in EXIF data.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<Image::Info|Image::Info>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/GPS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::Info(3pm)|Image::Info>

=cut
