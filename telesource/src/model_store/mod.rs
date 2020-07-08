use xgboost::Booster;
use xgboost::parameters::{
  TrainingParametersBuilder,
  learning::LearningTaskParametersBuilder,
  BoosterType,
  BoosterParametersBuilder,
  tree::TreeBoosterParametersBuilder,
};

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

    let learning_params =
      LearningTaskParametersBuilder::default()
      .base_score(hyp.get_base_score() as f32)
      .build()
      .expect("failed to build learning params");

    let tree_booster_parameters =
      TreeBoosterParametersBuilder::default()
      .eta(hyp.get_eta() as f32)
      .max_depth(hyp.get_max_depth() as u32)
      .min_child_weight(hyp.get_min_child_weight() as f32)
      .max_delta_step(hyp.get_max_delta_step() as f32)
      .subsample(hyp.get_subsample() as f32)
      .colsample_bytree(hyp.get_colsample_bytree() as f32)
      .colsample_bylevel(hyp.get_colsample_bylevel() as f32)
      .colsample_bynode(hyp.get_colsample_bynode() as f32)
      .lambda(hyp.get_lambda() as f32)
      .alpha(hyp.get_alpha() as f32)
      .tree_method(hyp.get_tree_method().into())
      .num_parallel_tree(hyp.get_num_parallel_tree() as u32)
      .build()
      .expect("failed to build tree booster params");

    let booster_params = 
      BoosterParametersBuilder::default()
      .booster_type(BoosterType::Tree(tree_booster_parameters))
      .learning_params(learning_params)
      .verbose(false)
      .threads(Some(hyp.get_nthread() as u32))
      .build()
      .expect("failed to build booster params");

    let params =
      TrainingParametersBuilder::default()
      .dtrain(&trn)
      .boost_rounds(hyp.get_nrounds() as u32)
      .booster_params(booster_params)
      .evaluation_sets(Some(eval_sets))
      // TODO: custom objective function
      // TODO: custom evaluation function
      .build()
      .expect("failed to build training params");

    let model = Booster::train(&params).unwrap();

    let score = model.evaluate(&tst).unwrap()["rmse"] as float;

    self.table.push(model);
    let model_id = self.table.len();

    return (model_id, score);
  }
}

