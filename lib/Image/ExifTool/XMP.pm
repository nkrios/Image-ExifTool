#------------------------------------------------------------------------------
# File:         XMP.pm
#
# Description:  Definitions for XMP tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

sub ProcessXMP($$$);

# XMP tags need only be specified if a conversion or name change is necessary
%Image::ExifTool::XMP::Main = (
    GROUPS => { 2 => 'Unknown' },
    PROCESS_PROC => \&ProcessXMP,
    # I'll leave these parameters alone since I don't know what the Photoshop values mean
    Contrast => { 
        Groups => { 2 => 'Camera' },
    },
    Saturation => {
        Groups => { 2 => 'Camera' },
    },
    Sharpness => {
        Groups => { 2 => 'Camera' },
    },
    WhiteBalance => { # already converted to ASCII
        Groups => { 2 => 'Camera' },
    },
    DateCreated => {
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    TimeCreated => {
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
    },
    MetadataDate => {
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ExposureBiasValue => {
        Groups => { 2 => 'Image' },
        Name => 'ExposureCompensation',
        PrintConv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
);

# composite tags
# (the main script looks for the special 'Composite' hash)
%Image::ExifTool::XMP::Composite = (
    # set ISO from ISOSpeedRatings if not specified
    ISO => {
        Condition => 'not $oldVal',
        Description => 'ISO Speed',
        Groups => { 2 => 'Image' },
        Require => {
            0 => 'ISOSpeedRatings',
        },
        ValueConv => '$val[0]',
    },
    # Note: the following 2 composite tags are duplicated in Image::ExifTool::IPTC
    # (only the first loaded definition is used)
    DateTimeCreated => {
        Description => 'Date/Time Created',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateCreated',
            1 => 'TimeCreated',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # set the original date/time from DateTimeCreated if not set already
    DateTimeOriginal => {
        Condition => 'not defined($oldVal)',
        Description => 'Shooting Date/Time',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateTimeCreated',
        },
        ValueConv => '$val[0]',
        PrintConv => '$valPrint[0]',
    },
);

# fill out XMP table with entries from main table if they don't exist
foreach (Image::ExifTool::TagTableKeys(\%Image::ExifTool::Exif::Main)) {
    next if Image::ExifTool::GetSpecialTag($_); # ignore special tags
    my $exifInfo = $Image::ExifTool::Exif::Main{$_};
    # just take first entry in table info array
    my $name;
    if (ref $exifInfo) {
        ref($exifInfo) eq 'ARRAY' and $exifInfo = $$exifInfo[0];
        $name = $$exifInfo{Name};
    } else {
        $name = $exifInfo;
    }
    next if $Image::ExifTool::XMP::Main{$name};
    my $tagInfo = { Name => $name };
    if (ref $exifInfo) {
        # use ValueConv, PrintConv, Description and Groups
        # from EXIF tag information (except Groups family 0 and 1)
        if (defined $$exifInfo{ValueConv}) {
            $$tagInfo{ValueConv} = $$exifInfo{ValueConv};
        }
        if (defined $$exifInfo{Description}) {
            $$tagInfo{Description} = $$exifInfo{Description};
        }
        if (defined $$exifInfo{PrintConv}) {
            $$tagInfo{PrintConv} = $$exifInfo{PrintConv};
        }
        if (defined $$exifInfo{Groups}) {
            foreach (keys %{$$exifInfo{Groups}}) {
                next if $_ < 2;
                $$tagInfo{Groups} or $$tagInfo{Groups} = { };
                $tagInfo->{Groups}->{$_} = $exifInfo->{Groups}->{$_};
            }
        }
    }
    $Image::ExifTool::XMP::Main{$name} = $tagInfo;
}

#------------------------------------------------------------------------------
# Process XMP data
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table, 2) DirInfo reference
# Returns: 1 on success
sub ProcessXMP($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my (@lines, $buff, $seqVal, @outterTag);

    return 0 unless $tagTablePtr;

    # take substring if necessary
    if ($dirInfo->{DirStart} != 0 or $dirInfo->{DataLen} != $dirInfo->{DirLen}) {
        $buff = substr($$dataPt, $dirInfo->{DirStart}, $dirInfo->{DirLen});
        $dataPt = \$buff;
    }
    # split XMP information into separate lines
    @lines = split /(\n|\r)/,$$dataPt;
    
    $exifTool->Options('Verbose') and print "-------- Start XMP --------\n";

    foreach (@lines) {
        my ($tag, $val);
        if (/<(\w*):(\w*).*?>(.+?)<\/\1:\2>/) {
            $tag = $2;
            $val = $3;
            if ($val =~ /^(-{0,1}\d+)\/(-{0,1}\d+)/) {
                $val = $1 / $2 if $2;       # calculate quotient
            } elsif ($val =~ /^(\d{4})-(\d{2})-(\d{2}).{1}(\d{2}:\d{2}:\d{2})/) {
                $val = "$1:$2:$3 $4";       # convert back to EXIF time format
            }
            if ($tag eq 'li') {
                if (defined $seqVal) {
                    $seqVal and $seqVal .= ', ';
                    $seqVal .= $val;
                    next;
                }
                next unless $tag = $outterTag[0];
            }
        } elsif (/<(\w*):(\w*)/) {
            if ($2 eq 'Seq' or $2 eq 'Bag') {
                if ($outterTag[0]) {
                    $seqVal = '';
                }
            } elsif ($2 ne 'Alt') {
                unshift @outterTag, $2;
            }
            next;
        } elsif (/<\/(\w*):(\w*)/) {
            if ($2 eq 'Seq' or $2 eq 'Bag') {
                next unless defined $seqVal;
                next unless $outterTag[0];
                $val = $seqVal;
                $tag = shift @outterTag;
                undef $seqVal;
            } elsif ($outterTag[0] and $2 eq $outterTag[0]) {
                shift @outterTag;
                next;
            } else {
                next;
            }
        } else {
            next;
        }
        # look up this tag in the XMP table
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            # construct tag information (use the default groups)
            $tagInfo = {
                'Name' => $tag,
                'Groups' => $$tagTablePtr{GROUPS},
                'GotGroups' => 1,
                'Table' => $tagTablePtr,
            };
            $$tagTablePtr{$tag} = $tagInfo; # add to this table for next time
        }
        $exifTool->FoundTag($tagInfo, $val);
    }
    $exifTool->Options('Verbose') and print "-------- End XMP --------\n";
    
    return 1;
}


1;  #end
