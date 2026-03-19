# open.gismo — Post-MVP Backlog

## Deferred from README comparison

- [ ] **Web Front-end — Code Viewer**: Display the R source code of functions called in each workflow step (README mentions showing "code" for each workflow set)
- [ ] **Web Front-end — Data Model Visualization**: Visual diagram showing how data domains flow and transform across steps/phases (README mentions "View the data model at each step")
- [ ] **Config — External Workflow Fetching**: Support fetching workflow YAMLs from arbitrary external GitHub repos at runtime (not just during Package_Snapshot creation)

## Future enhancements to consider

- [ ] **Web Front-end — Project Snapshot Comparison**: Side-by-side diff of outputs between two Project_Snapshots to identify changes from different input data versions
- [ ] **Analytics Engine — Partial Pipeline Re-runs**: Re-run only failed or not_run steps within a Project_Snapshot without re-executing completed steps
- [ ] **Analytics Engine — Shiny/WASM Engine**: Alternative analytics engine using R Shiny with WASM for browser-based execution
- [ ] **Database — Alternative Storage Backends**: Concrete implementations for Supabase and AWS S3 + DuckDB backends
- [ ] **Platform — Authentication / Access Control**: Support for private repos, token management, and role-based access to projects
- [ ] **Web Front-end — Report Viewer**: Render HTML/PDF reports produced by workflow steps directly in the front-end

## AI Skills — Deferred

- [ ] **Kiro Steering Files**: Always-included steering with project architecture overview; file-match steering per component (*.R, *.yml, site/**)
- [ ] **Architecture Documentation for Agents**: Machine-readable component interface contracts, data flow diagrams, decision trees for cross-component changes
