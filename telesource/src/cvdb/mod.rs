//! Provides some pre-built CVDB store implementations.

use std::collections::HashMap;

use crate::prelude::*;

/// Represents types that can access the backing store for CVDB.
pub trait CVDB
{
  /// Adds new rows to the store.
  ///
  /// - `test_date_ids`: the runs to run.
  /// - `hyp_id`: the ID of the hypothesis to test.
  fn propose_hypothesis_test(&mut self, test_date_id: id, hyp_id: id);

  /// Record the score for a particular Hypothesis on a particular run.
  ///
  /// - `test_date_id`: ID of the date we are testing.
  /// - `hyp_id`: the ID of the hypothesis we are testing.
  /// - `score`: the score that that Hypothesis got when tested against that date.
  fn record_score(&mut self, test_date_id: id, hyp_id: id, score: float, model_id: id);

  /// Returns the next `(run_id, hyp_id)` to be run.
  fn get_next_untested_row(&self) -> Option<(id, id)>;
}

/// In-memory CVDB.
pub struct InMemory
{
  table: HashMap<id, HashMap<id, Option<(float, id)>>>
}

impl InMemory
{
  pub fn new() -> Self
  {
    Self
    {
      table: HashMap::new(),
    }
  }
}

impl CVDB for InMemory
{
  fn propose_hypothesis_test(&mut self, test_date_id: id, hyp_id: id)
  {
    self.table.entry(hyp_id).or_insert(HashMap::new()).entry(test_date_id).or_insert(None);
  }

  fn record_score(&mut self, test_date_id: id, hyp_id: id, score: float, model_id: id)
  {
    let hyp = self.table.get_mut(&hyp_id).unwrap();
    let item = hyp.get_mut(&test_date_id).unwrap();
    *item = Some((score, model_id));
  }

  fn get_next_untested_row(&self) -> Option<(id, id)>
  {
    for hyp_id in self.table.keys()
    {
      for test_date_id in self.table[hyp_id].keys()
      {
        if self.table[hyp_id][test_date_id].is_none()
        {
          return Some((*test_date_id, *hyp_id))
        }
      }
    }

    None
  }
}

