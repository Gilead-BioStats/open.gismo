# Install the pinned package environment from manifest.csv SHAs.
if (!requireNamespace("yaml", quietly = TRUE)) {
  install.packages("yaml", repos = "https://packagemanager.posit.co/cran/latest")
}
source("R/install-environment.R")
install_environment()
