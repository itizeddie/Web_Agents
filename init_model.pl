#!/usr/local/bin/perl -w

use strict;

use Carp;
use FileHandle;

my $corpus_list = "corpus_list";
my $corpuses_fh = new FileHandle $corpus_list, "r" 
    or croak "Failed $corpus_list";


my $line = undef;
my $corpus = "";
while(defined($line = <$corpuses_fh>)) {
  chomp $line;
  $corpus = $line;

  system($^X, "vector1.prl", ("bypass", $corpus))
}
