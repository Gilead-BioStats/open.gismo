# datasim_lConfig.R — Factory function for datasim-backed lConfig
#
# Creates an lConfig object compatible with workr::RunWorkflow that uses
# gsm.datasim's spec-driven simulator as the storage backend, via
# datasim_LoadData and datasim_SaveData hooks. Useful for demos/dry-runs
# where no real GitHub-backed snapshot is available: missing domains are
# generated on the fly from each workflow's `spec`, and outputs are kept
# in an in-memory store so downstream workflows in the same demo session
# (e.g. a mapping workflow feeding a metrics workflow) can find them.

#' Create a datasim-backed lConfig object for workr::RunWorkflow
#'
#' @param n_participants Integer. Target participant count for simulated data. Default 50.
#' @param n_sites Integer. Target site count for simulated data. Default 5.
#' @param study_id Character. Simulated study identifier. Default "DEMO-001".
#' @param start_date Character or Date. First date of simulated data. Default "2023-01-01".
#' @param end_date Character or Date. Last date of simulated data. Default "2023-12-31".
#' @param data_store Environment. In-memory store shared across workflow runs so that
#'   outputs saved by one workflow (e.g. Mapped_AE) are available to LoadData for the
#'   next workflow. Default: a fresh empty environment.
#'
#' @return List with LoadData and SaveData functions conforming to the workr lConfig interface.
#' @export
datasim_lConfig <- function(
  n_participants = 50,
  n_sites = 5,
  study_id = "DEMO-001",
  start_date = "2023-01-01",
  end_date = "2023-12-31",
  data_store = new.env(parent = emptyenv())
) {
  list(
    n_participants = n_participants,
    n_sites = n_sites,
    study_id = study_id,
    start_date = start_date,
    end_date = end_date,
    data_store = data_store,
    LoadData = datasim_LoadData,
    SaveData = datasim_SaveData
  )
}
