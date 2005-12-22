#------------------------------------------------------------------------------
# File:         ID3.pm
#
# Description:  Read ID3 meta information from MP3 audio files
#
# Revisions:    09/12/2005 - P. Harvey Created
#
# References:   1) http://www.id3.org/
#               2) http://www.mp3-tech.org/
#------------------------------------------------------------------------------

package Image::ExifTool::ID3;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

sub ProcessID3v2($$$);

# This table is just for documentation purposes
%Image::ExifTool::ID3::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData, # (not really)
    NOTES => q{
ID3 information is found in different types of audio files, most notably MP3
files.
    },
    ID3v1 => {
        Name => 'ID3v1',
        SubDirectory => { TagTable => 'Image::ExifTool::ID3::v1' },
    },
    ID3v22 => {
        Name => 'ID3v2_2',
        SubDirectory => { TagTable => 'Image::ExifTool::ID3::v2_2' },
    },
    ID3v23 => {
        Name => 'ID3v2_3',
        SubDirectory => { TagTable => 'Image::ExifTool::ID3::v2_3' },
    },
    ID3v24 => {
        Name => 'ID3v2_4',
        SubDirectory => { TagTable => 'Image::ExifTool::ID3::v2_4' },
    },
);

# Mapping for ID3v1 Genre numbers
my %genre = (
      0 => 'Blues',
      1 => 'Classic Rock',
      2 => 'Country',
      3 => 'Dance',
      4 => 'Disco',
      5 => 'Funk',
      6 => 'Grunge',
      7 => 'Hip-Hop',
      8 => 'Jazz',
      9 => 'Metal',
     10 => 'New Age',
     11 => 'Oldies',
     12 => 'Other',
     13 => 'Pop',
     14 => 'R&B',
     15 => 'Rap',
     16 => 'Reggae',
     17 => 'Rock',
     18 => 'Techno',
     19 => 'Industrial',
     20 => 'Alternative',
     21 => 'Ska',
     22 => 'Death Metal',
     23 => 'Pranks',
     24 => 'Soundtrack',
     25 => 'Euro-Techno',
     26 => 'Ambient',
     27 => 'Trip-Hop',
     28 => 'Vocal',
     29 => 'Jazz+Funk',
     30 => 'Fusion',
     31 => 'Trance',
     32 => 'Classical',
     33 => 'Instrumental',
     34 => 'Acid',
     35 => 'House',
     36 => 'Game',
     37 => 'Sound Clip',
     38 => 'Gospel',
     39 => 'Noise',
     40 => 'AlternRock',
     41 => 'Bass',
     42 => 'Soul',
     43 => 'Punk',
     44 => 'Space',
     45 => 'Meditative',
     46 => 'Instrumental Pop',
     47 => 'Instrumental Rock',
     48 => 'Ethnic',
     49 => 'Gothic',
     50 => 'Darkwave',
     51 => 'Techno-Industrial',
     52 => 'Electronic',
     53 => 'Pop-Folk',
     54 => 'Eurodance',
     55 => 'Dream',
     56 => 'Southern Rock',
     57 => 'Comedy',
     58 => 'Cult',
     59 => 'Gangsta',
     60 => 'Top 40',
     61 => 'Christian Rap',
     62 => 'Pop/Funk',
     63 => 'Jungle',
     64 => 'Native American',
     65 => 'Cabaret',
     66 => 'New Wave',
     67 => 'Psychadelic',
     68 => 'Rave',
     69 => 'Showtunes',
     70 => 'Trailer',
     71 => 'Lo-Fi',
     72 => 'Tribal',
     73 => 'Acid Punk',
     74 => 'Acid Jazz',
     75 => 'Polka',
     76 => 'Retro',
     77 => 'Musical',
     78 => 'Rock & Roll',
     79 => 'Hard Rock',
     # The following genres are Winamp extensions
     80 => 'Folk',
     81 => 'Folk-Rock',
     82 => 'National Folk',
     83 => 'Swing',
     84 => 'Fast Fusion',
     85 => 'Bebob',
     86 => 'Latin',
     87 => 'Revival',
     88 => 'Celtic',
     89 => 'Bluegrass',
     90 => 'Avantgarde',
     91 => 'Gothic Rock',
     92 => 'Progressive Rock',
     93 => 'Psychedelic Rock',
     94 => 'Symphonic Rock',
     95 => 'Slow Rock',
     96 => 'Big Band',
     97 => 'Chorus',
     98 => 'Easy Listening',
     99 => 'Acoustic',
    100 => 'Humour',
    101 => 'Speech',
    102 => 'Chanson',
    103 => 'Opera',
    104 => 'Chamber Music',
    105 => 'Sonata',
    106 => 'Symphony',
    107 => 'Booty Bass',
    108 => 'Primus',
    109 => 'Porn Groove',
    110 => 'Satire',
    111 => 'Slow Jam',
    112 => 'Club',
    113 => 'Tango',
    114 => 'Samba',
    115 => 'Folklore',
    116 => 'Ballad',
    117 => 'Power Ballad',
    118 => 'Rhythmic Soul',
    119 => 'Freestyle',
    120 => 'Duet',
    121 => 'Punk Rock',
    122 => 'Drum Solo',
    123 => 'Acapella',
    124 => 'Euro-House',
    125 => 'Dance Hall',
    255 => 'None',
    # ID3v2 adds some text short forms...
    CR  => 'Cover',
    RX  => 'Remix',
);

# Tags for ID3v1
%Image::ExifTool::ID3::v1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 1 => 'ID3v1', 2 => 'Audio' },
    3 => {
        Name => 'Title',
        Format => 'string[30]',
    },
    33 => {
        Name => 'Artist',
        Groups => { 2 => 'Author' },
        Format => 'string[30]',
    },
    63 => {
        Name => 'Album',
        Format => 'string[30]',
    },
    93 => {
        Name => 'Year',
        Groups => { 2 => 'Time' },
        Format => 'string[4]',
    },
    97 => {
        Name => 'Comment',
        Format => 'string[30]',
    },
    127 => {
        Name => 'Genre',
        Notes => 'CR and RX are ID3v2 only',
        Format => 'int8u',
        PrintConv => \%genre,
    },
);

# Tags for ID2v2.2
%Image::ExifTool::ID3::v2_2 = (
    PROCESS_PROC => \&Image::ExifTool::ID3::ProcessID3v2,
    GROUPS => { 1 => 'ID3v2_2', 2 => 'Audio' },
    NOTES => q{
ExifTool extracts mainly text-based tags from ID3v2 information.  The tags
in the tables below are those extracted by ExifTool, and don't represent a
complete list of available ID3v2 tags.

ID3 version 2.2 tags.  (These are the tags written by iTunes 5.0.)
    },
    CNT => 'PlayCounter',
    COM => 'Comment',
    IPL => 'InvolvedPeople',
    PIC => {
        Name => 'Picture',
        ValueConv => '\$val',
    },
  # POP => 'Popularimeter',
    TAL => 'Album',
    TBP => 'BeatsPerMinute',
    TCM => 'Composer',
    TCO =>{
        Name => 'Genre',
        Notes => 'uses same lookup table as ID3v1 Genre',
        PrintConv => 'Image::ExifTool::ID3::PrintGenre($val)',
    },
    TCP => 'Compilation', # not part of spec, but used by iTunes
    TCR => 'Copyright',
    TDA => { Name => 'Date', Groups => { 2 => 'Time' } },
    TDY => 'PlaylistDelay',
    TEN => 'EncodedBy',
    TFT => 'FileType',
    TIM => { Name => 'Time', Groups => { 2 => 'Time' } },
    TKE => 'InitialKey',
    TLA => 'Language',
    TLE => 'Length',
    TMT => 'Media',
    TOA => { Name => 'OriginalArtist', Groups => { 2 => 'Author' } },
    TOF => 'OriginalFilename',
    TOL => 'OriginalLyricist',
    TOR => 'OriginalReleaseYear',
    TOT => 'OriginalAlbum',
    TP1 => { Name => 'Artist', Groups => { 2 => 'Author' } },
    TP2 => 'Band',
    TP3 => 'Conductor',
    TP4 => 'InterpretedBy',
    TPA => 'PartOfSet',
    TPB => 'Publisher',
    TRC => 'ISRC', # (international standard recording code)
    TRD => 'RecordingDates',
    TRK => 'Track',
    TSI => 'Size',
    TSS => 'EncoderSettings',
    TT1 => 'Grouping',
    TT2 => 'Title',
    TT3 => 'Subtitle',
    TXT => 'Lyricist',
    TXX => 'UserDefinedText',
    TYE => { Name => 'Year', Groups => { 2 => 'Time' } },
    ULT => 'Lyrics',
    WAF => 'FileRUL',
    WAR => { Name => 'ArtistURL', Groups => { 2 => 'Author' } },
    WAS => 'SourceURL',
    WCM => 'CommercialURL',
    WCP => 'CopyrightURL',
    WPB => 'PublisherURL',
    WXX => 'UserDefinedURL',
);

# tags common to ID3v2.3 and ID3v2.4
my %id3v2_common = (
    APIC => {
        Name => 'Picture',
        ValueConv => '\$val',
    },
    COMM => 'Comment',
  # OWNE => 'Ownership', # enc(1), _price, 00, _date(8), Seller
    PCNT => 'Play counter',
  # POPM => 'Popularimeter', # _email, 00, rating(1), counter(4-N)
    TALB => 'Album',
    TBPM => 'BeatsPerMinute',
    TCOM => 'Composer',
    TCON =>{
        Name => 'Genre',
        Notes => 'uses same lookup table as ID3v1 Genre',
        PrintConv => 'Image::ExifTool::ID3::PrintGenre($val)',
    },
    TCOP => 'Copyright',
    TDLY => 'PlaylistDelay',
    TENC => 'EncodedBy',
    TEXT => 'Lyricist',
    TFLT => 'FileType',
    TIT1 => 'Grouping',
    TIT2 => 'Title',
    TIT3 => 'Subtitle',
    TKEY => 'InitialKey',
    TLAN => 'Language',
    TLEN => {
        Name => 'Length',
        ValueConv => '$val / 1000',
        PrintConv => '"$val sec"',
    },
    TMED => 'Media',
    TOAL => 'OriginalAlbum',
    TOFN => 'OriginalFilename',
    TOLY => 'OriginalLyricist',
    TOPE => { Name => 'OriginalArtist', Groups => { 2 => 'Author' } },
    TOWN => 'FileOwner',
    TPE1 => { Name => 'Artist', Groups => { 2 => 'Author' } },
    TPE2 => 'Band',
    TPE3 => 'Conductor',
    TPE4 => 'InterpretedBy',
    TPOS => 'PartOfSet',
    TPUB => 'Publisher',
    TRCK => 'Track',
    TRSN => 'InternetRadioStationName',
    TRSO => 'InternetRadioStationOwner ',
    TSRC => 'ISRC', # (international standard recording code)
    TSSE => 'EncoderSettings',
    TXXX => 'UserDefinedText',
    USLT => 'Lyrics',
    USER => 'TermsOfUse',
    WCOM => 'CommercialURL',
    WCOP => 'CopyrightURL',
    WOAF => 'FileRUL',
    WOAR => { Name => 'ArtistURL', Groups => { 2 => 'Author' } },
    WOAS => 'SourceURL',
    WORS => 'InternetRadioStationURL',
    WPAY => 'PaymentURL',
    WPUB => 'PublisherURL',
    WXXX => 'UserDefinedURL',
);

# Tags for ID3v2.3
%Image::ExifTool::ID3::v2_3 = (
    PROCESS_PROC => \&Image::ExifTool::ID3::ProcessID3v2,
    GROUPS => { 1 => 'ID3v2_3', 2 => 'Audio' },
    NOTES => 'ID3 version 2.3 tags',
    %id3v2_common,  # include common tags
    IPLS => 'InvolvedPeople',
    TDAT => { Name => 'Date', Groups => { 2 => 'Time' } },
    TIME => { Name => 'Time', Groups => { 2 => 'Time' } },
    TORY => 'OriginalReleaseYear',
    TRDA => 'RecordingDates',
    TSIZ => 'Size',
    TYER => { Name => 'Year', Groups => { 2 => 'Time' } },
);

# Tags for ID3v2.4
%Image::ExifTool::ID3::v2_4 = (
    PROCESS_PROC => \&Image::ExifTool::ID3::ProcessID3v2,
    GROUPS => { 1 => 'ID3v2_4', 2 => 'Audio' },
    NOTES => 'ID3 version 2.4 tags',
    %id3v2_common,  # include common tags
    TDEN => { Name => 'EncodingTime',       Groups => { 2 => 'Time' } },
    TDOR => { Name => 'OriginalReleaseTime',Groups => { 2 => 'Time' } },
    TDRC => { Name => 'RecordingTime',      Groups => { 2 => 'Time' } },
    TDRL => { Name => 'ReleaseTime',        Groups => { 2 => 'Time' } },
    TDTG => { Name => 'TaggingTime',        Groups => { 2 => 'Time' } },
    TIPL => 'InvolvedPeople',
    TMCL => 'MusicianCredits',
    TMOO => 'Mood',
    TPRO => 'ProducedNotice',
    TSOA => 'AlbumSortOrder',
    TSOP => 'PerformerSortOrder',
    TSOT => 'TitleSortOrder',
    TSST => 'SetSubtitle',
);

# can't share tagInfo hashes between two tables, so we must make
# copies of the necessary hashes
{
    my $tag;
    foreach $tag (keys %id3v2_common) {
        next unless ref $id3v2_common{$tag} eq 'HASH';
        my %tagInfo = %{$id3v2_common{$tag}};
        $Image::ExifTool::ID3::v2_4{$tag} = \%tagInfo;
    }
}

#------------------------------------------------------------------------------
# Print ID3v2 Genre
# Inputs: TCON or TCO frame data
# Returns: Content type with decoded genre numbers
sub PrintGenre($)
{
    my $val = shift;
    # make sure that %genre has an entry for all numbers we are interested in
    # (genre numbers are in brackets for ID3v2.2 and v2.3)
    while ($val =~ /\((\d+)\)/g) {
        $genre{$1} or $genre{$1} = "Unknown ($1)";
    }
    # (genre numbers are separated by nulls in ID3v2.4,
    #  but nulls are converted to '/' by DecodeString())
    while ($val =~ /(?:^|\/)(\d+)/g) {
        $genre{$1} or $genre{$1} = "Unknown ($1)";
    }
    $val =~ s/\((\d+)\)/\($genre{$1}\)/g;
    $val =~ s/(^|\/)(\d+)/$1$genre{$2}/g;
    return $val;
}

#------------------------------------------------------------------------------
# Decode ID3 string
# Inputs: 0) ExifTool object reference, 1) string beginning with encoding byte
# Returns: Decoded string in scalar context, or list of strings in list context
sub DecodeString($$)
{
    my ($exifTool, $val) = @_;
    return '' unless length $val;
    my $enc = unpack('C', $val);
    return "<Unknown encoding> $val" unless $enc == 0 or $enc == 1;
    $val = substr($val, 1); # remove encoding byte
    $val =~ s/\0+$//;       # remove null padding if it exists
    my @vals;
    if ($enc) {
        @vals = split "\0\0", $val;
        foreach $val (@vals) {
            if ($val =~ s/^\xfe\xff//) {
                $val = $exifTool->Unicode2Byte($val, 'MM');
            } elsif ($val =~ s/^\xff\xfe//) {
                $val = $exifTool->Unicode2Byte($val, 'II');
            } # (else not really unicode)
        }
    } else {
        @vals = split "\0", $val;
    }
    return @vals if wantarray;
    return join('/',@vals);
}

#------------------------------------------------------------------------------
# Process ID3v2 information
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference
sub ProcessID3v2($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $vers = $$dirInfo{Version};
    my $verbose = $exifTool->Options('Verbose');
    my ($id, $len, $flags, $hi);

    $verbose and $exifTool->VerboseDir($tagTablePtr->{GROUPS}->{1}, 0, $size);

    for (;;$offset+=$len) {
        if ($vers >= 0x0300) {
            # version 2.3/2.4 frame header is 10 bytes
            last if $offset + 10 > $size;
            ($id, $len, $flags) = unpack("x${offset}a4Nn",$$dataPt);
            last if $id eq "\0\0\0\0";
            $offset += 10;
        } else {
            # version 2.2 frame header is 6 bytes
            last if $offset + 6 > $size;
            ($id, $hi, $len) = unpack("x${offset}a3Cn",$$dataPt);
            last if $id eq "\0\0\0";
            $len += $hi << 16;
            $offset += 6;
        }
        last if $offset + $len > $size;
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $id);
        if ($verbose) {
            $exifTool->VerboseInfo($id, $tagInfo,
                Table  => $tagTablePtr,
                Value  => substr($$dataPt, $offset, $len),
                DataPt => $dataPt,
                Size   => $len,
                Start  => $offset,
            );
        }
        next unless $tagInfo;
#
# decode data in this frame
#
        my $val = substr($$dataPt, $offset, $len);
        if ($id =~ /^T[^X]/ or $id =~ /^(IPL|IPLS)$/) {
            $val = DecodeString($exifTool, $val);
        } elsif ($id =~ /^(TXX|TXXX|WXX|WXXX)$/) {
            my @vals = DecodeString($exifTool, $val);
            foreach (0..1) { $vals[$_] = '' unless defined $vals[$_]; }
            ($val = "($vals[0]) $vals[1]") =~ s/^\(\) //;
        } elsif ($id =~ /^(COM|COMM|ULT|USLT)$/) {
            $len > 4 or $exifTool->Warn("Short $id frame"), next;
            substr($val, 1, 3) = '';    # remove language code
            my @vals = DecodeString($exifTool, $val);
            foreach (0..1) { $vals[$_] = '' unless defined $vals[$_]; }
            ($val = "($vals[0]) $vals[1]") =~ s/^\(\) //;
        } elsif ($id eq 'USER') {
            $len > 4 or $exifTool->Warn('Short USER frame'), next;
            substr($val, 1, 3) = '';    # remove language code
            $val = DecodeString($exifTool, $val);
        } elsif ($id =~ /^(CNT|PCNT)$/) {
            $len >= 4 or $exifTool->Warn("Short $id frame"), next;
            my $cnt = unpack('N', $val);
            my $i;
            for ($i=4; $i<$len; ++$i) {
                $cnt = $cnt * 256 + unpack("x${i}C", $val);
            }
            $val = $cnt;
        } elsif ($id =~ /^(PIC|APIC)$/) {
            $len >= 4 or $exifTool->Warn("Short $id frame"), next;
            my $enc = unpack('C', $val);
            my $hdr = ($id eq 'PIC') ? '.{5}.*?\0' : '..*?\0..*?\0';
            # remove header (encoding, image format or MIME type, picture type, description)
            $val =~ s/$hdr//s or $exifTool->Warn("Invalid $id frame"), next;
            $enc and $val =~ s/^\0//;   # remove 2nd terminator if Unicode encoding
        } else {
            $exifTool->Warn("Don't know how to handle $id frame");
            next;
        }
        $exifTool->FoundTag($tagInfo, $val);
    }
}

#------------------------------------------------------------------------------
# Extract ID3 information from an audio file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this file didn't contain ID3 information
sub ProcessID3($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    my $rtnVal = 0;

    # read first 3 bytes of file
    return 0 unless $raf->Read($buff, 3) == 3;
#
# look for ID3v2 header
#
    if ($buff =~ /^ID3/) {
        $exifTool->SetFileType();
        $rtnVal = 1;
        $raf->Read($buff, 7) == 7 or $exifTool->Warn('Short ID3 header'), return 1;
        my ($vers, $flags, $size) = unpack('nCN', $buff);
        $size & 0x80808080 and $exifTool->Warn('Invalid ID3 header'), return 1;
        my $verStr = sprintf("2.%d.%d", $vers >> 8, $vers & 0xff);
        $exifTool->VPrint(0, "ID3v$verStr:\n");
        if ($vers >= 0x0500) {
            $exifTool->Warn("Unsupported ID3 version: $verStr");
            return 1;
        }
        $size =  ($size & 0x0000007f) |
                (($size & 0x00007f00) >> 1) |
                (($size & 0x007f0000) >> 2) |
                (($size & 0x7f000000) >> 3);
        unless ($raf->Read($buff, $size) == $size) {
            $exifTool->Warn('Truncated ID3 data');
            return 1;
        }
        if ($flags & 0x80) {
            # reverse the unsynchronization
            $buff =~ s/\xff\x00/\xff/g;
        }
        if ($flags & 0x40) {
            # skip the extended header
            $size >= 4 or $exifTool->Warn('Bad ID3 extended header'), return 1;
            my $len = unpack('N', $buff);
            if ($len > length($buff) - 4) {
                $exifTool->Warn('Truncated ID3 extended header');
                return 1;
            }
            $buff = substr($buff, $len + 4);
        }
        my %dirInfo = (
            DataPt => \$buff,
            DirStart => 0,
            DirLen => length($buff),
            Version => $vers,
        );
        my $tagTablePtr;
        if ($vers >= 0x0400) {
            $tagTablePtr = GetTagTable('Image::ExifTool::ID3::v2_4');
        } elsif ($vers >= 0x0300) {
            $tagTablePtr = GetTagTable('Image::ExifTool::ID3::v2_3');
        } else {
            $tagTablePtr = GetTagTable('Image::ExifTool::ID3::v2_2');
        }
        $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
    }
#
# look for ID3v1 trailer
#
    if ($raf->Seek(-128, 2) and $raf->Read($buff, 128) == 128 and $buff =~ /^TAG/) {
        $rtnVal or $exifTool->SetFileType();
        $rtnVal = 1;
        $exifTool->VPrint(0, "ID3v1:\n");
        SetByteOrder('MM');
        my %dirInfo = (
            DataPt => \$buff,
            DirStart => 0,
            DirLen => length($buff),
        );
        my $tagTablePtr = GetTagTable('Image::ExifTool::ID3::v1');
        $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Extract ID3 information from an MP3 audio file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MP3 file
sub ProcessMP3($$)
{
    my ($exifTool, $dirInfo) = @_;

    return 1 if ProcessID3($exifTool, $dirInfo);
    my $raf = $$dirInfo{RAF};
    return 0 unless $raf->Seek(0, 0);   # rewind file
    my $buff;
    # see if this could be an MP3 file
    return 0 unless $raf->Read($buff, 2) == 2;
    # could be an MP3 file if it starts with 0xfff*
    my $word = unpack('n', $buff);
    return 0 unless ($word & 0xfff0) == 0xfff0;
    $exifTool->SetFileType();
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ID3 - Read ID3 meta information from MP3 audio files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract ID3
information from audio files.  ID3 information is found in MP3 and various
other types of audio files.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.id3.org/>

=item L<http://www.mp3-tech.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ID3 Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

