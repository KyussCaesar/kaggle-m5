use crate::prelude::*;
use crate::dmatrixptr::DMatrixPtr;

pub trait DMatrixStore
{
  /// Returns the train and test sets for a design matrix constructed with the
  /// specified features, training dates, and test date.
  fn get(&self, features: &Vec<String>, trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr);
}

/// Blanket impl for closures with the same call signature as the method.
///
/// This allows you to use a plain function as the "DMatrixStore", for cases
/// when:
/// * you don't have any state to track in-between builds, or
/// * your function invokes something else that keeps track of the state, so
///   there's no need for an in-memory type to do the book-keeping.
impl<F: Fn(&Vec<String>, &[int], int) -> (DMatrixPtr, DMatrixPtr)> DMatrixStore for F
{
  fn get(&self, features: &Vec<String>, trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr)
  {
    self(features, trn_dates, tst_date)
  }
}

/// Dummy DMatrixStore; just returns `agaricus.txt` train and test sets.
pub fn agaricus( _: &Vec<String>, _: &[int], _: int) -> (DMatrixPtr, DMatrixPtr)
{
  return (
    "agaricus.txt.train".into(),
    "agaricus.txt.test".into()
  )
}

