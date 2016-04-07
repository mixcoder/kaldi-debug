#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

# NOTE: You will want to download the data set first, before executing this script.
#       This can be done for example by:
#       1. Setting the DATA_ROOT variable to point to a directory with enough free
#          space (at least 20-25GB currently (Feb 2014))
#       2. Running "getdata.sh"

# The second part of this script comes mostly from egs/rm/s5/run.sh
# with some parameters changed

. ./path.sh || exit 1

# If you have cluster of machines running GridEngine you may want to
# change the train and decode commands in the file below
. ./cmd.sh || exit 1

# The number of parallel jobs to be started for some parts of the recipe
# Make sure you have enough resources(CPUs and RAM) to accomodate this number of jobs
njobs=1

# Word position dependent phones?
pos_dep_phones=false

# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false
. utils/parse_options.sh || exit 1

[[ $# -ge 1 ]] && { echo "Unexpected arguments"; exit 1; }

database=/home/vavrek/kaldi-debug/egs/parlament/database;



#===========================================================
# 	CREATING TRAINING DATA & EXTRACTING MFCCs
#===========================================================

# prepare traning data for parlament
./local/parlament_data_prep_train.pl $database || exit 1;
./utils/validate_data_dir.sh --no-feats data/train;
./utils/fix_data_dir.sh data/train;

# Now make MFCC features.
mfccdir_train=${DATA_ROOT}/data/mfcc_train
steps/make_mfcc.sh --cmd "$train_cmd" --nj $njobs data/train exp/make_mfcc/train $mfccdir_train || exit 1;
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir_train || exit 1;

# Prepare data/lang and data/local/lang directories
utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones data/local/train '-' data/local/lang_temp_train data/lang_train || exit 1

#===========================================================
# 	CREATING TESTING DATA & EXTRACTING MFCCs
#===========================================================

#./local/parlament_data_prep_test.pl $database || exit 1;
#./utils/validate_data_dir.sh --no-feats data/test;
#./utils/fix_data_dir.sh data/test;

# Now make MFCC features.
#mfccdir_test=${DATA_ROOT}/data/mfcc_test
#steps/make_mfcc.sh --cmd "$train_cmd" --nj $njobs data/test exp/make_mfcc/test $mfccdir_test || exit 1;
#steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir_test || exit 1;

# Prepare data/lang and data/local/lang directories
#utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones data/local/test '-' data/local/lang_temp_test data/lang_test || exit 1

#create test set
#cat data/local/test/lm.arpa | utils/find_arpa_oovs.pl data/lang_test/words.txt > data/lang_test/oovs.txt
#cat data/local/test/lm.arpa | grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | arpa2fst - | fstprint | utils/remove_oovs.pl data/lang_test/oovs.txt | utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang_test/words.txt --osymbols=data/lang_test/words.txt  --keep_isymbols=false --keep_osymbols=false | fstrmepsilon | fstarcsort --sort_type=ilabel > data/lang_test/G.fst 
#fstisstochastic data/lang_test/G.fst

#===========================================================
# 	TRAINING MONOPHONE MODELS
#===========================================================

#utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;
#steps/train_mono.sh --nj $njobs --cmd "$train_cmd" data/train data/lang_train exp/mono  || exit 1;

#utils/mkgraph.sh --mono data/lang_test exp/mono exp/mono/graph || exit 1;
#steps/decode.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode

#===========================================================
# 	TRAINING TRIPHONE MODELS
#===========================================================

#./steps/align_si.sh --nj $njobs --cmd "$train_cmd" data/train data/lang_train exp/mono exp/mono_ali || exit 1;

# train tri1 [first triphone pass]
#steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/lang_train exp/mono_ali exp/tri1 || exit 1;

# decode tri1
#utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;
#steps/decode.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

#===========================================================
# 	TRAINING +DELTAS+DELTA-DELTAS
#===========================================================

#steps/align_si.sh --nj $njobs --cmd "$train_cmd" --use-graphs true data/train data/lang_train exp/tri1 exp/tri1_ali || exit 1;

# train tri2a [delta+delta-deltas]
#steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/lang_train exp/tri1_ali exp/tri2a || exit 1;

# decode tri2a
#utils/mkgraph.sh data/lang_test exp/tri2a exp/tri2a/graph 
#steps/decode.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" exp/tri2a/graph data/test exp/tri2a/decode

#===========================================================
# 	TRAINING +LDA + MLLT
#===========================================================

#steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 11000 data/train data/lang_train exp/tri1_ali exp/tri2b || exit 1;
#utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph
#steps/decode.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b/decode

#===========================================================
# 	TRAINING +MMI
#===========================================================

# Align all data with LDA+MLLT system (tri2b)
#steps/align_si.sh --nj $njobs --cmd "$train_cmd" --use-graphs true data/train data/lang_train exp/tri2b exp/tri2b_ali || exit 1;

#  Do MMI on top of LDA+MLLT.
#steps/make_denlats.sh --nj $njobs --cmd "$train_cmd" data/train data/lang_train exp/tri2b exp/tri2b_denlats || exit 1;
#steps/train_mmi.sh data/train data/lang_train exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi || exit 1;
#steps/decode.sh --config conf/decode.config --iter 4 --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b_mmi/decode_it4
#steps/decode.sh --config conf/decode.config --iter 3 --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b_mmi/decode_it3

#===========================================================
# 	TRAINING +boost
#===========================================================

#steps/train_mmi.sh --boost 0.05 data/train data/lang_train exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi_b0.05 || exit 1;
#steps/decode.sh --config conf/decode.config --iter 4 --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b_mmi_b0.05/decode_it4 || exit 1;
#steps/decode.sh --config conf/decode.config --iter 3 --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b_mmi_b0.05/decode_it3 || exit 1;


# Do MPE.
#steps/train_mpe.sh data/train data/lang_train exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mpe || exit 1;
#steps/decode.sh --config conf/decode.config --iter 4 --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b_mpe/decode_it4 || exit 1;
#steps/decode.sh --config conf/decode.config --iter 3 --nj 1 --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b_mpe/decode_it3 || exit 1;


## Do LDA+MLLT+SAT, and decode.
#steps/train_sat.sh 2000 11000 data/train data/lang_train exp/tri2b_ali exp/tri3b || exit 1;
#utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph || exit 1;
#steps/decode_fmllr.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" exp/tri3b/graph data/test exp/tri3b/decode || exit 1;


# Align all data with LDA+MLLT+SAT system (tri3b)
#steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" --use-graphs true data/train data/lang_train exp/tri3b exp/tri3b_ali || exit 1;

## MMI on top of tri3b (i.e. LDA+MLLT+SAT+MMI)
#steps/make_denlats.sh --config conf/decode.config --nj $njobs --cmd "$train_cmd" --transform-dir exp/tri3b_ali data/train data/lang_train exp/tri3b exp/tri3b_denlats || exit 1;
#steps/train_mmi.sh data/train data/lang_train exp/tri3b_ali exp/tri3b_denlats exp/tri3b_mmi || exit 1;

#steps/decode_fmllr.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" --alignment-model exp/tri3b/final.alimdl --adapt-model exp/tri3b/final.mdl exp/tri3b/graph data/test exp/tri3b_mmi/decode || exit 1;

# Do a decoding that uses the exp/tri3b/decode directory to get transforms from.
#steps/decode.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_mmi/decode2 || exit 1;

#done

