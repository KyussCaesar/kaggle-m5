use crate::dmatrixptr::DMatrixPtr;

pub trait DMatrixStore
{
  /// Returns the train and test sets for a design matrix constructed with the
  /// specified features, training dates, and test date.
  pub fn get(&self, features: &[str], trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr);
}

struct Local;

impl DMatrixStore for Local
{
  pub fn get(&self, features: &[str], trn_dates: &[int], tst_date: int) -> (DMatrixPtr, DMatrixPtr)
  {
    for f in features
    {
      Command::new("Rscript")
        .arg("generate-feature.R")
        .arg(f)
        .status()
        .expect("failed to run process");
    }

    let trn =
      Command::new("Rscript")
        .arg("create-dm.R")
        .arg("--features")
        .args(features)
        .arg("--dates")
        .args(trn_dates)
        .output()
        .expect("failed to run process")
        .stdout;

    let tst =
      Command::new("Rscript")
        .arg("create-dm.R")
        .arg("--features")
        .args(features)
        .arg("--dates")
        .arg(tst_date)
        .output()
        .expect("failed to run process")
        .stdout;

    return (trn, tst);
  }
}

