#------------------------------------------------------------------------------
# File:         GPS.pm
#
# Description:  Definitions for EXIF GPS tags
#
# Revisions:    12/09/2003  - P. Harvey Created
#
# Notes:        It is unfortunate, but string values all seem to be terminated
#               with "\0" (darn C programmers think they own the world),
#               so we have to strip this off manually before we use them.
#               Pain in the butt really.
#------------------------------------------------------------------------------

package Image::ExifTool::GPS;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

%Image::ExifTool::GPS::Main = (
    GROUPS => { 2 => 'Location' },
    0x0000 => {
        Name => 'GPSVersionID',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    0x0001 => {
        Name => 'GPSLatitudeRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x0002 => {
        Name => 'GPSLatitude',
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
    },
    0x0003 => {
        Name => 'GPSLongitudeRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0x0004 => {
        Name => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
    },
    0x0005 => {
        Name => 'GPSAltitudeRef',
        # don't need to remove "\0" here -- not a string
        PrintConv => {
            0 => 'Sea Level',
        },
    },
    0x0006 => {
        Name => 'GPSAltitude',
        PrintConv => '"$val metres"',
    },
    0x0007 => {
        Name => 'GPSTimeStamp',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    0x0008 => 'GPSSatellites',
    0x0009 => {
        Name => 'GPSStatus',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            A => 'Measurement In Progress',
            V => 'Measurement Interoperability',
        },
    },
    0x000A => {
        Name => 'GPSMeasureMode',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0x000B => 'GPSDOP',
    0x000C => {
        Name => 'GPSSpeedRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    0x000D => 'GPSSpeed',
    0x000E => {
        Name => 'GPSTrackRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x000F => 'GPSTrack',
    0x0010 => {
        Name => 'GPSImgDirectionRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x0011 => 'GPSImgDirection',
    0x0012 => 'GPSMapDatum',
    0x0013 => {
        Name => 'GPSDestLatitudeRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x0014 => {
        Name => 'GPSDestLatitude',
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
    },
    0x0015 => {
        Name => 'GPSDestLongitudeRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0x0016 => {
        Name => 'GPSDestLongitude',
        PrintConv => 'Image::ExifTool::GPS::DMS($val)',
    },
    0x0017 => {
        Name => 'GPSDestBearingRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x0018 => 'GPSDestBearing',
    0x0019 => {
        Name => 'GPSDestDistanceRef',
        ValueConv => '$val =~ s/\0$//; $val',
        PrintConv => {
            K => 'Kilometers',
            M => 'Miles',
            N => 'Nautical Miles',
        },
    },
    0x001A => 'GPSDestDistance',
    0x001B => 'GPSProcessingMethod',
    0x001C => 'GPSAreaInformation',
    0x001D => {
        Name => 'GPSDateStamp',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    0x001E => {
        Name => 'GPSDifferential',
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

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<Image::Info|Image::Info>

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>,  L<Image::Info|Image::Info>

=cut
