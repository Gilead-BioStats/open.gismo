# Restore the package environment for a study run.
#
# Adapted from AA-AA-000-0000 (demo/gsm-datasim-load-single-snapshot):
# installs every manifest.csv row at its exact commit SHA. This vendored
# copy carries public repos only, so no org PAT is required and workr is
# pinned directly in the manifest (no library.yaml side-load needed).
#
# rproject.toml carries the same pins for `rv sync`; manifest install is the
# library the run actually uses (rv remains a non-blocking verification
# path in CI, mirroring the source study repo).

install_environment <- function(manifest_path = "manifest.csv") {
  needed <- c("remotes")
  missing_boot <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_boot) > 0) {
    install.packages(missing_boot, repos = "https://packagemanager.posit.co/cran/latest")
  }

  # Large tarballs (gsm.datasim) can blow through R's default 60s download
  # timeout; give downloads room and retry once.
  options(timeout = 600)
  install_with_retry <- function(repo, ref) {
    for (attempt in 1:2) {
      ok <- tryCatch(
        {
          remotes::install_github(repo, ref = ref, upgrade = "never")
          TRUE
        },
        error = function(e) {
          message(sprintf("attempt %d failed for %s: %s", attempt, repo, conditionMessage(e)))
          FALSE
        }
      )
      if (ok) return(TRUE)
    }
    FALSE
  }

  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)

  # manifest.csv is ordered with gsm.core first; install in order so
  # in-org dependencies resolve from the already-installed SHA versions.
  failed <- character()
  for (i in seq_len(nrow(manifest))) {
    row <- manifest[i, ]
    message(sprintf("Installing %s/%s @ %s (%s)", row$org, row$package, row$version, substr(row$sha, 1, 7)))
    if (!install_with_retry(sprintf("%s/%s", row$org, row$package), row$sha)) {
      failed <- c(failed, row$package)
      message(sprintf("FAILED %s after retries", row$package))
    }
  }
  if (length(failed) > 0) {
    message(sprintf("Manifest packages that failed to install: %s", paste(failed, collapse = ", ")))
  }

  required <- c("workr", "gsm.core", "gsm.mapping", "gsm.datasim")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(sprintf(
      "Demo-critical packages missing after install: %s",
      paste(missing, collapse = ", ")
    ))
  }

  invisible(NULL)
}
