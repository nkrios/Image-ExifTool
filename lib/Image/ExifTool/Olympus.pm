#------------------------------------------------------------------------------
# File:         Olympus.pm
#
# Description:  Definitions for Olympus EXIF Maker Notes
#
# Revisions:    12/09/2003 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Olympus;

use strict;
use vars qw($VERSION);

$VERSION = '1.01';

%Image::ExifTool::Olympus::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0200 => 'SpecialMode',
    0x0201 => { 
        Name => 'Quality', 
        Description => 'Image Quality',
        PrintConv => { 0 => 'SQ', 1 => 'HQ', 2 => 'SHQ' },
    },
    0x0202 => { 
        Name => 'Macro', 
        PrintConv => { 0 => 'Normal', 1 => 'Macro' },
    },
    0x0204 => 'DigitalZoom',
    0x0207 => 'SoftwareRelease',
    0x0208 => 'PictInfo',
    0x0209 => 'CameraID',
    0x0f00 => 'DataDump',
);


1;  # end
