#------------------------------------------------------------------------------
# File:         XMP2.pm
#
# Description:  Additional XMP schema definitions
#
# Revisions:    10/12/2008 - P. Harvey Created
#
# References:   1) PLUS - http://ns.useplus.org/
#               2) PRISM - http://www.prismstandard.org/
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use Image::ExifTool qw(:Utils);
use Image::ExifTool::XMP;

#------------------------------------------------------------------------------
# PLUS vocabulary conversions
my %plusVocab = (
    ValueConv => '$val =~ s{http://ns.useplus.org/ldf/vocab/}{}; $val',
    ValueConvInv => '"http://ns.useplus.org/ldf/vocab/$val"',
);

# PLUS License Data Format 1.2.0 (plus) (ref 1)
%Image::ExifTool::XMP::plus = (
    %xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-plus', 2 => 'Author' },
    NAMESPACE => 'plus',
    NOTES => q{
        PLUS License Data Format 1.2.0 schema tags.  Note that all
        controlled-vocabulary tags in this table (ie. tags with a fixed set of
        values) have raw values which begin with "http://ns.useplus.org/ldf/vocab/",
        but to reduce clutter this prefix has been removed from the values shown
        below.
    },
    Version  => { Name => 'PLUSVersion' },
    Licensee => {
        SubDirectory => { },
        Struct => 'Licensee',
        List => 'Seq',
    },
    LicenseeLicenseeID   => { List => 1, Name => 'LicenseeID' },
    LicenseeLicenseeName => { List => 1, Name => 'LicenseeName' },
    EndUser => {
        SubDirectory => { },
        Struct => 'EndUser',
        List => 'Seq',
    },
    EndUserEndUserID    => { List => 1, Name => 'EndUserID' },
    EndUserEndUserName  => { List => 1, Name => 'EndUserName' },
    Licensor => {
        SubDirectory => { },
        Struct => 'Licensor',
        List => 'Seq',
    },
    LicensorLicensorID              => { List => 1, Name => 'LicensorID' },
    LicensorLicensorName            => { List => 1, Name => 'LicensorName' },
    LicensorLicensorStreetAddress   => { List => 1, Name => 'LicensorStreetAddress' },
    LicensorLicensorExtendedAddress => { List => 1, Name => 'LicensorExtendedAddress' },
    LicensorLicensorCity            => { List => 1, Name => 'LicensorCity' },
    LicensorLicensorRegion          => { List => 1, Name => 'LicensorRegion' },
    LicensorLicensorPostalCode      => { List => 1, Name => 'LicensorPostalCode' },
    LicensorLicensorCountry         => { List => 1, Name => 'LicensorCountry' },
    LicensorLicensorTelephoneType1  => {
        Name => 'LicensorTelephoneType1',
        List => 1,
        %plusVocab,
        PrintConv => {
            'work'  => 'Work',
            'cell'  => 'Cell',
            'fax'   => 'FAX',
            'home'  => 'Home',
            'pager' => 'Pager',
        },
    },
    LicensorLicensorTelephone1      => { List => 1, Name => 'LicensorTelephone1' },
    LicensorLicensorTelephoneType2  => {
        Name => 'LicensorTelephoneType2',
        List => 1,
        %plusVocab,
        PrintConv => {
            'work'  => 'Work',
            'cell'  => 'Cell',
            'fax'   => 'FAX',
            'home'  => 'Home',
            'pager' => 'Pager',
        },
    },
    LicensorLicensorTelephone2      => { List => 1, Name => 'LicensorTelephone2' },
    LicensorLicensorEmail           => { List => 1, Name => 'LicensorEmail' },
    LicensorLicensorURL             => { List => 1, Name => 'LicensorURL' },
    LicensorNotes               => { Writable => 'lang-alt' },
    MediaSummaryCode            => { },
    LicenseStartDate            => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    LicenseEndDate              => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    MediaConstraints            => { Writable => 'lang-alt' },
    RegionConstraints           => { Writable => 'lang-alt' },
    ProductOrServiceConstraints => { Writable => 'lang-alt' },
    ImageFileConstraints => {
        List => 'Bag',
        %plusVocab,
        PrintConv => {
            'IF-MFN' => 'Maintain File Name',
            'IF-MID' => 'Maintain ID in File Name',
            'IF-MMD' => 'Maintain Metadata',
            'IF-MFT' => 'Maintain File Type',
        },
    },
    ImageAlterationConstraints => {
        List => 'Bag',
        %plusVocab,
        PrintConv => {
            'AL-CRP' => 'No Cropping',
            'AL-FLP' => 'No Flipping',
            'AL-RET' => 'No Retouching',
            'AL-CLR' => 'No Colorization',
            'AL-DCL' => 'No De-Colorization',
            'AL-MRG' => 'No Merging',
        },
    },
    ImageDuplicationConstraints => {
        %plusVocab,
        PrintConv => {
            'DP-NDC' => 'No Duplication Constraints',
            'DP-LIC' => 'Duplication Only as Necessary Under License',
            'DP-NOD' => 'No Duplication',
        },
    },
    ModelReleaseStatus => {
        %plusVocab,
        PrintConv => {
            'MR-NON' => 'None',
            'MR-NAP' => 'Not Applicable',
            'MR-UMR' => 'Unlimited Model Releases',
            'MR-LMR' => 'Limited or Incomplete Model Releases',
        },
    },
    ModelReleaseID      => { List => 'Bag' },
    MinorModelAgeDisclosure => {
        %plusVocab,
        PrintConv => {
            'AG-UNK' => 'Age Unknown',
            'AG-A25' => 'Age 25 or Over',
            'AG-A24' => 'Age 24',
            'AG-A23' => 'Age 23',
            'AG-A22' => 'Age 22',
            'AG-A21' => 'Age 21',
            'AG-A20' => 'Age 20',
            'AG-A19' => 'Age 19',
            'AG-A18' => 'Age 18',
            'AG-A17' => 'Age 17',
            'AG-A16' => 'Age 16',
            'AG-A15' => 'Age 15',
            'AG-U14' => 'Age 14 or Under',
        },
    },
    PropertyReleaseStatus => {
        %plusVocab,
        PrintConv => {
            'PR-NON' => 'None',
            'PR-NAP' => 'Not Applicable',
            'PR-UPR' => 'Unlimited Property Releases',
            'PR-LPR' => 'Limited or Incomplete Property Releases',
        },
    },
    PropertyReleaseID   => { List => 'Bag' },
    OtherConstraints    => { Writable => 'lang-alt' },
    CreditLineRequired => {
        %plusVocab,
        PrintConv => {
            'CR-NRQ' => 'Not Required',
            'CR-COI' => 'Credit on Image',
            'CR-CAI' => 'Credit Adjacent To Image',
            'CR-CCA' => 'Credit in Credits Area',
        },
    },
    AdultContentWarning => {
        %plusVocab,
        PrintConv => {
            'CW-NRQ' => 'Not Required',
            'CW-AWR' => 'Adult Content Warning Required',
            'CW-UNK' => 'Unknown',
        },
    },
    OtherLicenseRequirements    => { Writable => 'lang-alt' },
    TermsAndConditionsText      => { Writable => 'lang-alt' },
    TermsAndConditionsURL       => { },
    OtherConditions             => { Writable => 'lang-alt' },
    ImageType => {
        %plusVocab,
        PrintConv => {
            'TY-PHO' => 'Photographic Image',
            'TY-ILL' => 'Illustrated Image',
            'TY-MCI' => 'Multimedia or Composited Image',
            'TY-VID' => 'Video',
            'TY-OTR' => 'Other',
        },
    },
    LicensorImageID     => { },
    FileNameAsDelivered => { },
    ImageFileFormatAsDelivered => {
        %plusVocab,
        PrintConv => {
            'FF-JPG' => 'JPEG Interchange Formats (JPG, JIF, JFIF)',
            'FF-TIF' => 'Tagged Image File Format (TIFF)',
            'FF-GIF' => 'Graphics Interchange Format (GIF)',
            'FF-RAW' => 'Proprietary RAW Image Format',
            'FF-DNG' => 'Digital Negative (DNG)',
            'FF-EPS' => 'Encapsulated PostScript (EPS)',
            'FF-BMP' => 'Windows Bitmap (BMP)',
            'FF-PSD' => 'Photoshop Document (PSD)',
            'FF-PIC' => 'Macintosh Picture (PICT)',
            'FF-PNG' => 'Portable Network Graphics (PNG)',
            'FF-WMP' => 'Windows Media Photo (HD Photo)',
            'FF-OTR' => 'Other',
        },
    },
    ImageFileSizeAsDelivered => {
        %plusVocab,
        PrintConv => {
            'SZ-U01' => 'Up to 1 MB',
            'SZ-U10' => 'Up to 10 MB',
            'SZ-U30' => 'Up to 30 MB',
            'SZ-U50' => 'Up to 50 MB',
            'SZ-G50' => 'Greater than 50 MB',
        },
    },
    CopyrightStatus => {
        %plusVocab,
        PrintConv => {
            'CS-PRO' => 'Protected',
            'CS-PUB' => 'Public Domain',
            'CS-UNK' => 'Unknown',
        },
    },
    CopyrightRegistrationNumber => { },
    FirstPublicationDate        => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    CopyrightOwner => {
        SubDirectory => { },
        Struct => 'CopyrightOwner',
        List => 'Seq',
    },
    CopyrightOwnerCopyrightOwnerID   => { List => 1, Name => 'CopyrightOwnerID' },
    CopyrightOwnerCopyrightOwnerName => { List => 1, Name => 'CopyrightOwnerName' },
    CopyrightOwnerImageID            => { },
    ImageCreator => {
        SubDirectory => { },
        Struct => 'ImageCreator',
        List => 'Seq',
    },
    ImageCreatorImageCreatorID   => { List => 1, Name => 'ImageCreatorID' },
    ImageCreatorImageCreatorName => { List => 1, Name => 'ImageCreatorName' },
    ImageCreatorImageID          => { },
    ImageSupplier => {
        SubDirectory => { },
        Struct => 'ImageSupplier',
        List => 'Seq',
    },
    ImageSupplierImageSupplierID   => { List => 1, Name => 'ImageSupplierID' },
    ImageSupplierImageSupplierName => { List => 1, Name => 'ImageSupplierName' },
    ImageSupplierImageID    => { },
    LicenseeImageID         => { },
    LicenseeImageNotes      => { Writable => 'lang-alt' },
    OtherImageInfo          => { Writable => 'lang-alt' },
    LicenseID               => { },
    LicensorTransactionID   => { List => 'Bag' },
    LicenseeTransactionID   => { List => 'Bag' },
    LicenseeProjectReference=> { List => 'Bag' },
    LicenseTransactionDate  => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    Reuse => {
        %plusVocab,
        PrintConv => {
            'RE-REU' => 'Repeat Use',
            'RE-NAP' => 'Not Applicable',
        },
    },
    OtherLicenseDocuments   => { List => 'Bag' },
    OtherLicenseInfo        => { Writable => 'lang-alt' },
    # Note: these are Bag's of lang-alt lists -- a nested list tag!
    Custom1     => { List => 'Bag', Writable => 'lang-alt' },
    Custom2     => { List => 'Bag', Writable => 'lang-alt' },
    Custom3     => { List => 'Bag', Writable => 'lang-alt' },
    Custom4     => { List => 'Bag', Writable => 'lang-alt' },
    Custom5     => { List => 'Bag', Writable => 'lang-alt' },
    Custom6     => { List => 'Bag', Writable => 'lang-alt' },
    Custom7     => { List => 'Bag', Writable => 'lang-alt' },
    Custom8     => { List => 'Bag', Writable => 'lang-alt' },
    Custom9     => { List => 'Bag', Writable => 'lang-alt' },
    Custom10    => { List => 'Bag', Writable => 'lang-alt' },
);

#------------------------------------------------------------------------------
# PRISM
#
# NOTE: The "Avoid" flag is set for all PRISM tags

# my %obsolete = (
#     Notes => 'obsolete in 2.0',
#     ValueConvInv => sub {
#         my ($val, $self) = @_;
#         unless ($self->Options('IgnoreMinorErrors')) {
#             warn "Warning: [minor] Attempt to write obsolete tag\n";
#             return undef;
#         }
#         return $val;
#     }
# );

# Publishing Requirements for Industry Standard Metadata 2.1 (prism) (ref 2)
%Image::ExifTool::XMP::prism = (
    %xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-prism', 2 => 'Document' },
    NAMESPACE => 'prism',
    NOTES => 'Publishing Requirements for Industry Standard Metadata 2.1 schema tags.',
    aggregationType => { List => 'Bag' },
    alternateTitle  => { List => 'Bag' },
    byteCount       => { Writable => 'integer' },
    channel         => { List => 'Bag' },
    complianceProfile=>{ PrintConv => { three => 'Three' } },
    copyright       => { Groups => { 2 => 'Author' } },
    corporateEntity => { List => 'Bag' },
    coverDate       => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    coverDisplayDate=> { },
    creationDate    => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    dateRecieved    => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    distributor     => { },
    doi             => { Name => 'DOI', Description => 'Digital Object Identifier' },
    edition         => { },
    eIssn           => { },
    embargoDate     => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    endingPage      => { },
    event           => { List => 'Bag' },
    expirationDate  => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    genre           => { List => 'Bag' },
    hasAlternative  => { List => 'Bag' },
    hasCorrection   => { },
    hasPreviousVersion => { },
    hasTranslation  => { List => 'Bag' },
    industry        => { List => 'Bag' },
    isCorrectionOf  => { List => 'Bag' },
    issn            => { Name => 'ISSN' },
    issueIdentifier => { },
    issueName       => { },
    isTranslationOf => { },
    keyword         => { List => 'Bag' },
    killDate        => { %dateTimeInfo, Groups => { 2 => 'Time'} },
    location        => { List => 'Bag' },
    # metadataContainer => { },
    modificationDate=> { %dateTimeInfo, Groups => { 2 => 'Time'} },
    number          => { },
    object          => { List => 'Bag' },
    organization    => { List => 'Bag' },
    originPlatform  => {
        List => 'Bag',
        PrintConv => {
            email       => 'E-Mail',
            mobile      => 'Mobile',
            broadcast   => 'Broadcast',
            web         => 'Web',
           'print'      => 'Print',
            recordableMedia => 'Recordable Media',
            other       => 'Other',
        },
    },
    pageRange       => { List => 'Bag' },
    person          => { },
    publicationDate => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    publicationName => { },
    rightsAgent     => { },
    section         => { },
    startingPage    => { },
    subsection1     => { },
    subsection2     => { },
    subsection3     => { },
    subsection4     => { },
    teaser          => { List => 'Bag' },
    ticker          => { List => 'Bag' },
    timePeriod      => { },
    url             => { Name => 'URL', List => 'Bag' },
    versionIdentifier => { },
    volume          => { },
    wordCount       => { Writable => 'integer' },
    # new in PRISM 2.1
    isbn            => { Name => 'ISBN' },
# tags that existed in version 1.3
#    category        => { %obsolete, List => 'Bag' },
#    hasFormat       => { %obsolete, List => 'Bag' },
#    hasPart         => { %obsolete, List => 'Bag' },
#    isFormatOf      => { %obsolete, List => 'Bag' },
#    isPartOf        => { %obsolete },
#    isReferencedBy  => { %obsolete, List => 'Bag' },
#    isRequiredBy    => { %obsolete, List => 'Bag' },
#    isVersionOf     => { %obsolete },
#    objectTitle     => { %obsolete, List => 'Bag' },
#    receptionDate   => { %obsolete },
#    references      => { %obsolete, List => 'Bag' },
#    requires        => { %obsolete, List => 'Bag' },
# tags in older versions
#    page
#    contentLength
#    creationTime
#    expirationTime
#    hasVersion
#    isAlternativeFor
#    isBasedOn
#    isBasisFor
#    modificationTime
#    publicationTime
#    receptionTime
#    releaseTime
);

# PRISM Rights Language 2.1 schema (prl) (ref 2)
%Image::ExifTool::XMP::prl = (
    %xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-prl', 2 => 'Document' },
    NAMESPACE => 'prl',
    NOTES => 'PRISM Rights Language 2.1 schema tags.',
    geography       => { List => 'Bag' },
    industry        => { List => 'Bag' },
    usage           => { List => 'Bag' },
);

# PRISM Usage Rights 2.1 schema (prismusagerights) (ref 2)
%Image::ExifTool::XMP::pur = (
    %xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-pur', 2 => 'Document' },
    NAMESPACE => 'prismusagerights',
    NOTES => 'PRISM Rights Language 2.1 schema tags.',
    NOTES => q{
        Prism Usage Rights 2.1 schema tags.  The actual namespace prefix is
        "prismusagerights", but ExifTool shortens this for the "XMP-pur" family 1
        group name.
    },
    adultContentWarning => { List => 'Bag' },
    agreement           => { List => 'Bag' },
    copyright           => { Writable => 'lang-alt', Groups => { 2 => 'Author' } },
    creditLine          => { List => 'Bag' },
    embargoDate         => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    exclusivityEndDate  => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    expirationDate      => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    imageSizeRestriction=> { },
    optionEndDate       => { List => 'Bag', %dateTimeInfo, Groups => { 2 => 'Time'} },
    permissions         => { List => 'Bag' },
    restrictions        => { List => 'Bag' },
    reuseProhibited     => { Writable => 'boolean' },
    rightsAgent         => { },
    rightsOwner         => { },
    usageFee            => { List => 'Bag' },
);

# set "Avoid" flag for all PRISM tags
my ($table, $key);
foreach $table (\%prism, \%prl, \%pur) {
    foreach $key (TagTableKeys($table)) {
        $table->{$key}->{Avoid} = 1;
    }
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::XMP - Additional XMP schema definitions

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This file contains definitions for the following XMP schemas:

1) PLUS License Data Format 1.2.0

2) Publishing Requirements for Industry Standard Metadata (PRISM) 2.1

=head1 AUTHOR

Copyright 2003-2008, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://ns.useplus.org/>

=item L<http://www.prismstandard.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
