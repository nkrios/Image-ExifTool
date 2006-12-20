#------------------------------------------------------------------------------
# File:         GPS.pm
#
# Description:  EXIF GPS meta information tags
#
# Revisions:    12/09/2003  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::GPS;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.11';

my %coordConv = (
    ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val)',
    ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val)',
    PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val)',
);

%Image::ExifTool::GPS::Main = (
    GROUPS => { 0 => 'EXIF', 1 => 'GPS', 2 => 'Location' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    WRITE_GROUP => 'GPS',
    NOTES => q{
        When adding GPS information to an image, it is important to set all of the
        following tags: GPSLatitude, GPSLatitudeRef, GPSLongitude, GPSLongitudeRef,
        GPSAltitude and GPSAltitudeRef.  ExifTool will write the required
        GPSVersionID tag automatically if new a GPS IFD is added to an image.
    },
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
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
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
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
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
        Writable => 'rational64u',
        PrintConv => '"$val metres"',
        PrintConvInv => '$val=~s/\s*m.*//;$val',
    },
    0x0007 => {
        Name => 'GPSTimeStamp',
        Groups => { 2 => 'Time' },
        Writable => 'rational64u',
        Count => 3,
        Shift => 'Time',
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
        Description => 'GPS Dilution Of Precision',
        Writable => 'rational64u',
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
        Writable => 'rational64u',
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
        Writable => 'rational64u',
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
        Writable => 'rational64u',
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
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
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
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
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
        Writable => 'rational64u',
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
        Writable => 'rational64u',
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
        Groups => { 2 => 'Time' },
        Writable => 'string',
        Notes => 'YYYY:MM:DD',
        Count => 11,
        Shift => 'Time',
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
    GPSPosition => {
        Require => {
            0 => 'GPSLatitude',
            1 => 'GPSLongitude',
        },
        Desire => {
            2 => 'GPSLatitudeRef',
            3 => 'GPSLongitudeRef',
        },
        ValueConv => q{
            foreach (0..1) {
                # set sign from lat/long reference direction if it exists
                next unless $val[$_+2];
                $val[$_] = abs($val[$_]);
                $val[$_] = -$val[$_] if $val[$_+2] =~ /^(S|W)/i;
            }
            return "$val[0] $val[1]";
        },
        PrintConv => q{
            my $lat  = Image::ExifTool::GPS::ToDMS($self, $val[0], 1, 'N');
            my $long = Image::ExifTool::GPS::ToDMS($self, $val[1], 1, 'E');
            return "$lat, $long";
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::GPS::Composite);

#------------------------------------------------------------------------------
# Convert degrees to DMS, or whatever the current settings are
# Inputs: 0) ExifTool reference, 1) Value in degrees,
#         2) format code (0=no format, 1=CoordFormat, 2=XMP format)
#         3) 'N' or 'E' if sign is significant and N/S/E/W should be added
# Returns: DMS string
sub ToDMS($$;$$)
{
    my ($exifTool, $val, $doPrintConv, $ref) = @_;
    my ($fmt, $num);

    if ($ref) {
        if ($val < 0) {
            $val = -$val;
            $ref = {N => 'S', E => 'W'}->{$ref};
        }
        $ref = " $ref" unless $doPrintConv and $doPrintConv eq '2';
    } else {
        $ref = '';
    }
    if ($doPrintConv) {
        if ($doPrintConv eq '1') {
            $fmt = ($exifTool->Options('CoordFormat') || q{%d deg %d' %.2f"}) . $ref;
        } else {
            $fmt = "%d,%.2f$ref";   # use XMP standard format
        }
        # count the number of format specifiers
        $num = ($fmt =~ tr/%/%/);
    } else {
        $num = 3;
    }
    my ($d, $m, $s);
    $d = $val;
    if ($num > 1) {
        $d = int($d);
        $m = ($val - $d) * 60;
        if ($num > 2) {
            $m = int($m);
            $s = ($val - $d - $m / 60) * 3600;
        }
    }
    return $doPrintConv ? sprintf($fmt, $d, $m, $s) : "$d $m $s$ref";
}

#------------------------------------------------------------------------------
# Convert to decimal degrees
# Inputs: 0) a string containing 1-3 decimal numbers and any amount of other garbage
#         1) true if value should be negative if coordinate ends in 'S' or 'W'
# Returns: Coordinate in degrees
sub ToDegrees($;$)
{
    my ($val, $doSign) = @_;
    # extract decimal values out of any other garbage
    my ($d, $m, $s) = ($val =~ /((?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?)/g);
    my $deg = ($d || 0) + (($m || 0) + ($s || 0)/60) / 60;
    # make negative if S or W coordinate
    $deg = -$deg if $doSign and $val =~ /[^A-Z](S|W)$/i;
    return $deg;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::GPS - EXIF GPS meta information tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
GPS (Global Positioning System) meta information in EXIF data.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<Image::Info|Image::Info>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/GPS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::Info(3pm)|Image::Info>

=cut
