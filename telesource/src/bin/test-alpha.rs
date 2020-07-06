use telesource::{
  cvdb,
  hypothesis_store,
  dmatrix_store,
  model_store,
  Experiment
};

fn main()
{
  let e = Experiment::new(
    cvdb::InMemory::new(),
    hypothesis_store::InMemory::new(),
    dmatrix_store::Local::new(),
    model_store::InMemory::new(),
    324 as usize,
    |cvdb, hyp_id, td_id, hyp| {}
  );
}

