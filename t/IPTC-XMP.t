# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/IPTC-XMP.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib 'check';

my $testname = 'IPTC-XMP';
my $testnum = 1;

# test 2: Extract information from IPTC-XMP.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/IPTC-XMP.jpg', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test GetValue() in list context
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo('t/IPTC-XMP.jpg', {JoinLists => 0});
    my @values = $exifTool->GetValue('Keywords','ValueConv');
    my $values = join '-', @values;
    my $expected = 'ExifTool-Test-XMP';
    unless ($values eq $expected) {
        warn "\n  Test $testnum differs with \"$values\"\n";
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
