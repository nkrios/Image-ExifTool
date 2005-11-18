#------------------------------------------------------------------------------
# File:         Ricoh.pm
#
# Description:  Ricoh EXIF maker notes tags
#
# Revisions:    03/28/2005  - P. Harvey Created
#
# References:   1) http://www.ozhiker.com/electronics/pjmt/jpeg_info/ricoh_mn.html
#------------------------------------------------------------------------------

package Image::ExifTool::Ricoh;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.01';

sub ProcessRicohText($$$);

%Image::ExifTool::Ricoh::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    0x0001 => 'MakerNoteType',
    0x0002 => 'MakerNoteVersion',
    0x0e00 => {
        Name => 'PrintIM',
        Writable => 0,
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x2001 => [
        {
            Name => 'RicohSubdir',
            Condition => '$self->{CameraModel} !~ /^Caplio RR1\b/',
            SubDirectory => {
                Validate => '$val =~ /^\[Ricoh Camera Info\]/',
                TagTable => 'Image::ExifTool::Ricoh::Subdir',
                Start => '$valuePtr + 20',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'RicohRR1Subdir',
            SubDirectory => {
                Validate => '$val =~ /^\[Ricoh Camera Info\]/',
                TagTable => 'Image::ExifTool::Ricoh::Subdir',
                Start => '$valuePtr + 20',
                ByteOrder => 'BigEndian',
                # the Caplio RR1 uses a different base address -- doh!
                Base => '$start-20',
            },
        },
    ],
);

# NOTE: this subdir is not currently writable because the offsets would require
# special code to handle the funny start location and base offset
%Image::ExifTool::Ricoh::Subdir = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    0x0004 => 'RicohDateTime1', #PH
    0x0005 => 'RicohDateTime2', #PH
);

# Ricoh text-type maker notes (PH)
%Image::ExifTool::Ricoh::Text = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessRicohText,
    Rev => 'Revision',
    Rv => 'Revision',
    Rg => 'RedGain',
    Gg => 'GreenGain',
    Bg => 'BlueGain',
);

#------------------------------------------------------------------------------
# Process Ricoh text-based maker notes
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessRicohText($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = $$dirInfo{DataLen};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $dataLen - $dirStart;
    my $verbose = $exifTool->Options('Verbose');
    
    my $data = substr($$dataPt, $dirStart, $dirLen);
    return 1 if $data =~ /^\0/;     # blank Ricoh maker notes
    # validate text maker notes
    unless ($data =~ /^(Rev|Rv)/) {
        $exifTool->Warn('Bad Ricoh maker notes');
        return 0;
    }
    my $pos = 0;
    while ($data =~ m/([A-Z][a-z]{1,2})([0-9A-F]+);/sg) {
        my $tag = $1;
        my $val = $2;
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $tag);
        if ($verbose) {
            $exifTool->VerboseInfo($tag, $tagInfo,
                Table  => $tagTablePtr,
                Value  => $val,
            );
        }
        unless ($tagInfo) {
            next unless $exifTool->{OPTIONS}->{Unknown};
            $tagInfo = {
                Name => "Ricoh_Text_$tag",
                Unknown => 1,
                PrintConv => 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val',
            };
            # add tag information to table
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $exifTool->FoundTag($tagInfo, $val);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Ricoh - Ricoh EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Ricoh maker notes EXIF meta information.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/ricoh_mn.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Ricoh Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
