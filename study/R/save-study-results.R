# Persist run results plus the metadata needed to reproduce and audit the run.

save_study_results <- function(results, output_dir = "data/output") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(results, file.path(output_dir, "workr-results.rds"))

  lock <- if (file.exists("library-snapshot-lock.yaml")) {
    yaml::read_yaml("library-snapshot-lock.yaml")
  }

  run_metadata <- list(
    study_config = yaml::read_yaml("study.yaml"),
    library_lock = lock,
    session_info = utils::capture.output(utils::sessionInfo()),
    run_time_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  yaml::write_yaml(run_metadata, file.path(output_dir, "run-metadata.yaml"))

  message(sprintf("Saved results + run-metadata.yaml to %s", output_dir))
  invisible(results)
}
