//! Library for distributed data-science build.

use rand::distributions::uniform::Uniform;
use rand::Rng;
use rand_chacha::ChaCha20Rng;
use rand_chacha::rand_core::RngCore;
use rand_chacha::rand_core::SeedableRng;

#[allow(non_camel_case_types)]
pub mod prelude
{
  // basic type aliases; simplify for prototype
  pub type float = f64;
  pub type int = u16;
  pub type short = u8;
  pub type id = usize;
}

pub mod cvdb;
pub mod dmatrix_store;
pub mod dmatrixptr;
pub mod hypothesis;
pub mod hypothesis_store;
pub mod model_store;

use crate::cvdb::CVDB;
use crate::dmatrix_store::DMatrixStore;
use crate::hypothesis::Hypothesis;
use crate::hypothesis_store::HypothesisStore;
use crate::model_store::ModelStore;
use crate::prelude::*;

fn mk_dates(n_dates: usize, base_seed: id, run_id: id) -> (Vec<int>, int)
{
  assert!(n_dates >  0);
  assert!(n_dates <= 1855);

  let mut rng = {
    let mut rng = ChaCha20Rng::seed_from_u64(base_seed as u64);
    for _ in 0..run_id { rng.next_u64(); }
    ChaCha20Rng::seed_from_u64(rng.next_u64())
  };

  let last_trn = rng.sample(Uniform::from(730..=1855));

  let mut dates: Vec<int> = Vec::with_capacity(n_dates);

  for i in 0..n_dates
  {
    dates.push(last_trn - i as int);
  }

  let tst_date = last_trn + 28;

  (dates, tst_date)
}

pub struct Experiment
{
  cvdb: Box<dyn CVDB>,
  hyp_s: Box<dyn HypothesisStore>,
  dmatrix_s: Box<dyn DMatrixStore>,
  model_s: Box<dyn ModelStore>,
  base_seed: id,
  end_of_run: Box<dyn Fn(&mut dyn CVDB, id, id, &Hypothesis)>
}

impl Experiment
{
  pub fn new
  <
    C: CVDB + 'static,
    HS: HypothesisStore + 'static,
    DS: DMatrixStore + 'static,
    MS: ModelStore + 'static,
    F: Fn(&mut dyn CVDB, id, id, &Hypothesis) + 'static
  >
  (
    cvdb: C,
    hyp_s: HS,
    dmatrix_s: DS,
    model_s: MS,
    base_seed: id,
    end_of_run: F
  ) -> Self
  {
    Self
    {
      cvdb: Box::new(cvdb),
      hyp_s: Box::new(hyp_s),
      dmatrix_s: Box::new(dmatrix_s),
      model_s: Box::new(model_s),
      base_seed: base_seed,
      end_of_run: Box::new(end_of_run),
    }
  }

  pub fn run(&mut self)
  {
    while let Some((test_date_id, hyp_id)) = self.cvdb.get_next_untested_row()
    {
      let hyp = self.hyp_s.get(hyp_id);

      let (trn_dates, tst_date) = mk_dates(hyp.get_n_training_dates(), self.base_seed, test_date_id);

      let (trn, tst) = self.dmatrix_s.get(hyp.get_features(), &trn_dates, tst_date);

      let (model_id, score) = self.model_s.train(hyp.clone(), trn, tst);

      self.cvdb.record_score(test_date_id, hyp_id, score, model_id);

      (self.end_of_run)(&mut *self.cvdb, test_date_id, hyp_id, &hyp);
    }
  }
}

