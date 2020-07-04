pub trait ModelStore
{
  pub fn train(&mut self, hyp_id: id, trn: &dyn DMatrixPtr, tst: &dyn DMatrixPtr) -> (id, float);

  // TODO:
  // - some method to return feature contributions
  // - some method to return feature importance
}

struct InMemory
{
  table: Vec<Booster>
}

impl ModelStore for InMemory
{
  pub fn train(&mut self, hyp_id: id, trn: &dyn DMatrixPtr, tst: &dyn DMatrixPtr) -> (id, float)
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

    let model = Booster:::train(&params).unwrap();

    let score = model.evaluate(&trn).unwrap()["rmse"];

    self.table.push(model);
    let model_id = self.table.len();

    return (model_id, score);
  }
}

