#------------------------------------------------------------------------------
# File:         Photoshop.pm
#
# Description:  Definitions for Photoshop APP13 records
#
# Revisions:    02/06/04 - P. Harvey Created
#               02/25/04 - P. Harvey Added hack for problem with old photoshops
#------------------------------------------------------------------------------

package Image::ExifTool::Photoshop;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(Get16u Get16s Get32u Get32s GetFloat GetDouble
                       GetByteOrder SetByteOrder);

$VERSION = '1.00';

sub ProcessPhotoshop($$$);

# Photoshop APP13 tag table
%Image::ExifTool::Photoshop::Main = (
    PROCESS_PROC => \&ProcessPhotoshop,
    0x0404 => {
        Name => 'IPTCData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x040c => {
        Name => 'PhotoshopThumbnail',
        Groups => { 2 => 'Image' },
        ValueConv => 'substr($val, 0x1c)',
        PrintConv => '\$val',
    },
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
