# Implementation Plan: open.gismo Platform

## Overview

Build the open.gismo platform as a thin integration layer over {workr}. Uses red/green TDD throughout: write tests first (red — confirm they fail), then implement until tests pass (green). The implementation proceeds in phases: R package scaffolding and lConfig hooks, Project Snapshot management, GitHub Actions workflows, front-end migration and extension, AGENTS.md/AI Skills, and example projects.

## TDD Approach

Every implementation task follows this cycle:
1. **RED**: Write tests first (unit tests and/or property-based tests). Run them. Confirm they fail.
2. **GREEN**: Write the minimal implementation to make the tests pass. Run tests again. Confirm they pass.
3. Move to the next task.

## Tasks

- [ ] 1. Scaffold the open.gismo R package
  - [ ] 1.1 Create R package structure (DESCRIPTION, NAMESPACE, .Rbuildignore) with dependencies on workr, base64enc, httr2, jsonlite, yaml
    - Create `open.gismo/DESCRIPTION` with package metadata, imports, and suggests (testthat, hedgehog)
    - Create `open.gismo/NAMESPACE` placeholder (roxygen2-managed)
    - Create `open.gismo/.Rbuildignore` excluding site/, .github/, skills/, AGENTS.md
    - Create `open.gismo/R/` directory
    - Create `open.gismo/tests/testthat.R` and `open.gismo/tests/testthat/` directory
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.3_

- [ ] 2. Implement GitHub API helpers (red/green TDD)
  - [ ] 2.1 RED: Write tests for `gh_api.R` — low-level GitHub API helpers
    - Write tests for `gh_get_content(repo, path, branch, token)` — successful retrieval and error cases (404, 403, 5xx) using mocked HTTP responses
    - Write tests for `gh_put_content(repo, path, content, message, branch, sha, token)` — successful commit and error cases
    - Write tests for `gh_list_directory(repo, path, branch, token)` — successful listing and error cases
    - Run tests. Confirm all fail (functions don't exist yet).
    - _Requirements: 1.1, 1.4, 1.5, 2.5, 2.6_

  - [ ] 2.2 GREEN: Implement `gh_api.R` to make tests pass
    - Implement `gh_get_content`, `gh_put_content`, `gh_list_directory`
    - Handle HTTP error responses (401/403/404/5xx) with informative error messages
    - Run tests. Confirm all pass.
    - _Requirements: 1.1, 1.4, 1.5, 2.5, 2.6_

- [ ] 3. Implement GitHub lConfig hooks (red/green TDD)
  - [ ] 3.1 RED: Write tests for `gh_lConfig.R`, `gh_LoadData.R`, `gh_SaveData.R`
    - Write tests for `gh_lConfig(repo, branch, snapshot_id, data_config, token)` — returns list with correct structure and function signatures conforming to workr::RunWorkflow expectations
    - Write tests for `gh_LoadData(lWorkflow, lConfig, lData)` — reads spec domains, fetches from GitHub (mocked), parses CSV to data.frames, handles missing domains, logs errors on API failure
    - Write tests for `gh_SaveData(lWorkflow, lConfig)` — serializes lResult to CSV, commits to GitHub (mocked), records execution status, handles API errors and retains data
    - Run tests. Confirm all fail.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 14.1, 19.1, 19.2, 19.3, 19.4, 19.8, 19.9_

  - [ ] 3.2 GREEN: Implement `gh_lConfig.R`, `gh_LoadData.R`, `gh_SaveData.R`
    - Implement factory function, LoadData, and SaveData to make all tests pass
    - Run tests. Confirm all pass.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 14.1, 19.1, 19.2, 19.3, 19.4, 19.8, 19.9_

  - [ ] 3.3 RED: Write tests for `status_tracker.R`
    - Write tests for `record_step_status` — records completed, failed, not_run with error messages
    - Write tests for `build_status_json` — constructs correct status.json structure from workflow results
    - Write tests verifying subsequent workflows still execute after a step failure
    - Run tests. Confirm all fail.
    - _Requirements: 3.6, 20.1, 20.2_

  - [ ] 3.4 GREEN: Implement `status_tracker.R`
    - Implement `record_step_status` and `build_status_json` to make all tests pass
    - Run tests. Confirm all pass.
    - _Requirements: 3.6, 20.1, 20.2_

- [ ] 4. Implement Project Snapshot management (red/green TDD)
  - [ ] 4.1 RED: Write tests for `snapshot_manager.R`
    - Write tests for `create_project_snapshot(repo, branch, input_data_version, package_snapshot, token)` — creates metadata.json with correct fields, allocates sequential ps-NNN IDs, updates snapshots.json index
    - Write tests for `list_project_snapshots(repo, branch, token)` — returns data frame with snapshot_id, created_at, input_data_version, package_snapshot columns; handles empty project
    - Write tests for `get_snapshot_status(repo, branch, snapshot_id, token)` — returns workflow statuses with per-step status
    - Write tests for snapshot data inheritance — LoadData falls back to previous snapshots when domain missing in current snapshot; current snapshot data takes precedence over previous
    - Run tests. Confirm all fail.
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6, 18.7, 18.8, 18.9_

  - [ ] 4.2 GREEN: Implement `snapshot_manager.R`
    - Implement `create_project_snapshot`, `list_project_snapshots`, `get_snapshot_status`
    - Implement snapshot inheritance logic in `gh_LoadData` (check current snapshot first, fall back to previous snapshots in reverse order)
    - Run tests. Confirm all pass.
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6, 18.7, 18.8, 18.9_

- [ ] 5. Property-based tests for R package (Properties 1–4, 17–18)
  - [ ] 5.1 RED: Write hedgehog property tests for lConfig hooks and snapshots
    - Property 1 (SaveData/LoadData Round Trip): Generate random data frames, save via gh_SaveData (mocked), load via gh_LoadData, verify equivalence after type coercion
    - Property 2 (Artifact Path Organization): Generate random workflow metadata (Type, ID, Phase), save artifacts, verify path contains project/snapshot/phase segments
    - Property 3 (Failure Status Recording): Generate random pipelines with injected failures, run through status tracker, verify failed steps recorded and subsequent workflows executed
    - Property 4 (Data Config Parsing): Generate random domain-to-path YAML mappings, parse, verify all domains map to non-empty paths
    - Property 17 (Project Snapshot Listing): Generate random sequences of snapshot creations, list them, verify count, uniqueness, and metadata completeness
    - Property 18 (Project Snapshot Data Inheritance): Generate random multi-snapshot projects with overlapping domains, verify LoadData returns correct precedence
    - Run tests. Confirm all fail (implementations may pass some; new property edge cases should surface failures).
    - _Requirements: 1.4, 2.2, 2.4, 1.6, 18.5, 3.6, 6.2, 18.1–18.8_

  - [ ] 5.2 GREEN: Fix any implementation gaps revealed by property tests
    - Address edge cases surfaced by hedgehog generators
    - Run all R tests (unit + property). Confirm all pass.
    - _Requirements: 1.4, 2.2, 2.4, 1.6, 18.5, 3.6, 6.2, 18.1–18.8_

- [ ] 6. R package checkpoint
  - Verify all R unit tests and property tests pass: `devtools::test()`
  - Verify `devtools::check()` passes with no errors or warnings
  - Verify NAMESPACE exports are correct
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1–2.6, 3.6, 18.1–18.9, 19.1–19.9_

- [ ] 7. Implement GitHub Actions workflows (red/green TDD)
  - [ ] 7.1 RED: Write validation tests for GitHub Actions YAML files
    - Write tests that parse each YAML workflow file and verify: required inputs are defined, required steps are present, R setup and package installation steps exist, workr function calls are correct
    - Verify `run-pipeline.yaml` calls gh_lConfig, MakeWorkflowList, RunWorkflows in correct order
    - Verify `create-snapshot.yaml` calls create_project_snapshot and commits snapshots.json
    - Verify `build-site.yaml` collects snapshot data and builds Vite app
    - Run tests. Confirm all fail (YAML files don't exist yet).
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1–4.10, 13.2, 13.3, 13.4, 13.5, 13.6_

  - [ ] 7.2 GREEN: Implement GitHub Actions workflow YAML files
    - Create `.github/workflows/run-pipeline.yaml` — reusable workflow: checkout, install R + packages from manifest, source open.gismo, create/load snapshot, build lConfig, MakeWorkflowList, RunWorkflows, commit artifacts
    - Create `.github/workflows/create-snapshot.yaml` — create new Project Snapshot with input data
    - Create `.github/workflows/init-snapshot.yaml` — initialize Package Snapshot branch from packages.yaml via workr::pkgSnapshot
    - Create `.github/workflows/build-site.yaml` — collect data from all ss-* branches + project snapshots, build Vite app, deploy to GitHub Pages
    - Create `.github/workflows/nightly-snapshot.yaml` — scheduled nightly Package Snapshot update
    - Run validation tests. Confirm all pass.
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1–4.10, 13.2, 13.3, 13.4, 13.5, 13.6_

- [ ] 8. Migrate and scaffold the Vite front-end (red/green TDD)
  - [ ] 8.1 Migrate existing workr/site modules to open.gismo/site
    - Copy `constants.js`, `utils.js`, `parsers.js`, `data.js`, `pipeline.js`, `detail.js`, `packages.js`, `filters.js`, `main.js` from workr/site/src/
    - Copy `index.html`, `style.css`, `vite.config.js`, `package.json` from workr/site/
    - Add vitest and fast-check to devDependencies
    - Create `site/vitest.config.js`
    - Verify existing modules load without errors: `npm run build`
    - _Requirements: 8.1, 8.2, 9.1–9.9, 10.1–10.7, 11.1–11.6, 12.1–12.4, 13.1_

  - [ ] 8.2 RED: Write tests for migrated modules (parsers, data, pipeline, detail, packages, filters)
    - Write vitest unit tests for `parseYamlMeta`, `parseWorkflow`, `parseCsv` with specific inputs and edge cases
    - Write vitest unit tests for branch sort, phase grouping, card rendering, detail view, manifest table
    - Write vitest unit tests for filter and search behavior
    - Run tests. Confirm all fail (modules need JSDOM/test harness wiring).
    - _Requirements: 7.1–7.6, 8.2, 9.2–9.9, 10.2–10.4, 11.2–11.4, 12.1–12.4_

  - [ ] 8.3 GREEN: Wire up test harness and fix any migrated module issues
    - Configure vitest with JSDOM environment for DOM tests
    - Fix any import/export issues from migration
    - Run tests. Confirm all pass.
    - _Requirements: 7.1–7.6, 8.2, 9.2–9.9, 10.2–10.4, 11.2–11.4, 12.1–12.4_

- [ ] 9. Implement new front-end modules — Project Snapshots (red/green TDD)
  - [ ] 9.1 RED: Write tests for `snapshots.js` and `data.js` extensions
    - Write tests for `loadSnapshots(branch)` — fetches snapshots.json, returns array of snapshot objects
    - Write tests for `loadSnapshotStatus(branch, snapshotId)` — fetches status.json, returns workflow status map
    - Write tests for `buildSnapshotSelector(snapshots, onSelect)` — renders dropdown with snapshots in reverse chronological order; auto-selects when only one snapshot
    - Write tests for `onSnapshotChange(snapshotId)` — triggers status and artifact loading
    - Run tests. Confirm all fail.
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5, 23.6, 23.7_

  - [ ] 9.2 GREEN: Implement `snapshots.js` and extend `data.js`
    - Implement `buildSnapshotSelector`, `onSnapshotChange` in `snapshots.js`
    - Add `loadSnapshots`, `loadSnapshotStatus`, `loadArtifact`, `loadLog` to `data.js`
    - Integrate snapshot selector into `main.js`
    - Run tests. Confirm all pass.
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5, 23.6, 23.7_

- [ ] 10. Implement new front-end modules — Status, Artifacts, Logs (red/green TDD)
  - [ ] 10.1 RED: Write tests for `status.js`
    - Write tests for `buildStatusBadge(status)` — renders correct icon, color, CSS class for completed/failed/not_run
    - Write tests for `buildStatusSummary(steps)` — renders aggregate counts that sum to total steps
    - Write tests for failed status displaying error message
    - Write tests for status indicators appearing in step execution order
    - Run tests. Confirm all fail.
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7_

  - [ ] 10.2 GREEN: Implement `status.js`
    - Implement `buildStatusBadge` and `buildStatusSummary`
    - Integrate status indicators into `pipeline.js` workflow cards and `detail.js` step views
    - Run tests. Confirm all pass.
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7_

  - [ ] 10.3 RED: Write tests for `artifacts.js`
    - Write tests for `buildArtifactViewer(step, snapshotId, branch)` — lists input and output artifacts for completed/failed steps
    - Write tests for `buildDataTable(csvText)` — renders scrollable table from CSV data
    - Write tests for not_run step disabling artifact viewer
    - Write tests for partial output artifacts on failed steps
    - Run tests. Confirm all fail.
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7_

  - [ ] 10.4 GREEN: Implement `artifacts.js`
    - Implement `buildArtifactViewer` and `buildDataTable`
    - Integrate into `detail.js` step detail view
    - Run tests. Confirm all pass.
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7_

  - [ ] 10.5 RED: Write tests for `logs.js`
    - Write tests for `buildLogViewer(log, workflowId)` — renders log entries in chronological order
    - Write tests for `buildLogEntry(entry)` — renders stdout/stderr with distinct CSS classes
    - Write tests for failed step log entries having highlighted error sections
    - Write tests for not_run step showing "no logs available" message
    - Run tests. Confirm all fail.
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5, 22.6, 22.7, 22.8_

  - [ ] 10.6 GREEN: Implement `logs.js`
    - Implement `buildLogViewer` and `buildLogEntry`
    - Integrate into `detail.js` workflow/step detail view
    - Run tests. Confirm all pass.
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5, 22.6, 22.7, 22.8_

- [ ] 11. Property-based tests for front-end (Properties 5–16, 19–23)
  - [ ] 11.1 RED: Write fast-check property tests for parsers and rendering
    - Property 5 (YAML Workflow Parsing Round Trip): Generate random workflow objects, pretty-print to YAML, parse, pretty-print, parse again, verify equivalence
    - Property 6 (Branch Sort Order): Generate random branch name arrays, sort, verify priority order + alphabetical remainder
    - Property 7 (Workflow Phase Grouping): Generate random workflow paths with prefixes, group, verify assignment and counts
    - Property 8 (Workflow Card Contains Required Information): Generate random metadata, render card, verify all fields present
    - Property 9 (Compact Mode Omits Metadata Tags): Generate random metadata, render compact, verify ID present but tags absent
    - Property 10 (Group Level Filtering): Generate random card sets with group levels, filter, verify only matching visible
    - Property 11 (Search Filtering): Generate random metadata and search substrings, verify matching cards visible
    - Property 12 (Detail View Contains All Metadata): Generate random meta key-value pairs, verify all in HTML
    - Property 13 (Detail View Contains Spec Information): Generate random spec structures, verify all names in HTML
    - Property 14 (Detail View Contains Step Information): Generate random steps, verify function names/outputs/params in order
    - Property 15 (Manifest Table Rendering): Generate random manifest rows, verify all fields and links
    - Property 16 (CSV Parsing Correctness): Generate random CSV text, parse, verify row count and field values
    - Run tests. Confirm all fail.
    - _Requirements: 7.1–7.6, 8.2, 9.2–9.9, 10.2–10.4, 11.2–11.4, 12.1–12.4_

  - [ ] 11.2 RED: Write fast-check property tests for new modules (status, artifacts, logs, snapshots)
    - Property 19 (Execution Status Display): Generate random step statuses, verify distinct CSS classes and error messages
    - Property 20 (Execution Status Order and Summary): Generate random workflows with N steps, verify order and count summary
    - Property 21 (Artifact Viewer Completeness): Generate random artifact lists, verify all shown with name/domain/preview
    - Property 22 (Log Viewer Rendering): Generate random log entries, verify chronological order and distinct styling
    - Property 23 (Project Snapshot Selector): Generate random snapshot lists, verify reverse chronological order and metadata display
    - Run tests. Confirm all fail.
    - _Requirements: 20.2–20.7, 21.1–21.4, 22.3–22.6, 23.2, 23.3_

  - [ ] 11.3 GREEN: Fix any implementation gaps revealed by property tests
    - Address edge cases surfaced by fast-check generators across all front-end modules
    - Run all JS tests (unit + property). Confirm all pass.
    - _Requirements: 7.1–7.6, 8.2, 9.2–9.9, 10.2–10.4, 11.2–11.4, 12.1–12.4, 20.2–20.7, 21.1–21.4, 22.3–22.6, 23.2, 23.3_

- [ ] 12. Front-end checkpoint
  - Verify all JS unit tests and property tests pass: `npx vitest --run`
  - Verify Vite build succeeds: `npm run build`
  - Verify built HTML contains all expected modules (snapshot selector, status badges, artifact viewer, log viewer)
  - _Requirements: 8.1–8.4, 9.1–9.9, 10.1–10.7, 11.1–11.6, 12.1–12.4, 13.1, 20.1–20.7, 21.1–21.7, 22.1–22.8, 23.1–23.7_

- [ ] 13. Create AGENTS.md and AI Skills (red/green TDD)
  - [ ] 13.1 RED: Write validation tests for AGENTS.md and skills files
    - Write tests that verify AGENTS.md contains required sections: architecture overview, component development workflows, testing instructions, PR/review workflow, interface contracts
    - Write tests that verify each skills/*.md file contains required sections: preconditions, step-by-step instructions, expected outputs, verification criteria
    - Write tests that verify skills files use tool-agnostic language (no product-specific references)
    - Run tests. Confirm all fail.
    - _Requirements: 25.1, 25.2, 25.3, 25.4, 25.5, 25.6, 26.1, 26.8, 26.9_

  - [ ] 13.2 GREEN: Create AGENTS.md and skills files
    - Create `open.gismo/AGENTS.md` with architecture overview, component workflows (R, JS, Actions, YAML), testing instructions, PR workflow, interface contracts
    - Create `open.gismo/skills/add-workflow.md` — guided process for creating a new Workflow YAML
    - Create `open.gismo/skills/add-lconfig-hook.md` — guided process for implementing a new LoadData/SaveData pair
    - Create `open.gismo/skills/add-frontend-view.md` — guided process for adding a new front-end view
    - Create `open.gismo/skills/run-pipeline.md` — instructions for triggering and debugging a GitHub Actions pipeline
    - Create `open.gismo/skills/create-package-snapshot.md` — guided process for creating/updating a Package_Snapshot
    - Create `open.gismo/skills/create-project-snapshot.md` — guided process for creating a new Project_Snapshot
    - Run validation tests. Confirm all pass.
    - _Requirements: 25.1–25.6, 26.1–26.9_

- [ ] 14. Create example projects and demo data
  - [ ] 14.1 RED: Write tests for example project structure
    - Write tests verifying example project contains: workflow YAMLs, config files (packages.yaml, data-config.yaml, study-config.yaml), sample input data CSVs
    - Write tests verifying example workflows are parseable by workr::MakeWorkflowList
    - Write tests verifying example data-config.yaml maps all domains referenced in workflow specs
    - Run tests. Confirm all fail.
    - _Requirements: 24.1, 24.2, 24.3, 24.5_

  - [ ] 14.2 GREEN: Create example project files
    - Create `open.gismo/inst/examples/demo-study/` with workflow YAMLs, config files, and sample CSV data
    - Ensure example exercises all four components (Database, Analytics Engine, Web Front-end, Config)
    - Add README documenting the example project purpose, workflows, and expected output
    - Run tests. Confirm all pass.
    - _Requirements: 24.1, 24.2, 24.3, 24.4, 24.5, 24.6_

- [ ] 15. Final integration checkpoint
  - Run all R tests: `devtools::test()` — all unit + property tests pass
  - Run all JS tests: `npx vitest --run` — all unit + property tests pass
  - Run `devtools::check()` — no errors or warnings
  - Run `npm run build` in site/ — Vite build succeeds
  - Verify GitHub Actions YAML files are valid
  - Verify AGENTS.md and all skills files pass validation tests
  - Verify example project is complete and parseable
  - _Requirements: All (1–26)_

## Notes

- **{workr} integration**: Do NOT recreate {workr} functionality. Use `RunWorkflow`, `RunWorkflows`, `RunStep`, `MakeWorkflowList`, `RunQuery`, `pkgSnapshot` directly.
- **workr open.gismo branch**: If {workr} changes are needed (e.g., new exports), create an `open.gismo` branch in the workr repo. Do not build overlapping functionality.
- **Front-end migration**: The Vite app in `workr/site/` is the starting point. Migrate it to `open.gismo/site/` and extend — do not rewrite from scratch.
- **Package_Snapshot vs Project_Snapshot**: Package_Snapshots capture R package versions (managed by workr::pkgSnapshot on ss-* branches). Project_Snapshots capture pipeline output artifacts (managed by open.gismo on the data branch). These are distinct concepts.
- **Snapshot inheritance**: Newer Project_Snapshots inherit data from previous snapshots. Current snapshot data always takes precedence.
- **AI Skills**: Skills must be generic and tool-agnostic. Do not reference any specific AI coding assistant product.
- **Property-based testing**: Use hedgehog for R (minimum 100 iterations) and fast-check for JS (minimum 100 iterations). Properties are mandatory, not optional.
- **TDD discipline**: Every implementation task must have its tests written and confirmed failing (RED) before implementation begins (GREEN).
