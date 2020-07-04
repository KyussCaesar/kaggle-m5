use crate::prelude::*;
use crate::hypothesis::Hypothesis;

/// Each row in the CVDB is a Hypothesis being tested.
/// This trait represents types that can access the backing store for Hypotheses.
pub trait HypothesisStore
{
  pub fn get(&self, hyp_id: id) -> Hypothesis;
  pub fn put(&mut self, hyp: Hypothesis) -> id;
}

/// An in-memory `HypothesisStore`.
struct InMemory
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
  pub fn get(&self, hyp_id: id) -> &Hypothesis
  {
    self.table[i]
  }

  pub fn put(&mut self, hyp: Hypothesis) -> id
  {
    self.table.push(hyp);
    return self.table.len();
  }
}

