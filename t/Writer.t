# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/Writer.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..23\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'Writer';
my $testnum = 1;
my $testfile;

# compare 2 binary files
# Inputs: 0) file name 1, 1) file name 2
# Returns: 1 if files are identical
sub binaryCompare($$)
{
    my ($file1, $file2) = @_;
    my $success = 1;
    open(TESTFILE1, $file1) or return 0;
    unless (open(TESTFILE2, $file2)) {
        close(TESTFILE1);
        return 0;
    }
    binmode(TESTFILE1);
    binmode(TESTFILE2);
    my ($buf1, $buf2);
    while (read(TESTFILE1, $buf1, 65536)) {
        read(TESTFILE2, $buf2, 65536) or $success = 0, last;
        $buf1 eq $buf2 or $success = 0, last;
    }
    read(TESTFILE2, $buf2, 65536) and $success = 0;
    close(TESTFILE1);
    close(TESTFILE2);
    return $success
}

# tests 2/3: Test writing new comment to JPEG file and removing it again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testFile1 = "t/${testname}_${testnum}_failed.jpg";
    -e $testFile1 and unlink $testFile1;
    $exifTool->SetNewValue('Comment','New comment in JPG file');
    $exifTool->WriteInfo('t/images/ExifTool.jpg', $testFile1);
    my $info = ImageInfo($testFile1);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    my $testFile2 = "t/${testname}_${testnum}_failed.jpg";
    -e $testFile2 and unlink $testFile2;
    $exifTool->SetNewValue('Comment');
    $exifTool->WriteInfo($testFile1, $testFile2);
    if (binaryCompare($testFile2, 't/images/ExifTool.jpg')) {
        unlink $testFile1;
        unlink $testFile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 4/5: Test editing a TIFF in memory then changing it back again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Unknown => 1);
    my $newtiff;
    $exifTool->SetNewValue(Headline => 'A different headline');
    $exifTool->SetNewValue(ImageDescription => 'Modified TIFF');
    $exifTool->SetNewValue(Keywords => 'another keyword', AddValue => 1);
    $exifTool->SetNewValue('xmp:SupplementalCategories' => 'new XMP info');
    $exifTool->WriteInfo('t/images/ExifTool.tif', \$newtiff);
    my $info = $exifTool->ImageInfo(\$newtiff);
    unless (check($exifTool, $info, $testname, $testnum)) {
        $testfile = "t/${testname}_${testnum}_failed.tif";
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $newtiff;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";

    ++$testnum;
    my $newtiff2;
    $exifTool->SetNewValue();   # clear all the changes
    $exifTool->SetNewValue(Headline => 'headline');
    $exifTool->SetNewValue(ImageDescription => 'The picture caption');
    $exifTool->SetNewValue(Keywords => 'another keyword', DelValue => 1);
    $exifTool->SetNewValue(SupplementalCategories);
    $exifTool->WriteInfo(\$newtiff, \$newtiff2);
    $testfile = "t/${testname}_${testnum}_failed.tif";
    open(TESTFILE,">$testfile");
    binmode(TESTFILE);
    print TESTFILE $newtiff2;
    close(TESTFILE);
    if (binaryCompare($testfile,'t/images/ExifTool.tif')) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 6/7: Test rewriting a JPEG file then changing it back again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Unknown => 1);
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile1;
    $exifTool->SetNewValue(DateTimeOriginal => '2005:01:01 00:00:00', Group => 'IFD0');
    $exifTool->SetNewValue(Contrast => '+2', Group => 'XMP');
    $exifTool->SetNewValue(ExposureCompensation => 999, Group => 'EXIF');
    $exifTool->SetNewValue(LightSource => 'cloud');
    $exifTool->SetNewValue(Flash => '0x1', Type => 'ValueConv');
    $exifTool->SetNewValue(FocalPlaneResolutionUnit => 'mm');
    $exifTool->SetNewValue(Category => 'IPTC test');
    $exifTool->SetNewValue(Description => 'New description');
    $exifTool->WriteInfo('t/images/ExifTool.jpg', $testfile1);
    my $info = $exifTool->ImageInfo($testfile1);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue(DateTimeOriginal => '2003:12:04 06:46:52');
    $exifTool->SetNewValue(Contrast => undef, Group => 'XMP');
    $exifTool->SetNewValue(ExposureCompensation => 0, Group => 'EXIF');
    $exifTool->SetNewValue(LightSource);
    $exifTool->SetNewValue(Flash => '0x0', Type => 'ValueConv');
    $exifTool->SetNewValue(FocalPlaneResolutionUnit => 'in');
    $exifTool->SetNewValue(Category);
    $exifTool->SetNewValue(Description);
    my $image;
    $exifTool->WriteInfo($testfile1, \$image);
    $info = $exifTool->ImageInfo(\$image);
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile1;
        unlink $testfile2;
    } else {
        # save bad file
        open(TESTFILE,">$testfile2");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 8: Test rewriting everything in a JPEG file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Binary => 1, List => 1);
    my $info = $exifTool->ImageInfo('t/images/ExifTool.jpg');
    my $tag;
    foreach $tag (keys %$info) {
        my $group = $exifTool->GetGroup($tag);
        # eat return values so warning don't get printed
        my @rtns = $exifTool->SetNewValue($tag,$info->{$tag},Group=>$group);
    }
    undef $info;
    my $image;
    $exifTool->WriteInfo('t/images/ExifTool.jpg', \$image);
    $exifTool->Options(Unknown => 1, Binary => 0, List => 0);
    $info = $exifTool->ImageInfo(\$image);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool, $info, $testname, $testnum, 7)) {
        unlink $testfile;
    } else {
        # save bad file
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 9: Test copying over information with SetNewValuesFromFile()
#         (including a transfer of the ICC_Profile record)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg');
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.tif', 'ICC_Profile');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/Nikon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 10: Another SetNewValuesFromFile() test
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options('IgnoreMinorErrors' => 1);
    $exifTool->SetNewValuesFromFile('t/images/Pentax.jpg');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/ExifTool.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 11/12: Try creating something from nothing and removing it again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(DateTimeOriginal => '2005:01:19 13:37:22', Group => 'EXIF');
    $exifTool->SetNewValue(FileVersion => 12, Group => 'IPTC');
    $exifTool->SetNewValue(Contributor => 'Guess who', Group => 'XMP');
    $exifTool->SetNewValue(GPSLatitude => q{44 deg 14' 12.25"}, Group => 'GPS');
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile1;
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile1);
    my $info = $exifTool->ImageInfo($testfile1);
    my $success = check($exifTool, $info, $testname, $testnum);
    print 'not ' unless $success;
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue('DateTimeOriginal');
    $exifTool->SetNewValue('FileVersion');
    $exifTool->SetNewValue('Contributor');
    $exifTool->SetNewValue('GPSLatitude');
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    $exifTool->WriteInfo($testfile1, $testfile2);
    if (binaryCompare('t/images/Writer.jpg', $testfile2)) {
        unlink $testfile1 if $success;
        unlink $testfile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 13: Copy tags from CRW file to JPG
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/CanonRaw.crw');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 14: Delete all information in a group
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('All' => undef, Group => 'MakerNotes');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/ExifTool.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 15: Copy a specific set of tags
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my @copyTags = qw(exififd:all -lightSource ifd0:software);
    $exifTool->SetNewValuesFromFile('t/images/Olympus.jpg', @copyTags);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/ExifTool.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 16-18: Test SetNewValuesFromFile() order of operations
{
    my @argsList = (
        [ 'ifd0:xresolution>xmp:*', 'ifd1:xresolution>xmp:*' ],
        [ 'ifd1:xresolution>xmp:*', 'ifd0:xresolution>xmp:*' ],
        [ '*:xresolution', '-ifd0:xresolution', 'xresolution>xmp:*' ],
    );
    my $args;
    foreach $args (@argsList) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValuesFromFile('t/images/GPS.jpg', @$args);
        $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'xresolution');
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 19: Test SaveNewValues()/RestoreNewValues()
my $testOK;
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(ISO => 25);
    $exifTool->SetNewValue(Sharpness => '+1');
    $exifTool->SetNewValue(Artist => 'Phil', Group => 'IFD0');
    $exifTool->SetNewValue(Artist => 'Harvey', Group => 'ExifIFD');
    $exifTool->SetNewValue(DateTimeOriginal => '2006:03:27 16:25:00');
    $exifTool->SaveNewValues();
    $exifTool->SetNewValue(Artist => 'nobody');
    $exifTool->SetNewValuesFromFile('t/images/FujiFilm.jpg');
    $exifTool->RestoreNewValues();
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        $testOK = 1;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 20/21: Test edit in place (using the file from the last test)
{
    my ($skip, $size);
    ++$testnum;
    $skip = '';
    if ($testOK) {
        my $exifTool = new Image::ExifTool;
        my $newComment = 'This is a new test comment';
        $exifTool->SetNewValue(Comment => $newComment);
        $exifTool->WriteInfo($testfile);
        my $info = $exifTool->ImageInfo($testfile, 'Comment');
        if ($$info{Comment} and $$info{Comment} eq $newComment) {
            $size = -s $testfile;
        } else {
            $testOK = 0;
            print 'not ';
        }
    } else {
        $skip = ' # skip Relies on previous test';
    }
    print "ok $testnum$skip\n";

    # test in-place edit of file passed by handle
    ++$testnum;
    $skip = '';
    if ($testOK) {
        my $exifTool = new Image::ExifTool;
        my $shortComment = 'short comment';
        $exifTool->SetNewValue(Comment => $shortComment);
        open FILE, "+<$testfile";   # open test file for update
        $exifTool->WriteInfo(\*FILE);
        close FILE;
        my $info = $exifTool->ImageInfo($testfile, 'Comment');
        if ($$info{Comment} and $$info{Comment} eq $shortComment) {
            my $newSize = -s $testfile;
            unless ($newSize < $size) {
                # test to see if the file got shorter as it should have
                $testOK = 0;
                $skip = ' # skip truncate() not supported on this system';
            }
        } else {
            $testOK = 0;
            print 'not ';
        }
    } else {
        $skip = ' # skip Relies on previous test';
    }
    print "ok $testnum$skip\n";
}

# test 22: Test time shift feature
{
    ++$testnum;
    my @writeInfo = (
        ['DateTimeOriginal' => '1:2', 'Shift' => 1],
        ['ModifyDate' => '2:1: 3:4', 'Shift' => 1],
        ['CreateDate' => '200 0', 'Shift' => -1],
        ['DateCreated' => '20:', 'Shift' => -1],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/IPTC-XMP.jpg', 1);
    print "ok $testnum\n";
}

# test 23: Test renaming a file from the value of DateTimeOriginal
{
    ++$testnum;
    my $skip = '';
    if ($testOK) {
        my $newfile = "t/${testname}_${testnum}_20060327_failed.jpg";
        unlink $newfile;
        my $exifTool = new Image::ExifTool;
        $exifTool->Options(DateFormat => "${testname}_${testnum}_%Y%m%d_failed.jpg");
        $exifTool->SetNewValuesFromFile($testfile, 'FileName<DateTimeOriginal');
        $exifTool->WriteInfo($testfile);
        if (-e $newfile and not -e $testfile) {
            $testfile = $newfile;
        } else {
            $testOK = 0;
            print 'not ';
        }
    } else {
        $skip = ' # skip Relies on test 21';
    }
    print "ok $testnum$skip\n";

    $testOK and unlink $testfile;   # erase test file if all tests passed
}

# end
