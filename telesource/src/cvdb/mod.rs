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

  // TODO: add some methods to inspect the status of the DB, to help end-of-run
  // callbacks to make decisions about how to derive new hypotheses to test.

  /// Invokes `f` on each hypothesis ID stored in the database.
  fn each_hyp(&self, f: &mut dyn FnMut(&id) -> ());

  /// Invokes `f` on each result in the database.
  fn each_res(&self, hyp_id: id, f: &mut dyn FnMut(id, Option<(float, id)>) -> ());

  /// Retrieve the result for a particular test of a particular hypothesis.
  fn get(&self, test_date_id: id, hyp_id: id) -> Option<(float, id)>;
}

impl dyn CVDB
{
  pub fn get_hyp_score_mean(&self, hyp_id: id) -> float
  {
    let mut count = 0.0;
    let mut sum = 0.0;

    self.each_res(hyp_id, &mut |_, res| {
      if let Some((score, _)) = res
      {
        sum += score;
        count += 1.0;
      }
    });

    return count / sum;
  }

  pub fn each_row(&self, f: &mut dyn FnMut(id, id, Option<(float, id)>) -> ())
  {
    self.each_hyp(&mut |hyp_id| {
      self.each_res(*hyp_id, &mut |test_id, res| {
        f(*hyp_id, test_id, res);
      });
    });
  }

  pub fn len_default(&self) -> usize
  {
    let mut count = 0;
    self.each_row(&mut |_, _, _| count += 1);
    return count;
  }

  pub fn get_score(&self, test_date_id: id, hyp_id: id) -> Option<float>
  {
    self.get(test_date_id, hyp_id).map(|res| res.0)
  }
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

  pub fn dump_table(&self)
  {
    println!("hyp_id,test_date_id,score,model_id");

    (self as &dyn CVDB).each_row(&mut |hyp_id, test_date_id, res| {
      let mut score = float::NAN;
      let mut id = 0;

      if let Some((ref s, ref i)) = res
      {
        score = s.clone();
        id = i.clone();
      }

      println!("{},{},{},{}", hyp_id, test_date_id, score, id);
    });
  }

  pub fn len(&self) -> usize
  {
    let mut count = 0;

    for hyp_id in self.table.keys()
    {
      count += self.table[hyp_id].len();
    }

    return count;
  }

  pub fn show_best_score(&self) -> Option<(id, float)>
  {
    let mut best = None;

    (self as &dyn CVDB).each_row(&mut |hyp_id, _, res| {
      match (best, res) {
        (None, None) => (),
        (_, None) => (),
        (None, Some((score, _))) => best = Some((hyp_id, score)),
        (Some((_, b_score)), Some((t_score, _))) if t_score < b_score => best = Some((hyp_id, t_score)),
        _ => (),
      }
    });

    if let Some((b_id, b_score)) = best
    {
      println!("the best score: id={} score={}", b_id, b_score);
    }

    else
    {
      println!("there is no best score");
    }

    return best;
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
    let mut retval = None;

    (self as &dyn CVDB).each_row(&mut |hyp_id, test_date_id, res| {
      if res.is_none() { retval = Some((test_date_id, hyp_id)) };
    });

    return retval;
  }

  fn each_hyp(&self, f: &mut dyn FnMut(&id) -> ())
  {
    for key in self.table.keys()
    {
      f(key);
    }
  }

  fn each_res(&self, hyp_id: id, f: &mut dyn FnMut(id, Option<(float, id)>) -> ())
  {
    for test_id in self.table[&hyp_id].keys()
    {
      f(*test_id, self.table[&hyp_id][test_id]);
    }
  }

  fn get(&self, test_date_id: id, hyp_id: id) -> Option<(float, id)>
  {
    self.table[&hyp_id][&test_date_id]
  }
}

