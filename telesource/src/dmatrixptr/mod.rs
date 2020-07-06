use std::path::PathBuf;

use xgboost;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DMatrixPtr
{
  kind: DMatrixPtrKind
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum DMatrixPtrKind
{
  /// Forwarded to `xgboost::DMatrix::load`.
  LoadByXgboost {
    path: PathBuf
  },

  // ideas for future implementations:
  // - read from CSV (custom one c.f. XGBoost using CSV, to support filter)
  // - read from R `qs` type
  // - read from R `rds` type
  // - read from SQLite DB
  // - read from S3 storage
  // - read from Postgres DB

}

impl DMatrixPtr
{
  /// Specify a filter to be applied to each row during the load.
  ///
  /// Rows which do not satisfy the predicate are ignored.
  ///
  /// This is to implement "splitting" of design matrix.
  //pub fn set_filter(&mut self, f: Fn(NotSure) -> bool);

  pub fn load(&self) -> xgboost::DMatrix
  {
    use DMatrixPtrKind::*;
    match self.kind
    {
      LoadByXgboost { ref path } => xgboost::DMatrix::load(path).unwrap()
    }
  }
}

impl<T: Into<PathBuf>> From<T> for DMatrixPtr
{ 
  fn from(t: T) -> Self
  {
    Self
    {
      kind: DMatrixPtrKind::LoadByXgboost { path: t.into() }
    }
  }
}

