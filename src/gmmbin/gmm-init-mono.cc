// gmmbin/gmm-init-mono.cc

// Copyright 2009-2011  Microsoft Corporation

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.


#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "gmm/am-diag-gmm.h"
#include "hmm/hmm-topology.h"
#include "hmm/transition-model.h"

namespace kaldi {
// This function reads a file like:
// 1 2 3
// 4 5
// 6 7 8
// where each line is a list of integer id's of phones (that should have their pdfs shared).
void ReadSharedPhonesList(std::string rxfilename, std::vector<std::vector<int32> > *list_out) {
  list_out->clear();
  Input input(rxfilename);
  std::istream &is = input.Stream();
  std::string line;
  while (std::getline(is, line)) {
    list_out->push_back(std::vector<int32>());
    if (!SplitStringToIntegers(line, " \t\r", true, &(list_out->back())))
      KALDI_ERR << "Bad line in shared phones list: " << line << " (reading "
                << PrintableRxfilename(rxfilename) << ")";
    std::sort(list_out->rbegin()->begin(), list_out->rbegin()->end());
    if (!IsSortedAndUniq(*(list_out->rbegin())))
      KALDI_ERR << "Bad line in shared phones list (repeated phone): " << line
                << " (reading " << PrintableRxfilename(rxfilename) << ")";
  }
}

} // end namespace kaldi

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using kaldi::int32;

    const char *usage =
        "Initialize monophone GMM.\n"
        "Usage:  gmm-init-mono <topology-in> <dim> <model-out> <tree-out> \n"
        "e.g.: \n"
        " gmm-init-mono topo 39 mono.mdl mono.tree\n";

    bool binary = trues;
    std::string train_feats;
    std::string shared_phones_rxfilename;
    BaseFloat perturb_factor = 0.0;
    ParseOptions po(usage);
    po.Register("binary", &binary, "Write output in binary mode");
    po.Register("train-feats", &train_feats,
                "rspecifier for training features [used to set mean and variance]");
    po.Register("shared-phones", &shared_phones_rxfilename,
                "rxfilename containing, on each line, a list of phones whose pdfs should be shared.");
    po.Register("perturb-factor", &perturb_factor,
                "Perturb the means using this fraction of standard deviation.");
    po.Read(argc, argv);

    if (po.NumArgs() != 4) {
      po.PrintUsage();
      exit(1);
    }

    std::string topo_filename = po.GetArg(1);
    int dim = atoi(po.GetArg(2).c_str());
    KALDI_ASSERT(dim> 0 && dim < 10000);
    std::string model_filename = po.GetArg(3);
    std::string tree_filename = po.GetArg(4);

    Vector<BaseFloat> glob_inv_var(dim);
    glob_inv_var.Set(1.0);
    Vector<BaseFloat> glob_mean(dim);
    glob_mean.Set(1.0);
    //for(int i=0;i<dim;i++) std::cout << "mean[" << i << "]" <<*glob_mean.Data() << " var[" << i << "]" << *glob_inv_var.Data() << std::endl;

    if (train_feats != "") {
      double count = 0.0;
      Vector<double> var_stats(dim);
      Vector<double> mean_stats(dim);
      SequentialDoubleMatrixReader feat_reader(train_feats);

      for (; !feat_reader.Done(); feat_reader.Next()) {
        const Matrix<double> &mat = feat_reader.Value();
        for (int32 i = 0; i < mat.NumRows(); i++) {
          count += 1.0;
          var_stats.AddVec2(1.0, mat.Row(i));
          mean_stats.AddVec(1.0, mat.Row(i));
          //std::cout <<"Row ["<< i <<"] "<<mat.Row(i) << std::endl;
          //for(int32 i_ = 0; i_ < dim; i_++) {
           // std::cout << "mean_stats: [" << i_ << "]" <<mean_stats.Data()[i_] << " var_stats: [" << i_ << "]" << var_stats.Data()[i_] << std::endl;
          //}
          //std::cout << mat.NumRows() << std::endl;
        }


      }

      if (count == 0) { KALDI_ERR << "no features were seen."; }
      //for(int32 i_ = 0; i_ < dim; i_++) {
      // std::cout << "mean_stats: [" << i_ << "]" <<mean_stats.Data()[i_] << " var_stats: [" << i_ << "]" << var_stats.Data()[i_] << std::endl;
      //}
      //std::cout<<"count_rows_for_all_files: "<<count<<std::endl;
      var_stats.Scale(1.0/count);
      mean_stats.Scale(1.0/count);
      //for(int32 i_ = 0; i_ < dim; i_++) {
       //  std::cout << "mean_stats_scale: [" << i_ << "]" <<mean_stats.Data()[i_] << " var_stats_scale: [" << i_ << "]" << var_stats.Data()[i_] << std::endl;
      //}
      var_stats.AddVec2(-1.0, mean_stats);
      if (var_stats.Min() <= 0.0)
        KALDI_ERR << "bad variance";
      var_stats.InvertElements();
      glob_inv_var.CopyFromVec(var_stats);
      glob_mean.CopyFromVec(mean_stats);
      //std::cout <<"Dim: "<<glob_mean.Dim() << std::endl;
      //for(int32 i_ = 0; i_ < dim; i_++) {
    //	  std::cout << "global_mean_stats: [" << i_ << "]" <<glob_mean.Data()[i_] << " global_inv_var_stats: [" << i_ << "]" << glob_inv_var.Data()[i_] << std::endl;
      //}
    }

    HmmTopology topo;
    bool binary_in;
    Input ki(topo_filename, &binary_in);
    topo.Read(ki.Stream(), binary_in);

    const std::vector<int32> &phones = topo.GetPhones();

    std::vector<int32> phone2num_pdf_classes (1+phones.back());
    for (size_t i = 0; i < phones.size(); i++){
    	//std::cout<<"phone["<< i <<"]: "<<phones[i]<<std::endl;
      phone2num_pdf_classes[phones[i]] = topo.NumPdfClasses(phones[i]);
      //std::cout<<"phone2num_pdf_classes["<< phones[i] <<"]: "<<topo.NumPdfClasses(phones[i])<<std::endl;
    }

    // Now the tree [not really a tree at this point]:
    ContextDependency *ctx_dep = NULL;
    //std::cout<<"shared_phones_rxfilename"<<shared_phones_rxfilename<<std::endl;
    if (shared_phones_rxfilename == "") {  // No sharing of phones: standard approach.
    	ctx_dep = MonophoneContextDependency(phones, phone2num_pdf_classes);
    } else {
      std::vector<std::vector<int32> > shared_phones;
      ReadSharedPhonesList(shared_phones_rxfilename, &shared_phones);
      //for(int k=0; k<shared_phones.size(); ++k){
    //	  for (int l=0; l<shared_phones[k].size(); l++){
    //		  std::cout<<"shared_phones:["<<k<<"]"<< "["<<l<<"]: "<<shared_phones[k][l]<<std::endl;
    //	  }
     // }

      // ReadSharedPhonesList crashes on error.
      ctx_dep = MonophoneContextDependencyShared(shared_phones, phone2num_pdf_classes);
    }

    int32 num_pdfs = ctx_dep->NumPdfs();
    //std::cout<<"num_pdfs"<<num_pdfs<<std::endl;
    AmDiagGmm am_gmm;
    DiagGmm gmm;
    gmm.Resize(1, dim);
    {  // Initialize the gmm.
      Matrix<BaseFloat> inv_var(1, dim);
      inv_var.Row(0).CopyFromVec(glob_inv_var);
      	  //std::cout<<"inv_var: "<<inv_var.Row(0)<<std::endl;
      Matrix<BaseFloat> mu(1, dim);
      mu.Row(0).CopyFromVec(glob_mean);
      	  //std::cout<<"mu: "<<mu.Row(0)<<std::endl;
      Vector<BaseFloat> weights(1);
      weights.Set(1.0);
      	  //for(int32 x = 0; x < dim; x++) std::cout<<"weights["<<x<<"]"<<weights.Data()[x]<<std::endl;
      gmm.SetInvVarsAndMeans(inv_var, mu);

      gmm.SetWeights(weights);
      gmm.ComputeGconsts();
    }

    for (int i = 0; i < num_pdfs; i++)
      am_gmm.AddPdf(gmm);

    if (perturb_factor != 0.0) {
    	//std::cout<<"perturb_factor != 0.0"<<std::endl;
      for (int i = 0; i < num_pdfs; i++)
        am_gmm.GetPdf(i).Perturb(perturb_factor);
    }

    // Now the transition model:
    TransitionModel trans_model(*ctx_dep, topo);

    {
      Output ko(model_filename, binary);
      trans_model.Write(ko.Stream(), binary);
      am_gmm.Write(ko.Stream(), binary);
    }

    // Now write the tree.
    ctx_dep->Write(Output(tree_filename, binary).Stream(),
                   binary);

    delete ctx_dep;
    return 0;
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}

