# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/CanonRaw.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'CanonRaw';
my $testnum = 1;

# test 2: Extract information from CanonRaw.crw
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/CanonRaw.crw');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Extract JpgFromRaw
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(PrintConv => 0, IgnoreMinorErrors => 1);
    my $info = $exifTool->ImageInfo('t/CanonRaw.crw','JpgFromRaw');
    print 'not ' unless ${$info->{JpgFromRaw}} eq '<Dummy JpgFromRaw image data>';
    print "ok $testnum\n";
}

# test 4: Write a whole pile of tags
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    # set IgnoreMinorErrors option to allow invalid JpgFromRaw to be written
    $exifTool->Options(IgnoreMinorErrors => 1);
    $exifTool->SetNewValuesFromFile('t/ExifTool.jpg');
    $exifTool->SetNewValue(SerialNumber => 1234);
    $exifTool->SetNewValue(OwnerName => 'Phil Harvey');
    $exifTool->SetNewValue(JpgFromRaw => 'not a real image');
    $exifTool->SetNewValue(ROMOperationMode => 'CDN');
    $exifTool->SetNewValue(FocalPlaneXSize => '35mm');
    my $testfile = "t/${testname}_${testnum}_failed.crw";
    unlink $testfile;
    $exifTool->WriteInfo('t/CanonRaw.crw', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 5: Test verbose output
{
    ++$testnum;
    my ($ok, $skip) = testVerbose($testname, $testnum, 't/CanonRaw.crw', 1);
    print 'not ' unless $ok;
    print "ok $testnum$skip\n";
}

# end
