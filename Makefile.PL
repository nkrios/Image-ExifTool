use ExtUtils::MakeMaker;
use File::Spec;

my $ExifTool_pm = File::Spec->catfile('lib', 'Image', 'ExifTool.pm');

WriteMakefile(
    'NAME'          => 'Image::ExifTool',
    'AUTHOR'        => 'Phil Harvey (phil@owl.phy.queensu.ca)',
    'VERSION_FROM'  => $ExifTool_pm,
    'PREREQ_PM'     => { },
    'clean'         => { FILES => 't/*.tmp' },
    'EXE_FILES'     => [ 'exiftool' ],
);
