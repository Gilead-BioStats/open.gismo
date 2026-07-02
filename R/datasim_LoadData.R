# datasim_LoadData.R — lConfig$LoadData implementation for gsm.datasim
#
# Reads data domains specified in lWorkflow$spec. Domains already produced
# by an earlier workflow in this demo session are read from
# lConfig$data_store first; anything still missing is simulated via
# gsm.datasim::generate_data_from_workflows(), which generates type-correct
# columns for arbitrary domain names (falling back to dedicated generators
# for recognized clinical domains like Raw_AE).

#' Load data for a workr workflow using gsm.datasim simulation
#'
#' Reads lWorkflow$spec to determine which data domains are needed. Domains
#' already available in lConfig$data_store (e.g. saved by a previous
#' workflow's SaveData) take precedence; remaining domains are simulated.
#'
#' @param lWorkflow List. Workflow object with $meta and $spec.
#' @param lConfig List. Config object with $data_store and simulation
#'   parameters ($n_participants, $n_sites, $study_id, $start_date, $end_date).
#' @param lData List. Existing data list to populate.
#'
#' @return lData with additional data.frames loaded or simulated per lWorkflow$spec.
#' @export
datasim_LoadData <- function(lWorkflow, lConfig, lData) {
  spec <- lWorkflow$spec

  if (is.null(spec) || length(spec) == 0) {
    return(lData)
  }

  domain_names <- names(spec)
  missing_domains <- character(0)

  for (domain in domain_names) {
    if (!is.null(lData[[domain]])) {
      next
    }

    stored <- lConfig$data_store[[domain]]
    if (!is.null(stored)) {
      lData[[domain]] <- stored
    } else {
      missing_domains <- c(missing_domains, domain)
    }
  }

  if (length(missing_domains) == 0) {
    return(lData)
  }

  if (!requireNamespace("gsm.datasim", quietly = TRUE)) {
    warning(
      "datasim_LoadData: package 'gsm.datasim' is required to simulate domains: ",
      paste(missing_domains, collapse = ", ")
    )
    return(lData)
  }

  simulated <- tryCatch(
    gsm.datasim::generate_data_from_workflows(
      lWorkflows = stats::setNames(list(lWorkflow), lWorkflow$meta$ID %||% "demo"),
      n_participants = lConfig$n_participants %||% 50,
      n_sites = lConfig$n_sites %||% 5,
      study_id = lConfig$study_id %||% "DEMO-001",
      start_date = lConfig$start_date %||% "2023-01-01",
      end_date = lConfig$end_date %||% "2023-12-31",
      desired_domains = missing_domains
    ),
    error = function(e) {
      warning(sprintf(
        "datasim_LoadData: error simulating domains [%s]: %s",
        paste(missing_domains, collapse = ", "),
        conditionMessage(e)
      ))
      list()
    }
  )

  for (domain in missing_domains) {
    if (!is.null(simulated[[domain]])) {
      lData[[domain]] <- simulated[[domain]]
      assign(domain, simulated[[domain]], envir = lConfig$data_store)
    } else {
      warning(sprintf("datasim_LoadData: domain '%s' could not be simulated.", domain))
    }
  }

  lData
}

`%||%` <- function(x, y) if (is.null(x)) y else x
