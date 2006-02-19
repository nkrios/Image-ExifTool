#------------------------------------------------------------------------------
# File:         Minolta.pm
#
# Description:  Minolta EXIF maker notes tags
#
# Revisions:    04/06/2004 - P. Harvey Created
#               09/09/2005 - P. Harvey Added ability to write MRW files
#
# References:   1) http://www.dalibor.cz/minolta/makernote.htm
#               2) Jay Al-Saadi private communication (testing with A2)
#               3) Shingo Noguchi, PhotoXP (http://www.daifukuya.com/photoxp/)
#               4) Niels Kristian Bech Jensen private communication
#               5) http://www.cybercom.net/~dcoffin/dcraw/
#               6) Pedro Corte-Real private communication
#               7) ExifTool forum post by bronek (http://www.cpanforum.com/posts/1118)
#------------------------------------------------------------------------------

package Image::ExifTool::Minolta;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

$VERSION = '1.21';

%Image::ExifTool::Minolta::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0000 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        # These camera settings are different for the DiMAGE X31
        Condition => '$self->{CameraModel} ne "DiMAGE X31"',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    # it appears that image stabilization is on if this tag exists (ref 2),
    # but it is an 8kB binary data block!
    0x0018 => {
        Name => 'ImageStabilization',
        Writable => 0,
        ValueConv => '"On"',
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        # preview image in TIFF format files
        %Image::ExifTool::previewImageTagInfo,
        Permanent => 1,     # don't add this to a file because it doesn't exist in JPEG images
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0101 => {
        Name => 'ColorMode',
        Priority => 0, # Other ColorMode is more reliable for A2
        Writable => 'int32u',
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
        Writable => 'int32u',
        # PrintConv strings conform with Minolta reference manual (ref 4)
        # (note that Minolta calls an uncompressed TIFF image "Super fine")
        PrintConv => {
            0 => 'Raw',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    # (0x0103 is the same as 0x0102 above) -- this is true for some
    # cameras (A2/7Hi), but not others - PH
    0x0103 => [
        {
            Name => 'MinoltaQuality',
            Writable => 'int32u',
            Condition => '$self->{CameraModel} =~ /^DiMAGE (A2|7Hi)$/',
            Notes => 'quality for DiMAGE A2/7Hi',
            Priority => 0, # lower priority because this doesn't work for A200
            PrintConv => { #4
                0 => 'Raw',
                1 => 'Super Fine',
                2 => 'Fine',
                3 => 'Standard',
                4 => 'Economy',
                5 => 'Extra fine',
            },
        },
        { #PH
            Name => 'MinoltaImageSize',
            Writable => 'int32u',
            Condition => '$self->{CameraModel} !~ /^DiMAGE A200$/',
            Notes => 'image size for other models except A200',
            PrintConv => {
                1 => '1600x1200',
                2 => '1280x960',
                3 => '640x480',
                5 => '2560x1920',
                6 => '2272x1704',
                7 => '2048x1536',
            },
        },
    ],
    0x010c => { #3 (Alpha 7)
        Name => 'LensID',
        Writable => 'int32u',
        PrintConv => {
            1 => 'AF80-200mm F2.8G',
            2 => 'AF28-70mm F2.8G',
            6 => 'AF24-85mm F3.5-4.5',
            7 => 'AF100-400mm F4.5-6.7(D)',
            11 => 'AF300mm F4G',
            12 => 'AF100mm F2.8 Soft',
            15 => 'AF400mm F4.5G',
            16 => 'AF17-35mm F3.5G',
            19 => 'AF35mm/1.4',
            20 => 'STF135mm F2.8[T4.5]',
            23 => 'AF200mm F4G Macro',
            24 => 'AF24-105mm F3.5-4.5(D) or SIGMA 18-50mm F2.8',
            25 => 'AF100-300mm F4.5-5.6(D)',
            27 => 'AF85mm F1.4G',
            28 => 'AF100mm F2.8 Macro(D)',
            29 => 'AF75-300mm F4.5-5.6(D)',
            30 => 'AF28-80mm F3.5-5.6(D)',
            31 => 'AF50mm F2.8 Macro(D) or AF50mm F3.5 Macro',
            32 => 'AF100-400mm F4.5-6.7(D) x1.5',
            33 => 'AF70-200mm F2.8G SSM',
            35 => 'AF85mm F1.4G(D) Limited',
            38 => 'AF17-35mm F2.8-4(D)',
            39 => 'AF28-75mm F2.8(D)',
            40 => 'AFDT18-70mm F3.5-5.6(D)', #6
            128 => 'TAMRON 18-200, 28-300 or 80-300mm F3.5-6.3',
            25501 => 'AF50mm F1.7', #7
            25521 => 'TOKINA 19-35mm F3.5-4.5 or TOKINA 28-70mm F2.8 AT-X', #3/7
            25541 => 'AF35-105mm F3.5-4.5',
            25551 => 'AF70-210mm F4 Macro or SIGMA 70-210mm F4-5.6 APO', #7/6
            25581 => 'AF24-50mm F4',
            25611 => 'SIGMA 70-300mm F4-5.6 or SIGMA 300mm F4 APO Macro', #3/7
            25621 => 'AF50mm F1.4 NEW',
            25631 => 'AF300mm F2.8G',
            25641 => 'AF50mm F2.8 Macro',
            25661 => 'AF24mm F2.8',
            25721 => 'AF500mm F8 Reflex',
            25781 => 'AF16mm F2.8 Fisheye or SIGMA 8mm F4 Fisheye',
            25791 => 'AF20mm F2.8',
            25811 => 'AF100mm F2.8 Macro(D), TAMRON 90mm F2.8 Macro or SIGMA 180mm F5.6 Macro',
            25858 => 'TAMRON 24-135mm F3.5-5.6',
            25891 => 'TOKINA 80-200mm F2.8',
            25921 => 'AF85mm F1.4G(D)',
            25931 => 'AF200mm F2.8G',
            25961 => 'AF28mm F2',
            25981 => 'AF100mm F2',
            26061 => 'AF100-300mm F4.5-5.6(D)',
            26081 => 'AF300mm F2.8G',
            26121 => 'AF200mm F2.8G(D)',
            26131 => 'AF50mm F1.7',
            26241 => 'AF35-80mm F4-5.6',
            45741 => 'AF200mm F2.8G x2 or TOKINA 300mm F2.8 x2',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x0f00 => {
        Name => 'MinoltaCameraSettings2',
        Writable => 0,
    },
);

%Image::ExifTool::Minolta::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    1 => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture priority',
            2 => 'Shutter priority',
            3 => 'Manual',
        },
    },
    2 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Fill flash',
            1 => 'Red-eye reduction',
            2 => 'Rear flash sync',
            3 => 'Wireless',
        },
    },
    3 => {
        Name => 'WhiteBalance',
        PrintConv => 'Image::ExifTool::Minolta::ConvertWhiteBalance($val)',
    },
    4 => {
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Full',
            1 => '1600x1200',
            2 => '1280x960',
            3 => '640x480',
            6 => '2080x1560', #PH (A2)
            7 => '2560x1920', #PH (A2)
            8 => '3264x2176', #PH (A2)
        },
    },
    5 => {
        Name => 'MinoltaQuality',
        PrintConv => { #4
            0 => 'Raw',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    6 => {
        Name => 'DriveMode',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            2 => 'Self-timer',
            4 => 'Bracketing',
            5 => 'Interval',
            6 => 'UHS continuous',
            7 => 'HS continuous',
        },
    },
    7 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center weighted',
            2 => 'Spot',
        },
    },
    8 => {
        Name => 'MinoltaISO',
        ValueConv => '2 ** (($val/8-1))*3.125',
        PrintConv => 'int($val)',
    },
    9 => {
        Name => 'MinoltaShutterSpeed',
        ValueConv => '2 ** ((48-$val)/8)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    10 => {
        Name => 'MinoltaAperture',
        ValueConv => '2 ** ($val/16 - 0.5)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    11 => {
        Name => 'MacroMode',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'Off',
            1 => 'Electronic magnification',
            2 => '2x',
        },
    },
    13 => {
        Name => 'ExposureCompensation',
        ValueConv => '$val/3 - 2',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        ValueConvInv => '($val + 2) * 3',
        PrintConvInv => 'eval $val',
    },
    14 => {
        Name => 'BracketStep',
        PrintConv => {
            0 => '1/3 EV',
            1 => '2/3 EV',
            2 => '1 EV',
        },
    },
    16 => 'IntervalLength',
    17 => 'IntervalNumber',
    18 => {
        Name => 'FocalLength',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
        PrintConv => 'sprintf("%.1fmm",$val)',
        PrintConvInv => '$val=~s/mm$//;$val',
    },
    19 => {
        Name => 'FocusDistance',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '$val ? "$val m" : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s.*//, $val',
    },
    20 => {
        Name => 'FlashFired',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    21 => {
        Name => 'MinoltaDate',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'sprintf("%4d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    22 => {
        Name => 'MinoltaTime',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'sprintf("%.2d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    23 => {
        Name => 'MaxAperture',
        ValueConv => '2 ** ($val/16 - 0.5)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    26 => {
        Name => 'FileNumberMemory',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    27 => 'LastFileNumber',
    28 => {
        Name => 'ColorBalanceRed',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    29 => {
        Name => 'ColorBalanceGreen',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    30 => {
        Name => 'ColorBalanceBlue',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    31 => {
        Name => 'Saturation',
        ValueConv => '$val - ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    32 => {
        Name => 'Contrast',
        ValueConv => '$val - ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        PrintConv => 'Image::ExifTool::Exif::PrintParameter($val)',
        PrintConvInv => '$val=~/normal/i ? 0 : $val',
    },
    33 => {
        Name => 'Sharpness',
        PrintConv => {
            0 => 'Hard',
            1 => 'Normal',
            2 => 'Soft',
        },
    },
    34 => {
        Name => 'SubjectProgram',
        PrintConv => {
            0 => 'None',
            1 => 'Portrait',
            2 => 'Text',
            3 => 'Night portrait',
            4 => 'Sunset',
            5 => 'Sports action',
        },
    },
    35 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        ValueConv => '($val - 6) / 3',
        ValueConvInv => '$val * 3 + 6',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        PrintConvInv => 'eval $val',
    },
    36 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => '100',
            1 => '200',
            2 => '400',
            3 => '800',
            4 => 'auto',
            5 => '64',
        },
    },
    37 => {
        Name => 'MinoltaModel',
        PrintConv => {
            0 => 'DiMAGE 7 or X31',
            1 => 'DiMAGE 5',
            2 => 'DiMAGE S304',
            3 => 'DiMAGE S404',
            4 => 'DiMAGE 7i',
            5 => 'DiMAGE 7Hi',
            6 => 'DiMAGE A1',
            7 => 'DiMAGE A2 or S414',
        },
    },
    38 => {
        Name => 'IntervalMode',
        PrintConv => {
            0 => 'Still Image',
            1 => 'Time-lapse Movie',
        },
    },
    39 => {
        Name => 'FolderName',
        PrintConv => {
            0 => 'Standard Form',
            1 => 'Data Form',
        },
    },
    40 => {
        Name => 'ColorMode',
        PrintConv => {
            0 => 'Natural color',
            1 => 'Black&white',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
        },
    },
    41 => {
        Name => 'ColorFilter',
        ValueConv => '$val - ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{CameraModel}=~/DiMAGE A2/ ? 5 : 3)',
    },
    42 => 'BWFilter',
    43 => {
        Name => 'InternalFlash',
        PrintConv => {
            0 => 'No',
            1 => 'Fired',
        },
    },
    44 => {
        Name => 'Brightness',
        ValueConv => '$val/8 - 6',
        ValueConvInv => '($val + 6) * 8',
    },
    45 => 'SpotFocusPointX',
    46 => 'SpotFocusPointY',
    47 => {
        Name => 'WideFocusZone',
        PrintConv => {
            0 => 'No zone',
            1 => 'Center zone (horizontal orientation)',
            2 => 'Center zone (vertical orientation)',
            3 => 'Left zone',
            4 => 'Right zone',
        },
    },
    48 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },
    49 => {
        Name => 'FocusArea',
        PrintConv => {
            0 => 'Wide Focus (normal)',
            1 => 'Spot Focus',
        },
    },
    50 => {
        Name => 'DECPosition',
        PrintConv => {
            0 => 'Exposure',
            1 => 'Contrast',
            2 => 'Saturation',
            3 => 'Filter',
        },
    },
    # 7Hi only:
    51 => {
        Name => 'ColorProfile',
        Condition => '$self->{CameraModel} eq "DiMAGE 7Hi"',
        Notes => 'DiMAGE 7Hi only',
        PrintConv => {
            0 => 'Not Embedded',
            1 => 'Embedded',
        },
    },
    # (the following may be entry 51 for other models?)
    52 => {
        Name => 'DataImprint',
        Condition => '$self->{CameraModel} eq "DiMAGE 7Hi"',
        Notes => 'DiMAGE 7Hi only',
        PrintConv => {
            0 => 'None',
            1 => 'YYYY/MM/DD',
            2 => 'MM/DD/HH:MM',
            3 => 'Text',
            4 => 'Text + ID#',
        },
    },
);

# basic Minolta white balance lookup
my %minoltaWhiteBalance = (
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    5 => 'Custom',
    7 => 'Fluorescent',
    8 => 'Fluorescent 2',
    11 => 'Custom 2',
    12 => 'Custom 3',
    # the following come from tests with the A2 (ref 2)
    0x0800000 => 'Auto',
    0x1800000 => 'Daylight',
    0x2800000 => 'Cloudy',
    0x3800000 => 'Tungsten',
    0x4800000 => 'Flash',
    0x5800000 => 'Fluorescent',
    0x6800000 => 'Shade',
    0x7800000 => 'Custom1',
    0x8800000 => 'Custom2',
    0x9800000 => 'Custom3',
);

#------------------------------------------------------------------------------
# PrintConv for Minolta white balance
sub ConvertWhiteBalance($)
{
    my $val = shift;
    my $printConv = $minoltaWhiteBalance{$val};
    unless (defined $printConv) {
        # the A2 values can be shifted by += 3 settings, where
        # each setting adds or subtracts 0x001000 (ref 2)
        my $type = ($val & 0xff000000) + 0x800000;
        if ($type and $printConv = $minoltaWhiteBalance{$type}) {
            $printConv .= sprintf("%+.8g", ($val - $type) / 0x10000);
        } else {
            $printConv = sprintf("Unknown (0x%x)", $val);
        }
    }
    return $printConv;
}

#------------------------------------------------------------------------------
# Read or write Minolta MRW file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MRW file, or -1 on write error
sub ProcessMRW($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my $verbose = $exifTool->Options('Verbose');
    my $out = $exifTool->Options('TextOut');
    my ($data, $err);

    $raf->Read($data,8) == 8 or return 0;
    $data =~ /^\0MRM/ or return 0;
    $exifTool->SetFileType();
    SetByteOrder('MM');
    $outfile and $exifTool->InitWriteDirs('TIFF'); # use same write dirs as TIFF
    my $offset = Get32u(\$data, 4) + 8;
    my $pos = 8;
    my $rtnVal = 1;
    $verbose and printf $out "  [Data Offset: 0x%x]\n", $offset;
    # decode MRW structure to locate start of TIFF-format image (ref 5)
    while ($pos < $offset) {
        $raf->Read($data,8) == 8 or $err = 1, last;
        $pos += 8;
        my $tag = substr($data, 0, 4);
        my $len = Get32u(\$data, 4);
        if ($verbose) {
            print $out "MRW ",$exifTool->Printable($tag)," segment ($len bytes):\n";
            if ($verbose > 2) {
                $raf->Read($data,$len) == $len and $raf->Seek($pos,0) or $err = 1, last;
                my %parms = (Addr => $pos, Out => $out);
                $parms{MaxLen} = 96 unless $verbose > 3;
                Image::ExifTool::HexDump(\$data,undef,%parms);
            }
        }
        if ($tag eq "\0TTW") {
            # parse the TIFF structure after the TTW tag
            my %dirInfo = (
                Parent => 'MRW',
                RAF    => $raf,
                Base   => $pos,
            );
            # rewrite the EXIF information (plus the file header)
            my $buff = '';
            $dirInfo{OutFile} = \$buff if $outfile;
            my $result = $exifTool->ProcessTIFF(\%dirInfo);
            if ($result < 0) {
                $rtnVal = -1;
            } elsif (not $result) {
                $err = 1;
            } elsif ($outfile) {
                # adjust offset for new EXIF length
                my $newLen = length($buff) - $pos;
                $offset += $newLen - $len;
                Set32u($offset - 8, \$buff, 4);
                Set32u($newLen, \$buff, $pos - 4);
                Write($outfile, $buff) or $rtnVal = -1;
                # rewrite the rest of the file
                $pos += $len;
                $raf->Seek($pos, 0) or $err = 1, last;
                while ($raf->Read($buff, 65536)) {
                    Write($outfile, $buff) or $rtnVal = -1;
                }
                last;   # all done
            }
            last unless $verbose;
        }
        $pos += $len;
        $raf->Seek($pos, 0) or $err = 1, last;
    }
    $err and $exifTool->Error("MRW format error");
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Minolta - Minolta EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Minolta and Konica-Minolta maker notes in EXIF information, and to read
and write Minolta RAW (MRW) images.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.dalibor.cz/minolta/makernote.htm>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Jay Al-Saadi, Niels Kristian Bech Jensen, Shingo Noguchi and Pedro
Corte-Real for the information they provided.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
