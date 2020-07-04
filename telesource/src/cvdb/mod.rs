//! Provides some pre-built CVDB store implementations.

use crate::prelude::*;

/// Represents types that can access the backing store for CVDB.
pub trait CVDBStore
{
  /// Adds new rows to the store.
  ///
  /// - `test_date_ids`: the runs to run.
  /// - `hyp_id`: the ID of the hypothesis to test.
  pub fn propose_hypothesis_test(&mut self, test_date_id: id, hyp_id: id);

  /// Record the score for a particular Hypothesis on a particular run.
  ///
  /// - `test_date_id`: ID of the date we are testing.
  /// - `hyp_id`: the ID of the hypothesis we are testing.
  /// - `score`: the score that that Hypothesis got when tested against that date.
  pub fn record_score(&mut self, test_date_id: id, hyp_id: id, score: float, model_id: id);

  /// Returns the next `(run_id, hyp_id)` to be run.
  pub fn get_next_untested_row(&self) -> (id, id);
}

/// In-memory CVDB.
struct InMemory
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

impl CVDBStore for InMemory
{
  pub fn propose_hypothesis_test(&mut self, test_date_id: id, hyp_id: id)
  {
    let mut hyp_entries = self.table.entry(hyp_id).or_insert(HashMap::new());
    hyp_entries[test_date_id] = None;
  }

  pub fn record_score(&mut self, test_date_id: id, hyp_id: id, score: float, model_id: id)
  {
    self.table[hyp_id][test_date_id] = Some((score, model_id))
  }

  pub fn get_next_untested_row() -> Option<(id, id)>
  {
    for hyp_id in self.table.keys()
    {
      for test_date_id in self.table[hyp_id].keys()
      {
        if self.table[hyp_id][test_date_id].is_none()
        {
          return Some((test_date_id, hyp_id))
        }
      }
    }

    None
  }
}

