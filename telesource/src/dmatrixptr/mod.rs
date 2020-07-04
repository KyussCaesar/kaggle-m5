use xgboost;
use serde::{Serialize, Deserialize};

/// "Pointer" to a DMatrix.
pub trait DMatrixPtr: Serialize + Deserialize + Clone
{
  /// Specify a filter to be applied to each row during the load.
  ///
  /// Rows which do not satisfy the predicate are ignored.
  ///
  /// This is to implement "splitting" of design matrix.
  //pub fn set_filter(&mut self, f: Fn(NotSure) -> bool);

  /// Load this design matrix into memory.
  pub fn load(&self) -> xgboost::DMatrix;
}

// If your data is already stored on-disk in a format acceptable by XGBoost
// library, then you can just pass the file name directly.
impl<P: AsRef<Path>> DMatrixPtr for P
{
  pub fn load(&self) -> xgboost::DMatrix
  {
    xgboost::DMatrix::load(self).unwrap()
  }
}

// ideas for future implementations:
// - read from CSV (custom one c.f. XGBoost using CSV, to support filter)
// - read from R `qs` type
// - read from R `rds` type
// - read from SQLite DB
// - read from S3 storage
// - read from Postgres DB

