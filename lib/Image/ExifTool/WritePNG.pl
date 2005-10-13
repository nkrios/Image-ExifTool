#------------------------------------------------------------------------------
# File:         WritePNG.pl
#
# Description:  Routines for writing PNG metadata
#
# Revisions:    09/16/2005 - P. Harvey Created
#
# References:   1) http://www.libpng.org/pub/png/spec/1.2/
#------------------------------------------------------------------------------
package Image::ExifTool::PNG;

use strict;

#------------------------------------------------------------------------------
# Calculate CRC or update running CRC (ref 1)
# Inputs: 0) data reference, 1) running crc to update (undef intially)
#         2) data position (undef for 0), 3) data length (undef for all data),
# Returns: updated CRC
my @crcTable;
sub CalculateCRC($;$$$)
{
    my ($dataPt, $crc, $pos, $len) = @_;
    $crc = 0 unless defined $crc;
    $pos = 0 unless defined $pos;
    $len = length($$dataPt) - $pos unless defined $len;
    $crc ^= 0xffffffff;         # undo 1's complement
    # build lookup table unless done already
    unless (@crcTable) {
        my ($c, $n, $k);
        for ($n=0; $n<256; ++$n) {
            for ($k=0, $c=$n; $k<8; ++$k) {
                $c = ($c & 1) ? 0xedb88320 ^ ($c >> 1) : $c >> 1;
            }
            $crcTable[$n] = $c;
        }
    }
    # calculate the CRC
    foreach (unpack("x${pos}C$len", $$dataPt)) {
        $crc = $crcTable[($crc^$_) & 0xff] ^ ($crc >> 8);
    }
    return $crc ^ 0xffffffff;   # return 1's complement
}

#------------------------------------------------------------------------------
# Encode data in ASCII Hex
# Inputs: 0) input data reference
# Returns: Hex-encoded data (max 72 chars per line)
sub HexEncode($)
{
    my $dataPt = shift;
    my $len = length($$dataPt);
    my $hex = '';
    my $pos;
    for ($pos = 0; $pos < $len; $pos += 36) {
        my $n = $len - $pos;
        $n > 36 and $n = 36;
        $hex .= unpack('H*',substr($$dataPt,$pos,$n)) . "\n";
    }
    return $hex;
}

#------------------------------------------------------------------------------
# Write profile to tEXt or zTXt chunk (zTXt if Zlib is available)
# Inputs: 0) outfile, 1) Raw profile type, 2) profile header type, 3) data ref
# Returns: 1 on success
sub WriteProfile($$$$)
{
    my ($outfile, $rawType, $profile, $dataPt) = @_;
    my $txtHdr = sprintf("\ngeneric profile\n%8d\n", length($$dataPt));
    my $buff = $txtHdr . HexEncode($dataPt);
    my $prefix = "Raw profile type $rawType\0";
    $dataPt = \$buff;
    my $chnk = 'tEXt';
    # write profile as zTXt chunk if Zlib is available
    if (eval 'require Compress::Zlib') {
        my $deflate = Compress::Zlib::deflateInit();
        if ($deflate) {
            my $buf2 = $deflate->deflate($buff);
            if (defined $buf2) {
                $buf2 .= $deflate->flush();
                $dataPt = \$buf2;
                $chnk = 'zTXt';
                $prefix .= "\0";    # compression type byte (0=deflate)
            }
        }
    }
    my $hdr = pack('Na4', length($prefix) + length($$dataPt), $chnk) . $prefix;
    my $crc = CalculateCRC(\$hdr, undef, 4);
    $crc = CalculateCRC($dataPt, $crc);
    return Write($outfile, $hdr, $$dataPt, pack('N',$crc));
}

#------------------------------------------------------------------------------
# Add any outstanding new chunks to the PNG image
# Inputs: 0) ExifTool object ref, 1) output file or scalar ref
# Returns: true on success
sub AddChunks($$)
{
    my ($exifTool, $outfile) = @_;
    # write any outstanding PNG tags
    my $addTags = $exifTool->{ADD_PNG};
    delete $exifTool->{ADD_PNG};
    my ($tag, $dir, $err, $tagTablePtr);
    my $verbose = $exifTool->Options('Verbose');
    foreach $tag (sort keys %$addTags) {
        my $tagInfo = $$addTags{$tag};
        my $newValueHash = $exifTool->GetNewValueHash($tagInfo);
        next unless Image::ExifTool::IsCreating($newValueHash);
        my $val = Image::ExifTool::GetNewValues($newValueHash);
        if (defined $val) {
            my $data = "tEXt$tag\0$val";
            my $hdr = pack('N', length($data) - 4);
            my $cbuf = pack('N', CalculateCRC(\$data, undef));
            Write($outfile, $hdr, $data, $cbuf) or $err = 1;
            $verbose > 1 and print "    + $$tagInfo{Name} = '$val'\n";
            ++$exifTool->{CHANGED};
        }
    }
    $addTags = { };     # prevent from adding tags again
    # create any necessary directories
    foreach $dir (sort keys %{$exifTool->{ADD_DIRS}}) {
        my $buff;
        my %dirInfo = (
            Parent => 'PNG',
            DirName => $dir,
        );
        if ($dir eq 'IFD0') {
            $verbose and print "Creating EXIF profile:\n";
            $exifTool->{TIFF_TYPE} = 'APP1';
            $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
            # use specified byte ordering or ordering from maker notes if set
            my $byteOrder = $exifTool->Options('ByteOrder') || $exifTool->{MAKER_NOTE_BYTE_ORDER} || 'MM';
            unless (SetByteOrder($byteOrder)) {
                warn "Invalid byte order '$byteOrder'\n";
                $byteOrder = $exifTool->{MAKER_NOTE_BYTE_ORDER} || 'MM';
                SetByteOrder($byteOrder);
            }
            $dirInfo{NewDataPos} = 8,   # new data will come after TIFF header
            $dirInfo{Multi} = 1,        # allow multiple IFD's
            $buff = $exifTool->WriteDirectory(\%dirInfo, $tagTablePtr);
            if (defined $buff and length $buff) {
                my $tiffHdr = $byteOrder . Set16u(42) . Set32u(8);
                $buff = $Image::ExifTool::exifAPP1hdr . $tiffHdr . $buff;
                WriteProfile($outfile, 'APP1', 'generic', \$buff) or $err = 1;
            }
        } elsif ($dir eq 'XMP') {
            $verbose and print "Creating XMP profile:\n";
            # write new XMP data
            $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
            $buff = $exifTool->WriteDirectory(\%dirInfo, $tagTablePtr);
            if (defined $buff and length $buff) {
                $buff = $Image::ExifTool::xmpAPP1hdr . $buff;
                WriteProfile($outfile, 'APP1', 'generic', \$buff) or $err = 1;
            }
        } elsif ($dir eq 'IPTC') {
            $verbose and print "Creating IPTC profile:\n";
            # write new XMP data
            $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
            $buff = $exifTool->WriteDirectory(\%dirInfo, $tagTablePtr);
            if (defined $buff and length $buff) {
                WriteProfile($outfile, 'iptc', 'IPTC', \$buff) or $err = 1;
            }
        }
    }
    $exifTool->{ADD_DIRS} = { };    # prevent from adding dirs again
    return not $err;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WritePNG.pl - Routines for writing PNG metadata

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::PNG.

=head1 DESCRIPTION

This file contains routines to write PNG metadata.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::PNG(3pm)|Image::ExifTool::PNG>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
