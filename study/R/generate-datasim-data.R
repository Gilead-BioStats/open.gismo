# Generate one seeded gsm.datasim input set from the rendered workflow specs.
#
# Runs ONCE per study run, before RunProject(). Nothing downstream regenerates
# data — the result is passed to RunProject() as lData (see R/run-study.R).

generate_datasim_data <- function(
  study_config_path = "study.yaml",
  output_path = "data/raw/datasim-raw.rds"
) {
  study_config <- yaml::read_yaml(study_config_path)

  set.seed(study_config$datasim$seed)

  spec_workflows <- workr::MakeWorkflowList(
    strPath = study_config$datasim$spec_path,
    bRecursive = FALSE
  )

  raw_data <- gsm.datasim::generate_data_from_workflows(
    lWorkflows = spec_workflows,
    n_participants = study_config$study$participants,
    n_sites = study_config$study$sites,
    study_id = study_config$study$id,
    start_date = study_config$study$start_date,
    end_date = study_config$study$end_date,
    snapshot_count = study_config$study$snapshots,
    snapshot_width = study_config$study$snapshot_width,
    desired_domains = study_config$datasim$desired_domains,
    domain_counts = study_config$datasim$domain_counts,
    # Raw_LB's registry generator silently fails with mapping-only specs and
    # the type-based fallback emits random strings for toxgrg_nsv, so the LB
    # metrics' WHERE toxgrg_nsv IN ('0'..'4') matches nothing (GAPS.md #13).
    # Reproduce the registry generator's grade mix until that's fixed.
    column_overrides = list(
      Raw_LB = list(
        toxgrg_nsv = function(n) {
          sample(
            c("", "0", "1", "2", "3", "4"),
            n,
            replace = TRUE,
            prob = c(0.49, 0.4875, 0.01, 0.005, 0.005, 0.0025)
          )
        }
      ),
      # Registry generation for Raw_QUERY fails at small n (snapshot 1 of a
      # longitudinal ramp, n=28) and silently falls back, producing
      # querystatus values the QUERY metrics' IN filter never matches —
      # same class as the Raw_LB gap (GAPS.md #13, multi-snapshot evidence).
      # Mirror the registry generator's status mix.
      Raw_QUERY = list(
        querystatus = function(n) {
          sample(
            c("Answered", "Closed", "Open"),
            n,
            replace = TRUE,
            prob = c(0.02, 0.96, 0.02)
          )
        }
      )
    )
  )

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(raw_data, output_path)

  n_domains <- if (study_config$study$snapshots > 1) {
    length(raw_data[[1]])
  } else {
    length(raw_data)
  }
  message(sprintf(
    "Generated %d snapshot(s) x %d domain(s) with seed %s -> %s",
    study_config$study$snapshots, n_domains, study_config$datasim$seed, output_path
  ))
  invisible(raw_data)
}
