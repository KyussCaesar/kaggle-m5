use std::path::{Path, PathBuf};

use crate::prelude::*;
use crate::dmatrixptr::DMatrixPtr;

pub trait DMatrixStore
{
  /// Returns the train and test sets for a design matrix constructed with the
  /// specified features, training dates, and test date.
  fn get(&self, features: &Vec<String>, trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr);
}

/// Dummy DMatrix store; just returns `agaricus.txt` train and test sets.
pub struct Agaricus
{
  trn: PathBuf,
  tst: PathBuf,
}

impl Agaricus
{
  pub fn new<P1: AsRef<Path>, P2: AsRef<Path>>(trn_p: P1, tst_p: P2) -> Self
  {
    Self
    {
      trn: trn_p.as_ref().to_owned(),
      tst: tst_p.as_ref().to_owned(),
    }
  }
}

impl Default for Agaricus
{
  fn default() -> Self
  {
    Self::new("agaricus.txt.train", "agaricus.txt.test")
  }
}

impl DMatrixStore for Agaricus
{
  fn get(&self, _: &Vec<String>, _: &[int], _: int) -> (DMatrixPtr, DMatrixPtr)
  {
    return (self.trn.clone().into(), self.tst.clone().into())
  }
}

