#------------------------------------------------------------------------------
# File:         Photoshop.pm
#
# Description:  Definitions for Photoshop APP13 records
#
# Revisions:    02/06/04 - P. Harvey Created
#               02/25/04 - P. Harvey Added hack for problem with old photoshops
#               10/04/04 - P. Harvey Added a bunch of tags (ref Image::MetaData::JPEG)
#                          but left most of them commented out until I have enough
#                          information to write PrintConv routines for them to
#                          display something useful
#------------------------------------------------------------------------------

package Image::ExifTool::Photoshop;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(Get16u Get16s Get32u Get32s GetFloat GetDouble
                       GetByteOrder SetByteOrder);

$VERSION = '1.02';

sub ProcessPhotoshop($$$);

# Photoshop APP13 tag table
%Image::ExifTool::Photoshop::Main = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&ProcessPhotoshop,
#    0x03e9 => 'MacintoshPrintInfo',
#    0x03ea => 'XMLData?',
#    0x03ed => 'ResolutionInfo',
#    0x03ee => 'AlphaChannelsNames',
#    0x03ef => 'DisplayInfo',
#    0x03f0 => 'PStringCaption',
#    0x03f1 => 'BorderInformation',
#    0x03f2 => 'BackgroundColor',
#    0x03f3 => 'PrintFlags',
#    0x03f4 => 'BW_HalftoningInfo',
#    0x03f5 => 'ColorHalftoningInfo',
#    0x03f6 => 'DuotoneHalftoningInfo',
#    0x03f7 => 'BW_TransferFunc',
#    0x03f8 => 'ColorTransferFuncs',
#    0x03f9 => 'DuotoneTransferFuncs',
#    0x03fa => 'DuotoneImageInfo',
#    0x03fb => 'EffectiveBW',
#    0x03fe => 'QuickMaskInfo',
#    0x0400 => 'LayerStateInfo',
#    0x0401 => 'WorkingPath',
#    0x0402 => 'LayersGroupInfo',
    0x0404 => {
        Name => 'IPTCData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
#    0x0405 => 'RawImageMode',
#    0x0406 => 'JPEG_Quality',
#    0x0408 => 'GridGuidesInfo',
#    0x0409 => 'ThumbnailResource',
#    0x040a => 'CopyrightFlag',
    0x040b => {
        Name => 'URL',
        Groups => { 2 => 'Author' },
    },
    0x040c => {
        Name => 'PhotoshopThumbnail',
        Groups => { 2 => 'Image' },
        ValueConv => 'substr($val, 0x1c)',
        PrintConv => '\$val',
    },
#    0x040d => 'GlobalAngle',
#    0x040e => 'ColorSamplersResource',
#    0x040f => 'ICC_Profile',
#    0x0410 => 'Watermark',
#    0x0411 => 'ICC_Untagged',
#    0x0412 => 'EffectsVisible',
#    0x0413 => 'SpotHalftone',
#    0x0414 => 'IDsBaseValue',
#    0x0415 => 'UnicodeAlphaNames',
#    0x0416 => 'IndexedColourTableCount',
#    0x0417 => 'TransparentIndex',
#    0x0419 => 'GlobalAltitude',
#    0x041a => 'Slices',
#    0x041b => 'WorkflowURL',
#    0x041c => 'JumpToXPEP',
#    0x041d => 'AlphaIdentifiers',
#    0x041e => 'URL_List',
#    0x0421 => 'VersionInfo',
#    0x0bb7 => 'ClippingPathName',
#    0x2710 => 'PrintFlagsInfo',
);


#------------------------------------------------------------------------------
# Process Photoshop APP13 record
# Inputs: 0) ExifTool object reference, 1) Tag table reference
#         2) Reference to directory information
sub ProcessPhotoshop($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $pos = $dirInfo->{DirStart};
    my $dirEnd = $pos + $dirInfo->{DirLen};
    
    my $oldOrder = GetByteOrder();
    SetByteOrder('MM');     # IPTC is always big-endian
    
    # scan through resource blocks:
    # Format: 0) Type, 4 bytes - "8BIM"
    #         1) ID,   2 bytes - 0x0404 for IPTC data
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
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
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
                my %newDirInfo = (
                    DataPt   => \$value,
                    DataLen  => $size,
                    DirStart => 0,
                    DirLen   => $size,
                    DirBase  => 0,
                    
                );
                # process the directory
                $exifTool->ProcessTagTable($newTagTable, \%newDirInfo);
            } else {
                $exifTool->FoundTag($tagInfo, $value);
            }
        } elsif ($exifTool->Options('Verbose') > 1) {
            printf("  APP13 resource 0x%.4x:\n",$tag);
            Image::ExifTool::HexDump(\substr($$dataPt, $pos, $size));
        }
        $size += 1 if $size & 0x01; # size is padded to an even # bytes
        $pos += $size;
    }
    SetByteOrder($oldOrder);
}


1; # end


__END__

=head1 NAME

Image::ExifTool::Photoshop - Definitions for Photoshop meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

Photoshop writes its own format of meta information to the APP13 record in
JPEG files.  This module contains the definitions to read this information.

=head1 AUTHOR

Copyright 2003-2004, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
