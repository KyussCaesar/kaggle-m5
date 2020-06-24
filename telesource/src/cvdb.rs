//! Provides some pre-built CVDB store implementations.

use crate::prelude::*;

/// In-memory CVDB.
struct InMemory
{
  table: Vec<(id, id, id, id)>,
  score: Vec<Option<float>>,
  next_rowid: id,
}

impl InMemory
{
  pub fn new() -> Self
  {
    Self
    {
      table: Vec::new(),
      score: Vec::new(),
      next_rowid: 0 as usize,
    }
  }
}

impl CVDBStore for InMemory
{
  pub fn propose_hypothesis(&mut self, round_ids: &[id], run_ids: &[id], hyp_id: id) -> Vec<id>
  {
    assert!(round_ids.len() == run_ids.len());

    let mut res = Vec::with_capacity(round_ids.len());

    for i in 0..round_ids.len()
    {
      // TODO: check if a row already exists; no point running the same hypothesis for the same run
      // and round (unless you were testing that the results truly are deterministic).
      self.table.push((self.next_rowid, round_ids[i], run_ids[i], hyp_id));
      self.score.push(None);

      res.push(self.next_rowid);
      self.next_rowid += 1;
    }

    return res;
  }

  pub fn record_score(&mut self, row_id: id, score: float)
  {
    assert!(self.score[row_id].is_none());
    self.score[row_id] = score;
  }

  pub fn get_next_untested_row() -> Option<(id, id, id, id)>
  {
    for i in self.score.iter()
    {
      if self.score[i].is_none() { return Some(self.table[i].clone()); }
    }

    None
  }
}

