#------------------------------------------------------------------------------
# File:         Shortcuts.pm
#
# Description:  Definitions for tag shortcuts
#
# Revisions:    02/07/2004 - P. Harvey Moved out of Exif.pm
#               09/15/2004 - P. Harvey Added D70Boring from Greg Troxel
#------------------------------------------------------------------------------

package Image::ExifTool::Shortcuts;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

# this is a special table used to define command-line shortcuts
%Image::ExifTool::Shortcuts::Main = (
    # This is a shortcut to some common information which is useful in most images
    Common => [ 'FileName',
                'FileSize',
                'Model',
                'DateTimeOriginal',
                'ImageSize',
                'Quality',
                'FocalLength',
                'ShutterSpeed',
                'Aperture',
                'ISO',
                'WhiteBalance',
                'Flash',
    ],
    # This shortcut provides the same information as the Canon utilities
    Canon => [  'FileName',
                'Model',
                'DateTimeOriginal',
                'ShootingMode',
                'ShutterSpeed',
                'Aperture',
                'MeteringMode',
                'ExposureCompensation',
                'ISO',
                'Lens',
                'FocalLength',
                'ImageSize',
                'Quality',
                'FlashOn',
                'FlashType',
                'ConditionalFEC',
                'RedEyeReduction',
                'ShutterCurtainHack',
                'WhiteBalance',
                'FocusMode',
                'Contrast',
                'Sharpness',
                'Saturation',
                'ColorTone',
                'FileSize',
                'FileNumber',
                'DriveMode',
                'OwnerName',
                'SerialNumber',
    ],
    # This shortcut intends to remove tags which contain no useful
    #  information given that the file was created with a Nikon D70.
    # Use "--d70boring" to suppress tags in this list.
    D70Boring => [
                'Make',
                'XResolution',
                'YResolution',
                'ResolutionUnit',
                'YCbCrPositioning',
                'FileSource',
                'SceneType',
                'ThumbnailOffset',
                'ThumbnailLength',
                'CreateDate',
                'ComponentsConfiguration',
                'InteropIndex',
                'InteropVersion',
                'SubSecTime',
                'SubSecTimeDigitized',
                'SensingMethod',
                'CFAPattern',
                'ThumbnailImageIFD',
    ],
);


1; # end

__END__

=head1 NAME

Image::ExifTool::Shortcuts - Definitions for Image::ExifTool shortcuts

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains definitions for tag name shortcuts used by
Image::ExifTool.  You can customize this file to add your own
shortcuts.

=head1 AUTHOR

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
