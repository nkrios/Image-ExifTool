#------------------------------------------------------------------------------
# File:         Nikon.pm
#
# Description:  Definitions for Nikon EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#               05/17/2004 - P. Harvey Added information from Joseph Heled
#               09/21/2004 - P. Harvey Changed tag 2 to ISOUsed & added PrintConv
#------------------------------------------------------------------------------

package Image::ExifTool::Nikon;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(GetByteOrder SetByteOrder Get16u Get32u);

$VERSION = '1.00';

sub ProcessNikon($$$);

%Image::ExifTool::Nikon::Main = (
    PROCESS_PROC => \&ProcessNikon,
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0x0001 => {
        Name => 'FileSystemVersion',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_;',
    },
    # 0x0001 - unknown. Always 0210 for D70. Might be a version number?
    0x0002 => {
        # this is the ISO actually used by the camera
        # (may be different than ISO setting if auto)
        Name => 'ISOUsed',
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val;s/^0 //;$_',
    },
    0x0003 => 'ColorMode',
    0x0004 => 'Quality',
    0x0005 => 'WhiteBalance',
    0x0006 => 'Sharpness',
    0x0007 => 'FocusMode',
    0x0008 => 'FlashSetting',
    # FlashType shows 'Built-in,TTL' when builtin flash fires,
    # and 'Optional,TTL' when external flash is used
    0x0009 => 'FlashType',
    0x000b => 'WhiteBalanceFineTune',
    0x000c => 'ColorBalance1',
    # 0x000e last 3 bytes '010c00', first byte changes from shot to shot.
    0x000f => 'ISOSelection',
    0x0010 => {
        Name => 'DataDump',
        PrintConv => '\$val',
    },
    0x0011 => {
        Name => 'ThumbnailImageIFD',
        Groups => { 2 => 'Image' },
    },
    0x0012 => {
        Name => 'FEC',
        Format => 'Long',
        # just the top byte, signed
        PrintConv => 'sprintf("%.1f",($val >> 24)/6)'
    },
    # D70 - another ISO tag
    0x0013 => {
        Name => 'ISOSetting',
        PrintConv => '$_=$val;s/^0 //;$_',
    },
    # D70 Image boundry?? top x,y bot-right x,y
    0x0016 => 'ImageBoundry',
    0x0080 => 'ImageAdjustment',
    0x0081 => 'ToneComp',
    0x0082 => 'AuxiliaryLens',
    # 0x0083 => "LensBrand??",
    # 6 with the D70 kit len and nikon 70-300G, 2 for 2 sigma lens and 0 for old nikon
    # lens.
    0x0084 => {
        Name => "Lens",
        # short long ap short ap long
    },
    0x0085 => 'ManualFocusDistance',
    0x0086 => 'DigitalZoom',
    # 0x0087 1 byte. Flash related. 9 when flash fires, 0 otherwise
    0x0088 => {
        Name => 'AFPoint',
        Format => 'ULong',  # override format since ULong is more sensible
        PrintConv => {
            0x0000 => 'Center',
            0x0100 => 'Top',
            0x0200 => 'Bottom',
            0x0300 => 'Left',
            0x0400 => 'Right',

            # D70
            0x00001 => 'Single Area, Center',
            0x10002 => 'Single Area, Top',
            0x20004 => 'Single Area, Bottom',
            0x30008 => 'Single Area, Left',
            0x40010 => 'Single Area, Right',

            0x1000001 => 'Dynamic Area, Center',
            0x1010002 => 'Dynamic Area, Top',
            0x1020004 => 'Dynamic Area, Bottom',
            0x1030008 => 'Dynamic Area, Left',
            0x1040010 => 'Dynamic Area, Right',

            0x2000001 => 'Closest Subject,Center',
            0x2010002 => 'Closest Subject, Top',
            0x2020004 => 'Closest Subject, Bottom',
            0x2030008 => 'Closest Subject, Left',
            0x2040010 => 'Closest Subject, Right',
        },
    },
    # 0x008b First byte depends on len used, last 3 010c00
    #   40 with kit len, 48 with nikon 70-300G , 3c with sigma 70-300, 48 with old nikon
    #   70-210, 44 with sigma 135 400

    0x008c => {
        Name => 'NEFCurve1',
        PrintConv => '\$val',
    },
    0x008d => 'ColorHue' ,
    # LightSource shows 3 values COLORED SPEEDLIGHT NATURAL.
    # (SPEEDLIGHT when flash goes. Have no idea about difference between other two.)
    0x0090 => 'LightSource',
    0x0092 => 'HueAdjustment', 
    0x0094 => 'Saturation',
    0x0095 => 'NoiseReduction',
    0x0096 => {
        Name => 'NEFCurve2',
        PrintConv => '\$val',
    },
    0x0097 => [
        # the following information taken from dcraw:
        {
            Condition => '$self->{CameraModel} =~ /NIKON D70/',
            Name => 'ColorBalanceD70',
            # D70:  at file offset 'tag-value + base + 20', 4 16 bits numbers,
            # v[0]/v[1] , v[2]/v[3] are the red/blue multipliers.
            SubDirectory => {
                Start => '$valuePtr + 20',
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceD70',
            },
        },
        {
            Condition => '$self->{CameraModel} =~ /NIKON D2H/',
            Name => 'ColorBalance2DH',
            SubDirectory => {
                Start => '$valuePtr + 10',
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceD2H',
            },
        },
        {
            Condition => '$self->{CameraModel} =~ /NIKON D100/',
            Name => 'ColorBalanceD100',
            SubDirectory => {
                Start => '$valuePtr + 72',
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceD100',
            },
        },
        {
            Name => 'ColorBalanceUnknown',
        },
    ],
    # D70 gussing here
    0x0099 => 'NEFThumbnailSize',
    # 0x009a unknown shows '7.8 7.8' on all my shots
    # 0x00a0 looks like a camera serial number ie) 'NO= 300042a4'
    0x00a0 => 'SerialNumber',
    0x00a7 => 'ShutterCount',   # Number of shots taken by camera so far???
    0x00a9 => 'ImageOptimization',
    0x00aa => 'Saturation',
    0x00ab => 'VariProgram',
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
        },
    },
);

%Image::ExifTool::Nikon::ColorBalanceD70 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'ShortRational',
    FIRST_ENTRY => 0,
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        PrintConv => 'sprintf("%.5f",$val);',
    },
    1 => {
        Name => 'BlueBalance',
        PrintConv => 'sprintf("%.5f",$val);',
    },
);

%Image::ExifTool::Nikon::ColorBalanceD2H = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'ShortRational',
    FIRST_ENTRY => 0,
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        PrintConv => 'sprintf("%.5f",$val);',
    },
    1 => {
        Name => 'BlueBalance',
        ValueConv => '$val ? 1/$val : 0',
        PrintConv => 'sprintf("%.5f",$val);',
    },
);

%Image::ExifTool::Nikon::ColorBalanceD100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'UShort',
    FIRST_ENTRY => 0,
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'RedBalance',
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.5f",$val);',
    },
    1 => {
        Name => 'BlueBalance',
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.5f",$val);',
    },
);

%Image::ExifTool::Nikon::MakerNotesB = (
    PROCESS_PROC => \&ProcessNikon,
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0x0003 => {
        Name => 'Quality',
        Description => 'Image Quality',
    },
    0x0004 => 'ColorMode',
    0x0005 => 'ImageAdjustment',
    0x0006 => 'CCDSensitivity',
    0x0007 => 'WhiteBalance',
    0x0008 => 'Focus',
    0x000A => 'DigitalZoom',
    0x000B => 'Converter',
);

#------------------------------------------------------------------------------
# process Nikon maker notes
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
# Notes: This routine is necessary because Nikon is horribly inconsistent in
#        its maker notes format from one camera to the next, so the logic is
#        complicated enough that it warrants a subroutine of its own.
sub ProcessNikon($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $offset = $dirInfo->{DirStart};
    my $size = $dirInfo->{DirLen};
    my $success = 0;

    # get start of maker notes data
    my $header = substr($$dataPt, $offset, 10);

    # figure out what type of maker notes we are dealing with
    if ($header =~ /^Nikon\x00\x01/) {

        # this is a type A1 header -- ie)
        # 4e 69 6b 6f 6e 00 01 00 0b 00 02 00 02 00 06 00 [Nikon...........]

        # add offset to start of directory
        $dirInfo->{DirStart} += 8;
        $dirInfo->{DirLen} -= 8;
        # use table B
        my $table2 = Image::ExifTool::GetTagTable('Image::ExifTool::Nikon::MakerNotesB');
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $table2, $dirInfo);

    } elsif ($header =~ /^Nikon\x00\x02/) {

        # this is a type B2 header (NEF file) -- ie)
        # 4e 69 6b 6f 6e 00 02 10 00 00 4d 4d 00 2a 00 00 [Nikon.....MM.*..]
        # 00 08 00 2b 00 01 00 07 00 00 00 04 30 32 31 30 [...+........0210]

        # set our byte ordering
        my $saveOrder = GetByteOrder();
        unless (SetByteOrder(substr($$dataPt,$offset+10,2))) {
            $exifTool->Warn('Bad Nikon type 2 maker notes');
            return 0;
        }
        unless (Get16u($dataPt, $offset+12) == 42) {
            $exifTool->Warn('Invalid magic number for Nikon maker notes');
            return 0;
        }
        my $val = Get32u($dataPt, $offset+14);

        $dirInfo->{DirStart} += $val + 10;  # set offset to start of directory
        $dirInfo->{DirLen} -= $val + 10;
        $dirInfo->{DirBase} = $offset + 10; # base address for directory pointers

        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $tagTablePtr, $dirInfo);

        SetByteOrder($saveOrder);           # restore original byte order

    } elsif ($header =~ /^Nikon/) {

        $exifTool->Warn('Unrecognized Nikon maker notes');

    } else {

        # this is a type B header -- ie)
        # 12 00 01 00 07 00 04 00 00 00 00 01 00 00 02 00 [................]

        # process main Nikon table as standard EXIF
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $tagTablePtr, $dirInfo);
    }
    return $success;
}

1;  # end
