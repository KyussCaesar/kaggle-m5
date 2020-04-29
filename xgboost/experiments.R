bin/
  run-exp <expname>
  new-exp <expname>
src/
  dm-prep.R <expname> <date>
  cv-step.R <expname>
experiments/
  {exp_name}/
    features.R # defines features to use in DM
    config.R   # defines static config
    dm/
      {d}/
        x.qs
        y.qs
        b.qs

    cv/
      cvdb.qs
      params/
        {param_id}/ # id's a set of parameters
          rounds/
            {round_id}/ # id's a particular set of test dates
              runs/
                {run_id}/ # id's a particular test date within the round
                  mdl.qs
                  tst.qs
                  trn.qs

