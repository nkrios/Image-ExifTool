# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/ExifTool.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..15\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'Writer';
my $testnum = 1;

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
    $exifTool->WriteInfo('t/ExifTool.jpg', $testFile1);
    my $info = ImageInfo($testFile1);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    my $testFile2 = "t/${testname}_${testnum}_failed.jpg";
    -e $testFile2 and unlink $testFile2;
    $exifTool->SetNewValue('Comment');
    $exifTool->WriteInfo($testFile1, $testFile2);
    if (binaryCompare($testFile2, 't/ExifTool.jpg')) {
        unlink $testFile1;
        unlink $testFile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 4/5: Test removing comment then adding it back again to GIF in memory
{
    ++$testnum;
    open(TESTFILE, 't/ExifTool.gif');
    binmode(TESTFILE);
    my $gifImage;
    read(TESTFILE, $gifImage, 100000);
    close(TESTFILE);
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('Comment');
    my $image1;
    $exifTool->WriteInfo(\$gifImage, \$image1);
    my $info = ImageInfo(\$image1);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $info = ImageInfo(\$gifImage);
    my $gifComment = $info->{Comment};
    $exifTool->SetNewValue('Comment',$gifComment);
    my $image2;
    $exifTool->WriteInfo(\$image1, \$image2);
    print 'not ' unless $image2 eq $gifImage;
    print "ok $testnum\n";
}

# tests 6/7: Test editing a TIFF in memory then changing it back again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Unknown => 1);
    my $newtiff;
    $exifTool->SetNewValue(Headline => 'A different headline');
    $exifTool->SetNewValue(ImageDescription => 'Modified TIFF');
    $exifTool->SetNewValue(Keywords => 'another keyword', AddValue => 1);
    $exifTool->SetNewValue(SupplementalCategories => 'new XMP info', Group => 'XMP');
    $exifTool->WriteInfo('t/ExifTool.tif', \$newtiff);
    my $info = $exifTool->ImageInfo(\$newtiff);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
    
    ++$testnum;
    my $newtiff2;
    $exifTool->SetNewValue();   # clear all the changes
    $exifTool->SetNewValue(Headline => 'headline');
    $exifTool->SetNewValue(ImageDescription => 'The picture caption');
    $exifTool->SetNewValue(Keywords => 'another keyword', DelValue => 1);
    $exifTool->SetNewValue(SupplementalCategories);
    $exifTool->WriteInfo(\$newtiff, \$newtiff2);
    my $testfile = "t/${testname}_${testnum}_failed.tif";
    open(TESTFILE,">$testfile");
    binmode(TESTFILE);
    print TESTFILE $newtiff2;
    close(TESTFILE);
    if (binaryCompare($testfile,'t/ExifTool.tif')) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 8/9: Test rewriting a JPEG file then changing it back again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Unknown => 1);
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile1;
    $exifTool->SetNewValue(DateTimeOriginal => '2005:01:01 00:00:00');
    $exifTool->SetNewValue(Contrast => '+2', Group => 'XMP');
    $exifTool->SetNewValue(ExposureCompensation => 999, Group => 'EXIF');
    $exifTool->SetNewValue(LightSource => 'cloud');
    $exifTool->SetNewValue(FocalPlaneResolutionUnit => 'mm');
    $exifTool->SetNewValue(Category => 'IPTC test');
    $exifTool->SetNewValue(Description => 'New description');
    $exifTool->WriteInfo('t/ExifTool.jpg', $testfile1);
    my $info = $exifTool->ImageInfo($testfile1);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue(DateTimeOriginal => '2003:12:04 06:46:52');
    $exifTool->SetNewValue(Contrast => undef, Group => 'XMP');
    $exifTool->SetNewValue(ExposureCompensation => 0, Group => 'EXIF');
    $exifTool->SetNewValue(LightSource);
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

# test 10: Test rewriting everything in a JPEG file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Binary => 1, List => 1);
    my $info = $exifTool->ImageInfo('t/ExifTool.jpg');
    my $tag;
    foreach $tag (keys %$info) {
        my $group = $exifTool->GetGroup($tag);
        my $val = $info->{$tag};
        my @values;
        if (ref $val eq 'ARRAY') {
            @values = @$val;
        } elsif (ref $val eq 'SCALAR') {
            @values = ( $$val );
        } else {
            @values = ( $val );
        }
        foreach $val (@values) {
            # eat return values so warning don't get printed
            my @rtns = $exifTool->SetNewValue($tag,$val,Group=>$group);
        }
    }
    undef $info;
    my $image;
    $exifTool->WriteInfo('t/ExifTool.jpg', \$image);
    $exifTool->Options(Unknown => 1, Binary => 0, List => 0);
    $info = $exifTool->ImageInfo(\$image);
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool, $info, $testname, $testnum, 9)) {
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

# test 11: Test copying over information with SetNewValuesFromFile()
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/ExifTool.jpg');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/Nikon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 12: Another SetNewValuesFromFile() test
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options('IgnoreMinorErrors' => 1);
    $exifTool->SetNewValuesFromFile('t/Pentax.jpg');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/ExifTool.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 13/14: Try creating something from nothing and removing it again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(DateTimeOriginal => '2005:01:19 13:37:22', Group => 'EXIF');
    $exifTool->SetNewValue(FileVersion => 12, Group => 'IPTC');
    $exifTool->SetNewValue(Contributor => 'Guess who', Group => 'XMP');
    $exifTool->SetNewValue(GPSLatitude => q{44 deg 14' 12.25"}, Group => 'GPS');
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile1;
    $exifTool->WriteInfo('t/Writer.jpg', $testfile1);
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
    if (binaryCompare('t/Writer.jpg', $testfile2)) {
        unlink $testfile1 if $success;
        unlink $testfile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 15: Copy tags from CRW file to JPG
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/CanonRaw.crw');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}


# end
