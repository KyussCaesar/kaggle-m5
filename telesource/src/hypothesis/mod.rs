use crate::prelude::*;

/*[[[cog
import cog
cog.out("\n")

FIELDS = [
  ('n_training_dates'          , 'int', '1'),
  ('features'                  , 'Vec<String>', 'Vec::new()'),
  ('split'                     , 'Vec<(String, int)>', 'Vec::new()'),
  ('xgb_nrounds'               , 'int', '1'),
  ('xgb_objective'             , 'Option<String>', 'None'),
  ('xgb_eval_metric'           , 'Option<String>', 'None'),
  ('xgb_base_score'            , 'float', '0.0'),
  ('xgb_early_stopping_rounds' , 'Option<int>', 'None'),
  ('xgb_nthread'               , 'short', '1'),
  ('xgb_eta'                   , 'float', '0.3'),
  ('xgb_gamma'                 , 'float', '0.0'),
  ('xgb_max_depth'             , 'short', '6'),
  ('xgb_min_child_weight'      , 'float', '1.0'),
  ('xgb_max_delta_step'        , 'float', '0.0'),
  ('xgb_subsample'             , 'float', '1.0'),
  ('xgb_sampling_method'       , 'String', '"uniform".to_string()'),
  ('xgb_colsample_bytree'      , 'float', '1.0'),
  ('xgb_colsample_bylevel'     , 'float', '1.0'),
  ('xgb_colsample_bynode'      , 'float', '1.0'),
  ('xgb_lambda'                , 'float', '0.0'),
  ('xgb_alpha'                 , 'float', '0.0'),
  ('xgb_tree_method'           , 'String', '"auto".to_string()'),
  ('xgb_num_parallel_tree'     , 'short', '1')
]

# generate Hypothesis struct definition
cog.outl("#[derive(Clone, Debug)]")
cog.outl("pub struct Hypothesis")
cog.outl("{")
for (k, v, _) in FIELDS:
  cog.outl("  %s: %s," % (k, v))
cog.outl("}\n")

# generate HypothesisPub struct definition
cog.outl("#[derive(Clone, Debug)]")
cog.outl("pub struct HypothesisPub")
cog.outl("{")
for (k, v, _) in FIELDS:
  cog.outl("  pub %s: %s," % (k, v))
cog.outl("}\n")

# impl From<Hypothesis> for HypothesisPub
cog.outl("fn into_pub(h: Hypothesis) -> HypothesisPub")
cog.outl("{")
cog.outl("  HypothesisPub")
cog.outl("  {")
for (k, _, _) in FIELDS:
  cog.outl("    %s: h.%s," % (k, k))
cog.outl("  }")
cog.outl("}\n")

# impl From<HypothesisPub> for Hypothesis
cog.outl("fn from_pub(h: HypothesisPub) -> Hypothesis")
cog.outl("{")
cog.outl("  Hypothesis")
cog.outl("  {")
for (k, _, _) in FIELDS:
  cog.outl("    %s: h.%s," % (k, k))
cog.outl("  }")
cog.outl("}\n")

# impl Default for Hypothesis
cog.outl("impl Default for Hypothesis")
cog.outl("{")
cog.outl("  fn default() -> Self")
cog.outl("  {")
cog.outl("    let this =")
cog.outl("    Self")
cog.outl("    {")
for (k, _, v) in FIELDS:
  cog.outl("      %s: %s," % (k, v))
cog.outl("    };")
cog.outl("    this.validate();")
cog.outl("    return this;")
cog.outl("  }")
cog.outl("}\n")

]]]*/

#[derive(Clone, Debug)]
pub struct Hypothesis
{
  n_training_dates: int,
  features: Vec<String>,
  split: Vec<(String, int)>,
  xgb_nrounds: int,
  xgb_objective: Option<String>,
  xgb_eval_metric: Option<String>,
  xgb_base_score: float,
  xgb_early_stopping_rounds: Option<int>,
  xgb_nthread: short,
  xgb_eta: float,
  xgb_gamma: float,
  xgb_max_depth: short,
  xgb_min_child_weight: float,
  xgb_max_delta_step: float,
  xgb_subsample: float,
  xgb_sampling_method: String,
  xgb_colsample_bytree: float,
  xgb_colsample_bylevel: float,
  xgb_colsample_bynode: float,
  xgb_lambda: float,
  xgb_alpha: float,
  xgb_tree_method: String,
  xgb_num_parallel_tree: short,
}

#[derive(Clone, Debug)]
pub struct HypothesisPub
{
  pub n_training_dates: int,
  pub features: Vec<String>,
  pub split: Vec<(String, int)>,
  pub xgb_nrounds: int,
  pub xgb_objective: Option<String>,
  pub xgb_eval_metric: Option<String>,
  pub xgb_base_score: float,
  pub xgb_early_stopping_rounds: Option<int>,
  pub xgb_nthread: short,
  pub xgb_eta: float,
  pub xgb_gamma: float,
  pub xgb_max_depth: short,
  pub xgb_min_child_weight: float,
  pub xgb_max_delta_step: float,
  pub xgb_subsample: float,
  pub xgb_sampling_method: String,
  pub xgb_colsample_bytree: float,
  pub xgb_colsample_bylevel: float,
  pub xgb_colsample_bynode: float,
  pub xgb_lambda: float,
  pub xgb_alpha: float,
  pub xgb_tree_method: String,
  pub xgb_num_parallel_tree: short,
}

fn into_pub(h: Hypothesis) -> HypothesisPub
{
  HypothesisPub
  {
    n_training_dates: h.n_training_dates,
    features: h.features,
    split: h.split,
    xgb_nrounds: h.xgb_nrounds,
    xgb_objective: h.xgb_objective,
    xgb_eval_metric: h.xgb_eval_metric,
    xgb_base_score: h.xgb_base_score,
    xgb_early_stopping_rounds: h.xgb_early_stopping_rounds,
    xgb_nthread: h.xgb_nthread,
    xgb_eta: h.xgb_eta,
    xgb_gamma: h.xgb_gamma,
    xgb_max_depth: h.xgb_max_depth,
    xgb_min_child_weight: h.xgb_min_child_weight,
    xgb_max_delta_step: h.xgb_max_delta_step,
    xgb_subsample: h.xgb_subsample,
    xgb_sampling_method: h.xgb_sampling_method,
    xgb_colsample_bytree: h.xgb_colsample_bytree,
    xgb_colsample_bylevel: h.xgb_colsample_bylevel,
    xgb_colsample_bynode: h.xgb_colsample_bynode,
    xgb_lambda: h.xgb_lambda,
    xgb_alpha: h.xgb_alpha,
    xgb_tree_method: h.xgb_tree_method,
    xgb_num_parallel_tree: h.xgb_num_parallel_tree,
  }
}

fn from_pub(h: HypothesisPub) -> Hypothesis
{
  Hypothesis
  {
    n_training_dates: h.n_training_dates,
    features: h.features,
    split: h.split,
    xgb_nrounds: h.xgb_nrounds,
    xgb_objective: h.xgb_objective,
    xgb_eval_metric: h.xgb_eval_metric,
    xgb_base_score: h.xgb_base_score,
    xgb_early_stopping_rounds: h.xgb_early_stopping_rounds,
    xgb_nthread: h.xgb_nthread,
    xgb_eta: h.xgb_eta,
    xgb_gamma: h.xgb_gamma,
    xgb_max_depth: h.xgb_max_depth,
    xgb_min_child_weight: h.xgb_min_child_weight,
    xgb_max_delta_step: h.xgb_max_delta_step,
    xgb_subsample: h.xgb_subsample,
    xgb_sampling_method: h.xgb_sampling_method,
    xgb_colsample_bytree: h.xgb_colsample_bytree,
    xgb_colsample_bylevel: h.xgb_colsample_bylevel,
    xgb_colsample_bynode: h.xgb_colsample_bynode,
    xgb_lambda: h.xgb_lambda,
    xgb_alpha: h.xgb_alpha,
    xgb_tree_method: h.xgb_tree_method,
    xgb_num_parallel_tree: h.xgb_num_parallel_tree,
  }
}

impl Default for Hypothesis
{
  fn default() -> Self
  {
    let this =
    Self
    {
      n_training_dates: 1,
      features: Vec::new(),
      split: Vec::new(),
      xgb_nrounds: 1,
      xgb_objective: None,
      xgb_eval_metric: None,
      xgb_base_score: 0.0,
      xgb_early_stopping_rounds: None,
      xgb_nthread: 1,
      xgb_eta: 0.3,
      xgb_gamma: 0.0,
      xgb_max_depth: 6,
      xgb_min_child_weight: 1.0,
      xgb_max_delta_step: 0.0,
      xgb_subsample: 1.0,
      xgb_sampling_method: "uniform".to_string(),
      xgb_colsample_bytree: 1.0,
      xgb_colsample_bylevel: 1.0,
      xgb_colsample_bynode: 1.0,
      xgb_lambda: 0.0,
      xgb_alpha: 0.0,
      xgb_tree_method: "auto".to_string(),
      xgb_num_parallel_tree: 1,
    };
    this.validate();
    return this;
  }
}

//[[[end]]]

impl Hypothesis 
{
  /// Create a new `Hypothesis`.
  pub fn new() -> Self
  {
    Self::default()
  }

  /// Derive a new `Hypothesis` from this one.
  /// # Example:
  /// ```
  /// let hyp = Hypothesis::new();
  /// let new_hyp = hyp.derive_new(|h| {
  ///   h.num_parallel_tree = 4;
  ///   h.gamma = 0.1;
  /// })
  /// ```
  pub fn derive_new<F: FnMut(&mut HypothesisPub)>(&self, f: F) -> Self
  {
    // clone and make editable
    let cln = into_pub(self.clone());

    // pass the editable version to the function to edit.
    f(&mut cln);

    // convert back into Hypothesis and return.
    from_pub(cln)
  }
}

