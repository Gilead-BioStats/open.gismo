# One-command local runner: install -> run -> save.
# The workflow bundle is vendored in workflows/ (public-only subset), so
# there is no library pull step; datasim generation happens inside
# RunProject via workr's gsm.datasim LoadData provider (study.yaml
# datasim.mode = load_provider).
source("scripts/01-install-environment.R")
source("scripts/03-run-workflows.R")
