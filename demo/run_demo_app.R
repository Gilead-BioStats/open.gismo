# run_demo_app.R — launch the workr demo Shiny app over open.gismo's demo workflows
#
# Loads every workflow YAML under docs/data/demo/workflows/ and runs them
# through workr::DemoApp_init(), backed by datasim_lConfig() so missing data
# domains are simulated on the fly (no GitHub snapshot required). Each
# workflow's YAML appears as a clickable card in the app; "Run Step" /
# "Run All" execute it against simulated or chained data.
#
# Usage:
#   Rscript demo/run_demo_app.R
# or, from an R session with the working directory at the repo root:
#   source("demo/run_demo_app.R")

if (!requireNamespace("workr", quietly = TRUE)) {
  stop("Package 'workr' is required. Install it with devtools::install_local('../workr') or remotes::install_github('Gilead-BioStats/workr').")
}
if (!requireNamespace("gsm.datasim", quietly = TRUE)) {
  stop("Package 'gsm.datasim' is required. Install it with devtools::install_local('../gsm.datasim').")
}

devtools::load_all(".", quiet = TRUE)

workflows_path <- "docs/data/demo/workflows"
if (!dir.exists(workflows_path)) {
  stop(
    "Could not find '", workflows_path, "'. Run this script with the ",
    "open.gismo repo root as the working directory."
  )
}

lWorkflows <- workr::MakeWorkflowList(strPath = workflows_path, strPackage = NULL)

lConfig <- datasim_lConfig(
  n_participants = 50,
  n_sites = 5,
  study_id = "DEMO-001",
  start_date = "2023-01-01",
  end_date = "2023-12-31"
)

workr::DemoApp_init(
  lWorkflows = lWorkflows,
  lData = list(),
  lConfig = lConfig
)
