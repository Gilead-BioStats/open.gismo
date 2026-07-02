# Run the workflow project and save results + run metadata.
# On failure, still write failure context + metadata so the CI artifact
# answers "what went wrong?" (artifacts are diagnostic breadcrumbs).
source("R/run-study.R")
source("R/save-study-results.R")

results <- tryCatch(
  run_study(),
  error = function(e) {
    dir.create("data/output", recursive = TRUE, showWarnings = FALSE)
    yaml::write_yaml(
      list(
        error = conditionMessage(e),
        traceback = vapply(sys.calls(), function(x) deparse1(x), character(1))
      ),
      "data/output/failure-context.yaml"
    )
    save_study_results(NULL)
    stop(e)
  }
)
save_study_results(results)
