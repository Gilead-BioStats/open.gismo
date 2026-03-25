import './style.css';
import { esc } from './utils.js';
import { loadConfig, loadBranch, loadWorkflowYaml, loadSnapshots, loadSnapshotStatus, loadLog } from './data.js';
import { buildSnapshotSelector } from './snapshots.js';
import { buildPipeline, setPipelineBranch } from './pipeline.js';
import { buildPackagesTable, loadPackages, loadSnapshotDate } from './packages.js';
import { setFilter, applyFilters, resetFilters } from './filters.js';
import { buildDetailView } from './detail.js';

let currentBranch = '';
let currentPhases = null;
let compactMode = false;
let currentSnapshotId = null;
let currentSnapshotStatus = null;
let currentLog = null;

function showTab(name) {
  document.getElementById('workflowsTab').style.display = name === 'workflows' ? '' : 'none';
  document.getElementById('packagesTab').style.display = name === 'packages' ? '' : 'none';
  document.querySelectorAll('.tab-btn').forEach(b => {
    const active = b.dataset.tab === name;
    b.classList.toggle('active', active);
    b.setAttribute('aria-selected', active);
  });
}

function renderWorkflows() {
  if (!currentPhases) return;
  const wTab = document.getElementById('workflowsTab');

  // Preserve snapshot selector if it exists
  const existingSelector = wTab.querySelector('.snapshot-selector');

  wTab.innerHTML = buildPipeline(currentPhases, compactMode);
  wTab.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => setFilter(btn.dataset.group));
  });
  resetFilters();
  updateToggleBtn();

  // Re-insert snapshot selector at the top
  if (existingSelector) {
    wTab.insertBefore(existingSelector, wTab.firstChild);
  }
}

function updateToggleBtn() {
  const btn = document.getElementById('viewToggle');
  if (btn) btn.textContent = compactMode ? 'Detailed' : 'Compact';
}

async function onSnapshotSelect(id) {
  currentSnapshotId = id;
  try {
    currentSnapshotStatus = await loadSnapshotStatus(currentBranch, id);
  } catch { currentSnapshotStatus = null; }
  try {
    currentLog = await loadLog(currentBranch, id);
  } catch { currentLog = null; }
}

async function openDetail(yamlPath) {
  const modal = document.getElementById('detailModal');
  const content = document.getElementById('detailModalContent');
  modal.style.display = '';
  content.innerHTML = '<div class="loading"><span class="spinner"></span> Loading workflow…</div>';
  document.body.style.overflow = 'hidden';
  try {
    const text = await loadWorkflowYaml(currentBranch, yamlPath);
    content.innerHTML = buildDetailView(text, yamlPath, null, currentSnapshotId, currentBranch, currentLog);
    content.querySelector('.modal-close').addEventListener('click', closeDetail);
    const yamlToggle = content.querySelector('.yaml-toggle');
    if (yamlToggle) {
      yamlToggle.addEventListener('click', () => {
        const parsed = content.querySelector('.detail-parsed');
        const yaml = content.querySelector('.detail-yaml');
        const showing = yaml.style.display !== 'none';
        parsed.style.display = showing ? '' : 'none';
        yaml.style.display = showing ? 'none' : '';
        yamlToggle.textContent = showing ? 'Show YAML' : 'Show Details';
      });
    }
  } catch (err) {
    content.innerHTML = `<div class="error-msg">Error loading workflow: ${esc(err.message)}</div>`;
  }
}

function closeDetail() {
  document.getElementById('detailModal').style.display = 'none';
  document.getElementById('detailModalContent').innerHTML = '';
  document.body.style.overflow = '';
}

async function init() {
  const wTab = document.getElementById('workflowsTab');
  const pTab = document.getElementById('packagesTab');
  const branchLabel = document.getElementById('projectBranch');

  try {
    // Load project config to get the branch
    const config = await loadConfig();
    currentBranch = config.branch;
    setPipelineBranch(currentBranch);
    branchLabel.textContent = currentBranch;

    // Load workflows, snapshots, and packages in parallel
    const [phases, snapshots, pkgResult] = await Promise.allSettled([
      loadBranch(currentBranch),
      loadSnapshots(currentBranch),
      Promise.all([loadPackages(currentBranch), loadSnapshotDate(currentBranch)]),
    ]);

    // Render workflows
    if (phases.status === 'fulfilled') {
      currentPhases = phases.value;
      if (Object.keys(currentPhases).length === 0) {
        wTab.innerHTML = '<div class="loading">No workflows found</div>';
      } else {
        renderWorkflows();
        document.getElementById('searchInput').value = '';
      }
    } else {
      wTab.innerHTML = `<div class="error-msg">Error loading workflows: ${esc(phases.reason?.message || 'Unknown error')}</div>`;
    }

    // Render snapshot selector
    currentSnapshotId = null;
    currentSnapshotStatus = null;
    currentLog = null;
    if (snapshots.status === 'fulfilled' && snapshots.value?.snapshots?.length) {
      const selectorEl = buildSnapshotSelector(snapshots.value.snapshots, onSnapshotSelect);
      wTab.insertBefore(selectorEl, wTab.firstChild);
    }

    // Render packages tab
    if (pkgResult.status === 'fulfilled') {
      const [rows, snapDate] = pkgResult.value;
      pTab.innerHTML = buildPackagesTable(rows, snapDate);
    } else {
      pTab.innerHTML = '<div class="loading">No manifest.csv available</div>';
    }
  } catch (err) {
    wTab.innerHTML = `<div class="error-msg">Could not load project: ${esc(err.message)}</div>`;
  }
}

// Wire up tabs
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => showTab(btn.dataset.tab));
});

// Wire up compact/detailed toggle
document.getElementById('viewToggle').addEventListener('click', () => {
  compactMode = !compactMode;
  renderWorkflows();
});

// Wire up search
document.getElementById('searchInput').addEventListener('input', applyFilters);

// Delegate info-button clicks on the workflows tab
document.getElementById('workflowsTab').addEventListener('click', (e) => {
  const btn = e.target.closest('.card-info-btn');
  if (btn && btn.dataset.path) {
    e.stopPropagation();
    openDetail(btn.dataset.path);
  }
});

// Close modal on overlay click or Escape
document.getElementById('detailModal').addEventListener('click', (e) => {
  if (e.target === e.currentTarget) closeDetail();
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && document.getElementById('detailModal').style.display !== 'none') {
    closeDetail();
  }
});

init();
