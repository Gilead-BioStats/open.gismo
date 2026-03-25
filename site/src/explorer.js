/**
 * Snapshot Explorer — sidebar tree of output artifacts + data viewer panel.
 *
 * buildExplorer(statusData, branch, snapshotId, onSelect) → HTMLElement
 *   Renders the full explorer layout: sidebar (tree + search) and main viewer.
 *
 * The artifact tree is derived from status.json: each workflow's completed
 * steps produce output domains, grouped by phase/workflow.
 */

import { esc } from './utils.js';
import { loadArtifact } from './data.js';
import { buildDataTable } from './artifacts.js';

/** SVG icons */
const dataIcon = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="3" x2="9" y2="21"/></svg>';
const folderIcon = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z"/></svg>';
const chevron = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg>';
const infoIcon = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';

/**
 * Extract a flat list of artifacts from status.json data.
 * Returns [{domain, phase, workflowId, workflowKey, stepName, path}]
 */
export function extractArtifacts(statusData) {
  if (!statusData?.workflows) return [];
  const artifacts = [];
  for (const [key, wf] of Object.entries(statusData.workflows)) {
    if (!wf.steps) continue;
    for (const step of wf.steps) {
      if (step.status === 'completed' && step.output) {
        artifacts.push({
          domain: step.output,
          phase: wf.phase,
          workflowId: wf.workflow_id,
          workflowKey: key,
          stepName: step.name,
          path: `${wf.phase}/${wf.workflow_id}/${step.output}.csv`,
        });
      }
    }
  }
  return artifacts;
}

/**
 * Group artifacts into a nested tree: { [phase]: { [workflowId]: artifact[] } }
 */
export function groupArtifacts(artifacts) {
  const tree = {};
  for (const a of artifacts) {
    if (!tree[a.phase]) tree[a.phase] = {};
    if (!tree[a.phase][a.workflowId]) tree[a.phase][a.workflowId] = [];
    tree[a.phase][a.workflowId].push(a);
  }
  return tree;
}

/**
 * Build the sidebar tree HTML from grouped artifacts.
 */
function buildSidebarTree(tree) {
  let h = '';
  for (const [phase, workflows] of Object.entries(tree)) {
    h += `<div class="explorer-phase">`;
    h += `<div class="explorer-phase-header" data-phase="${esc(phase)}">${chevron} ${folderIcon} <span>${esc(phase)}</span></div>`;
    h += `<div class="explorer-phase-children">`;
    for (const [wfId, artifacts] of Object.entries(workflows)) {
      h += `<div class="explorer-wf">`;
      h += `<div class="explorer-wf-header" data-wf="${esc(wfId)}">${chevron} ${folderIcon} <span>${esc(wfId)}</span></div>`;
      h += `<div class="explorer-wf-children">`;
      for (const a of artifacts) {
        h += `<div class="explorer-item" data-path="${esc(a.path)}" data-domain="${esc(a.domain)}" data-search="${esc(a.domain.toLowerCase())}">`;
        h += `${dataIcon} <span class="explorer-item-name">${esc(a.domain)}</span>`;
        h += `<span class="explorer-item-info" title="Produced by ${esc(a.workflowKey)} step: ${esc(a.stepName)}">${infoIcon}</span>`;
        h += `</div>`;
      }
      h += `</div></div>`;
    }
    h += `</div></div>`;
  }
  return h;
}

/**
 * Build the full Snapshot Explorer element.
 *
 * @param {object} statusData - Parsed status.json
 * @param {string} branch
 * @param {string} snapshotId
 * @returns {HTMLElement}
 */
export function buildExplorer(statusData, branch, snapshotId) {
  const artifacts = extractArtifacts(statusData);
  const tree = groupArtifacts(artifacts);

  const el = document.createElement('div');
  el.className = 'explorer-layout';

  // Sidebar
  const sidebar = document.createElement('div');
  sidebar.className = 'explorer-sidebar';
  sidebar.innerHTML =
    `<div class="explorer-search"><input type="text" placeholder="Search artifacts…" aria-label="Search artifacts" class="explorer-search-input"></div>` +
    `<div class="explorer-tree">${artifacts.length ? buildSidebarTree(tree) : '<div class="explorer-empty">No artifacts available</div>'}</div>`;
  el.appendChild(sidebar);

  // Main viewer
  const viewer = document.createElement('div');
  viewer.className = 'explorer-viewer';
  viewer.innerHTML = '<div class="explorer-placeholder">Select an artifact to view</div>';
  el.appendChild(viewer);

  // Wire up tree expand/collapse
  sidebar.querySelectorAll('.explorer-phase-header, .explorer-wf-header').forEach(hdr => {
    hdr.addEventListener('click', () => {
      const children = hdr.nextElementSibling;
      const expanded = children.style.display !== 'none';
      children.style.display = expanded ? 'none' : '';
      hdr.classList.toggle('collapsed', !expanded);
    });
  });

  // Wire up search
  const searchInput = sidebar.querySelector('.explorer-search-input');
  searchInput.addEventListener('input', () => {
    const q = searchInput.value.toLowerCase();
    sidebar.querySelectorAll('.explorer-item').forEach(item => {
      const match = !q || item.dataset.search.includes(q);
      item.style.display = match ? '' : 'none';
    });
    // Show phases/workflows that have visible children
    sidebar.querySelectorAll('.explorer-wf').forEach(wf => {
      const hasVisible = wf.querySelector('.explorer-item:not([style*="display: none"])');
      wf.style.display = hasVisible ? '' : 'none';
    });
    sidebar.querySelectorAll('.explorer-phase').forEach(phase => {
      const hasVisible = phase.querySelector('.explorer-wf:not([style*="display: none"])');
      phase.style.display = hasVisible ? '' : 'none';
    });
  });

  // Wire up artifact selection
  sidebar.addEventListener('click', async (e) => {
    const item = e.target.closest('.explorer-item');
    if (!item) return;

    // Highlight selected
    sidebar.querySelectorAll('.explorer-item').forEach(i => i.classList.remove('selected'));
    item.classList.add('selected');

    const path = item.dataset.path;
    const domain = item.dataset.domain;

    viewer.innerHTML = '<div class="explorer-loading"><span class="spinner"></span> Loading…</div>';
    try {
      const text = await loadArtifact(branch, snapshotId, path);
      viewer.innerHTML = '';
      // Header
      const header = document.createElement('div');
      header.className = 'explorer-viewer-header';
      header.innerHTML = `<span class="explorer-viewer-title">${dataIcon} ${esc(domain)}</span><span class="explorer-viewer-snap">${esc(snapshotId)}</span>`;
      viewer.appendChild(header);
      // Data table
      const table = buildDataTable(text);
      table.classList.add('explorer-table-wrap');
      viewer.appendChild(table);
    } catch (err) {
      viewer.innerHTML = `<div class="explorer-error">Could not load artifact: ${esc(err.message)}</div>`;
    }
  });

  return el;
}

/**
 * Select an artifact in an existing explorer by path.
 */
export function selectArtifact(explorerEl, artifactPath) {
  const item = explorerEl.querySelector(`.explorer-item[data-path="${CSS.escape(artifactPath)}"]`);
  if (item) item.click();
}
