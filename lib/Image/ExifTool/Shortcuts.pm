#------------------------------------------------------------------------------
# File:         Shortcuts.pm
#
# Description:  Definitions for tag shortcuts
#
# Revisions:    02/07/2004 - P. Harvey Moved out of Exif.pm
#               09/15/2004 - P. Harvey Added D70Boring from Greg Troxel
#               01/11/2005 - P. Harvey Added Canon20D from Christian Koller
#               03/03/2005 - P. Harvey Added user defined shortcuts
#------------------------------------------------------------------------------

package Image::ExifTool::Shortcuts;

use strict;
use vars qw($VERSION);

$VERSION = '1.04';

# this is a special table used to define command-line shortcuts
%Image::ExifTool::Shortcuts::Main = (
    # This is a shortcut to some common information which is useful in most images
    Common => [
        'FileName',
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
    Canon => [
        'FileName',
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
    # courtesy of Christian Koller
    Canon20D => [
        'FileName',
        'Model',
        'DateTimeOriginal',
        'ShootingMode',
        'ShutterSpeedValue', #changed for 20D
        'ApertureValue', #changed for 20D
        'MeteringMode',
        'ExposureCompensation',
        'ISO',
        'Lens',
        'FocalLength',
        #'ImageSize', #wrong in CR2
        'ExifImageWidth', #instead
        'ExifImageLength', #instead
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
        'ColorSpace', # new
        'LongExposureNoiseReduction', #new
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

# load user-defined shortcuts if available
Image::ExifTool::LoadConfig();
if (defined %Image::ExifTool::Shortcuts::UserDefined) {
    my $shortcut;
    foreach $shortcut (keys %Image::ExifTool::Shortcuts::UserDefined) {
        my $val = $Image::ExifTool::Shortcuts::UserDefined{$shortcut};
        # also allow simple aliases
        $val = [ $val ] unless ref $val eq 'ARRAY';
        # save the user-defined shortcut or alias
        $Image::ExifTool::Shortcuts::Main{$shortcut} = $val;
    }
}


1; # end

__END__

=head1 NAME

Image::ExifTool::Shortcuts - Definitions for Image::ExifTool shortcuts

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains definitions for tag name shortcuts used by
Image::ExifTool.  You can customize this file to add your own shortcuts.

Individual users may also add their own shortcuts to the .ExifTool_config
file in their home directory.  The shortcuts are defined in a hash called
%Image::ExifTool::Shortcuts::UserDefined.  The keys of the hash are the
shortcut names, and the elements are either tag names or references to lists
of tag names.

An example shortcut definition in .ExifTool_config:

    %Image::ExifTool::Shortcuts::UserDefined = (
        MyShortcut => ['createdate','exposuretime','aperture'],
        MyAlias => 'FocalLengthIn35mmFormat',
    );

In this example, MyShortcut is a shortcut for the CreateDate, ExposureTime
and Aperture tags, and MyAlias is a shortcut for FocalLengthIn35mmFormat.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
