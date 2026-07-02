# datasim_SaveData.R — lConfig$SaveData implementation for gsm.datasim
#
# Stores each artifact in lWorkflow$lResult into the in-memory
# lConfig$data_store so that later workflows in the same demo session
# (e.g. a metrics workflow consuming a mapping workflow's output) can
# pick them up as inputs via datasim_LoadData.

#' Save workflow results into the in-memory datasim data store
#'
#' @param lWorkflow List. Workflow object with $meta and $lResult.
#' @param lConfig List. Config object with $data_store.
#'
#' @return NULL (invisible). Side effect: populates lConfig$data_store.
#' @export
datasim_SaveData <- function(lWorkflow, lConfig) {
  lResult <- lWorkflow$lResult

  if (is.null(lResult) || length(lResult) == 0) {
    return(invisible(NULL))
  }

  for (artifact_name in names(lResult)) {
    assign(artifact_name, lResult[[artifact_name]], envir = lConfig$data_store)
  }

  invisible(NULL)
}
