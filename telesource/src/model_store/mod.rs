use xgboost::Booster;
use xgboost::parameters::TrainingParametersBuilder;

use crate::prelude::*;
use crate::dmatrixptr::DMatrixPtr;
use crate::hypothesis::Hypothesis;

pub trait ModelStore
{
  fn train(&mut self, hyp: Hypothesis, trn: DMatrixPtr, tst: DMatrixPtr) -> (id, float);

  // TODO:
  // - some method to return feature contributions
  // - some method to return feature importance
}

pub struct InMemory
{
  table: Vec<Booster>
}

impl InMemory
{
  pub fn new() -> Self
  {
    Self
    {
      table: Vec::new()
    }
  }
}

impl ModelStore for InMemory
{
  fn train(&mut self, hyp: Hypothesis, trn: DMatrixPtr, tst: DMatrixPtr) -> (id, float)
  {
    let trn = trn.load();
    let tst = tst.load();

    let eval_sets = &[(&trn, "trn"), (&tst, "tst")];

    let params =
      TrainingParametersBuilder::default()
      .dtrain(&trn)
      .evaluation_sets(Some(eval_sets))
      .build()
      .unwrap();

    let model = Booster::train(&params).unwrap();

    let score = model.evaluate(&trn).unwrap()["rmse"] as float;

    self.table.push(model);
    let model_id = self.table.len();

    return (model_id, score);
  }
}

