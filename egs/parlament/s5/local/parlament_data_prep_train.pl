#!/usr/bin/perl

use utf8;
use strict;

my $db_dir = shift;
my $info = "$db_dir/parlament3_diftong_j.infos";
my $lst = "$db_dir/train.lst";
my $out_dir = "data/train";

my $out_txt 	= $out_dir . "/text";
my $out_wav 	= $out_dir . "/wav.scp";
my $out_spks 	= $out_dir . "/speaker_ids.lst";
my $out_utt 	= $out_dir . "/utt2spk";
my $out_gender  = $out_dir . "/spk2gender";

my %files = ();

unless(-d $out_dir){ system("mkdir -p $out_dir"); }

#read list of files to prepare data and initialize all hash maps
open(LST, "<", $lst) or die "Error opening input list $lst\n";
while(my $line = <LST>)
{
	chomp $line;
	$files{ $line } = "";
}
close(LST);

#read information file 
open(IN, "<:encoding(cp1250)", $info) or die "Error opening input file $info\n";
while(my $line = <IN>)
{
	chomp $line;
	(my $file, my $infos) = split(/\s+/, $line, 2);
	
	if(exists $files{$file}){ $files{$file} = $infos; }
}
close(IN);

#check if all files where found
foreach my $file (keys %files)
{
	if($files{$file} eq ""){ die $file ." not found\n"; }
}

#output info to all files
open(OUT_TXT, ">:encoding(UTF-8)", $out_txt) or die "Error opening output file $out_txt\n";
open(OUT_WAV, ">:encoding(UTF-8)", $out_wav) or die "Error opening output file $out_wav\n";
open(OUT_SPK, ">:encoding(UTF-8)", $out_spks) or die "Error opening output file $out_spks\n";
open(OUT_UTT, ">:encoding(UTF-8)", $out_utt) or die "Error opening output file $out_utt\n";
open(OUT_GEN, ">:encoding(UTF-8)", $out_gender) or die "Error opening output file $out_gender\n";

my %spk2id = (); my %id2gen = (); my $spk = 0;
foreach my $file (sort keys %files)
{
	my $infos = $files{$file};

	#get speaker name
	$infos =~ /name=(\S+),/; my $name = $1; my $id = 0;
	if(exists $spk2id{$name}){ $id = $spk2id{$name}; }
	else{ $spk2id{$name} = $spk; $id = $spk; $spk++; }

	#get gender	
	my $gen = "m"; #for unknown sex;
	if($infos =~ /sex=female/){$gen = "f";}
	if($infos =~ /sex=male/){$gen = "m";}
	$id2gen{$id} = $gen;

	#remove all other infors and get plain text
	$infos =~ s/\{.*\}//g;
	$infos =~ s/\[\*\]//g;
	$infos =~ s/\./ /g;
	$infos =~ s/,/ /g;
	$infos =~ s/\?/ /g;
	$infos =~ s/\!/ /g;
	$infos =~ s/\s+/ /g;
	$infos =~ s/^\s+//;
	$infos =~ s/\s+$//;
	$infos = lc($infos);
	
	#assemble speaker name and file name
	my $out_id = sprintf("%03d", $id);
	my $out_name = "speaker$out_id-$file";


	#output all informations
	print OUT_TXT "$out_name\t$infos\n";
	print OUT_WAV "$out_name\t$db_dir/train_wav/$file.wav\n";
	
	print OUT_UTT "$out_name\tspeaker$out_id\n";
}

foreach my $id (sort{ $a<=>$b } keys %id2gen)
{
	my $out_id = sprintf("%03d", $id);
	print OUT_GEN "speaker$out_id\t$id2gen{$id}\n";
}

foreach my $name (sort { $spk2id{$a} <=> $spk2id{$b} } keys %spk2id)
{
	my $out_id = sprintf("%03d", $spk2id{$name});
	print OUT_SPK "speaker$out_id\t$name\n";
}

close(OUT_TXT);
close(OUT_WAV);
close(OUT_SPK);
close(OUT_UTT);
close(OUT_GEN);

print "done... \n";

system("mv $out_dir/utt2spk $out_dir/utt2spk_tmp");
system("sort -k1 $out_dir/utt2spk_tmp > $out_dir/utt2spk");
system("rm $out_dir/utt2spk_tmp");

system("mv $out_dir/text $out_dir/text_tmp");
system("sort -k1 $out_dir/text_tmp > $out_dir/text");
system("rm $out_dir/text_tmp");

system("mv $out_dir/wav.scp $out_dir/wav_tmp.scp");
system("sort -k1 $out_dir/wav_tmp.scp > $out_dir/wav.scp");
system("rm $out_dir/wav_tmp.scp");

system("./utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk > $out_dir/spk2utt");
