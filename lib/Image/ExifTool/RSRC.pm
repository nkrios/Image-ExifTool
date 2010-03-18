#------------------------------------------------------------------------------
# File:         RSRC.pm
#
# Description:  Read Mac OS Resource information
#
# Revisions:    2010/03/17 - P. Harvey Created
#
# References:   1) http://developer.apple.com/legacy/mac/library/documentation/mac/MoreToolbox/MoreToolbox-99.html
#------------------------------------------------------------------------------

package Image::ExifTool::RSRC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# Information decoded from Mac OS resources
%Image::ExifTool::RSRC::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        Tags extracted from Mac OS resource files and DFONT files.  These tags may
        also be extracted from the resource fork of any file on a Mac OS system,
        either by adding "/rsrc" to the filename to process the resource fork alone,
        or by using the -ee (ExtractEmbedded) option to process the resource fork as
        a sub-document of the main file.
    },
    '8BIM'=> {
        Name => 'PhotoshopInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::Main' },
    },
    'vers' => 'ResourceVersion',
    'fnt ' => {
        Name => 'Font',
        SubDirectory => { TagTable => 'Image::ExifTool::Font::Name' },
    },
);

#------------------------------------------------------------------------------
# Read information from a Mac resource file (DFONT files) (ref 4)
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid resource file
sub ProcessRSRC($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($hdr, $map, $buff, $i, $j);

    # attempt to validate the format as thoroughly as practical
    return 0 unless $raf->Read($hdr, 30) == 30;
    my ($datOff, $mapOff, $datLen, $mapLen) = unpack('N*', $hdr);
    return 0 unless $raf->Seek(0, 2);
    my $fLen = $raf->Tell();
    return 0 if $datOff < 0x10 or $datOff + $datLen > $fLen;
    return 0 if $mapOff < 0x10 or $mapOff + $mapLen > $fLen or $mapLen < 30;
    return 0 if $datOff < $mapOff and $datOff + $datLen > $mapOff;
    return 0 if $mapOff < $datOff and $mapOff + $mapLen > $datOff;

    # read the resource map
    $raf->Seek($mapOff, 0) and $raf->Read($map, $mapLen) == $mapLen or return 0;
    SetByteOrder('MM');
    my $typeOff = Get16u(\$map, 24);
    my $nameOff = Get16u(\$map, 26);
    my $numTypes = Get16u(\$map, 28);

    # validate offsets in the resource map
    return 0 if $typeOff < 28 or $nameOff < 30;

    $exifTool->SetFileType('RSRC') unless $$exifTool{IN_RESOURCE};
    my $verbose = $exifTool->Options('Verbose');

    # parse resource type list
    for ($i=0; $i<=$numTypes; ++$i) {
        my $off = $typeOff + 2 + 8 * $i;    # offset of entry in type list
        last if $off + 8 > $mapLen;
        my $resType = substr($map,$off,4);  # resource type
        my $resNum = Get16u(\$map,$off+4);  # number of resources - 1
        my $refOff = Get16u(\$map,$off+6) + $typeOff; # offset to first resource reference
        my $tmp = $resNum + 1;
        # loop through all resources
        for ($j=0; $j<=$resNum; ++$j) {
            my $roff = $refOff + 12 * $j;
            last if $roff + 12 > $mapLen;
            # read only the 24-bit resource data offset
            my $tag = Get16u(\$map,$roff);
            my $resOff = (Get32u(\$map,$roff+4) & 0x00ffffff) + $datOff;
            my $resNameOff = Get16u(\$map,$roff+2) + $nameOff + $mapOff;
            my ($val, $valLen);
            # read the resource data if necessary
            if ($resType eq 'vers' or $resType eq '8BIM' or $verbose) {
                unless ($raf->Seek($resOff, 0) and $raf->Read($buff, 4) == 4 and
                        ($valLen = unpack('N', $buff)) < 1024000 and # arbitrary size limit
                        $raf->Read($val, $valLen) == $valLen)
                {
                    $exifTool->Warn("Error reading $resType resource");
                    next;
                }
            }
            if ($verbose) {
                my ($resName, $nameLen);
                $resName = '' unless $raf->Seek($resNameOff, 0) and $raf->Read($buff, 1) and
                    ($nameLen = ord $buff) != 0 and $raf->Read($resName, $nameLen) == $nameLen;
                $exifTool->VPrint(0,sprintf("$resType resource ID 0x%.4x (offset 0x%.4x, $valLen bytes, name='$resName'):\n", $tag, $resOff));
            }
            if ($resType eq 'vers') {
                # parse the 'vers' resource to get the long version string
                next unless $valLen > 8;
                # long version string is after short version
                my $p = 7 + Get8u(\$val, 6);
                next if $p >= $valLen;
                my $vlen = Get8u(\$val, $p++);
                next if $p + $vlen > $valLen;
                my $tagTablePtr = GetTagTable('Image::ExifTool::RSRC::Main');
                my $val = $exifTool->Decode(substr($val, $p, $vlen), 'MacRoman');
                $exifTool->HandleTag($tagTablePtr, 'vers', $val);
            } elsif ($resType eq 'sfnt') {
                # parse the OTF font block
                $raf->Seek($resOff + 4, 0) or next;
                $$dirInfo{Base} = $resOff + 4;
                require Image::ExifTool::Font;
                unless (Image::ExifTool::Font::ProcessOTF($exifTool, $dirInfo)) {
                    $exifTool->Warn('Unrecognized sfnt resource format');
                }
                $exifTool->OverrideFileType('DFONT');
            } elsif ($resType eq '8BIM') {
                my $ttPtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                $exifTool->HandleTag($ttPtr, $tag, $val,
                    DataPt  => \$val,
                    DataPos => $resOff + 4,
                    Size    => $valLen,
                    Start   => 0,
                    Parent  => 'RSRC',
                );
            } else {
                $exifTool->VerboseDump(\$val) if defined $val;
            }
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::RSRC - Read Mac OS Resource information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read Mac OS
resource files.

=head1 AUTHOR

Copyright 2003-2010, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://developer.apple.com/legacy/mac/library/documentation/mac/MoreToolbox/MoreToolbox-99.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/RSRC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

