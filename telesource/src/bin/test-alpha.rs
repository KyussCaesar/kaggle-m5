use std::process::Command;

use env_logger;

use telesource::prelude::*;

use telesource::{
  cvdb,
  hypothesis_store,
  dmatrix_store,
  dmatrix_store::DMatrixStore,
  dmatrixptr::DMatrixPtr,
  model_store,
};

use telesource::hypothesis::Hypothesis;
use telesource::hypothesis_store::HypothesisStore;
use telesource::cvdb::CVDB;

fn end_of_run(
  cvdb: &mut dyn CVDB,
  hs: &mut dyn HypothesisStore,
  run_id: id,
  _hyp_id: id,
  hyp: &Hypothesis
)
{
  if run_id < 5
  {
    let new_h = hyp.derive_new(|h| {
      h.xgb_nrounds += 1;
      h.xgb_max_depth += 1;
    });

    cvdb.propose_hypothesis_test(run_id + 1, hs.put(new_h));
  }
}

fn main()
{
  env_logger::init();

  let mut hs = hypothesis_store::InMemory::new();
  let hyp = Hypothesis::new().derive_new(|h| {
    h.xgb_max_depth = 5;
  });

  let hyp_id = hs.put(hyp);

  let mut cvdb = cvdb::InMemory::new();

  cvdb.propose_hypothesis_test(0 as usize, hyp_id);

  let mut ds = dmatrix_store::Agaricus::default();

  let mut ms = model_store::InMemory::new();

  telesource::run_experiment(
    &mut cvdb,
    &mut hs,
    &mut ds,
    &mut ms,
    905678 as usize,
    end_of_run,
  );

  cvdb.dump_table();
}

pub struct Rscript;

impl DMatrixStore for Rscript
{
  fn get(&self, features: &Vec<String>, trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr)
  {
     for f in features
     {
       Command::new("Rscript")
         .arg("generate-feature.R")
         .arg(f)
         .status()
         .expect("failed to run process");
     }

     // TODO: pass output location as --output <location>
     let trn = {
       let mut trn = Command::new("Rscript");
       trn
         .arg("create-dm.R")
         .arg("--features")
         .args(features)
         .arg("--dates");

       for d in trn_dates
       {
         trn.arg(d.to_string());
       }

       trn.output().expect("failed to run process").stdout
     };

     let tst =
       Command::new("Rscript")
         .arg("create-dm.R")
         .arg("--features")
         .args(features)
         .arg("--dates")
         .arg(tst_date.to_string())
         .output()
         .expect("failed to run process")
         .stdout;

    return (String::from_utf8(trn).unwrap().into(), String::from_utf8(tst).unwrap().into());
  }
}

