#------------------------------------------------------------------------------
# File:         Sigma.pm
#
# Description:  Definitions for Sigma EXIF Maker Notes
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# Reference:    http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html
#------------------------------------------------------------------------------

package Image::ExifTool::Sigma;

use strict;
use vars qw($VERSION);

$VERSION = '1.01';

%Image::ExifTool::Sigma::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0002 => 'SerialNumber',
    0x0003 => 'DriveMode',
    0x0004 => 'ResolutionMode',
    0x0005 => 'AFMode',
    0x0006 => 'FocusSetting',
    0x0007 => 'WhiteBalance',
    0x0008 => 'ExposureMode',
    0x0009 => 'MeteringMode',
    0x000a => 'Lens',
    0x000b => 'ColorSpace',
    0x000c => {
        Name => 'ExposureCompensation',
        ValueConv => '$val =~ s/Expo:\s*//, $val',
    },
    0x000d => {
        Name => 'Contrast',
        ValueConv => '$val =~ s/Cont:\s*//, $val',
    },
    0x000e => {
        Name => 'Shadow',
        ValueConv => '$val =~ s/Shad:\s*//, $val',
    },
    0x000f => {
        Name => 'Highlight',
        ValueConv => '$val =~ s/High:\s*//, $val',
    },
    0x0010 => {
        Name => 'Saturation',
        ValueConv => '$val =~ s/Satu:\s*//, $val',
    },
    0x0011 => {
        Name => 'Sharpness',
        ValueConv => '$val =~ s/Shar:\s*//, $val',
    },
    0x0012 => {
        Name => 'X3FillLight',
        ValueConv => '$val =~ s/Fill:\s*//, $val',
    },
    0x0014 => {
        Name => 'ColorAdjustment',
        ValueConv => '$val =~ s/CC:\s*//, $val',
    },
    0x0015 => 'AdjustmentMode',
    0x0016 => {
        Name => 'Quality',
        ValueConv => '$val =~ s/Qual:\s*//, $val',
    },
    0x0017 => 'Firmware',
    0x0018 => 'Software',
    0x0019 => 'AutoBracket',
);

1;  # end
