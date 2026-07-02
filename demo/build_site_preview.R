# build_site_preview.R — populate site/public/ with simulated pipeline output
# so the JS dashboard (site/) can be previewed locally without a real GitHub
# snapshot, mirroring how demo/run_demo_app.R drives the Shiny demo with
# datasim-simulated data.
#
# Writes (relative to site/public/):
#   workflows/<phase>/<id>.yaml   — copies of the source workflow YAMLs
#   output/<phase>/<id>/<artifact>.csv — each step's result, from a
#     datasim-backed RunWorkflow chain
#   manifest.csv                  — sample package manifest
#
# Then shells out to `node scripts/generate-manifest.js` (in site/) to derive
# _index.json and status.json from the files just written — the same logic
# the project's build-site.sh uses to build the deployed `demo` branch.
#
# Usage (from the open.gismo repo root):
#   Rscript demo/build_site_preview.R
# Then:
#   cd site && npm install && npm run dev

if (!requireNamespace("workr", quietly = TRUE)) {
  stop("Package 'workr' is required.")
}

devtools::load_all(".", quiet = TRUE)

workflows_src <- "docs/data/demo/workflows"
site_public <- "site/public"
workflows_dest <- file.path(site_public, "workflows")
output_dest <- file.path(site_public, "output")

if (!dir.exists(workflows_src)) {
  stop("Could not find '", workflows_src, "'. Run this script from the open.gismo repo root.")
}

lWorkflows <- workr::MakeWorkflowList(strPath = workflows_src, strPackage = NULL)
cat("Workflows found:", paste(names(lWorkflows), collapse = ", "), "\n")

lConfig <- datasim_lConfig(n_participants = 50, n_sites = 5)

unlink(workflows_dest, recursive = TRUE)
unlink(output_dest, recursive = TRUE)
dir.create(workflows_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dest, recursive = TRUE, showWarnings = FALSE)

# Map each workflow name to its phase folder (mirrors docs/data/demo/workflows/<phase>/<file>.yaml)
yaml_files <- list.files(workflows_src, pattern = "\\.ya?ml$", recursive = TRUE, full.names = TRUE)
phase_for <- function(stem) {
  hit <- yaml_files[tools::file_path_sans_ext(basename(yaml_files)) == stem]
  if (length(hit) == 0) return("0_unknown")
  basename(dirname(hit[[1]]))
}

lData <- list()
for (wf_name in names(lWorkflows)) {
  lWorkflow <- lWorkflows[[wf_name]]
  cat("\n--- Running", wf_name, "---\n")

  result <- workr::RunWorkflow(lWorkflow, lData, lConfig = lConfig, bReturnResult = FALSE)
  lData <- result$lData

  phase <- phase_for(wf_name)
  workflow_id <- lWorkflow$meta$ID %||% wf_name

  phase_dir <- file.path(workflows_dest, phase)
  dir.create(phase_dir, recursive = TRUE, showWarnings = FALSE)
  src_yaml <- yaml_files[tools::file_path_sans_ext(basename(yaml_files)) == wf_name][[1]]
  # Normalize to LF: generate-manifest.js's regexes assume Unix line endings.
  con <- file(file.path(phase_dir, basename(src_yaml)), open = "wb")
  writeLines(readLines(src_yaml), con, sep = "\n")
  close(con)

  # RunWorkflow only keeps the *last* step's result in $lResult; every step's
  # output (by name) is accumulated in $lData, so write one CSV per step.
  artifact_dir <- file.path(output_dest, phase, workflow_id)
  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
  step_outputs <- vapply(lWorkflow$steps, function(s) s$output, character(1))
  written <- character(0)
  for (output_name in step_outputs) {
    df <- result$lData[[output_name]]
    if (is.data.frame(df)) {
      write.csv(df, file.path(artifact_dir, paste0(output_name, ".csv")), row.names = FALSE)
      written <- c(written, output_name)
    }
  }
  cat("Wrote artifacts:", paste(written, collapse = ", "), "\n")
}

manifest_src <- "site/public/data/demo/manifest.csv"
if (file.exists(manifest_src)) {
  file.copy(manifest_src, file.path(site_public, "manifest.csv"), overwrite = TRUE)
}

cat("\nGenerating _index.json and status.json...\n")
old_wd <- setwd("site")
status <- tryCatch(
  system2("node", c("scripts/generate-manifest.js", "public")),
  finally = setwd(old_wd)
)
if (status != 0) {
  stop("node scripts/generate-manifest.js failed with status ", status)
}

cat("\nDone. Preview with: cd site && npm install && npm run dev\n")
