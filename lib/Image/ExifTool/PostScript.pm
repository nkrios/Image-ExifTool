#------------------------------------------------------------------------------
# File:         PostScript.pm
#
# Description:  Read PostScript meta information
#
# Revisions:    07/08/05 - P. Harvey Created
#
# References:   1) http://partners.adobe.com/public/developer/en/ps/5002.EPSF_Spec.pdf
#               2) http://partners.adobe.com/public/developer/en/illustrator/sdk/AI7FileFormat.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::PostScript;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

# PostScript tag table
%Image::ExifTool::PostScript::Main = (
    GROUPS => { 2 => 'Image' },
    # Note: Make all of these tags priority 0 since the first one found
    # at the start of the file should take priority.
    Author      => { Priority => 0, Groups => { 2 => 'Author' } },
    CreationDate => {
        Name => 'CreateDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
    },
    Creator     => { Priority => 0 },
    For         => { Priority => 0, Notes => 'found in AI files'},
    Keywords    => { Priority => 0 },
    ModDate => {
        Name => 'ModifyDate',
        Priority => 0,
        Groups => { 2 => 'Author' },
    },
    Subject     => { Priority => 0 },
    Title       => { Priority => 0 },
    # these subdirectories for documentation only
    BeginPhotoshop => {
        Name => 'PhotoshopData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
        },
    },
    BeginICCProfile => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    begin_xml_packet => {
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
);

#------------------------------------------------------------------------------
# Set PostScript format error warning
# Inputs: 0) ExifTool object reference, 1) error string
# Returns: 1
sub PSErr($$)
{
    my ($exifTool, $str) = @_;
    $exifTool->Warn("PostScript format error ($str)");
    return 1;
}

#------------------------------------------------------------------------------
# set $/ according to the current file
# Inputs: 0) RAF reference
# Returns: Original separator or undefined if on error
sub SetInputRecordSeparator($)
{
    my $raf = shift;
    my $oldsep = $/;
    my $pos = $raf->Tell(); # save current position
    my $data;
    $raf->Read($data,256) or return undef;
    my ($a, $d) = (999,999);
    $a = pos($data), pos($data) = 0 if $data =~ /\x0a/g;
    $d = pos($data) if $data =~ /\x0d/g;
    my $diff = $a - $d;
    if ($diff eq 1) {
        $/ = "\x0d\x0a";
    } elsif ($diff eq -1) {
        $/ = "\x0a\x0d";
    } elsif ($diff > 0) {
        $/ = "\x0d";
    } elsif ($diff < 0) {
        $/ = "\x0a";
    } else {
        return undef;       # error
    }
    $raf->Seek($pos, 0);    # restore original position
    return $oldsep;
}

#------------------------------------------------------------------------------
# Extract information from EPS, PS or AI file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid PostScript file
sub ProcessPS($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $data;
#
# determine postscript file type
#
    $raf->Read($data, 4) == 4 or return 0;
    # accept either ASCII or DOS binary postscript file format
    return 0 unless $data =~ /^(%!PS|\xc5\xd0\xd3\xc6)/;
    # this appears to be in PostScript format
    $exifTool->SetFileType('PostScript');
    # process DOS binary file header
    if ($data =~ /^\xc5\xd0\xd3\xc6/) {
        $raf->Read($data, 26) == 26 or return PSErr($exifTool,'truncated header');
        SetByteOrder('II');
        # extract information from embedded TIFF file
        # (set Parent to '' to avoid setting FileType tag again)
        my %dirInfo = (
            Parent => '',
            RAF => $raf,
            Base => Get32u(\$data, 16),
        );
        $exifTool->ProcessTIFF(\%dirInfo);
        # extract information from PostScript section
        $raf->Seek(Get32u(\$data, 0), 0);
        unless ($raf->Read($data, 4) == 4 and $data =~ /^%!/) {
            return PSErr($exifTool, 'invalid PS header');
        }
    }
#
# set the newline type based on the first newline found in the file
#
    my $oldsep = SetInputRecordSeparator($raf);
    $oldsep or return PSErr($exifTool, 'invalid PS data');
#
# parse the file
#
    my ($buff, $mode, $endToken);
    my $tagTablePtr = GetTagTable('Image::ExifTool::PostScript::Main');
    while ($raf->ReadLine($data)) {
        if ($mode) {
            if (not $endToken) {
                $buff .= $data;
                next unless $data =~ m{<\?xpacket end=.w.\?>$/};
            } elsif ($data !~ /^$endToken/i) {
                if ($mode eq 'XMP') {
                    $buff .= $data;
                } else {
                    # data is ASCII-hex encoded
                    $data =~ tr/0-9A-Fa-f//dc;  # remove all but hex characters
                    $buff .= pack('H*', $data); # translate from hex
                }
                next;
            }
        } elsif ($data =~ /^(%{1,2})(Begin)(_xml_packet|Photoshop|ICCProfile)/i) {
            # the beginning of a data block
            my %modeLookup = (
                _xml_packet => 'XMP',
                iccprofile  => 'ICC_Profile',
                photoshop   => 'Photoshop',
            );
            $mode = $modeLookup{lc($3)};
            $buff = '';
            $endToken = $1 . ($2 eq 'begin' ? 'end' : 'End') . $3;
            next;
        } elsif ($data =~ /^<\?xpacket begin=.{7,13}W5M0MpCehiHzreSzNTczkc9d/) {
            # pick up any stray XMP data
            $mode = 'XMP';
            $buff = $data;
            undef $endToken;    # no end token (just look for xpacket end)
            # XMP could be contained in a single line (if newlines are different)
            next unless $data =~ m{<\?xpacket end=.w.\?>$/};
        } elsif ($data =~ /^%%(\w+): (.*)/s and $$tagTablePtr{$1}) {
            # extract information from PostScript tags in comments
            my $tag = $1;
            my $val = $2;
            chomp $val;
            if ($val =~ s/^\((.*)\)$/$1/) { # remove brackets if necessary
                $val =~ s/\) \(/, /g;       # convert contained brackets too
            }
            $exifTool->HandleTag($tagTablePtr, $tag, $val);
            next;
        } else {
            next;
        }
        # extract information from buffered data
        my %dirInfo = (
            DataPt => \$buff,
            DataLen => length $buff,
            DirStart => 0,
            DirLen => length $buff,
            Parent => 'PostScript',
        );
        my $subTablePtr = GetTagTable("Image::ExifTool::${mode}::Main");
        unless ($exifTool->ProcessDirectory(\%dirInfo, $subTablePtr)) {
            $exifTool->Warn("Error processing $mode information in PostScript file");
        }
        undef $mode;
        undef $buff;
    }
    $/ = $oldsep;   # restore original separator
    $mode and PSErr($exifTool, "unterminated $mode data");
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from EPS file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid PostScript file
sub ProcessEPS($$)
{
    return ProcessPS($_[0],$_[1]);
}

1; # end


__END__

=head1 NAME

Image::ExifTool::PostScript - Read PostScript meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This code reads meta information from EPS (Encapsulated PostScript), PS
(PostScript) and AI (Adobe Illustrator) files.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://partners.adobe.com/public/developer/en/ps/5002.EPSF_Spec.pdf>

=item L<http://partners.adobe.com/public/developer/en/illustrator/sdk/AI7FileFormat.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PostScript Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
