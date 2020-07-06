use crate::prelude::*;
use crate::hypothesis::Hypothesis;

/// Each row in the CVDB is a Hypothesis being tested.
/// This trait represents types that can access the backing store for Hypotheses.
pub trait HypothesisStore
{
  fn get(&self, hyp_id: id) -> Hypothesis;
  fn put(&mut self, hyp: Hypothesis) -> id;
}

/// An in-memory `HypothesisStore`.
pub struct InMemory
{
  table: Vec<Hypothesis>
}

impl InMemory
{
  pub fn new() -> Self
  {
    Self
    {
      table: Vec::new(),
    }
  }
}

impl HypothesisStore for InMemory
{
  fn get(&self, hyp_id: id) -> Hypothesis
  {
    self.table[hyp_id].clone()
  }

  fn put(&mut self, hyp: Hypothesis) -> id
  {
    let id = self.table.len();
    self.table.push(hyp);
    return id;
  }
}

