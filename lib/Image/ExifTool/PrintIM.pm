#------------------------------------------------------------------------------
# File:         PrintIM.pm
#
# Description:  Definitions for PrintIM IFD
#
# Revisions:    04/07/2004  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::PrintIM;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(Get16u Get32u GetByteOrder SetByteOrder ToggleByteOrder);

$VERSION = '1.00';

sub ProcessPrintIM($$$);

# PrintIM table (is this proprietary? I can't find any documentation on this)
%Image::ExifTool::PrintIM::Main = (
    PROCESS_PROC => \&ProcessPrintIM,
    GROUPS => { 0 => 'PrintIM', 1 => 'PrintIM', 2 => 'Printing' },
    PRINT_CONV => 'sprintf("0x%.8x", $val)',
    TAG_PREFIX => 'PrintIM',
);


#------------------------------------------------------------------------------
# Process PrintIM IFD
# Inputs: 0) ExifTool object reference, 1) pointer to tag table
#         2) reference to directory information
# Returns: 1 on success
sub ProcessPrintIM($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $offset = $dirInfo->{DirStart};
    my $size = $dirInfo->{DirLen};

    unless ($size > 15) {
        $exifTool->Warn('Bad PrintIM data');
        return 0;
    }
    my $header = substr($$dataPt, $offset, 7);
    unless ($header eq 'PrintIM') {
        $exifTool->Warn('Invalid PrintIM header');
        return 0;
    }
    # check size of PrintIM block
    my $saveOrder = GetByteOrder();
    my $num = Get16u($dataPt, $offset + 14);
    if ($size < 16 + $num * 6) {
        # size is too big, maybe byte ordering is wrong
        ToggleByteOrder();
        $num = Get16u($dataPt, $offset + 14);
        if ($size < 16 + $num * 6) {
            $exifTool->Warn('Bad PrintIM size');
            SetByteOrder($saveOrder);
            return 0;
        }
    }
    my $n;
    for ($n=0; $n<$num; ++$n) {
        my $pos = $offset + 16 + $n * 6;
        my $tag = Get16u($dataPt, $pos);
        my $val = Get32u($dataPt, $pos + 2);
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        $tagInfo and $exifTool->FoundTag($tagInfo,$val);
    }
    SetByteOrder($saveOrder);
    return 1;
}



1;  # end
