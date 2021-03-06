#!/usr/local/bin/perl -w

#
# This program walks through HTML pages, extracting all the links to other
# text/html pages and then walking those links. Basically the robot performs
# a breadth first search through an HTML directory structure.
#
# All other functionality must be implemented
#
# Example:
#
#    robot_base.pl mylogfile.log content.txt http://www.cs.jhu.edu/
#
# Note: you must use a command line argument of http://some.web.address
#       or else the program will fail with error code 404 (document not
#       found).

use strict;

use Carp;
use HTML::LinkExtor;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status;
use LWP::RobotUA;
use URI::URL;

URI::URL::strict( 1 );   # insure that we only traverse well formed URL's

$| = 1;

my $log_file = shift (@ARGV);
if ((!defined ($log_file))) {
    print STDERR "You must specify a log file, a content file and a base_url\n";
    print STDERR "when running the web robot:\n";
    print STDERR "  ./robot_base.pl mylogfile.log base_url\n";
    exit (1);
}

open LOG, ">$log_file";

############################################################
##               PLEASE CHANGE THESE DEFAULTS             ##
############################################################

# I don't want to be flamed by web site administrators for
# the lousy behavior of your robots. 

my $ROBOT_NAME = 'IdeanBot/1.0';
my $ROBOT_MAIL = 'ilabib1@jhu.edu';

#
# create an instance of LWP::RobotUA. 
#
# Note: you _must_ include a name and email address during construction 
#       (web site administrators often times want to know who to bitch at 
#       for intrusive bugs).
#
# Note: the LWP::RobotUA delays a set amount of time before contacting a
#       server again. The robot will first contact the base server (www.
#       servername.tag) to retrieve the robots.txt file which tells the
#       robot where it can and can't go. It will then delay. The default 
#       delay is 1 minute (which is what I am using). You can change this 
#       with a call of
#
#         $robot->delay( $ROBOT_DELAY_IN_MINUTES );
#
#       At any rate, if your program seems to be doing nothing, wait for
#       at least 60 seconds (default delay) before concluding that some-
#       thing is wrong.
#

my $robot = new LWP::RobotUA $ROBOT_NAME, $ROBOT_MAIL;
$robot->delay( 0.05 );

my $first_url    = shift(@ARGV);   # the root URL we will start from
$first_url =~ /^https?:\/\/(www\.)?(.*?)(\/.*?)?(#.*)?$/;
my $base_url = $2.$3;
my $domain = $2;

my @search_urls = ();    # current URL's waiting to be trapsed
my @wanted_urls = ();    # URL's which contain info that we are looking for
my %relevance   = ();    # how relevant is a particular URL to our search
my %pushed      = ();    # URL's which have either been visited or are already
                         #  on the @search_urls array
    
push @search_urls, $first_url;

my $id = 0;

while (@search_urls) {
  close LOG;
  open LOG, ">>$log_file";

    my $url = shift @search_urls;

    #
    # insure that the URL is well-formed, otherwise skip it
    # if not or something other than HTTP
    #

    my $parsed_url = eval { new URI::URL $url; };

    next if $@;
    next if $parsed_url->scheme !~/http/i;
	
    #
    # get header information on URL to see it's status (exis-
    # is not okay or the content type is not what we are 
    # looking for skip the URL and move on
    # 

    print LOG "[HEAD ] $url\n";

    my $request  = new HTTP::Request HEAD => $url;
    my $response = $robot->request( $request );
	
    next if $response->code != RC_OK;
    next if ! &wanted_content( $url, $response->content_type );

    print LOG "[GET  ] $url\n";

    $request->method( 'GET' );
    $response = $robot->request( $request );

    next if $response->code != RC_OK;
    next if $response->content_type !~ m@text/html@;

    open OUTPUT, ">".$id++.".html";
    print OUTPUT $response->content;
    close OUTPUT;
    
    my @related_urls  = &grab_urls( $response->content );

    foreach my $link (@related_urls) {
      my $full_url = eval { (new URI::URL $link, $response->base)->abs; };

      if ($full_url =~ /^https?:\/\/(www\.)?$base_url(#.*)?$/ ||
        $full_url !~ /^https?:\/\/(www\.)?$domain/) {

        next;
      }

      push @search_urls, $full_url and $pushed{ $full_url } = 1
          if ! exists $pushed{ $full_url };
    }
}

while(@wanted_urls) {
  my $url = shift(@wanted_urls);
  open OUTPUT, ">$url";
  my $request  = new HTTP::Request HEAD => $url;
  $request->method( 'GET' );
  my $response = $robot->request( $request );

  next if $response->code != RC_OK;
  next if $response->content_type !~ m@text/plain@;

  print OUTPUT ">".$id++.".txt";
  close OUTPUT;
}

close LOG;

exit (0);
    
#
# wanted_content
#
#    IMPLEMENTED
#
#  this function should check to see if the current URL content
#  is something which is either
#
#    a) something we are looking for (e.g. postscript, pdf,
#       plain text, or html). In this case we should save the URL in the
#       @wanted_urls array.
#
#    b) something we can traverse and search for links
#       (this can be just text/html).
#

sub wanted_content {
    my $url = shift;
    my $content = shift;

    # right now we only accept text/html
    #  and this requires only a *very* simple set of additions
    #

    if ($content =~ /text\/plain/) {
      print "PLAIN TEXT link: ", $url, "\n";
      print LOG "[PLAIN TEXT] $url\n";
      push @wanted_urls, $url;
    }

    return $content =~ m@text/html@;
}

#
# grab_urls
#
#    PARTIALLY IMPLEMENTED
#
#   this function parses through the content of a passed HTML page and
#   picks out all links and any immediately related text.
#
#   Example:
#
#     given 
#
#       <a href="somepage.html">This is some web page</a>
#
#     the link "somepage.html" and related text "This is some web page"
#     will be parsed out. However, given
#
#       <a href="anotherpage.html"><img src="image.jpg">
#
#       Further text which does not relate to the link . . .
# 
#     the link "anotherpage.html" will be parse out but the text "Further
#     text which . . . " will be ignored.
#
#   Relevancy based on both the link itself and the related text should
#   be calculated and stored in the %relevance hash
#
#   Example:
#
#      $relevance{ $link } = &your_relevance_method( $link, $text );
#
#   Currently _no_ relevance calculations are made and each link is 
#   given a relevance value of 1.
#

sub grab_urls {
    my $content = shift;
    my %urls    = ();    # NOTE: this is an associative array so that we only
                         #       push the same "href" value once.

    
  skip:
    while ($content =~ s/<\s*[aA] ([^>]*)>\s*(?:<[^>]*>)*(?:([^<]*)(?:<[^aA>]*>)*<\/\s*[aA]\s*>)?//) {
	    
	my $tag_text = $1;
	my $reg_text = $2;
	my $link = "";

	if (defined $reg_text) {
	    $reg_text =~ s/[\n\r]/ /;
	    $reg_text =~ s/\s{2,}/ /;

	    #
	    # compute some relevancy function here
	    #
	}

	if ($tag_text =~ /href\s*=\s*(?:["']([^"']*)["']|([^\s])*)/i) {
	    $link = $1 || $2;

	    #
	    # okay, the same link may occur more than once in a
	    # document, but currently I only consider the last
	    # instance of a particular link
	    #

	    $urls{ $link }      = 1;
	}

	#print $reg_text, "\n" if defined $reg_text;
	#print $link, "\n\n";
    }

    return keys %urls;   # the keys of the associative array hold all the
                         # links we've found (no repeats).
}
