#------------------------------------------------------------------------------
# File:         APP12.pm
#
# Description:  Read APP12 meta information
#
# Revisions:    10/18/2005 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::APP12;

use strict;
use vars qw($VERSION);

$VERSION = '1.05';

sub ProcessAPP12($$$);

# APP12 tags (ref PH)
%Image::ExifTool::APP12::Main = (
    PROCESS_PROC => \&ProcessAPP12,
    GROUPS => { 0 => 'APP12', 1 => 'PictureInfo', 2 => 'Image' },
    NOTES => q{
        The JPEG APP12 "Picture Info" segment was used by some older cameras, and
        contains ASCII-based meta information.  Below are some tags which have been
        observed Agfa and Polaroid images, however ExifTool will extract information
        from any tags found in this segment.
    },
    FNumber => {
        ValueConv => '$val=~s/^[A-Za-z ]*//;$val',  # Agfa leads with an 'F'
        PrintConv => 'sprintf("%.1f",$val)',
    },
    Aperture => {
        PrintConv => 'sprintf("%.1f",$val)',
    },
    TimeDate => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        ValueConv => '$val=~/^\d+$/ ? ConvertUnixTime($val) : $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Shutter => {
        Name => 'ExposureTime',
        ValueConv => '$val * 1e-6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    shtr => {
        Name => 'ExposureTime',
        ValueConv => '$val * 1e-6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
   'Serial#'    => {
        Name => 'SerialNumber',
        Groups => { 2 => 'Camera' },
    },
    Flash       => { PrintConv => { 0 => 'Off', 1 => 'On' } },
    Macro       => { PrintConv => { 0 => 'Off', 1 => 'On' } },
    StrobeTime  => { },
    Ytarget     => { Name => 'YTarget' },
    ylevel      => { Name => 'YLevel' },
    FocusPos    => { },
    FocusMode   => { },
    Quality     => { },
    ExpBias     => 'ExposureCompensation',
    FWare       => 'FirmwareVersion',
    StrobeTime  => { },
    Resolution  => { },
    Protect     => { },
    ConTake     => { },
    ImageSize   => { PrintConv => '$val=~tr/-/x/;$val' },
    ColorMode   => { },
    Zoom        => { },
    ZoomPos     => { },
    LightS      => { },
    Type        => {
        Name => 'CameraType',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraType',
        RawConv => '$self->{CameraType} = $val',
    },
    Version     => { Groups => { 2 => 'Camera' } },
    ID          => { Groups => { 2 => 'Camera' } },
);

# APP12 segment written in Photoshop "Save For Web" images
# (from tests with Photoshop 7 files - PH)
%Image::ExifTool::APP12::Ducky = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP12', 1 => 'Ducky', 2 => 'Image' },
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    NOTES => q{
        Photoshop uses the JPEG APP12 "Ducky" segment to store some information in
        "Save for Web" images.
    },
    # 0 = 1 in all my samples
    # 1 = 4 in all my samples
    # 2 = 0 in all my samples
    3 => { #PH
        Name => 'Quality',
        Priority => 0,
        PrintConv => '"$val%"',
    },
    # 4 = 0 if no copyright string, 3 otherwise (maybe number of integers to follow?)
    # ---- the following is only present if #4 above is 3 ----
    # 5 = number of bytes in copyright string, including character count #7 and null terminator
    # 6 = 0 in all my samples
    # 7 = number of unicode characters in copyright string, excluding null terminator
    8 => {
        Name => 'Copyright',
        Format => 'undef[$size-16]',
        Groups => { 2 => 'Author' },
        ValueConv => '$self->Unicode2Byte($val)',
    },
);

#------------------------------------------------------------------------------
# Process APP12 segment (ref PH)
# Inputs: 0) ExifTool object reference, 1) Directory information ref, 2) tag table ref
# Returns: 1 on success, 0 if this wasn't a recognized APP12
sub ProcessAPP12($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    if ($dirLen != $dirStart + length($$dataPt)) {
        my $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
    } else {
        pos($$dataPt) = $$dirInfo{DirStart};
    }
    my $verbose = $exifTool->Options('Verbose');
    my $success = 0;
    my $section = '';
    pos($$dataPt) = 0;

    # this regular expression is a bit complex, but basically we are looking for
    # section headers (ie. "[Camera Info]") and tag/value pairs (ie. "tag=value",
    # where "value" may contain white space), separated by spaces or CR/LF.
    # (APP12 uses CR/LF, but Olympus TextualInfo is similar and uses spaces)
    while ($$dataPt =~ /(\[.*?\]|[\w#-]+=[\x20-\x7e]+?(?=\s*([\n\r\0]|[\w#-]+=|\[|$)))/g) {
        my $token = $1;
        # was this a section name?
        if ($token =~ /^\[(.*)\]/) {
            $exifTool->VerboseDir($1) if $verbose;
            $section = ($token =~ /\[(\S+) ?Info\]/i) ? $1 : '';
            $success = 1;
            next;
        }
        $exifTool->VerboseDir($$dirInfo{DirName}) if $verbose and not $success;
        $success = 1;
        my ($tag, $val) = ($token =~ /(\S+)=(.+)/);
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        $verbose and $exifTool->VerboseInfo($tag, $tagInfo, Value => $val);
        unless ($tagInfo) {
            # add new tag to table
            $tagInfo = { Name => $tag };
            # put in Camera group if information in "Camera" section
            $$tagInfo{Groups} = { 2 => 'Camera' } if $section =~ /camera/i;
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $exifTool->FoundTag($tagInfo, $val);
    }
    return $success;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::APP12 - Read APP12 meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
APP12 meta information.

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/APP12 Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
