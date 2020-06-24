//! Library for distributed data-science build.

pub mod prelude
{
  // basic type aliases; simplify for prototype
  type float = f64;
  type int = u16;
  type short = u8;
  type id = usize;
}

use crate::prelude::*;

/// Parameters to XGBoost
struct xgb_params
{
  nrounds: int,
  objective: Option<String>,   // just a string, will parse it later
  eval_metric: Option<String>, // just a string, will parse it later
  base_score: float,
  early_stopping_rounds: Option<int>,
  nthread: short,
  eta: float,
  gamma: float,
  max_depth: short,
  min_child_weight: float,
  max_delta_step: float,
  subsample: float,
  sampling_method: String,
  colsample_bytree: float,
  colsample_bylevel: float,
  colsample_bynode: float,
  lambda: float,
  alpha: float,
  tree_method: String,
  num_parallel_tree: short
}

/// Represents a single hypothesis to test.
pub struct Hypothesis
{
  /// Number of historic dates to use for training.
  n_training_dates: int,

  /// Specification of the features to use. (list of names of features to include).
  features: Vec<String>,

  /// xgboost stuff
  params: xgb_params,
}


/// Each row in the CVDB is a Hypothesis being tested.
/// This trait represents types that can access the backing store for Hypotheses.
pub trait HypothesisStore
{
  pub fn get(&self, hyp_id: id) -> &Hypothesis;
  pub fn put(&mut self, hyp: Hypothesis) -> id;
}


/// Represents types that can access the backing store for CVDB.
pub trait CVDBStore
{
  /// Adds new rows to the store.
  /// `round_ids`: the rounds to run.
  /// `run_ids`: the runs to run.
  /// `hyp_id`: the hypothesis to test.
  /// `return`: list of row IDs.
  pub fn propose_hypothesis(&mut self, round_ids: &[id], run_ids: &[id], hyp_id: id) -> Vec<id>;

  /// Record the score for that row.
  /// `panic` if the row already had a score.
  pub fn record_score(&mut self, row_id: id, score: float);

  /// Returns the next `(row_id, round_id, run_id, hyp_id)` to be run.
  pub fn get_next_untested_row(&self) -> (id, id, id, id);
}

// need to think more about how these systems would pass data back and forth
// e.g? mos.train(&params, dms.get(&features, &dates))
// e.g for DM build; it would need to load each of the features
// but to support distributed build, you wouldn't pass around the actual data,
// just some kind of spec.
// e.g how could this work for different schedulers underneath?
// could have one that pushes jobs onto Batch queue
// other way, sends to Celery queue
// generally; want to be able to spawn copies of myself with a different entrypoint.
// other generally; don't want this part to have to know that "oh this is all in-memory"
// or "oh this is running somewhere else"
// could do something with redo? if you have proper structure around stuff
//
// might help to nail out what this _does_ care about/what this _does_ do for you
// - testing arbitrary hypotheses on a set of data in a CV-like fashion
// - generates artifacts in a structured way to feed into analysis tools
// - hyperparameter search and feature selection using arbitrary methods
//
// performing ^ in a "execution-place" independent way; up to implementors to decide
// where the code gets run
// e.g for building features; might do it in-process, might do it in forked process,
// might do it in AWS, doesn't matter
// library will also expose some "pre-baked goods"; e.g "store CVDB in local SQLite"
// already knows how to fork itself into ECS task on AWS, already knows how to use
// redis for hypothesis store.

pub trait Feature
{
  type data;

  /// Load this feature into memory.
  pub fn load(&self) -> data;
}

/// Represents types that can access the backing store for Features.
pub trait FeaturesStore
{
  /// The type of features; e.g "stored on S3" or "stored in DB" or...
  type F: Feature;

  /// Retrieve the named feature from the store.
  /// Commissions that feature to be built if it doesn't already exist.
  /// `panic` if the feature cannot be built.
  pub fn get(&self, feature: &str) -> Feature; // should probably just return Result; will think more about it later
}

// might make sense to abstract this out into a general purpose "abstract pointer
// to a thing stored externally"
pub trait DesignMatrix
{
  type data;

  /// Load this DesignMatrix into memory.
  pub fn load(&self) -> data;
}

/// Represents types that can access the backing store for Design Matrices.
/// Types which can map feature F onto design matrix DM
pub trait DesignMatrixStore
{
  /// The type of design matrix; e.g "stored on S3" or "stored in DB" or ...
  type DM: DesignMatrix;

  /// Returns the train and test sets for a design matrix constructed with the
  /// specified features, training dates, and test date.
  pub fn get(&self, features: &[str], trn_dates: &[int], tst_date: int) -> (DM, DM);
}


/// Represents types that can access the backing store for Model Objects.
pub trait ModelObjectStore
{
  type DM: DesignMatrix;
  type MO: ModelObject;
  pub fn train(&mut self, params: &xgb_params, trn: &DM, tst: &DM) -> (id, float);
  pub fn make_submission(&self, model_id: id, d_vald: &DM, d_eval: &DM) -> ();
}


fn mk_dates(n_dates: int, base_seed: id, round_id: id, run_id: id) -> (Vec<int>, int)
{
  // translated from this R code
  // old_seed = .Random.seed
  // set.seed(base_seed + round_id)
  // set.seed(floor(runif(1, min = 0, max = .Machine$integer.max - 1048576)) + run_id)
  // dm_dates = sort(sample(1:1855, n_dates, prob = 1:1855))
  // dm_dates[len(dm_dates) + 1] = dm_dates[len(dm_dates)] + 28
  // .Random.seed = old_seed
  // # tst_date = last_training_date + forecast horizon
  // 
  // trn_dates = dm_dates[-len(dm_dates)]
  // tst_date  = dm_dates[ len(dm_dates)]

  assert!(n_dates >  0);
  assert!(n_dates <= 1855);

  let possible_dates = 1..=1855;

  // weighted list of dates
  // bias toward later dates cause:
  // - makes training sets more similar to the "real deal" (continuous history)
  // - don't care so much if the model is rubbish at predicting old data c.f. newer
  // note: may have to undo this cause for large n_dates it means
  let mut items =
    possible_dates
    .iter()
    .map(|x| Weighted { weight: x, item: x})
    .collect();

  let wc = WeightedChoice::new(&mut items);

  // TODO: this needs to be replaced with a seed derived from the params to this
  // function
  let mut rng = rand::thread_rng();

  // rand crate doesn't implement sampling _without_ replacement >:(
  // so we just push values into a hashset until it reaches the required size.
  let dates: Vec<int> = {
    let mut ds = HashSet::with_capacity(n_dates as usize);
    while ds.len() != n_dates
    {
      ds.insert(wc.sample(&mut rng));
    }
    ds.into_iter().collect().sort_unstable();
  }

  (dates, dates[n_dates - 1] + 28)
}

pub fn run_experiment
<
  HS: HypothesisStore,
  CVDBS: CVDBStore,
  F: Feature,
  DM: DesignMatrix,
  FS: FeaturesStore<F=F>,
  DMS: DesignMatrixStore<F=F, DM=DM>,
  MOS: ModelObjectStore<DM=DM>,
>
(
  training_dates_base_seed: id,
  hs: HS,
  cs: CVDBS,
  fs: FS,
  ds: DMS,
  ms: MOS,
)
{
  // load the next un-tested hypothesis from the CVDB
  while let Some((row_id, round_id, run_id, hyp_id)) = cs.get_next_untested_row()
  {
    // generate selection of training dates
    let (trn_dates, tst_date) = mk_dates(training_date_base_seed, round_id, run_id);

    // Retrieve hypothesis details from the hypothesis store.
    let hyp = hs.get(hyp_id);

    // load trn/tst
    let (trn, tst) = ds.get(&hyp.features, &trn_dates, &tst_date);

    // train the model
    let (model_id, score) = ms.train(&hyp.params, &trn, &tst);

    // record score in CVDB
    cs.record_score(row_id, model_id, score);

    // invoke end-of-run callback
    // end_of_run();
  }
}

