use strict;
use warnings;
use LWP::Simple;
use File::Basename;
use File::Path;

use Cwd;
use Cwd 'abs_path';

use HTML::TreeBuilder;
use XML::LibXML;

# > perl ./html2fb2.pl "http://www.kabbalah.info/eng/layout/set/trans_page/content/view/full/31834" ./

#################################################
# Patterns
#################################################

#################################################
# Global Variables , Definitions; General Verifications
#################################################
my ($baseInput, $baseOutputDir) = @ARGV;

# checking input
unless (defined $baseInput and defined $baseOutputDir) {
  die "usage: $0 base_input base_output";    
}

# retrieve pathes, in need of case convert to absolute
my($baseInputFileName, $baseInputPath) = fileparse($baseInput, qr/\.[^.]*/);
$baseOutputDir = (abs_path($baseOutputDir)).'/';

#print "$baseInputFileName, $baseInputPath, $baseOutputDir\n";

# my $header = '<?xml version="1.0" encoding="UTF-8"?>
# <!-- edited with XML Spy v4.4 U (http://www.xmlspy.com) by Dmitry Grobov (DDS) -->
# <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:xlink="http://www.w3.org/1999/xlink">';
# my $tail = '</FictionBook>';


my %html2fb2 = ("p" => "p", #paragraph
                "b" => "strong", # bold text
                "strong" => "strong", # strong text
                "em" => "emphasis", # emphasized text 
                "i" => "emphasis", # italic text
                "sub" => "sub", 	# subscripted text
                "sup" => "sup", # superscripted text
                "code" => "code", # computer code text
                "cite" => "cite", # citation
                "del" => "strikethrough",	# deleted text
                "table" => "table", # table
                "th" => "th", # table header
                "tr" => "tr", # table row
                "td" => "td", #	table cell
                "img" => "image", # image
                );
#################################################
# Classes
#################################################

#################################################
# Functions
#################################################
sub getAndStore {
  my ($inputBase, $outBase, $file) = @_;  
  my $outFile = $outBase.$file;
  
  my($outName, $outPath) = fileparse($outFile, qr/\.[^.]*/);
  
  # treating output directory
  unless (-e $outPath and -d $outPath) {
    die "\nFailed mkdir: $outPath ($!)" unless (mkpath $outPath);
  }
  
  # store class in the file
  my $status = getstore(join("", $inputBase, $file), $outFile);
  unless (is_success($status)) {
    warn "$0: Error $status on $inputBase$file";
    return undef;
  }  
  
  return $outFile;
}

sub getElemContentR {
  my ($elem) = @_;
  
  if (not ref $elem or @{ $elem->content_array_ref() } <= 1) {
    if (not ref $elem) {print "not ref:\n $elem\n"}
    elsif (@{ $elem->content_array_ref() } <= 1) {print "content_array_ref <= 1\n";}
    return $elem;
  } else {
    my @content = ();
    foreach my $elemIn (@{ $elem->content_array_ref() }) { 
      push (@content, getElemContentR($elemIn));
    }
    return @content;
  } 
}

sub isHTMLParagraph {
  my ($elem) = @_;
  return undef unless (ref ($elem) and ref ($elem) =~ /HTML::Element/);
  $elem->tag() eq "p" ? return 1 : return undef;
}
#################################################
# Main
#################################################
my $content = get($baseInput);
# my $content = '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
#                <body><title>test</title>
#                  <div id="body">
#                    <p>aleph &#38; beyt &amp; <em>gimel</em> </p>
#                  </div>
#                </body></html>';

# my $content = '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
#                <head>
#                  <title>test</title>
#                </head>
#                <body>
#                  <div id="body">
#                    <p>aleph</p>
#                  </div>
#                </body>
#                </html>';
my $tree = HTML::TreeBuilder->new; # empty tree
$tree->parse($content);
$tree->eof();
$tree->elementify();
# print $content ."\n";
# print $tree->as_HTML() . "\n";

my $title = $tree->look_down('_tag', 'title');
print $title->as_text() . "\n";
print $title->as_HTML() . "\n";

my $body_text = $tree->look_down ('id', 'body');

my $dom = XML::LibXML::Document->createDocument( "1.0", "UTF-8" );

my $fb_elem = $dom->createElementNS("http://www.w3.org/1999/xlink", "FictionBook");
$fb_elem->setNamespace( "http://www.gribuser.ru/xml/fictionbook/2.0" , "xlink", 0 );

my $fb_elem_body = $fb_elem->createElement("body");

foreach my $elem (@{$body_text->content_array_ref()}) {
  my $fb_cur_elem = $fb_elem->createElement("p");
  foreach my $elemIn (getElemContentR($elem)) {  
    if (ref $elemIn) {
      if (ref ($elemIn) !~ /HTML::Element/) {
        my $elemInType = ref ($elemIn);
        die "Incorrect element type: $elemInType (Must be HTML::Element)";
      }
      if (not exists $html2fb2{$elemIn->tag()}) { # append to current elem as a text
        # $fb_cur_elem = $fb_elem->createElement($html2fb2{$elemIn->tag());
        my $elem_text_content = ($elemIn->content_array_ref())[0];
        if (ref elem_text_content) {
          die "at this stage we expects no sub-elements";
        }
        $fb_cur_elem->appendText($elem_text_content);
      } elsif (isHTMLParagraph $elemIn) { #push prev paragraph elem to the body elem; create new paragraph elem
        $fb_elem_body->appendChild($fb_cur_elem) if ($fb_cur_elem->textContent); # ???
        $fb_cur_elem =  $elemIn;
      } else { # create new sub-elem
        $fb_cur_elem->push_content($elemIn);
      }    
    } else {
    }
  }
}


# DEBUG Output
open (FH,,">out.txt");
foreach my $elem (@{ $body_text->content_array_ref() }) {
  print FH "="x20 . "\n";
    
  #if (@{ $elem->content_array_ref() } > 1) {
    #foreach my $elemIn (@{ $elem->content_array_ref() }) {
    foreach my $elemIn (getElemContentR($elem)) {  
      print FH "="x10 . "\n";
      print ref $elemIn;
      print "\n";
      if (ref $elemIn) {
        print FH "==ELEMENT==\n";
        print FH $elemIn->as_HTML() . "\n" ;
      } else {
        print FH "==TEXT==\n";
        print FH $elemIn . "\n";
      }
    }
  #} else {
  #  print FH $elem->as_HTML() . "\n";
  #}

}
close FH;


# open (FH,">out.html");
# print FH $tree->as_HTML();
# close FH;
  
$tree->delete(); # Now that we're done with it, we must destroy it.
exit;

#################################################
# The End
#################################################