#------------------------------------------------------------------------------
# File:         HTML.pm
#
# Description:  Read HTML meta information
#
# Revisions:    01/30/2007 - P. Harvey Created
#
# References:   1) http://www.w3.org/TR/html4/
#               2) http://www.daisy.org/publications/specifications/daisy_202.html
#               3) http://vancouver-webpages.com/META/metatags.detail.html
#               4) http://www.html-reference.com/META.htm
#------------------------------------------------------------------------------

package Image::ExifTool::HTML;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::PostScript;

$VERSION = '1.01';

# HTML info
# (tag ID's are case insensitive and must be all lower case in tables)
%Image::ExifTool::HTML::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        Meta information extracted from the header of HTML and XHTML files.  This is
        a mix of information found in the C<META> elements and the C<TITLE> element.
    },
    dc => {
        Name => 'DC',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::dc' },
    },
    ncc => {
        Name => 'NCC',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::ncc' },
    },
    prod => {
        Name => 'Prod',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::prod' },
    },
    vw96 => {
        Name => 'VW96',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::vw96' },
    },
   'http-equiv' => {
        Name => 'HTTP-equiv',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::equiv' },
    },
    abstract        => { },
    author          => { },
    classification  => { },
    copyright       => { },
    description     => { },
    distribution    => { },
   'doc-class'      => { Name => 'DocClass' },
   'doc-rights'     => { Name => 'DocRights' },
   'doc-type'       => { Name => 'DocType' },
    formatter       => { },
    generator       => { },
    googlebot       => { Name => 'GoogleBot' },
    keywords        => { List => 1 },
    mssmarttagspreventparsing => { Name => 'NoMSSmartTags' },
    owner           => { },
    progid          => { Name => 'ProgID' },
    rating          => { },
    refresh         => { },
   'resource-type'  => { Name => 'ResourceType' },
   'revisit-after'  => { Name => 'RevisitAfter' },
    robots          => { List => 1 },
    title           => { Notes => "the only extracted tag which isn't from an HTML META element" },
);

# ref 2
%Image::ExifTool::HTML::dc = (
    GROUPS => { 1 => 'HTML-dc', 2 => 'Document' },
    NOTES => 'Dublin Core schema tags (also used in XMP).',
    contributor => { Groups => { 2 => 'Author' }, List => 'Bag' },
    coverage    => { },
    creator     => { Groups => { 2 => 'Author' }, List => 'Seq' },
    date        => {
        Groups => { 2 => 'Time'   },
        List => 'Seq',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    description => { Groups => { 2 => 'Image'  } },
   'format'     => { Groups => { 2 => 'Image'  } },
    identifier  => { Groups => { 2 => 'Image'  } },
    language    => { List => 'Bag' },
    publisher   => { Groups => { 2 => 'Author' }, List => 'Bag' },
    relation    => { List => 'Bag' },
    rights      => { Groups => { 2 => 'Author' } },
    source      => { Groups => { 2 => 'Author' } },
    subject     => { Groups => { 2 => 'Image'  }, List => 'Bag' },
    title       => { Groups => { 2 => 'Image'  } },
    type        => { Groups => { 2 => 'Image'  }, List => 'Bag' },
);

# ref 2
%Image::ExifTool::HTML::ncc = (
    GROUPS => { 1 => 'HTML-ncc', 2 => 'Document' },
    charset         => { },
    depth           => { },
    files           => { },
    footnotes       => { },
    generator       => { },
    kbytesize       => { Name => 'KByteSize' },
    maxpagenormal   => { Name => 'MaxPageNormal' },
    multimediatype  => { Name => 'MultimediaType' },
    narrator        => { },
    pagefront       => { Name => 'PageFront' },
    pagenormal      => { Name => 'PageNormal' },
    pagespecial     => { Name => 'PageSpecial' },
    prodnotes       => { Name => 'ProdNotes' },
    producer        => { },
    produceddate    => { Name => 'ProducedDate', Groups => { 2 => 'Time' } }, # yyyy-mm-dd
    revision        => { },
    revisiondate    => { Name => 'RevisionDate', Groups => { 2 => 'Time' } },
    setinfo         => { Name => 'SetInfo' },
    sidebars        => { },
    sourcedate      => { Name => 'SourceDate', Groups => { 2 => 'Time' } },
    sourceedition   => { Name => 'SourceEdition' },
    sourcepublisher => { Name => 'SourcePublisher' },
    sourcerights    => { Name => 'SourceRights' },
    sourcetitle     => { Name => 'SourceTitle' },
    tocitems        => { Name => 'TOCItems' },
    totaltime       => { Name => 'Duration' }, # hh:mm:ss
);

# ref 3
%Image::ExifTool::HTML::vw96 = (
    GROUPS => { 1 => 'HTML-vw96', 2 => 'Document' },
    objecttype      => { Name => 'ObjectType' },
);

# ref 2
%Image::ExifTool::HTML::prod = (
    GROUPS => { 1 => 'HTML-prod', 2 => 'Document' },
    reclocation     => { Name => 'RecLocation' },
    recengineer     => { Name => 'RecEngineer' },
);

# ref 3/4
%Image::ExifTool::HTML::equiv = (
    GROUPS => { 1 => 'HTTP-equiv', 2 => 'Document' },
    NOTES => 'These tags have a family 1 group name of "HTTP-equiv".',
   'cache-control'       => { Name => 'CacheControl' },
   'content-disposition' => { Name => 'ContentDisposition' },
   'content-language'    => { Name => 'ContentLanguage' },
   'content-script-type' => { Name => 'ContentScriptType' },
   'content-style-type'  => { Name => 'ContentStyleType' },
   'content-type'        => { Name => 'ContentType' },
   'default-style'       => { Name => 'DefaultStyle' },
    expires              => { },
   'ext-cache'           => { Name => 'ExtCache' },
    imagetoolbar         => { Name => 'ImageToolbar' },
    lotus                => { },
   'page-enter'          => { Name => 'PageEnter' },
   'page-exit'           => { Name => 'PageExit' },
   'pics-label'          => { Name => 'PicsLabel' },
    pragma               => { },
    refresh              => { },
   'reply-to'            => { Name => 'ReplyTo' },
   'set-cookie'          => { Name => 'SetCookie' },
   'site-enter'          => { Name => 'SiteEnter' },
   'site-exit'           => { Name => 'SiteExit' },
    vary                 => { },
   'window-target'       => { Name => 'WindowTarget' },
);

#------------------------------------------------------------------------------
# Extract information from a HTML file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid HTML file
sub ProcessHTML($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $exifTool->Options('Verbose');
    my ($buff, $err);

    # validate HTML or XHTML file
    $raf->Read($buff, 256) or return 0;
    $buff =~ /^<(!DOCTYPE HTML|HTML|\?xml)/i or return 0;
    $buff =~ /<(!DOCTYPE )?HTML/i or return 0 if $1 eq '?xml';
    $exifTool->SetFileType();

    $raf->Seek(0,0) or $exifTool->Warn('Seek error'), return 1;

    my $oldsep = Image::ExifTool::PostScript::SetInputRecordSeparator($raf);
    $oldsep or $exifTool->Warn('Invalid HTML data'), return 1;

    # extract header information
    my $doc;
    while ($raf->ReadLine($buff)) {
        if (not defined $doc) {
            # look for 'head' element
            next unless $buff =~ /<head\b/ig;
            $doc = substr($buff, pos($buff));
            next;
        }
        $doc .= $buff;
        last if $buff =~ m{</head>}i;
    }

    # process all elements in header
    my $tagTablePtr = GetTagTable('Image::ExifTool::HTML::Main');
    for (;;) {
        last unless $doc =~ m{<([\w:.-]+)(.*?)>}sg;
        my ($tagName, $attrs) = ($1, $2);
        my $tag = lc($tagName);
        my ($val, $grp);
        unless ($attrs =~ m{/$}) {  # self-contained XHTML tags end in '/>'
            # look for element close
            my $pos = pos($doc);
            if ($doc =~ m{(.*?)</$tagName>}sg) {
                $val = $1;
            } else {
                pos($doc) = $pos;
                next unless $tag eq 'meta'; # META tags don't need to be closed
            }
        }
        my $table = $tagTablePtr;
        # parse HTML META element
        if ($tag eq 'meta') {
            undef $tag;
            # tag name is in NAME or HTTP-EQUIV attribute
            if ($attrs =~ /name=['"]?([\w:.-]+)/si) {
                $tagName = $1;
            } elsif ($attrs =~ /http-equiv=['"]?([\w:.-]+)/si) {
                $tagName = "HTTP-equiv.$1";
            } else {
                next;   # no name
            }
            $tag = lc($tagName);
            # tag value is in CONTENT attribute
            $val = $2 if $attrs =~ /content=(['"])(.*?)\1/si;
            next unless $tag and defined $val;
            # isolate group name (separator is '.' in HTML, but ':' in ref 2)
            if ($tag =~ /^([\w-]+)[:.]([\w-]+)/) {
                ($grp, $tag) = ($1, $2);
                my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $grp);
                if ($tagInfo and $$tagInfo{SubDirectory}) {
                    $table = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                } else {
                    $tag = "$grp.$tag";
                }
            }
        } else {
            # the only non-META element we process is TITLE
            next unless $tag eq 'title';
        }
        unless ($$table{$tag}) {
            my $name = $tagName;
            $name =~ s/\W+(\w)/\u$1/sg;
            my $info = { Name => $name, Groups => { 0 => 'HTML' } };
            $info->{Groups}->{1} = ($grp eq 'http-equiv' ? 'HTTP-equiv' : "HTML-$grp") if $grp;
            Image::ExifTool::AddTagToTable($table, $tag, $info);
            $exifTool->VPrint(0, "  [adding $tag '$tagName']\n");
        }
        $val =~ s{\s*$/\s*}{ }sg;   # replace linefeeds and indenting spaces
        $exifTool->HandleTag($table, $tag, $val);
    }
    $/ = $oldsep;   # restore original separator
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::HTML - Read HTML meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
meta information from HTML documents.

=head1 AUTHOR

Copyright 2003-2007, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.w3.org/TR/html4/>

=item L<http://www.daisy.org/publications/specifications/daisy_202.html>

=item L<http://vancouver-webpages.com/META/metatags.detail.html>

=item L<http://www.html-reference.com/META.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/HTML Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

