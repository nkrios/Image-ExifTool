#------------------------------------------------------------------------------
# File:         Unknown.pm
#
# Description:  Definitions for Unknown EXIF Maker Notes
#
# Revisions:    04/07/2004  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Unknown;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(Get16u Get16s Get32u Get32s GetFloat GetDouble
                       GetByteOrder SetByteOrder ToggleByteOrder);

$VERSION = '1.01';

sub ProcessUnknown($$$);

# Unknown maker notes
%Image::ExifTool::Unknown::Main = (
    PROCESS_PROC => \&ProcessUnknown,
    GROUPS => { 0 => 'MakerNotes', 1 => 'MakerUnknown', 2 => 'Camera' },
    
    # this seems to be a common fixture, so look for it in unknown maker notes
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
            Start => '$valuePtr',
        },
    },
);


#------------------------------------------------------------------------------
# Process unknown maker notes
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
sub ProcessUnknown($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $offset = $dirInfo->{DirStart};
    my $size = $dirInfo->{DirLen};
    my $success = 0;
    
    # scan for something that looks like an IFD
    if ($size >= 14) {  # minimum size for an IFD
        my $saveOrder = GetByteOrder();
        my $i;
IFD_TRY: for ($i=0; $i<=20; $i+=2) {
            last if $i + 14 > $size;
            my $num = Get16u($dataPt, $offset + $i);
            next unless $num;
            # number of entries in an IFD should be between 1 and 255
            if (!($num & 0xff)) {
                # lower byte is zero -- byte order could be wrong
                ToggleByteOrder();
                $num >>= 8;
            } elsif ($num & 0xff00) {
                # upper byte isn't zero -- not an IFD
                next;
            }
            my $bytesFromEnd = $size - ($i + 2 + 12 * $num);
            if ($bytesFromEnd < 4) {
                next unless $bytesFromEnd==2 or $bytesFromEnd==0;
            }
            # do a quick validation of all format types
            my $index;
            for ($index=0; $index<$num; ++$index) {
                my $entry = $offset + $i + 2 + 12 * $index;
                my $format = Get16u($dataPt, $entry+2);
                if ($format < 1 or $format > 12) {
                    # allow a 0 format (for null padding) unless first entry
                    next IFD_TRY unless $format == 0 and $index;
                }
            }
            # looks like we found an IFD
            $dirInfo->{DirStart} = $offset + $i;
            $dirInfo->{DirLen} = $size - $i;
            # process like a standard EXIF directory
            $success = Image::ExifTool::Exif::ProcessExif($exifTool, $tagTablePtr, $dirInfo);
            last;
        }
        SetByteOrder($saveOrder);
    }
    # this makernote doesn't appear to be in standard IFD format
    return $success;
}


1;  # end
