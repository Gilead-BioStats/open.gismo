import { PHASES } from './constants.js';
import { parseYamlMeta } from './parsers.js';

/**
 * Load project configuration.
 * Returns { branch } from data/config.json, or falls back to
 * reading data/branches.json and picking the first branch.
 */
export async function loadConfig() {
  // Try config.json first (single-project mode)
  try {
    const res = await fetch('data/config.json');
    if (res.ok) return res.json();
  } catch { /* fall through */ }

  // Fall back to branches.json for backwards compatibility
  const res = await fetch('data/branches.json');
  if (!res.ok) throw new Error('No config.json or branches.json found');
  const branches = await res.json();
  if (!branches.length) throw new Error('No branches available');
  return { branch: branches[0] };
}

export async function loadBranch(branch) {
  const indexRes = await fetch(`data/${branch}/_index.json`);
  if (!indexRes.ok) throw new Error('No workflow data for this branch');
  const yamlPaths = await indexRes.json();

  const filesByPhase = {};
  yamlPaths.forEach(p => {
    const rel = p.replace('workflows/', '');
    for (const phase of PHASES) {
      if (rel.startsWith(phase.prefix)) {
        (filesByPhase[phase.idx] = filesByPhase[phase.idx] || []).push(p);
        break;
      }
    }
  });

  const phases = {};
  for (const idx of Object.keys(filesByPhase).map(Number).sort()) {
    const paths = filesByPhase[idx];
    const contents = await Promise.all(
      paths.map(p => fetch(`data/${branch}/${p}`).then(r => r.text()))
    );
    phases[idx] = contents.map((text, i) => {
      const meta = parseYamlMeta(text);
      meta._stem = paths[i].split('/').pop().replace('.yaml', '');
      meta._path = paths[i];
      return meta;
    });
  }
  return phases;
}

export async function loadWorkflowYaml(branch, yamlPath) {
  const res = await fetch(`data/${branch}/${yamlPath}`);
  if (!res.ok) throw new Error(`Could not load ${yamlPath}`);
  return res.text();
}

export async function loadSnapshots(branch) {
  const res = await fetch(`data/${branch}/snapshots.json`);
  if (!res.ok) throw new Error('No snapshots data');
  return res.json();
}

export async function loadSnapshotStatus(branch, snapshotId) {
  const res = await fetch(`data/${branch}/${snapshotId}/status.json`);
  if (!res.ok) throw new Error('No status data');
  return res.json();
}

export async function loadArtifact(branch, snapshotId, artifactPath) {
  const res = await fetch(`data/${branch}/${snapshotId}/output/${artifactPath}`);
  if (!res.ok) throw new Error(`Could not load artifact: ${artifactPath}`);
  return res.text();
}

export async function loadLog(branch, snapshotId) {
  const res = await fetch(`data/${branch}/${snapshotId}/log.json`);
  if (!res.ok) throw new Error('No log data');
  return res.json();
}
