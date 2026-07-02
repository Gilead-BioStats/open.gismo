# Run the rendered workflow project against datasim input.
#
# Mainline architecture (issue #1): generate the input set once before
# RunProject() and pass it directly as lData. Demo branch architecture:
# datasim.mode = "load_provider" wraps workr's built-in `LoadData = "gsm.datasim"`
# provider in `lConfig$project$LoadData`, so generation happens once at the
# project boundary instead of once per workflow.

# Stage a filtered copy of the workflow phases, excluding workflows that
# reference packages not installed in this environment (e.g. private deps
# that cannot install without an org PAT — GAPS.md #7/#8). With workr's
# bContinueOnError these would merely fail-and-record, but excluding them
# keeps the status table about real signal rather than known install gaps.
# The exclusion list is itself gap evidence and is logged + saved alongside
# outputs.
prepare_run_path <- function(workflow_path, phases, exclude = character(),
                             run_path = "data/workflows-run") {
  unlink(run_path, recursive = TRUE, force = TRUE)
  excluded <- list()

  for (phase in phases) {
    src <- file.path(workflow_path, phase)
    dst <- file.path(run_path, phase)
    dir.create(dst, recursive = TRUE, showWarnings = FALSE)
    # Inject study-owned phase-boundary config (the bundle ships none).
    override <- file.path("phase-config", phase, "_config.yaml")
    if (file.exists(override)) file.copy(override, dst)
    for (f in list.files(src, pattern = "\\.ya?ml$", full.names = TRUE)) {
      # Study-side patch overlay: fixes for upstream workflow bugs live in
      # workflow-patches/<phase>/ and replace the bundle copy in the staged
      # dir, keeping the committed bundle pristine.
      if (basename(f) %in% exclude) {
        excluded[[basename(f)]] <- list(phase = phase, reason = "configured in study.yaml run.exclude_workflows")
        next
      }
      patch <- file.path("workflow-patches", phase, basename(f))
      if (file.exists(patch)) f <- patch
      text <- paste(readLines(f, warn = FALSE), collapse = "\n")
      pkgs <- unique(regmatches(text, gregexpr("[A-Za-z][A-Za-z0-9.]*(?=::)", text, perl = TRUE))[[1]])
      missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
      if (length(missing) > 0 && basename(f) != "_config.yaml") {
        excluded[[basename(f)]] <- list(phase = phase, missing_packages = missing)
      } else {
        file.copy(f, dst)
      }
    }
  }

  if (length(excluded) > 0) {
    message(sprintf(
      "Excluded %d workflow(s) referencing uninstalled packages: %s",
      length(excluded), paste(names(excluded), collapse = ", ")
    ))
    dir.create("data/output", recursive = TRUE, showWarnings = FALSE)
    yaml::write_yaml(excluded, "data/output/excluded-workflows.yaml")
  }

  run_path
}

datasim_mode <- function(study_config) {
  mode <- study_config$datasim$mode
  if (is.null(mode) || !nzchar(mode)) mode <- "rds"
  if (!mode %in% c("rds", "load_provider")) {
    stop(sprintf("Unsupported datasim.mode: %s", mode))
  }
  mode
}

datasim_provider_config <- function(study_config, run_path) {
  defaults <- list(
    profile = "standard",
    study_type = "standard",
    study_id = study_config$study$id,
    participants = study_config$study$participants,
    sites = study_config$study$sites,
    start_date = study_config$study$start_date,
    snapshot_count = 1,
    snapshot_width = study_config$study$snapshot_width,
    workflow_path = file.path(run_path, "1_mappings")
  )

  utils::modifyList(defaults, study_config$datasim$provider %||% list())
}

load_gsm_datasim_once <- function(provider_config, lData, study_id) {
  loader_workflow <- list(
    meta = list(Type = "LoadData", ID = study_id),
    steps = list()
  )

  loaded <- workr::RunWorkflow(
    lWorkflow = loader_workflow,
    lData = lData,
    lConfig = list(
      LoadData = "gsm.datasim",
      gsm.datasim = provider_config
    ),
    bReturnResult = FALSE
  )

  loaded$lData
}

apply_datasim_demo_overrides <- function(raw_data) {
  if ("Raw_LB" %in% names(raw_data) && "toxgrg_nsv" %in% names(raw_data$Raw_LB)) {
    raw_data$Raw_LB$toxgrg_nsv <- sample(
      c("", "0", "1", "2", "3", "4"),
      nrow(raw_data$Raw_LB),
      replace = TRUE,
      prob = c(0.49, 0.4875, 0.01, 0.005, 0.005, 0.0025)
    )
  }

  if ("Raw_QUERY" %in% names(raw_data) && "querystatus" %in% names(raw_data$Raw_QUERY)) {
    raw_data$Raw_QUERY$querystatus <- sample(
      c("Answered", "Closed", "Open"),
      nrow(raw_data$Raw_QUERY),
      replace = TRUE,
      prob = c(0.02, 0.96, 0.02)
    )
  }

  raw_data
}

run_study <- function(
  study_config_path = "study.yaml",
  raw_data_path = "data/raw/datasim-raw.rds"
) {
  study_config <- yaml::read_yaml(study_config_path)
  mode <- datasim_mode(study_config)
  raw_data <- if (identical(mode, "rds")) readRDS(raw_data_path) else NULL

  if (identical(mode, "load_provider") && as.integer(study_config$study$snapshots) != 1L) {
    stop("datasim.mode = 'load_provider' demo is single-snapshot only; set study.snapshots to 1.")
  }

  # Some rendered workflows call step functions WITHOUT a package prefix
  # (e.g. kri*: `Analyze_NormalApprox` from gsm.kri); workr resolves those
  # against attached packages only (GAPS.md #11), so attach the workflow
  # packages up front.
  for (pkg in c("gsm.core", "gsm.mapping", "gsm.kri", "gsm.qtl", "gsm.reporting")) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    }
  }

  run_path <- prepare_run_path(
    study_config$run$workflow_path,
    study_config$run$phases,
    exclude = unlist(study_config$run$exclude_workflows)
  )

  # gsm.datasim generates SOURCE-named columns (e.g. foldername), while the
  # bundle's mapping workflows assume INGESTED spec names (e.g.
  # response_folder via source_col). The classic gsm pipeline runs
  # gsm.mapping::Ingest() between the two; nothing in the RunProject path
  # does (GAPS.md #12), so replicate it here.
  mapping_workflows <- workr::MakeWorkflowList(
    strPath = file.path(run_path, "1_mappings"),
    bRecursive = FALSE
  )
  combined_specs <- gsm.mapping::CombineSpecs(mapping_workflows)

  # bContinueOnError = TRUE (workr fix-67 "validation ergonomics", GAPS.md
  # #9): workflow failures are recorded in a status table and the project
  # keeps going, so one broken workflow no longer hides everything behind it.
  # Return shape becomes list(results, status, failures).
  run_one <- function(snapshot_data, snapshot_date) {
    ingested <- gsm.mapping::Ingest(snapshot_data, combined_specs)
    summary <- workr::RunProject(
      strPath = run_path,
      lData = c(ingested, list(
        study_id = study_config$study$id,
        # Results.yaml (gsm.reporting::BindResults) needs a real Date; it
        # cannot come from _config.yaml input.extra (strings pass literally).
        dSnapshotDate = snapshot_date
      )),
      strPhases = study_config$run$phases,
      bRecursive = FALSE,
      bReturnResult = TRUE,
      bContinueOnError = TRUE
    )
    failures <- summary$failures
    list(
      status = if (is.null(failures) || nrow(failures) == 0) "ok" else "completed_with_failures",
      failures = failures,
      result = summary$results
    )
  }

  run_one_with_provider <- function(snapshot_date) {
    provider_config <- datasim_provider_config(study_config, run_path)
    summary <- workr::RunProject(
      strPath = run_path,
      lData = list(),
      lConfig = list(
        project = list(
          LoadData = function(lConfig, lData) {
            set.seed(study_config$datasim$seed)
            loaded <- load_gsm_datasim_once(
              provider_config = lConfig$gsm.datasim,
              lData = lData,
              study_id = study_config$study$id
            )
            raw_domains <- loaded[startsWith(names(loaded), "Raw_")]
            if (length(raw_domains) == 0) {
              stop("gsm.datasim LoadData provider returned no Raw_* domains.")
            }
            raw_domains <- apply_datasim_demo_overrides(raw_domains)
            ingested <- gsm.mapping::Ingest(raw_domains, combined_specs)
            c(ingested, list(
              study_id = study_config$study$id,
              dSnapshotDate = snapshot_date
            ))
          },
          gsm.datasim = provider_config
        )
      ),
      strPhases = study_config$run$phases,
      bRecursive = FALSE,
      bReturnResult = TRUE,
      bContinueOnError = TRUE
    )
    failures <- summary$failures
    list(
      status = if (is.null(failures) || nrow(failures) == 0) "ok" else "completed_with_failures",
      failures = failures,
      result = summary$results
    )
  }

  entries <- if (identical(mode, "load_provider")) {
    list(single = run_one_with_provider(as.Date(study_config$study$end_date)))
  } else if (study_config$study$snapshots > 1) {
    # Multi-snapshot output is keyed by snapshot end-date. tryCatch remains
    # only as a backstop for hard errors outside RunProject's tolerance
    # (e.g. Ingest itself).
    out <- lapply(names(raw_data), function(snap) {
      tryCatch(
        run_one(raw_data[[snap]], as.Date(snap)),
        error = function(e) {
          message(sprintf("Snapshot %s HARD-FAILED: %s", snap, conditionMessage(e)))
          list(status = "hard_error", error = conditionMessage(e))
        }
      )
    })
    names(out) <- names(raw_data)
    out
  } else {
    list(single = run_one(raw_data, as.Date(study_config$study$end_date)))
  }

  # Verdict policy: failures named in run.expected_failures are tolerated
  # everywhere; the FIRST snapshot of a longitudinal ramp tolerates any
  # recorded failures (sparse by design, GAPS.md #16) but not hard errors.
  # Anything else fails the run — after status is written for the artifact.
  expected <- unlist(study_config$run$expected_failures) %||% character()
  multi <- study_config$study$snapshots > 1

  status_report <- lapply(entries, function(e) {
    rep <- list(status = e$status)
    if (!is.null(e$error)) rep$error <- e$error
    if (!is.null(e$failures) && nrow(e$failures) > 0) {
      rep$failures <- sprintf(
        "%s/%s: %s", e$failures$phase, e$failures$workflow, e$failures$message
      )
    }
    rep
  })
  dir.create("data/output", recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(status_report, "data/output/snapshot-status.yaml")

  unexpected <- list()
  for (i in seq_along(entries)) {
    snap <- names(entries)[[i]]
    e <- entries[[i]]
    if (identical(e$status, "hard_error")) {
      unexpected[[snap]] <- e$error
    } else if (!is.null(e$failures) && nrow(e$failures) > 0) {
      if (multi && i == 1) next # ramp-floor sparsity is expected
      bad <- setdiff(e$failures$workflow, expected)
      if (length(bad) > 0) unexpected[[snap]] <- bad
    }
  }

  message(sprintf(
    "Snapshots: %s",
    paste(sprintf("%s=%s", names(entries),
                  vapply(entries, function(e) e$status, character(1))),
          collapse = ", ")
  ))
  if (length(unexpected) > 0) {
    stop(sprintf(
      "Unexpected workflow failures: %s (see data/output/snapshot-status.yaml)",
      paste(sprintf("[%s] %s", names(unexpected),
                    vapply(unexpected, paste, character(1), collapse = ", ")),
            collapse = "; ")
    ))
  }

  entries
}
