//! Provides some pre-built Hypothesis store implementations.

use crate::prelude::*;
use crate::Hypothesis;

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

