# fetch_run_results.R — pull a real study run's outputs from GitHub Actions
# into site/public/ so the JS dashboard renders actual CI results instead of
# locally simulated ones.
#
# Source of truth: this repo's own `Run Study` workflow
# (.github/workflows/run-study.yaml), which installs the pinned environment
# from study/manifest.csv, runs the vendored public-only workflow bundle via
# workr with datasim-generated input, and uploads a `study-output` artifact
# containing workr-results.rds.
#
# This script:
#   1. Downloads the `study-output` artifact (latest successful run, or a
#      specific run id passed as the first argument) via the `gh` CLI.
#   2. Converts workr-results.rds into per-workflow CSVs under
#      site/public/output/{phase}/{workflow_id}/{artifact}.csv.
#   3. Copies the vendored workflow YAML bundle from study/workflows/ into
#      site/public/workflows/.
#   4. Copies study/manifest.csv (pinned package environment).
#   5. Regenerates _index.json and status.json via site/scripts/generate-manifest.js.
#
# Usage (from the open.gismo repo root):
#   Rscript demo/fetch_run_results.R              # latest successful run
#   Rscript demo/fetch_run_results.R 12345678901  # specific run id
# Then: cd site && npm run dev

`%||%` <- function(x, y) if (is.null(x)) y else x

# Override with e.g. GISMO_STUDY_REPO=zdz2101/open.gismo to pull from a fork.
study_repo <- Sys.getenv("GISMO_STUDY_REPO", "Gilead-BioStats/open.gismo")
study_dir <- "study"
site_public <- "site/public"

args <- commandArgs(trailingOnly = TRUE)
run_id <- if (length(args) >= 1) args[[1]] else NULL

if (!dir.exists(site_public)) {
  stop("Could not find '", site_public, "'. Run this script from the open.gismo repo root.")
}

# -- 1. Resolve the output directory (local run or CI artifact) --------------
provenance <- list(source = "github-actions")
if (!is.null(run_id) && dir.exists(run_id)) {
  # A directory argument (e.g. study/data/output from a local
  # `Rscript scripts/03-run-workflows.R`) is ingested directly — no download.
  artifact_dir <- run_id
  provenance <- list(source = "local-run", label = artifact_dir)
  cat("Using local output directory:", artifact_dir, "\n")
} else {
  if (is.null(run_id)) {
    # shQuote: system2 doesn't quote args on unix, so the space in the
    # workflow name would otherwise split into a bogus extra argument.
    run_id <- system2(
      "gh",
      c("run", "list", "-R", study_repo, "-w", shQuote("Run Study"),
        "-s", "success", "-L", "1", "--json", "databaseId", "-q", shQuote(".[0].databaseId")),
      stdout = TRUE
    )
    if (length(run_id) == 0 || !nzchar(run_id)) {
      stop("No successful 'Run Study' run found in ", study_repo)
    }
  }
  cat("Using run:", run_id, "\n")

  artifact_dir <- file.path(tempdir(), paste0("study-output-", run_id))
  unlink(artifact_dir, recursive = TRUE)
  dir.create(artifact_dir, recursive = TRUE)
  status <- system2("gh", c(
    "run", "download", run_id, "-R", study_repo,
    "-n", "study-output", "-D", artifact_dir
  ))
  if (status != 0) {
    stop("gh run download failed (is the artifact still within its retention window?)")
  }
  triggered_by <- tryCatch(
    system2(
      "gh",
      c("api", sprintf("repos/%s/actions/runs/%s", study_repo, run_id),
        "-q", ".triggering_actor.login"),
      stdout = TRUE
    ),
    error = function(e) NULL
  )
  provenance <- list(
    source = "github-actions",
    label = paste0(study_repo, " run #", run_id),
    run_id = run_id,
    run_url = sprintf("https://github.com/%s/actions/runs/%s", study_repo, run_id),
    triggered_by = if (length(triggered_by) == 1 && nzchar(triggered_by)) triggered_by else NULL
  )
}

rds_path <- file.path(artifact_dir, "workr-results.rds")
if (!file.exists(rds_path)) {
  stop("workr-results.rds not found in the study-output artifact")
}

# -- 2. Convert results to per-workflow CSVs --------------------------------
results <- readRDS(rds_path)
snapshot <- results[[1]] # single-snapshot demo: one entry named "single"

output_dest <- file.path(site_public, "output")
unlink(output_dest, recursive = TRUE)
dir.create(output_dest, recursive = TRUE, showWarnings = FALSE)

n_csv <- 0L
for (phase in names(snapshot$result)) {
  phase_results <- snapshot$result[[phase]]$results
  for (wf_key in names(phase_results)) {
    entry <- phase_results[[wf_key]]
    # Result keys look like Mapped_AE / Analysis_cou0001 / Reporting_Groups;
    # the id after the Type_ prefix matches the workflow YAML stem.
    wf_id <- sub("^[^_]+_", "", wf_key)
    wf_dir <- file.path(output_dest, phase, wf_id)

    artifacts <- if (is.data.frame(entry)) {
      stats::setNames(list(entry), wf_key)
    } else if (is.list(entry)) {
      entry[vapply(entry, is.data.frame, logical(1))]
    } else {
      list()
    }

    if (length(artifacts) == 0) next
    dir.create(wf_dir, recursive = TRUE, showWarnings = FALSE)
    for (artifact_name in names(artifacts)) {
      write.csv(
        artifacts[[artifact_name]],
        file.path(wf_dir, paste0(artifact_name, ".csv")),
        row.names = FALSE
      )
      n_csv <- n_csv + 1L
    }
  }
}
cat("Wrote", n_csv, "artifact CSVs to", output_dest, "\n")

# -- 3. Copy the vendored workflow YAML bundle -------------------------------
# The bundle in study/workflows/ already excludes private-dep workflows;
# additionally skip workflows the run itself excluded (recorded by the
# Action in excluded-workflows.yaml, e.g. domains the datasim provider
# doesn't generate) so they don't render as permanently not-run cards.
excluded_files <- character(0)
excluded_path <- file.path(artifact_dir, "excluded-workflows.yaml")
if (file.exists(excluded_path) && requireNamespace("yaml", quietly = TRUE)) {
  excluded_files <- names(yaml::read_yaml(excluded_path))
}

workflows_dest <- file.path(site_public, "workflows")
unlink(workflows_dest, recursive = TRUE)
dir.create(workflows_dest, recursive = TRUE, showWarnings = FALSE)

workflows_src <- file.path(study_dir, "workflows")
if (dir.exists(workflows_src)) {
  yaml_list <- list.files(workflows_src, pattern = "\\.ya?ml$", recursive = TRUE)
  n_extracted <- 0L
  n_skipped <- 0L
  for (rel in yaml_list) {
    if (basename(rel) %in% excluded_files) {
      n_skipped <- n_skipped + 1L
      next
    }
    dest <- file.path(workflows_dest, rel)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    # Normalize to LF: generate-manifest.js's regexes assume Unix line endings.
    con <- file(dest, open = "wb")
    writeLines(readLines(file.path(workflows_src, rel), warn = FALSE), con, sep = "\n")
    close(con)
    n_extracted <- n_extracted + 1L
  }
  cat(
    "Copied", n_extracted, "workflow YAMLs from", workflows_src,
    "(skipped", n_skipped, "run-excluded workflows)\n"
  )

  manifest <- file.path(study_dir, "manifest.csv")
  if (file.exists(manifest)) {
    file.copy(manifest, file.path(site_public, "manifest.csv"), overwrite = TRUE)
  }
} else {
  warning("Vendored bundle '", workflows_src, "' not found; skipping workflow YAML copy.")
}

# -- 4. Write data provenance for the dashboard header ----------------------
meta_path <- file.path(artifact_dir, "run-metadata.yaml")
if (file.exists(meta_path) && requireNamespace("yaml", quietly = TRUE)) {
  meta <- yaml::read_yaml(meta_path)
  provenance$run_time_utc <- meta$run_time_utc
  provenance$study_id <- meta$study_config$study$id
}
writeLines(
  jsonlite::toJSON(provenance, auto_unbox = TRUE, pretty = TRUE),
  file.path(site_public, "provenance.json")
)
cat("Wrote provenance.json:", provenance$label %||% provenance$source, "\n")

# -- 5. Regenerate _index.json and status.json ------------------------------
cat("Generating _index.json and status.json...\n")
old_wd <- setwd("site")
status <- tryCatch(
  system2("node", c("scripts/generate-manifest.js", "public")),
  finally = setwd(old_wd)
)
if (status != 0) {
  stop("node scripts/generate-manifest.js failed with status ", status)
}

cat("\nDone. Preview with: cd site && npm run dev\n")
