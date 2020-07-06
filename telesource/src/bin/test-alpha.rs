use telesource::prelude::*;

use telesource::{
  cvdb,
  hypothesis_store,
  dmatrix_store,
  model_store,
};

use telesource::hypothesis::Hypothesis;
use telesource::hypothesis_store::HypothesisStore;
use telesource::cvdb::CVDB;

fn end_of_run(
  cvdb: &mut dyn CVDB,
  hs: &mut dyn HypothesisStore,
  run_id: id,
  hyp_id: id,
  hyp: &Hypothesis
)
{
  if run_id < 10
  {
    let new_h = hyp.derive_new(|h| {
      h.xgb_nrounds += 1;
    });

    cvdb.propose_hypothesis_test(run_id + 1, hs.put(new_h));
  }
}

fn main()
{
  let mut hs = hypothesis_store::InMemory::new();
  let hyp = Hypothesis::new();

  let hyp_id = hs.put(hyp);

  let mut cvdb = cvdb::InMemory::new();

  cvdb.propose_hypothesis_test(0 as usize, hyp_id);

  let mut ds = dmatrix_store::Local::new();

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

