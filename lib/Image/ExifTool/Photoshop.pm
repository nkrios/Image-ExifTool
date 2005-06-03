#------------------------------------------------------------------------------
# File:         Photoshop.pm
#
# Description:  Definitions for Photoshop IRB resource
#
# Revisions:    02/06/04 - P. Harvey Created
#               02/25/04 - P. Harvey Added hack for problem with old photoshops
#               10/04/04 - P. Harvey Added a bunch of tags (ref Image::MetaData::JPEG)
#                          but left most of them commented out until I have enough
#                          information to write PrintConv routines for them to
#                          display something useful
#
# References:   1) http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf
#               2) http://www.ozhiker.com/electronics/pjmt/jpeg_info/irb_jpeg_qual.html
#------------------------------------------------------------------------------

package Image::ExifTool::Photoshop;

use strict;
use vars qw($VERSION $AUTOLOAD);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.11';

sub ProcessPhotoshop($$$);
sub WritePhotoshop($$$);

# Photoshop APP13 tag table
# (set Unknown flag for information we don't want to display normally)
%Image::ExifTool::Photoshop::Main = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&ProcessPhotoshop,
    WRITE_PROC => \&WritePhotoshop,
    0x03e8 => { Unknown => 1, Name => 'Photoshop2Info' },
    0x03e9 => { Unknown => 1, Name => 'MacintoshPrintInfo' },
    0x03ea => { Unknown => 1, Name => 'XMLData' }, #PH
    0x03eb => { Unknown => 1, Name => 'Photoshop2ColorTable' },
    0x03ed => { Unknown => 1, Name => 'ResolutionInfo' },
    0x03ee => {
        Name => 'AlphaChannelsNames',
        PrintConv => 'Image::ExifTool::Photoshop::ConvertPascalString($val)',
    },
    0x03ef => { Unknown => 1, Name => 'DisplayInfo' },
    0x03f0 => { Unknown => 1, Name => 'PStringCaption' },
    0x03f1 => { Unknown => 1, Name => 'BorderInformation' },
    0x03f2 => { Unknown => 1, Name => 'BackgroundColor' },
    0x03f3 => { Unknown => 1, Name => 'PrintFlags' },
    0x03f4 => { Unknown => 1, Name => 'BW_HalftoningInfo' },
    0x03f5 => { Unknown => 1, Name => 'ColorHalftoningInfo' },
    0x03f6 => { Unknown => 1, Name => 'DuotoneHalftoningInfo' },
    0x03f7 => { Unknown => 1, Name => 'BW_TransferFunc' },
    0x03f8 => { Unknown => 1, Name => 'ColorTransferFuncs' },
    0x03f9 => { Unknown => 1, Name => 'DuotoneTransferFuncs' },
    0x03fa => { Unknown => 1, Name => 'DuotoneImageInfo' },
    0x03fb => { Unknown => 1, Name => 'EffectiveBW' },
    0x03fc => { Unknown => 1, Name => 'ObsoletePhotoshopTag1' },
    0x03fd => { Unknown => 1, Name => 'EPSOptions' },
    0x03fe => { Unknown => 1, Name => 'QuickMaskInfo' },
    0x03ff => { Unknown => 1, Name => 'ObsoletePhotoshopTag2' },
    0x0400 => { Unknown => 1, Name => 'LayerStateInfo' },
    0x0401 => { Unknown => 1, Name => 'WorkingPath' },
    0x0402 => { Unknown => 1, Name => 'LayersGroupInfo' },
    0x0403 => { Unknown => 1, Name => 'ObsoletePhotoshopTag3' },
    0x0404 => {
        Name => 'IPTCData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x0405 => { Unknown => 1, Name => 'RawImageMode' },
    0x0406 => { #2
        Name => 'JPEG_Quality',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::JPEG_Quality',
        },
    },
    0x0408 => { Unknown => 1, Name => 'GridGuidesInfo' },
    0x0409 => { Unknown => 1, Name => 'ThumbnailResource' },
    0x040a => { Unknown => 1, Name => 'CopyrightFlag' },
    0x040b => {
        Name => 'URL',
        Writable => 1,
        Groups => { 2 => 'Author' },
    },
    0x040c => {
        Name => 'PhotoshopThumbnail',
        Groups => { 2 => 'Image' },
        ValueConv => 'my $img=substr($val, 0x1c);\$img',
    },
    0x040d => { Unknown => 1, Name => 'GlobalAngle' },
    0x040e => { Unknown => 1, Name => 'ColorSamplersResource' },
    0x040f => { Unknown => 1, Name => 'ICC_Profile' },
    0x0410 => { Unknown => 1, Name => 'Watermark' },
    0x0411 => { Unknown => 1, Name => 'ICC_Untagged' },
    0x0412 => { Unknown => 1, Name => 'EffectsVisible' },
    0x0413 => { Unknown => 1, Name => 'SpotHalftone' },
    0x0414 => { Unknown => 1, Name => 'IDsBaseValue', Description => "ID's Base Value" },
    0x0415 => { Unknown => 1, Name => 'UnicodeAlphaNames' },
    0x0416 => { Unknown => 1, Name => 'IndexedColourTableCount' },
    0x0417 => { Unknown => 1, Name => 'TransparentIndex' },
    0x0419 => { Unknown => 1, Name => 'GlobalAltitude' },
    0x041a => { Unknown => 1, Name => 'Slices' },
    0x041b => { Unknown => 1, Name => 'WorkflowURL' },
    0x041c => { Unknown => 1, Name => 'JumpToXPEP' },
    0x041d => { Unknown => 1, Name => 'AlphaIdentifiers' },
    0x041e => { Unknown => 1, Name => 'URL_List' },
    0x0421 => { Unknown => 1, Name => 'VersionInfo' },
    0x0bb7 => { Unknown => 1, Name => 'ClippingPathName' },
    0x2710 => { Unknown => 1, Name => 'PrintFlagsInfo' },
);

# Photoshop JPEG quality record (ref 2)
%Image::ExifTool::Photoshop::JPEG_Quality = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'PhotoshopQuality',
        PrintConv => '$val + 4',
    },
    1 => {
        Name => 'PhotoshopFormat',
        PrintConv => {
            0x0000 => 'Standard',
            0x0001 => 'Optimised',
            0x0101 => 'Progressive',
        },
    },
    2 => {
        Name => 'ProgressiveScans',
        PrintConv => {
            1 => '3 Scans',
            2 => '4 Scans',
            3 => '5 Scans',
        },
    },
);


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Convert pascal string(s) to something we can use
# Inputs: 1) Pascal string data
# Returns: Strings, concatinated with ', '
sub ConvertPascalString($)
{
    my $inStr = shift;
    my $outStr = '';
    my $len = length($inStr);
    my $i=0;
    while ($i < $len) {
        my $n = ord(substr($inStr, $i, 1));
        last if $i + $n >= $len;
        $i and $outStr .= ', ';
        $outStr .= substr($inStr, $i+1, $n);
        $i += $n + 1;
    }
    return $outStr;
}

#------------------------------------------------------------------------------
# Process Photoshop APP13 record
# Inputs: 0) ExifTool object reference, 1) Tag table reference
#         2) Reference to directory information
# Returns: 1 on success
sub ProcessPhotoshop($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $pos = $dirInfo->{DirStart};
    my $dirEnd = $pos + $dirInfo->{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $success = 0;

    my $saveOrder = GetByteOrder();
    SetByteOrder('MM');     # Photoshop is always big-endian
    $verbose and $exifTool->VerboseDir('Photoshop', 0, $$dirInfo{DirLen});

    # scan through resource blocks:
    # Format: 0) Type, 4 bytes - "8BIM"
    #         1) TagID,2 bytes
    #         2) Name, null terminated string padded to even no. bytes
    #         3) Size, 4 bytes - N
    #         4) Data, N bytes
    while ($pos + 8 < $dirEnd) {
        my $type = substr($$dataPt, $pos, 4);
        if ($type ne '8BIM') {
            $exifTool->Warn("Bad APP13 data $type");
            last;
        }
        my $tag = Get16u($dataPt, $pos + 4);
        $pos += 6;
        # get resource block name (null-terminated, padded to an even # of bytes)
        my $name = '';
        my $bytes;
        while ($pos + 2 < $dirEnd) {
            $bytes = substr($$dataPt, $pos, 2);
            $pos += 2;
            $name .= $bytes;
            last if $bytes =~ /\0/;
        }
        if ($pos + 4 > $dirEnd) {
            $exifTool->Warn("Bad APP13 resource block");
            last;
        }
        my $size = Get32u($dataPt, $pos);
        $pos += 4;
        if ($size + $pos > $dirEnd) {
            # hack necessary because earlier versions of photoshop
            # sometimes don't put null terminator on string if it
            # ends at an even word boundary - PH 02/25/04
            if (defined($bytes) and $bytes eq "\0\0") {
                $pos -= 2;
                $size = Get32u($dataPt, $pos-4);
            }
            if ($size + $pos > $dirEnd) {
                $exifTool->Warn("Bad APP13 resource data size $size");
                last;
            }
        }
        $success = 1;
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        $verbose and $exifTool->VerboseInfo($tag, $tagInfo,
            'Table'  => $tagTablePtr,
            'DataPt' => $dataPt,
            'Size'   => $size,
            'Start'  => $pos,
        );
        if ($tagInfo) {
            my $value = substr($$dataPt, $pos, $size);
            my $subdir = $$tagInfo{SubDirectory};
            if ($subdir) {
                my $newTagTable;
                if ($$subdir{TagTable}) {
                    $newTagTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                    $newTagTable or warn "Unknown tag table $$subdir{TagTable}\n";
                } else {
                    $newTagTable = $tagTablePtr;
                }
                # build directory information hash
                my %subdirInfo = (
                    Name     => $$tagInfo{Name},
                    DataPt   => \$value,
                    DataPos  => $dirInfo->{DataPos} + $pos,
                    DataLen  => $size,
                    DirStart => 0,
                    DirLen   => $size,
                    Parent   => $dirInfo->{DirName},
                );
                # process the directory
                $exifTool->ProcessTagTable($newTagTable, \%subdirInfo, $$subdir{ProcessProc});
            } else {
                $exifTool->FoundTag($tagInfo, $value);
            }
        }
        $size += 1 if $size & 0x01; # size is padded to an even # bytes
        $pos += $size;
    }
    SetByteOrder($saveOrder);
    return $success;
}


1; # end


__END__

=head1 NAME

Image::ExifTool::Photoshop - Definitions for Photoshop IRB resource

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

Photoshop writes its own format of meta information called a Photoshop IRB
resource which is located in the APP13 record of JPEG files.  This module
contains the definitions to read this information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/irb_jpeg_qual.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Photoshop Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::MetaData::JPEG(3pm)|Image::MetaData::JPEG>

=cut
