library(workr)
library(gsm.core)
library(gsm.mapping)
library(gsm.kri)

# Load raw data from CSVs
raw_files <- list.files("input", pattern = "[.]csv$", full.names = TRUE)
lRaw <- list()
for (f in raw_files) {
  domain <- tools::file_path_sans_ext(basename(f))
  lRaw[[domain]] <- read.csv(f, stringsAsFactors = FALSE)
  cat(domain, ":", nrow(lRaw[[domain]]), "rows\n")
}

### Step 1 - Create Mapped Data Layer
cat("\n=== Step 1: Mappings ===\n")
mappings_wf <- MakeWorkflowList(strPath = "workflows/1_mappings")
mapped <- RunWorkflows(mappings_wf, lRaw)

### Step 2 - Create Metrics
cat("\n=== Step 2: Metrics ===\n")
metrics_wf <- MakeWorkflowList(strPath = "workflows/2_metrics")
analyzed <- RunWorkflows(metrics_wf, c(mapped, list(lWorkflows = metrics_wf)))

# Coerce GroupID to character across all analyzed results (site IDs are numeric,
# country IDs are character — BindResults needs consistent types to row-bind)
for (nm in names(analyzed)) {
  for (sub in names(analyzed[[nm]])) {
    if (is.data.frame(analyzed[[nm]][[sub]]) && "GroupID" %in% names(analyzed[[nm]][[sub]])) {
      analyzed[[nm]][[sub]]$GroupID <- as.character(analyzed[[nm]][[sub]]$GroupID)
    }
  }
}

### Step 3 - Create Reporting Layer
cat("\n=== Step 3: Reporting ===\n")
reporting_wf <- MakeWorkflowList(strPath = "workflows/3_reporting")
reporting <- RunWorkflows(reporting_wf, c(mapped, list(
  lAnalyzed = analyzed,
  lWorkflows = metrics_wf,
  dSnapshotDate = Sys.Date(),
  Reporting_Results_Longitudinal = NULL
)))

### Step 4 - Create KRI Reports
cat("\n=== Step 4: Modules ===\n")
module_wf <- MakeWorkflowList(strPath = "workflows/4_modules")
lReports <- RunWorkflows(module_wf, reporting)

### Save outputs to output/{phase}/{workflowId}/
cat("\n=== Saving Outputs ===\n")
dir.create("output", showWarnings = FALSE)

# Save mapped data: output/1_mappings/{ID}/Mapped_{ID}.csv
for (nm in names(mapped)) {
  if (is.data.frame(mapped[[nm]])) {
    id <- sub("^Mapped_", "", nm)
    out_dir <- file.path("output", "1_mappings", id)
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    write.csv(mapped[[nm]], file.path(out_dir, paste0(nm, ".csv")), row.names = FALSE)
    cat("Saved", nm, "\n")
  }
}

# Save analyzed metrics: output/2_metrics/{ID}/{step_output}.csv
for (nm in names(analyzed)) {
  id <- sub("^Analysis_", "", nm)
  out_dir <- file.path("output", "2_metrics", id)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  for (sub in names(analyzed[[nm]])) {
    if (is.data.frame(analyzed[[nm]][[sub]])) {
      write.csv(analyzed[[nm]][[sub]], file.path(out_dir, paste0(sub, ".csv")), row.names = FALSE)
    }
  }
  cat("Saved", nm, "\n")
}

# Save reporting data: output/3_reporting/{ID}/Reporting_{ID}.csv
for (nm in names(reporting)) {
  if (is.data.frame(reporting[[nm]])) {
    id <- sub("^Reporting_", "", nm)
    out_dir <- file.path("output", "3_reporting", id)
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    write.csv(reporting[[nm]], file.path(out_dir, paste0(nm, ".csv")), row.names = FALSE)
    cat("Saved", nm, "\n")
  }
}

# Move HTML reports to output/4_modules/{ID}/
for (f in list.files(".", pattern = "^kri_report.*\\.html$")) {
  # Extract module ID from filename pattern: kri_report_{StudyID}_{Level}_{Date}.html
  level <- if (grepl("_Site_", f)) "report_kri_site" else "report_kri_country"
  out_dir <- file.path("output", "4_modules", level)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  file.rename(f, file.path(out_dir, f))
  cat("Saved", f, "\n")
}

cat("\n=== Done ===\n")
cat("Mapped domains:", length(mapped), "\n")
cat("Analyzed metrics:", length(analyzed), "\n")
cat("Reporting objects:", length(reporting), "\n")
cat("Reports:", length(lReports), "\n")
