#------------------------------------------------------------------------------
# File:         MakerNotes.pm
#
# Description:  Read and write EXIF maker notes
#
# Revisions:    11/11/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MakerNotes;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

sub ProcessUnknown($$$);

$VERSION = '1.23';

my $debug;          # set to 1 to enabled debugging code

# conditional list of maker notes
# Notes:
# - This is NOT a normal tag table!
# - All byte orders are now specified because we can now
#   write maker notes into a file with different byte ordering!
# - Put these in alphabetical order to make TagNames documentation nicer.
@Image::ExifTool::MakerNotes::Main = (
    # decide which MakerNotes to use (based on camera make/model)
    {
        Name => 'MakerNoteCanon',
        # (starts with an IFD)
        Condition => '$self->{CameraMake} =~ /^Canon/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Main',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteCasio',
        # do negative lookahead assertion just to get tags
        # in a nice order for documentation
        # (starts with an IFD)
        Condition => '$self->{CameraMake}=~/^CASIO(?! COMPUTER CO.,LTD)/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::Main',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteCasio2',
        # (starts with "QVC\0")
        Condition => '$self->{CameraMake}=~/^CASIO COMPUTER CO.,LTD/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Casio::Type2',
            Start => '$valuePtr + 6',
            ByteOrder => 'Unknown',
        },
    },
    {
        # The Fuji programmers really botched this one up,
        # but with a bit of work we can still read this directory
        Name => 'MakerNoteFujiFilm',
        # (starts with "FUJIFILM")
        Condition => '$self->{CameraMake} =~ /^FUJIFILM/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FujiFilm::Main',
            # there is an 8-byte maker tag (FUJIFILM) we must skip over
            OffsetPt => '$valuePtr+8',
            ByteOrder => 'LittleEndian',
            # the pointers are relative to the subdirectory start
            # (before adding the offsetPt) - PH
            Base => '$start',
        },
    },
    {
        Name => 'MakerNoteJVC',
        Condition => '$self->{CameraMake}=~/^JVC/ and $$valPt=~/^JVC /',
        SubDirectory => {
            TagTable => 'Image::ExifTool::JVC::Main',
            Start => '$valuePtr + 4',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteJVCText',
        Condition => '$self->{CameraMake}=~/^(JVC|Victor)/ and $$valPt=~/^VER:/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::JVC::Text',
        },
    },
    {
        Name => 'MakerNoteKodak1a',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/ and $$valPt=~/^KDK INFO/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak1b',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/ and $$valPt=~/^KDK/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        Name => 'MakerNoteKodak2',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/i and $$valPt=~/^.{8}Eastman/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type2',
            ByteOrder => 'BigEndian',
        },
    },
    {
        # not much to key on here, but we know the
        # upper byte of the year should be 0x07:
        Name => 'MakerNoteKodak3',
        Condition => '$self->{CameraMake}=~/^EASTMAN KODAK/ and $$valPt=~/^.{12}\x07/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type3',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak4',
        Condition => '$self->{CameraMake}=~/^Eastman Kodak/ and $$valPt=~/^.{41}JPG/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type4',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak5',
        Condition => q{
            $self->{CameraMake}=~/^EASTMAN KODAK/ and
            ($self->{CameraModel}=~/CX(4200|4230|4300|4310|6200|6230)/ or
            # try to pick up similar models we haven't tested yet
            $$valPt=~/^\0(\x1a\x18|\x3a\x08|\x59\xf8|\x14\x80)\0/)
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type5',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak6a',
        Condition => q{
            $self->{CameraMake}=~/^EASTMAN KODAK/ and
            $self->{CameraModel}=~/DX3215/
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type6',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKodak6b',
        Condition => q{
            $self->{CameraMake}=~/^EASTMAN KODAK/ and
            $self->{CameraModel}=~/DX3700/
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Type6',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        Name => 'MakerNoteKodakUnknown',
        Condition => '$self->{CameraMake}=~/Kodak/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Unknown',
            ByteOrder => 'BigEndian',
        },
    },
    {
        Name => 'MakerNoteKyocera',
        # (starts with "KYOCERA")
        Condition => '$self->{CameraMake}=~/^KYOCERA/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Unknown::Main',
            Start => '$valuePtr + 22',
            Base => '$start + 2',
            EntryBased => 1,
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteMinolta',
        Condition => q{
            $self->{CameraMake}=~/^(Konica Minolta|Minolta)/i and
            $$valPt !~ /^(MINOL|CAMER|FUJIFILM|MLY0|KC|\+M\+M|\xd7)/
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            ByteOrder => 'Unknown',
        },
    },
    {
        # the DiMAGE E323 (MINOL) and E500 (CAMER)
        Name => 'MakerNoteMinolta2',
        Condition => q{
            $self->{CameraMake} =~ /^(Konica Minolta|Minolta)/i and
            $$valPt =~ /^(MINOL|CAMER)/
        },
        SubDirectory => {
            # these models use Olympus tags in the range 0x200-0x221 plus 0xf00
            TagTable => 'Image::ExifTool::Olympus::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'Unknown',
        },
    },
    {
        # the DiMAGE F200
        Name => 'MakerNoteMinolta3',
        Condition => q{
            $self->{CameraMake} =~ /^(Konica Minolta|Minolta)/i and
            $$valPt =~ /^FUJIFILM/
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::FujiFilm::Main',
            OffsetPt => '$valuePtr+8',
            ByteOrder => 'LittleEndian',
            Base => '$start',
        },
    },
    {
        # /^MLY0/ - DiMAGE G400, G500, G530, G600
        # /^KC/   - Revio KD-420Z, DiMAGE E203
        # /^+M+M/ - DiMAGE E201
        # /^\xd7/ - DiMAGE RD3000
        Name => 'MakerNoteMinolta4',
        Condition => '$self->{CameraMake} =~ /^(Konica Minolta|Minolta)/i',
        Notes => 'not EXIF-based',
        ValueConv => '\$val',
        ValueConvInv => '$val',
    },
    {
        # this maker notes starts with a standard TIFF header at offset 0x0a
        Name => 'MakerNoteNikon',
        Condition => '$self->{CameraMake}=~/^NIKON/i and $$valPt=~/^Nikon\x00\x02/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Main',
            Start => '$valuePtr + 18',
            ByteOrder => 'Unknown',
            Base => '$start - 8',
        },
    },
    {
        # older Nikon maker notes
        Name => 'MakerNoteNikon2',
        Condition => '$self->{CameraMake}=~/^NIKON/ and $$valPt=~/^Nikon\x00\x01/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Type2',
            Start => '$valuePtr + 8',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        # Headerless Nikon maker notes
        Name => 'MakerNoteNikon3',
        Condition => '$self->{CameraMake}=~/^NIKON/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Main',
            ByteOrder => 'Unknown', # most are little-endian, but D1 is big
        },
    },
    {
        Name => 'MakerNoteOlympus',
        # (if Make is 'SEIKO EPSON CORP.', starts with "EPSON\0")
        # (if Make is 'OLYMPUS OPTICAL CO.,LTD' or 'OLYMPUS CORPORATION',
        #  starts with "OLYMP\0")
        Condition => '$self->{CameraMake} =~ /^(OLYMPUS|SEIKO EPSON|AGFA )/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Main',
            Start => '$valuePtr+8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteLeica',
        # (starts with "LEICA\0")
        Condition => '$self->{CameraMake} =~ /^LEICA/',
        SubDirectory => {
            # Leica uses the same format as Panasonic
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNotePanasonic',
        # (starts with "Panasonic\0")
        Condition => '$self->{CameraMake} =~ /^Panasonic/ and $$valPt!~/^MKE/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Panasonic::Main',
            Start => '$valuePtr+12',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNotePanasonic2',
        # (starts with "Panasonic\0")
        Condition => '$self->{CameraMake} =~ /^Panasonic/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Panasonic::Type2',
            ByteOrder => 'LittleEndian',
        },
    },
    {
        Name => 'MakerNotePentax',
        # (if Make is 'PENTAX Corporation', starts with "AOC\0" (also Samsung DX-1S))
        # (if Make is 'Asahi Optical Co.,Ltd', starts with an IFD)
        Condition => '$self->{CameraMake}=~/^(PENTAX|AOC|Asahi)/ or $$valPt=~/^AOC\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::Main',
            # process as Unknown maker notes because the start offset and
            # byte ordering are so variable
            ProcessProc => \&ProcessUnknown,
            ByteOrder => 'Unknown',
            # offsets can be totally whacky for Pentax maker notes,
            # so attempt to fix the offset base if possible
            FixBase => 1,
        },
    },
    {
        Name => 'MakerNoteRicoh',
        Condition => '$self->{CameraMake}=~/^RICOH/ and $$valPt=~/^Ricoh/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Ricoh::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteRicohText',
        Condition => '$self->{CameraMake}=~/^RICOH/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Ricoh::Text',
            ByteOrder => 'Unknown',
        },
    },
    {
        # Samsung PreviewImage
        %Image::ExifTool::previewImageTagInfo,
        Condition => '$self->{CameraMake}=~/^Samsung/ and $self->{CameraModel}=~/^<Digimax/',
        Notes => 'Samsung preview image',
    },
    {
        Name => 'MakerNoteSanyo',
        # (starts with "SANYO\0")
        Condition => '$self->{CameraMake}=~/^SANYO/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sanyo::Main',
            Validate => '$val =~ /^SANYO/',
            Start => '$valuePtr + 8',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSigma',
        # (starts with "SIGMA\0")
        Condition => '$self->{CameraMake}=~/^(SIGMA|FOVEON)/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sigma::Main',
            Validate => '$val =~ /^(SIGMA|FOVEON)/',
            Start => '$valuePtr + 10',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSony',
        # (starts with "SONY DSC \0")
        Condition => '$self->{CameraMake}=~/^SONY/ and $self->{TIFF_TYPE}!~/^(SRF|SR2|DNG)$/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::Main',
            # validate the maker note because this is sometimes garbage
            Validate => 'defined($val) and $val =~ /^SONY DSC/',
            Start => '$valuePtr + 12',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSonySRF',
        Condition => '$self->{CameraMake}=~/^SONY/ and $$valPt =~ /^\x01\x00/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::SRF',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteSonySR2',
        Condition => '$self->{CameraMake}=~/^SONY/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::Main',
            Start => '$valuePtr',
            ByteOrder => 'Unknown',
        },
    },
    {
        Name => 'MakerNoteUnknown',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Unknown::Main',
            ProcessProc => \&ProcessUnknown,
            ByteOrder => 'Unknown',
        },
    },
);

# insert writable properties so we can write our maker notes
my $tagInfo;
foreach $tagInfo (@Image::ExifTool::MakerNotes::Main) {
    $$tagInfo{Writable} = 'undef';
    $$tagInfo{WriteGroup} = 'ExifIFD';
    $$tagInfo{Groups} = { 1 => 'MakerNotes' };
    next unless $$tagInfo{SubDirectory};
    # set up this tag so we can write it
    $$tagInfo{ValueConv} = '\$val';
    $$tagInfo{ValueConvInv} = '$val';
    $$tagInfo{MakerNotes} = 1;
}

#------------------------------------------------------------------------------
# Get normal offset of value data from end of maker note IFD
# Inputs: 0) ExifTool object reference
# Returns: Array: 0) relative flag (undef for no change)
#                 1) normal offset from end of IFD to first value (empty if unknown)
#                 2-N) other possible offsets used by some models
# Notes: Directory size should be validated before calling this routine
sub GetMakerNoteOffset($)
{
    my $exifTool = shift;
    # figure out where we expect the value data based on camera type
    my $make = $exifTool->{CameraMake};
    my $model = $exifTool->{CameraModel};
    my ($relative, @offsets);

    # normally value data starts 4 bytes after end of directory, so this is the default
    if ($make =~ /^Canon/) {
        push @offsets, ($model =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/) ? 6 : 4;
        # some Canon models (FV-M30, Optura50, Optura60) leave 24 unused bytes
        # at the end of the IFD (2 spare IFD entries?)
        push @offsets, 28 if $model =~ /\b(FV\b|OPTURA)/;
    } elsif ($make =~ /^KYOCERA/) {
        push @offsets, 12;
    } elsif ($make =~ /^OLYMPUS/ and $model =~ /^E-(1|300|330)\b/) {
        push @offsets, 16;
    } elsif ($make =~ /^OLYMPUS/ and
        # these Olympus models are just weird
        $model =~ /^(C2500L|C-1Z?|C-5000Z|X-2|C720UZ|C725UZ|C150|C2Z|E-10|E-20|FerrariMODEL2003|u20D|u10D)\b/)
    {
        # no expected offset --> determine offset empirically via FixBase()
    } elsif ($make =~ /^(Panasonic|SONY|JVC)\b/) {
        push @offsets, 0;
    } elsif ($make eq 'FUJIFILM') {
        # some models have offset of 6, so allow that too (A345,A350,A360,A370)
        push @offsets, 4, 6;
    } elsif ($make =~ /^TOSHIBA/) {
        # similar to Canon, can also have 24 bytes of padding
        push @offsets, 0, 24;
    } elsif ($make =~ /^PENTAX/) {
        push @offsets, 4;
        # the Pentax addressing mode is determined automatically, but
        # sometimes the algorithm gets it wrong, but Pentax always uses
        # absolute addressing, so force it to be absolute
        $relative = 0;
    } elsif ($make =~ /^Konica Minolta/i) {
        # patch for DiMAGE X50, Xg, Z2 and Z10
        push @offsets, 4, -16;
    } elsif ($make =~ /^Minolta/) {
        # patch for DiMAGE 7, X20 and Z1
        push @offsets, 4, -8, -12;
    } else {
        push @offsets, 4;   # the normal offset
    }
    return ($relative, @offsets);
}

#------------------------------------------------------------------------------
# Get hash of value offsets / block sizes
# Inputs: 0) Data pointer, 1) offset to start of directory
# Returns: 0) hash reference: keys are offsets, values are block sizes
#          1) same thing, but with keys adjusted for value-based offsets
# Notes: Directory size should be validated before calling this routine
# - calculates MIN and MAX offsets in entry-based hash
sub GetValueBlocks($$)
{
    my ($dataPt, $dirStart) = @_;
    my $numEntries = Get16u($dataPt, $dirStart);
    my ($index, $valPtr, %valBlock, %valBlkAdj, $end);
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $format = Get16u($dataPt, $entry+2);
        last if $format < 1 or $format > 13;
        my $count = Get32u($dataPt, $entry+4);
        my $size = $count * $Image::ExifTool::Exif::formatSize[$format];
        next if $size <= 4;
        $valPtr = Get32u($dataPt, $entry+8);
        # save location and size of longest block at this offset
        unless (defined $valBlock{$valPtr} and $valBlock{$valPtr} > $size) {
            $valBlock{$valPtr} = $size;
        }
        # adjust for case of value-based offsets
        $valPtr += 12 * $index;
        unless (defined $valBlkAdj{$valPtr} and $valBlkAdj{$valPtr} > $size) {
            $valBlkAdj{$valPtr} = $size;
            my $end = $valPtr + $size;
            if (defined $valBlkAdj{MIN}) {
                # save minimum only if it has a value of 12 or greater
                $valBlkAdj{MIN} = $valPtr if $valBlkAdj{MIN} < 12 or $valBlkAdj{MIN} > $valPtr;
                $valBlkAdj{MAX} = $end if $valBlkAdj{MAX} > $end;
            } else {
                $valBlkAdj{MIN} = $valPtr;
                $valBlkAdj{MAX} = $end;
            }
        }
    }
    return(\%valBlock, \%valBlkAdj);
}

#------------------------------------------------------------------------------
# Fix base for value offsets in maker notes IFD (if necessary)
# Inputs: 0) ExifTool object ref, 1) DirInfo hash ref
# Return: amount of base shift (and $dirInfo Base and DataPos are updated,
#         and Relative or EntryBased may be set)
sub FixBase($$)
{
    local $_;
    my ($exifTool, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $entryBased = $$dirInfo{EntryBased};

    # get hash of value block positions
    my ($valBlock, $valBlkAdj) = GetValueBlocks($dataPt, $dirStart);
    return 0 unless %$valBlock;
#
# analyze value offsets to see if they need fixing.  The first task is to
# determine the minimum valid offset used (this is tricky, because we have
# to weed out bad offsets written by some cameras)
#
    my $dataPos = $$dirInfo{DataPos};
    my $ifdLen = 2 + 12 * Get16u($$dirInfo{DataPt}, $dirStart);
    my $ifdEnd = $dirStart + $ifdLen;
    my ($relative, @offsets) = GetMakerNoteOffset($exifTool);
    my $makeDiff = $offsets[0];
    my $fixBase = $exifTool->Options('FixBase');
    my $setBase = (defined $fixBase and $fixBase ne '') ? 1 : 0;
    my $verbose = $exifTool->Options('Verbose');
    my $dirName = $$dirInfo{DirName};
    my ($diff, $shift);

    # calculate expected minimum value offset
    my $expected = $dataPos + $ifdEnd + (defined $makeDiff ? $makeDiff : 4);
    $debug and print "$expected expected\n";

    # get sorted list of value offsets
    my @valPtrs = sort { $a <=> $b } keys %$valBlock;
    my $minPt = $valPtrs[0];    # if life were simple, this would be it

    # zero our counters
    my ($countNeg12, $countZero, $countOverlap) = (0, 0, 0);
    my ($valPtr, $last);
    foreach $valPtr (@valPtrs) {
        printf("%d - %d (%d)\n", $valPtr, $valPtr + $$valBlock{$valPtr},
               $valPtr - ($last || 0)) if $debug;
        if (defined $last) {
            my $diff = $valPtr - $last;
            if ($diff == 0 or $diff == 1) {
                ++$countZero;
            } elsif ($diff == -12 and not $entryBased) {
                # you get this when value offsets are relative to the IFD entry
                ++$countNeg12;
            } elsif ($diff < 0) {
                # any other negative difference indicates overlapping values
                ++$countOverlap if $valPtr; # (but ignore zero value pointers)
            } elsif ($diff >= $ifdLen) {
                # ignore previous minimum if we took a jump to near the expected value
                # (some values can be stored before the IFD)
                $minPt = $valPtr if abs($valPtr - $expected) <= 4;
            }
            # an offset less than 12 is surely garbage, so ignore it
            $minPt = $valPtr if $minPt < 12;
        }
        $last = $valPtr + $$valBlock{$valPtr};
    }
    # could this IFD be using entry-based offsets?
    if ((($countNeg12 > $countZero and $$valBlkAdj{MIN} >= $ifdLen - 2) or
         ($$valBlkAdj{MIN} == $ifdLen - 2 or $$valBlkAdj{MIN} == $ifdLen + 2)
        ) and $$valBlkAdj{MAX} <= $$dirInfo{DirLen}-2)
    {
        # looks like these offsets are entry-based, so use the offsets
        # which have been correcting for individual entry position
        $entryBased = 1;
        $verbose and $exifTool->Warn("$dirName offsets are entry-based");
    } else {
        # calculate difference from normal
        $diff = ($minPt - $dataPos) - $ifdEnd;
        $shift = 0;
        $countOverlap and $exifTool->Warn("Overlapping $dirName values");
        if ($entryBased) {
            $exifTool->Warn("$dirName offsets do NOT look entry-based");
            undef $entryBased;
            undef $relative;
        }
    }
#
# handle entry-based offsets
#
    if ($entryBased) {
        $debug and print "--> entry-based!\n";
        # most of my entry-based samples have first value immediately
        # after last IFD entry (ie. no padding or next IFD pointer)
        $makeDiff = 0;
        push @offsets, 4;   # but some do have a next IFD pointer
        # corrected entry-based offsets are relative to start of first entry
        my $expected = 12 * Get16u($$dirInfo{DataPt}, $dirStart);
        $diff = $$valBlkAdj{MIN} - $expected;
        # set up directory to read values with entry-based offsets
        # (ignore everything and set base to start of first entry)
        $shift = $dataPos + $dirStart + 2;
        $$dirInfo{Base} += $shift;
        $$dirInfo{DataPos} -= $shift;
        $$dirInfo{EntryBased} = 1;
        $$dirInfo{Relative} = 1;    # entry-based offsets are relative
        delete $$dirInfo{FixBase};  # no automatic base fix
        undef $fixBase unless $setBase;
    }
#
# return without doing shift if offsets look OK
#
    unless ($setBase) {
        # don't try to fix offsets for whacky cameras
        return $shift unless defined $makeDiff;
        # normal value data starts 4 bytes after IFD, but allow 0 or 4...
        return $shift if $diff == 0 or $diff == 4;
        # also check for allowed make-specific differences
        foreach (@offsets) {
            return $shift if $diff == $_;
        }
    }
#
# apply the fix, or issue a warning
#
    # use default padding of 4 bytes unless already specified
    $makeDiff = 4 unless defined $makeDiff;
    my $fix = $makeDiff - $diff;    # assume standard diff for this make

    if ($$dirInfo{FixBase}) {
        # set flag if offsets are relative (base is at or above directory start)
        if ($dataPos - $fix + $dirStart <= 0) {
            $$dirInfo{Relative} = (defined $relative) ? $relative : 1;
        }
        if ($setBase) {
            $fix += $fixBase;
            $exifTool->Warn("Adjusted $dirName base by $fixBase",1);
        }
    } elsif (defined $fixBase) {
        $fix = $fixBase if $fixBase ne '';
        $exifTool->Warn("Adjusted $dirName base by $fix",1);
    } else {
        # print warning unless difference looks reasonable
        if ($diff < 0 or $diff > 16 or ($diff & 0x01)) {
            $exifTool->Warn("Possibly incorrect maker notes offsets (fix by $fix?)",1);
        }
        # don't do the fix (but we already adjusted base if entry-based)
        return $shift;
    }
    $$dirInfo{Base} += $fix;
    $$dirInfo{DataPos} -= $fix;
    return $fix + $shift;
}

#------------------------------------------------------------------------------
# Find start of IFD in unknown maker notes
# Inputs: 0) reference to directory information
# Returns: offset to IFD on success, undefined otherwise
# - dirInfo may contain TagInfo reference for tag associated with directory
# - on success, updates DirStart, DirLen, Base and DataPos in dirInfo
# - also sets Relative flag in dirInfo if offsets are relative to IFD
# Note: Changes byte ordering!
sub LocateIFD($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $size = $$dirInfo{DirLen} || ($$dirInfo{DataLen} - $dirStart);
    my $tagInfo = $$dirInfo{TagInfo};
    my $ifdOffsetPos;
    # the IFD should be within the first 32 bytes
    # (Kyocera sets the current record at 22 bytes)
    my ($firstTry, $lastTry) = (0, 32);

    # make sure Base and DataPos are defined
    $$dirInfo{Base} or $$dirInfo{Base} = 0;
    $$dirInfo{DataPos} or $$dirInfo{DataPos} = 0;
#
# use tag information (if provided) to determine directory location
#
    if ($tagInfo and $$tagInfo{SubDirectory}) {
        my $subdir = $$tagInfo{SubDirectory};
        unless ($$subdir{ProcessProc} and $$subdir{ProcessProc} eq \&ProcessUnknown) {
            # look for the IFD at the "Start" specified in our SubDirectory information
            my $valuePtr = $dirStart;
            my $newStart = $dirStart;
            if (defined $$subdir{Start}) {
                #### eval Start ($valuePtr)
                $newStart = eval($$subdir{Start});
            }
            if ($$subdir{Base}) {
                # calculate subdirectory start relative to $base for eval
                my $start = $newStart + $$dirInfo{DataPos};
                #### eval Base ($start)
                my $baseShift = eval($$subdir{Base});
                # shift directory base (note: we may do this again below
                # if an OffsetPt is defined, but that doesn't matter since
                # the base shift is relative to DataPos, which we set too)
                $$dirInfo{Base} += $baseShift;
                $$dirInfo{DataPos} -= $baseShift;
                # this is a relative directory if Base depends on $start
                $$dirInfo{Relative} = 1 if $$subdir{Base} =~ /\$start\b/;
            }
            # add offset to the start of the directory if necessary
            if ($$subdir{OffsetPt}) {
                if ($$subdir{ByteOrder} =~ /^Little/i) {
                    SetByteOrder('II');
                } elsif ($$subdir{ByteOrder} =~ /^Big/i) {
                    SetByteOrder('MM');
                } else {
                    warn "Can't have variable byte ordering for SubDirectories using OffsetPt\n";
                    return undef;
                }
                #### eval OffsetPt ($valuePtr)
                $ifdOffsetPos = eval($$subdir{OffsetPt}) - $dirStart;
            }
            # pinpoint position to look for this IFD
            $firstTry = $lastTry = $newStart - $dirStart;
        }
    }
#
# scan for something that looks like an IFD
#
    if ($size >= 14 + $firstTry) {  # minimum size for an IFD
        my $offset;
IFD_TRY: for ($offset=$firstTry; $offset<=$lastTry; $offset+=2) {
            last if $offset + 14 > $size;    # 14 bytes is minimum size for an IFD
            my $pos = $dirStart + $offset;
#
# look for a standard TIFF header (Nikon uses it, others may as well),
#
            if (SetByteOrder(substr($$dataPt, $pos, 2)) and
                Get16u($dataPt, $pos + 2) == 0x2a)
            {
                $ifdOffsetPos = 4;
            }
            if (defined $ifdOffsetPos) {
                # get pointer to IFD
                my $ptr = Get32u($dataPt, $pos + $ifdOffsetPos);
                if ($ptr >= $ifdOffsetPos + 4 and $ptr + $offset + 14 <= $size) {
                    # shift directory start and shorten dirLen accordingly
                    $$dirInfo{DirStart} += $ptr + $offset;
                    $$dirInfo{DirLen} -= $ptr + $offset;
                    # shift pointer base to the start of the TIFF header
                    my $shift = $$dirInfo{DataPos} + $dirStart + $offset;
                    $$dirInfo{Base} += $shift;
                    $$dirInfo{DataPos} -= $shift;
                    $$dirInfo{Relative} = 1;   # set "relative offsets" flag
                    return $ptr + $offset;
                }
                undef $ifdOffsetPos;
            }
#
# look for a standard IFD (starts with 2-byte entry count)
#
            my $num = Get16u($dataPt, $pos);
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
            my $bytesFromEnd = $size - ($offset + 2 + 12 * $num);
            if ($bytesFromEnd < 4) {
                next unless $bytesFromEnd == 2 or $bytesFromEnd == 0;
            }
            # do a quick validation of all format types
            my $index;
            for ($index=0; $index<$num; ++$index) {
                my $entry = $pos + 2 + 12 * $index;
                my $format = Get16u($dataPt, $entry+2);
                my $count = Get32u($dataPt, $entry+4);
                # allow everything to be zero if not first entry
                # because some manufacturers pad with null entries
                next unless $format or $count or $index == 0;
                # (would like to verify tag ID, but some manufactures don't
                #  sort entries in order of tag ID so we don't have much of
                #  a handle to verify this field)
                # verify format
                next IFD_TRY if $format < 1 or $format > 13;
                # count must be reasonable
                next IFD_TRY if $count == 0 or $count & 0xff000000;
            }
            $$dirInfo{DirStart} += $offset;    # update directory start
            $$dirInfo{DirLen} -= $offset;
            return $offset;   # success!!
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Process unknown maker notes assuming it is in EXIF IFD format
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success, and updates $dirInfo if necessary for new directory
sub ProcessUnknown($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $success = 0;

    my $loc = LocateIFD($exifTool, $dirInfo);
    if (defined $loc) {
        if ($exifTool->Options('Verbose') > 1) {
            my $out = $exifTool->Options('TextOut');
            my $indent = $exifTool->{INDENT};
            $indent =~ s/\| $/  /;
            printf $out "${indent}Found IFD at offset 0x%.4x in maker notes:\n",
                    $$dirInfo{DirStart} + $$dirInfo{DataPos} + $$dirInfo{Base};
        }
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
    } else {
        $exifTool->Warn("Unrecognized $$dirInfo{DirName}");
    }
    return $success;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::MakerNotes - Read and write EXIF maker notes

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2006, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames(3pm)|Image::ExifTool::TagNames>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
