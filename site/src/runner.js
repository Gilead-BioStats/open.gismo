/**
 * GitHub Actions runner — trigger and monitor real study runs.
 *
 * Dispatches the study repo's `Run Study` workflow (workflow_dispatch) via
 * the GitHub REST API and polls run + job-step status. The site stays
 * static: auth is a user-supplied PAT kept in localStorage, never committed.
 *
 * After a run succeeds, its `study-output` artifact is ingested into
 * site/public/ with `Rscript demo/fetch_run_results.R <run id>` (artifacts
 * hold an R .rds bundle the browser can't parse, so conversion happens in R).
 */

import { esc } from './utils.js';

const STORAGE_KEY = 'gismo.runner.config';
const POLL_MS = 15000;

export const DEFAULT_CONFIG = {
  token: '',
  repo: 'Gilead-BioStats/open.gismo',
  workflow: 'run-study.yaml',
  branch: 'workr-implementation',
};

export function getRunnerConfig() {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
    return { ...DEFAULT_CONFIG, ...stored };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

export function saveRunnerConfig(cfg) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
}

function api(cfg, path, options = {}) {
  return fetch(`https://api.github.com${path}`, {
    ...options,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${cfg.token}`,
      'X-GitHub-Api-Version': '2022-11-28',
      ...(options.headers || {}),
    },
  });
}

export async function listRuns(cfg, perPage = 10) {
  const res = await api(cfg, `/repos/${cfg.repo}/actions/workflows/${cfg.workflow}/runs?per_page=${perPage}`);
  if (!res.ok) throw new Error(`List runs failed: ${res.status}`);
  const data = await res.json();
  return data.workflow_runs || [];
}

export async function dispatchRun(cfg) {
  const res = await api(cfg, `/repos/${cfg.repo}/actions/workflows/${cfg.workflow}/dispatches`, {
    method: 'POST',
    body: JSON.stringify({ ref: cfg.branch }),
  });
  if (res.status !== 204) throw new Error(`Dispatch failed: ${res.status}`);
}

export async function getRunSteps(cfg, runId) {
  const res = await api(cfg, `/repos/${cfg.repo}/actions/runs/${runId}/jobs`);
  if (!res.ok) throw new Error(`Get jobs failed: ${res.status}`);
  const data = await res.json();
  const job = (data.jobs || [])[0];
  return job ? job.steps || [] : [];
}

/** Status → {label, cssClass} for a run or step. Pure, unit-testable. */
export function statusBadge(status, conclusion) {
  if (status === 'completed') {
    if (conclusion === 'success') return { label: 'success', cssClass: 'run-success' };
    if (conclusion === 'failure') return { label: 'failure', cssClass: 'run-failure' };
    return { label: conclusion || 'completed', cssClass: 'run-neutral' };
  }
  if (status === 'in_progress') return { label: 'running', cssClass: 'run-active' };
  return { label: status || 'queued', cssClass: 'run-neutral' };
}

/** True if any run in the list is still queued or running. Pure. */
export function hasActiveRun(runs) {
  return runs.some(r => r.status === 'queued' || r.status === 'in_progress');
}

function runDuration(run) {
  const start = new Date(run.run_started_at || run.created_at);
  const end = run.status === 'completed' ? new Date(run.updated_at) : new Date();
  const mins = Math.max(0, Math.round((end - start) / 60000));
  return `${mins}m`;
}

function renderRunRow(run) {
  const badge = statusBadge(run.status, run.conclusion);
  return `
    <div class="run-row" data-run-id="${run.id}">
      <span class="run-badge ${badge.cssClass}">${esc(badge.label)}</span>
      <a href="${esc(run.html_url)}" target="_blank" rel="noopener" class="run-link">#${run.run_number}</a>
      <span class="run-meta">${esc(run.head_branch)} · ${esc(runDuration(run))} · ${esc(new Date(run.created_at).toLocaleString())}</span>
      <button class="run-steps-btn" data-run-id="${run.id}">Steps</button>
      ${run.conclusion === 'success' ? `<code class="run-ingest">Rscript demo/fetch_run_results.R ${run.id}</code>` : ''}
    </div>
    <div class="run-steps" id="steps-${run.id}" style="display:none"></div>`;
}

function renderSettings(cfg) {
  return `
    <div class="runner-settings">
      <label>Repo <input id="runnerRepo" value="${esc(cfg.repo)}"></label>
      <label>Workflow <input id="runnerWorkflow" value="${esc(cfg.workflow)}"></label>
      <label>Branch <input id="runnerBranch" value="${esc(cfg.branch)}"></label>
      <label>Token <input id="runnerToken" type="password" placeholder="ghp_… (actions read/write)" value="${esc(cfg.token)}"></label>
      <button id="runnerSave" class="toggle-btn">Save</button>
      <button id="runnerDispatch" class="toggle-btn runner-go">▶ Run Study</button>
      <span id="runnerMsg" class="runner-msg"></span>
    </div>`;
}

/**
 * Build the Runs panel. Renders settings + run list, wires dispatch and
 * step drill-down, and polls while a run is active.
 */
export function buildRunnerPanel() {
  const el = document.createElement('div');
  el.className = 'runner-panel';
  let pollTimer = null;

  const msg = text => {
    const m = el.querySelector('#runnerMsg');
    if (m) m.textContent = text;
  };

  const readForm = () => ({
    repo: el.querySelector('#runnerRepo').value.trim(),
    workflow: el.querySelector('#runnerWorkflow').value.trim(),
    branch: el.querySelector('#runnerBranch').value.trim(),
    token: el.querySelector('#runnerToken').value.trim(),
  });

  async function refresh() {
    const cfg = getRunnerConfig();
    const list = el.querySelector('#runnerRuns');
    if (!cfg.token) {
      list.innerHTML = '<div class="loading">Enter a GitHub token above to list and trigger runs.</div>';
      return;
    }
    try {
      const runs = await listRuns(cfg);
      list.innerHTML = runs.length
        ? runs.map(renderRunRow).join('')
        : '<div class="loading">No runs yet.</div>';
      clearTimeout(pollTimer);
      if (hasActiveRun(runs)) pollTimer = setTimeout(refresh, POLL_MS);
    } catch (err) {
      list.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    }
  }

  el.innerHTML = `
    ${renderSettings(getRunnerConfig())}
    <div id="runnerRuns" class="runner-runs"><div class="loading">Loading runs…</div></div>`;

  el.addEventListener('click', async e => {
    if (e.target.id === 'runnerSave') {
      saveRunnerConfig(readForm());
      msg('Saved.');
      refresh();
    } else if (e.target.id === 'runnerDispatch') {
      const cfg = readForm();
      saveRunnerConfig(cfg);
      msg('Dispatching…');
      try {
        await dispatchRun(cfg);
        msg('Run dispatched — it should appear below shortly.');
        setTimeout(refresh, 4000);
      } catch (err) {
        msg(`Dispatch failed: ${err.message}`);
      }
    } else if (e.target.classList.contains('run-steps-btn')) {
      const runId = e.target.dataset.runId;
      const box = el.querySelector(`#steps-${runId}`);
      if (box.style.display !== 'none') {
        box.style.display = 'none';
        return;
      }
      box.style.display = '';
      box.innerHTML = '<div class="loading">Loading steps…</div>';
      try {
        const steps = await getRunSteps(getRunnerConfig(), runId);
        box.innerHTML = steps.map(s => {
          const badge = statusBadge(s.status, s.conclusion);
          return `<div class="run-step"><span class="run-badge ${badge.cssClass}">${esc(badge.label)}</span> ${esc(s.name)}</div>`;
        }).join('') || '<div class="loading">No steps reported.</div>';
      } catch (err) {
        box.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
      }
    }
  });

  refresh();
  return el;
}
