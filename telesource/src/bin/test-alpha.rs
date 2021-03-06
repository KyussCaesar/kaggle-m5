//! testing playground

use log::info;

use env_logger;

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

/// example end-of-run callback.
///
/// In this example, we just keep incrementing max_depth until the score stops
/// getting better.
fn end_of_run(
  cvdb: &mut dyn CVDB,
  hs: &mut dyn HypothesisStore,
  run_id: id,
  hyp_id: id,
  hyp: &Hypothesis
)
{
  info!("end of run {} for hyp {}", run_id, hyp_id);

  if hyp_id != 0
  {
    // get the scores of the current hypothesis and the last hypothesis.
    let prev_score = cvdb.get(run_id, hyp_id - 1);

    // telesource doesn't guarantee the ordering of testing; so if the "previous"
    // score hasn't been recorded yet, we can't make progress.
    if prev_score.is_none() { return; }

    let (prev_score, _) = prev_score.unwrap();
    let (this_score, _) = cvdb.get(run_id, hyp_id).unwrap();

    // nb^; the ".unwrap()" just means "crash the program if the value is not available".
    // obviously in a real system, you'd want to handle this more gracefully!

    // compare the score for this run against the previous
    if this_score < prev_score
    {
      info!("Found a better score! {} -> {}", prev_score, this_score);

      // this one did better than the last one!
      // derive a new hypothesis based on that fact.
      //
      // in this example we just try increasing max_depth; but you could always
      // do something smarter e.g update a bayesian optimiser and get params
      // from there...
      let new_h = hyp.derive_new(|h| {
        h.xgb_max_depth += 1;

        info!("Proposing a new hypothesis: max_depth={}", h.xgb_max_depth);
      });

      // put the new hypothesis into the hypothesis store and record the ID
      let new_h_id = hs.put(new_h);

      // tell the system that we want to test this new hypothesis
      cvdb.propose_hypothesis_test(run_id, new_h_id);

      // NOTE: for simplicity, I just add it once, but in practise you'd want to
      // add the new hypothesis for several run_ids and average the results (i.e
      // cross-validation).
    }
  }

  // nb; if hyp_id == 0, it means it's the first run, so we can't compare against
  // the "previous" one.
}

fn main()
{
  env_logger::init();

  info!("begin experiment test-alpha");

  // create a new "CVDB"
  // I guess the name is short for "cross-validation database", but don't read
  // too much into it; I haven't spent much time thinking about the name.
  //
  // this just keeps track of the experiment state, mainly
  // - which hypotheses have we tested? 
  // - what score did they get?
  //
  // in this example I use a simple in-memory store, but in practise this could
  // be anything; SQLite DB file, some larger DB like Postgres/MySQL, etc.
  let mut cvdb = cvdb::InMemory::new();

  // create a new HypothesisStore; storage for Hypotheses that you want to test.
  //
  // in this example we just use the provided "InMemory" store, which just holds
  // hypotheses in-memory, but the system will work with any type that implements
  // the HypothesisStore trait; e.g you could store in a DB, or Redis, or whatever
  let mut hs = hypothesis_store::InMemory::new();

  // create our starting hypotheses.
  //
  // in this example we're simply increasing the the max_depth until the score gets worse.
  // we'll start with max_depth=2 and go from there:
  let hyp_default = Hypothesis::default();

  // `derive_new` is a method on Hypothesis, allows you to make a copy and change
  // the copy.
  //
  // in this example hyp1 is the same as the default, but with max_depth = 2.
  let hyp1 = hyp_default.derive_new(|h| {
    h.xgb_max_depth = 2;
  });

  let hyp2 = hyp1.derive_new(|h| {
    h.xgb_max_depth += 1;
  });

  // put the hypotheses in the store and record the IDs.
  let hyp_id_1 = hs.put(hyp1);
  let hyp_id_2 = hs.put(hyp2);

  // initialise the CVDB; first parameter is the "test id", second is the "hypothesis id"
  //
  // the "test id" represents a particular "testing condition"; e.g for time-series
  // forecasting, a particular test id should represent the same set of target dates.
  //
  // the idea is to let you test two different hypotheses on the same data,
  // "compare like for like".
  //
  // we have two hypotheses to start with, so we put them both into the store
  cvdb.propose_hypothesis_test(0, hyp_id_1);
  cvdb.propose_hypothesis_test(0, hyp_id_2);

  // create DMatrixStore
  // since we use XGBoost at the end, you need a way to generate DMatrix objects
  // to actually give to XGBoost.
  //
  // we also don't want to have to carry all of the xgboost::DMatrix objects around
  // in-memory, because they can be very large, and you might want to store them
  // somewhere else.
  //
  // types implementing the DMatrixStore trait are responsible for building DMatrix
  // objects, storing them somewhere, and returning a "DMatrix pointer" type, which
  // can be used to load the DMatrix into memory only when it's actually needed.
  //
  // in this example, we just always return the example data from the XGBoost
  // library, but in practise you could want e.g a type that stores the DMatrix on-disk
  // in some format, and returns the name of the file that the objects are stored in.
  let mut ds = dmatrix_store::agaricus;

  // create ModelStore
  //
  // this object is responsible for actually training the model objects, according
  // to the hypothesis that we want to test.
  //
  // in this example, we just train the models in-memory, but you could want e.g
  // to send the DMatrix pointer and XGBoost parameters to another machine to
  // perform the training.
  let mut ms = model_store::InMemory::new();

  // provide our objects to telesource and tell it to run the experiment.
  // it will keep running until there are no more un-tested hypotheses in the CVDB
  telesource::run_experiment(
    &mut cvdb,       // db to store experiment state
    &mut hs,         // db to store hypotheses in
    &mut ds,         // object which knows how to build DMatrix from your Hypothesis
    &mut ms,         // object which knows how to train models based on your Hypothesis
    905678 as usize, // seed for RNG; this is to allow repeatable tests/test id
    end_of_run,      // callback invoked at the end of each run
  );

  // in-memory implementation of CVDB has handy method to print the table as CSV
  cvdb.dump_table();

  // ... also has method to show best hypothesis based on mean score across all tests.
  if let Some((b_hyp_id, _)) = cvdb.show_best_score()
  {
    println!("best hypothesis follows:");
    dbg!(hs.get(b_hyp_id));
  }
}

