#------------------------------------------------------------------------------
# File:         PostScript.pm
#
# Description:  Read PostScript meta information
#
# Revisions:    07/08/05 - P. Harvey Created
#
# References:   1) http://partners.adobe.com/public/developer/en/ps/5002.EPSF_Spec.pdf
#               2) http://partners.adobe.com/public/developer/en/ps/5001.DSC_Spec.pdf
#               3) http://partners.adobe.com/public/developer/en/illustrator/sdk/AI7FileFormat.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::PostScript;

use strict;
use vars qw($VERSION $AUTOLOAD);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.19';

sub WritePS($$);
sub CheckPS($$$);

# PostScript tag table
%Image::ExifTool::PostScript::Main = (
    WRITE_PROC => \&WritePS,
    CHECK_PROC => \&CheckPS,
    PREFERRED => 1, # always add these tags when writing
    GROUPS => { 2 => 'Image' },
    # Note: Make all of these tags priority 0 since the first one found at
    # the start of the file should take priority (in case multiples exist)
    Author      => { Priority => 0, Groups => { 2 => 'Author' }, Writable => 'string' },
    BoundingBox => { Priority => 0 },
    Copyright   => { Priority => 0, Writable => 'string' }, #2
    CreationDate => {
        Name => 'CreateDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
        Writable => 'string',
    },
    Creator     => { Priority => 0, Writable => 'string' },
    ImageData   => { Priority => 0 },
    For         => { Priority => 0, Writable => 'string', Notes => 'for whom the document was prepared'},
    Keywords    => { Priority => 0, Writable => 'string' },
    ModDate => {
        Name => 'ModifyDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
        Writable => 'string',
    },
    Pages       => { Priority => 0 },
    Routing     => { Priority => 0, Writable => 'string' }, #2
    Subject     => { Priority => 0, Writable => 'string' },
    Title       => { Priority => 0, Writable => 'string' },
    Version     => { Priority => 0, Writable => 'string' }, #2
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
    TIFFPreview => {
        Binary => 1,
        Notes => q{
            not a real tag ID, but used to represent the TIFF preview extracted from DOS
            EPS images
        },
    },
);

# composite tags
%Image::ExifTool::PostScript::Composite = (
    GROUPS => { 2 => 'Image' },
    # BoundingBox is in points, not pixels,
    # but use it anyway if ImageData is not available
    ImageWidth => {
        Desire => {
            0 => 'PostScript:ImageData',
            1 => 'PostScript:BoundingBox',
        },
        ValueConv => 'Image::ExifTool::PostScript::ImageSize(\@val, 0)',
    },
    ImageHeight => {
        Desire => {
            0 => 'PostScript:ImageData',
            1 => 'PostScript:BoundingBox',
        },
        ValueConv => 'Image::ExifTool::PostScript::ImageSize(\@val, 1)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::PostScript');

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Get image width or height
# Inputs: 0) value list ref (ImageData, BoundingBox), 1) true to get height
sub ImageSize($$)
{
    my ($vals, $getHeight) = @_;
    my ($w, $h);
    if ($$vals[0] and $$vals[0] =~ /^(\d+) (\d+)/) {
        ($w, $h) = ($1, $2);
    } elsif ($$vals[1] and $$vals[1] =~ /^(\d+) (\d+) (\d+) (\d+)/) {
        ($w, $h) = ($3 - $1, $4 - $2);
    }
    return $getHeight ? $h : $w;
}

#------------------------------------------------------------------------------
# Set PostScript format error warning
# Inputs: 0) ExifTool object reference, 1) error string
# Returns: 1
sub PSErr($$)
{
    my ($exifTool, $str) = @_;
    # set file type if not done already
    $exifTool->SetFileType('PS') unless $exifTool->GetValue('FileType');
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
    my ($data, $dos);
#
# determine if this is a postscript file
#
    $raf->Read($data, 4) == 4 or return 0;
    # accept either ASCII or DOS binary postscript file format
    return 0 unless $data =~ /^(%!PS|%!Ad|\xc5\xd0\xd3\xc6)/;
    if ($data =~ /^%!Ad/) {
        # I've seen PS files start with "%!Adobe-PS"...
        return 0 unless $raf->Read($data, 6) == 6 and $data eq "obe-PS";
    } elsif ($data =~ /^\xc5\xd0\xd3\xc6/) {
        # process DOS binary file header
        # - save DOS header then seek ahead and check PS header
        $raf->Read($dos, 26) == 26 or return 0;
        SetByteOrder('II');
        unless ($raf->Seek(Get32u(\$dos, 0), 0) and
                $raf->Read($data, 4) == 4 and $data eq '%!PS')
        {
            return PSErr($exifTool, 'invalid header');
        }
    }
#
# set the newline type based on the first newline found in the file
#
    my $oldsep = SetInputRecordSeparator($raf);
    $oldsep or return PSErr($exifTool, 'invalid PS data');

    # set file type (PostScript or EPS)
    $raf->ReadLine($data) or return 0;
    $exifTool->SetFileType($data =~ /EPSF/ ? 'EPS' : 'PS');
#
# extract TIFF information from DOS header
#
    my $tagTablePtr = GetTagTable('Image::ExifTool::PostScript::Main');
    if ($dos) {
        my $base = Get32u(\$dos, 16);
        if ($base) {
            my $pos = $raf->Tell();
            # extract the TIFF preview
            my $len = Get32u(\$dos, 20);
            my $val = $exifTool->ExtractBinary($base, $len, 'TIFFPreview');
            if (defined $val and $val =~ /^(MM\0\x2a|II\x2a\0|Binary)/) {
                $exifTool->HandleTag($tagTablePtr, 'TIFFPreview', $val);
            } else {
                $exifTool->Warn('Bad TIFF preview image');
            }
            # extract information from TIFF in DOS header
            # (set Parent to '' to avoid setting FileType tag again)
            my %dirInfo = (
                Parent => '',
                RAF => $raf,
                Base => $base,
            );
            $exifTool->ProcessTIFF(\%dirInfo) or $exifTool->Warn('Bad embedded TIFF');
            # position file pointer to extract PS information
            $raf->Seek($pos, 0);
        }
    }
#
# parse the postscript
#
    my ($buff, $mode, $endToken);
    my (@lines, $altnl);
    if ($/ eq "\x0d") {
        $altnl = "\x0a";
    } else {
        $/ = "\x0a";        # end on any LF (even if DOS CR+LF)
        $altnl = "\x0d";
    }
    for (;;) {
        if (@lines) {
            $data = shift @lines;
        } else {
            $raf->ReadLine($data) or last;
            # check for alternate newlines as efficiently as possible
            if ($data =~ /$altnl/) {
                # split into separate lines
                @lines = split /$altnl/, $data, -1;
                $data = shift @lines;
                if (@lines == 1 and $lines[0] eq $/) {
                    # handle case of DOS newline data inside file using Unix newlines
                    $data .= $lines[0];
                    undef @lines;
                }
            }
        }
        if ($mode) {
            if (not $endToken) {
                $buff .= $data;
                next unless $data =~ m{<\?xpacket end=.(w|r).\?>($/|$)};
            } elsif ($data !~ /^$endToken/i) {
                if ($mode eq 'XMP') {
                    $buff .= $data;
                } elsif ($mode eq 'Document') {
                    # ignore embedded documents 
                } else {
                    # data is ASCII-hex encoded
                    $data =~ tr/0-9A-Fa-f//dc;  # remove all but hex characters
                    $buff .= pack('H*', $data); # translate from hex
                }
                next;
            }
        } elsif ($data =~ /^(%{1,2})(Begin)(_xml_packet|Photoshop|ICCProfile|Binary)/i) {
            # the beginning of a data block
            my %modeLookup = (
                _xml_packet => 'XMP',
                iccprofile  => 'ICC_Profile',
                photoshop   => 'Photoshop',
            );
            $mode = $modeLookup{lc($3)};
            unless ($mode or @lines) {
                # skip binary data
                $raf->Seek($1, 1) or last if $data =~ /^%{1,2}BeginBinary:\s*(\d+)/i;
                next;
            }
            $buff = '';
            $endToken = $1 . ($2 eq 'begin' ? 'end' : 'End') . $3;
            next;
        } elsif ($data =~ /^(%{1,2})(Begin)(Document)/i) {
            $mode = 'Document';
            next;
        } elsif ($data =~ /^<\?xpacket begin=.{7,13}W5M0MpCehiHzreSzNTczkc9d/) {
            # pick up any stray XMP data
            $mode = 'XMP';
            $buff = $data;
            undef $endToken;    # no end token (just look for xpacket end)
            # XMP could be contained in a single line (if newlines are different)
            next unless $data =~ m{<\?xpacket end=.(w|r).\?>($/|$)};
        } elsif ($data =~ /^%%?(\w+): ?(.*)/s and $$tagTablePtr{$1}) {
            my ($tag, $val) = ($1, $2);
            # only allow 'ImageData' to have single leading '%'
            next unless $data =~ /^%%/ or $1 eq 'ImageData';
            # extract information from PostScript tags in comments
            $val =~ s/\x0d*\x0a*$//;        # remove trailing CR, LF or CR/LF
            if ($val =~ s/^\((.*)\)$/$1/) { # remove brackets if necessary
                $val =~ s/\) \(/, /g;       # convert contained brackets too
            }
            $exifTool->HandleTag($tagTablePtr, $tag, $val);
            next;
        } else {
            next;
        }
        # extract information from buffered data
        if ($mode ne 'Document'){
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
            undef $buff;
        }
        undef $mode;
    }
    $/ = $oldsep;   # restore original separator
    $mode and $mode ne 'Document' and PSErr($exifTool, "unterminated $mode data");
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

=head1 NOTES

Currently doesn't handle continued lines ("%+" syntax).

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://partners.adobe.com/public/developer/en/ps/5002.EPSF_Spec.pdf>

=item L<http://partners.adobe.com/public/developer/en/ps/5001.DSC_Spec.pdf>

=item L<http://partners.adobe.com/public/developer/en/illustrator/sdk/AI7FileFormat.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PostScript Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
