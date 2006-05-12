#------------------------------------------------------------------------------
# File:         Sony.pm
#
# Description:  Sony EXIF Maker Notes tags
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#------------------------------------------------------------------------------

package Image::ExifTool::Sony;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.05';

sub ProcessSRF($$$);
sub ProcessSR2($$$);

%Image::ExifTool::Sony::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0xb020 => 'ColorModeSetting', #PH
);

# tag table for Sony RAW Format
%Image::ExifTool::Sony::SRF = (
    PROCESS_PROC => \&ProcessSRF,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SRF#', 2 => 'Camera' },
    NOTES => q{
        The maker notes in SRF (Sony Raw Format) images contain 7 IFD's (with family
        1 group names SRF0 through SRF6).  SRF0 through SRF5 use these Sony tags,
        while SRF6 uses standard EXIF tags.  All information other than SRF0 is
        encrypted, but thanks to Dave Coffin the decryption algorithm is known.
    },
    0 => {
        Name => 'SRF2_Key',
        Notes => 'key to decrypt maker notes from the start of SRF2',
        RawConv => '$self->{SRF2_Key} = $val',
    },
    1 => {
        Name => 'DataKey',
        Notes => 'key to decrypt the rest of the file from the end of the maker notes',
        RawConv => '$self->{SRFDataKey} = $val',
    },
);

# tag table for Sony RAW 2 Format Private IFD (ref 1)
%Image::ExifTool::Sony::SR2Private = (
    PROCESS_PROC => \&ProcessSR2,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2', 2 => 'Camera' },
    NOTES => q{
        The SR2 format uses the DNGPrivateData tag to reference a private IFD
        containing these tags.
    },
    0x7200 => {
        Name => 'SR2SubIFDOffset',
        Flags => 'IsOffset',
        OffsetPair => 0x7201,
        RawConv => '$self->{SR2SubIFDOffset} = $val',
    },
    0x7201 => {
        Name => 'SR2SubIFDLength',
        OffsetPair => 0x7200,
        RawConv => '$self->{SR2SubIFDLength} = $val',
    },
    0x7221 => {
        Name => 'SR2SubIFDKey',
        Format => 'int32u',
        Notes => 'key to decrypt SR2SubIFD',
        RawConv => '$self->{SR2SubIFDKey} = $val',
    },
);

%Image::ExifTool::Sony::SR2SubIFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2', 2 => 'Camera' },
    NOTES => 'Tags in the encrypted SR2SubIFD',
    0x7303 => 'WB_GRBGLevels', #1
    0x74c0 => { #PH
        Name => 'SR2DataIFD',
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::SR2DataIFD',
            Start => '$val',
            MaxSubdirs => 6,
        },
    },
    0x74a0 => 'MaxApertureAtMaxFocal', #PH
    0x74a1 => 'MaxApertureAtMinFocal', #PH
);

%Image::ExifTool::Sony::SR2DataIFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2', 2 => 'Camera' },
    0x7770 => 'ColorMode', #PH
);

#------------------------------------------------------------------------------
# decrypt Sony data (ref 1)
# Inputs: 0) data reference, 1) start offset, 2) data length, 3) decryption key
# Returns: nothing (original data buffer is updated with decrypted data)
sub Decrypt($$$$)
{
    my ($dataPt, $start, $len, $key) = @_;
    my ($i, $j, @pad);
    my $words = $len / 4;

    for ($i=0; $i<4; ++$i) {
        my $lo = ($key & 0xffff) * 0x0edd + 1;
        my $hi = ($key >> 16) * 0x0edd + ($key & 0xffff) * 0x02e9 + ($lo >> 16);
        $pad[$i] = $key = (($hi & 0xffff) << 16) + ($lo & 0xffff);
    }
    $pad[3] = ($pad[3] << 1 | ($pad[0]^$pad[2]) >> 31) & 0xffffffff;
    for ($i=4; $i<0x7f; ++$i) {
        $pad[$i] = (($pad[$i-4]^$pad[$i-2]) << 1 |
                    ($pad[$i-3]^$pad[$i-1]) >> 31) & 0xffffffff;
    }
    my @data = unpack("x$start N$words", $$dataPt);
    for ($i=0x7f,$j=0; $j<$words; ++$i,++$j) {
        $data[$j] ^= $pad[$i & 0x7f] = $pad[($i+1) & 0x7f] ^ $pad[($i+65) & 0x7f];
    }
    substr($$dataPt, $start, $words*4) = pack('N*', @data);
}

#------------------------------------------------------------------------------
# Process SRF maker notes
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub ProcessSRF($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $start = $$dirInfo{DirStart};
    my $verbose = $exifTool->Options('Verbose');

    # process IFD chain
    my ($ifd, $success);
    for ($ifd=0; ; ) {
        my $srf = $$dirInfo{DirName} = "SRF$ifd";
        my $srfTable = $tagTablePtr;
        # SRF6 uses standard EXIF tags
        $srfTable = GetTagTable('Image::ExifTool::Exif::Main') if $ifd == 6;
        $exifTool->{SET_GROUP1} = $srf;
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $srfTable);
        delete $exifTool->{SET_GROUP1};
        last unless $success;
#
# get pointer to next IFD
#
        my $count = Get16u($dataPt, $$dirInfo{DirStart});
        my $dirEnd = $$dirInfo{DirStart} + 2 + $count * 12;
        last if $dirEnd + 4 > length($$dataPt);
        my $nextIFD = Get32u($dataPt, $dirEnd);
        last unless $nextIFD;
        $nextIFD -= $$dirInfo{DataPos}; # adjust for position of makernotes data
        $$dirInfo{DirStart} = $nextIFD;
#
# decrypt next IFD data if necessary
#
        ++$ifd;
        my ($key, $len);
        if ($ifd == 1) {
            # get the key to decrypt IFD1
            my $cp = $start + 0x8ddc;    # why?
            my $ip = $cp + 4 * unpack("x$cp C", $$dataPt);
            $key = unpack("x$ip N", $$dataPt);
            $len = $cp + $nextIFD;  # decrypt up to $cp
        } elsif ($ifd == 2) {
            # get the key to decrypt IFD2
            $key = $exifTool->{SRF2_Key};
            $len = length($$dataPt) - $nextIFD; # decrypt rest of maker notes
        } else {
            next;   # no decryption needed
        }
        # decrypt data
        Decrypt($dataPt, $nextIFD, $len, $key) if defined $key;
        next unless $verbose > 2;
        # display decrypted data in verbose mode
        $exifTool->VerboseDir("Decrypted SRF$ifd", 0, $nextIFD + $len);
        my %parms = (
            Prefix => "$exifTool->{INDENT}  ",
            Start => $nextIFD,
            DataPos => $$dirInfo{DataPos},
            Out => $exifTool->Options('TextOut'),
        );
        $parms{MaxLen} = 96 unless $verbose > 3;
        Image::ExifTool::HexDump($dataPt, $len, %parms);
    }
}

#------------------------------------------------------------------------------
# Process SR2 data
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub ProcessSR2($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $result = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
    return $result unless $result;
    my $offset = $exifTool->{SR2SubIFDOffset};
    my $length = $exifTool->{SR2SubIFDLength};
    my $key = $exifTool->{SR2SubIFDKey};
    my $raf = $$dirInfo{RAF};
    my $base = $$dirInfo{Base} || 0;
    if ($offset and $length and defined $key and $raf) {
        my $buff;
        if ($raf->Seek($offset+$base, 0) and $raf->Read($buff, $length)) {
            Decrypt(\$buff, 0, $length, $key);
            # display decrypted data in verbose mode
            if ($verbose > 2) {
                $exifTool->VerboseDir("Decrypted SR2SubIFD", 0, $length);
                my %parms = (
                    Out => $exifTool->{OPTIONS}->{TextOut},
                    Prefix => $exifTool->{INDENT},
                    Addr => $offset + $base,
                );
                $parms{MaxLen} = 96 unless $verbose > 3;
                Image::ExifTool::HexDump(\$buff, $length, %parms);
            }
            my %dirInfo = (
                DataPt => \$buff,
                DataLen => length $buff,
                DirStart => 0,
                DirName => 'SR2SubIFD',
                DataPos => $offset,
            );
            my $subTable = Image::ExifTool::GetTagTable('Image::ExifTool::Sony::SR2SubIFD');
            $result = $exifTool->ProcessDirectory(\%dirInfo, $subTable);
            
        } else {
            $exifTool->Warn('Error reading SR2 data');
        }
    }
    delete $exifTool->{SR2SubIFDOffset};
    delete $exifTool->{SR2SubIFDLength};
    delete $exifTool->{SR2SubIFDKey};
    return $result;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Sony - Sony EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Sony maker notes EXIF meta information.

=head1 NOTES

The Sony maker notes use the standard EXIF IFD structure, but unfortunately
the entries are large blocks of binary data for which I can find no
documentation.  You can use "exiftool -v3" to dump these blocks in hex.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sony Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
