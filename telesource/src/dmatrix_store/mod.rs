use std::process::Command;

use crate::prelude::*;
use crate::dmatrixptr::DMatrixPtr;

pub trait DMatrixStore
{
  /// Returns the train and test sets for a design matrix constructed with the
  /// specified features, training dates, and test date.
  fn get(&self, features: &Vec<String>, trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr);
}

pub struct Local;

impl Local
{
  pub fn new() -> Self
  {
    Self
  }
}

impl DMatrixStore for Local
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

    //return (String::from_utf8(trn).unwrap().into(), String::from_utf8(tst).unwrap().into());
    return ("agaricus.txt.train".into(), "agaricus.txt.test".into())
  }
}

