#!/usr/bin/perl
# script for creating list of queries and utterance files 
use strict;
use warnings;

use File::Basename; #for extracting $name $path and $suffix of filename 

my $hearder = "[create_list] ... \t";

if ( @ARGV != 2 ) {die $hearder . "Usage: /full_path_input_dir output_namelist\n"};

my $dir_in=shift;
my $namelist_out=shift;

my ($name,$path,$suffix)=();
#printf("$dir_in\n");

opendir( DIR,"$dir_in" ) or die $hearder . "Error opening input directory $dir_in\n";
my @dirs = sort(grep(!/^(\.|\.\.)$/, readdir(DIR)));#read dir without dot and dot dot and sort files_dirs 
closedir( DIR );
if( @dirs == 0 ){ die $hearder . "No files_dirs found in $dir_in\n"; }

open(OUT,">$namelist_out") or die ("Can not open output file: $namelist_out\n");

foreach my $file ( @dirs ){
#	printf("$file\n");
	($name,$path,$suffix) = fileparse(<$dir_in\*$file>,qr/\.[^.]*/);
	#printf("$name $path $suffix\n");
	printf OUT ("$name\n");
}
