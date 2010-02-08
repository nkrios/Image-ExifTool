# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/InDesign.t".

BEGIN { $| = 1; print "1..4\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::InDesign;
$loaded = 1;
print "ok 1\n";

use t::TestLib;

my $testname = 'InDesign';
my $testnum = 1;

# test 2: Extract information from InDesign.indd
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/InDesign.indd');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 3-4: Write an XMP tag then delete all XMP (writes empty XMP record)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(Author => 'Phil Harvey');
    my $testfile = "t/${testname}_${testnum}_failed.indd";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/InDesign.indd', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    my $not;
    unless (check($exifTool, $info, $testname, $testnum)) {
        print 'not ';
        $not = 1;
    }
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->Options(PrintConv => 0);
    $exifTool->SetNewValue();
    $exifTool->SetNewValue('XMP:*');
    my $testfile2 = "t/${testname}_${testnum}_failed.indd";
    unlink $testfile2;
    $exifTool->WriteInfo($testfile, $testfile2);
    $info = $exifTool->ImageInfo($testfile2);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile unless $not;
        unlink $testfile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
