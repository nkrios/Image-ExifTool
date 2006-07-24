# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/Olympus.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Olympus;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'Olympus';
my $testnum = 1;

# test 2: Extract information from Olympus.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Olympus.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        [Software => 'ExifTool', Group => 'XMP'],
        [Macro => 'On'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Extract information from OlympusE1.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/OlympusE1.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 5: Rewrite Olympus E1 image
{
    ++$testnum;
    my @writeInfo = (
        [LensSerialNumber => '012345678'],
        [CoringFilter => 0],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/OlympusE1.jpg');
    print "ok $testnum\n";
}


# end
