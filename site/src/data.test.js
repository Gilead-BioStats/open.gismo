import { describe, it, expect } from 'vitest';
import { loadConfig, loadSnapshots, loadSnapshotStatus } from './data.js';

// ── loadConfig tests ─────────────────────────────────────────────────────────

describe('loadConfig', () => {
  it('returns branch from config.json when available', async () => {
    globalThis.fetch = async (url) => {
      if (url === 'data/config.json') {
        return { ok: true, json: async () => ({ branch: 'ss-dev' }) };
      }
      return { ok: false };
    };
    const config = await loadConfig();
    expect(config.branch).toBe('ss-dev');
  });

  it('falls back to branches.json when config.json is missing', async () => {
    globalThis.fetch = async (url) => {
      if (url === 'data/config.json') return { ok: false };
      if (url === 'data/branches.json') {
        return { ok: true, json: async () => ['ss-demo', 'ss-prod'] };
      }
      return { ok: false };
    };
    const config = await loadConfig();
    expect(config.branch).toBe('ss-demo');
  });

  it('throws when neither config.json nor branches.json is available', async () => {
    globalThis.fetch = async () => ({ ok: false, status: 404 });
    await expect(loadConfig()).rejects.toThrow();
  });
});

// Test phase grouping logic (from data.js loadBranch)
// The grouping assigns workflows to phases based on directory prefix
import { PHASES } from './constants.js';

function groupByPhase(yamlPaths) {
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
  return filesByPhase;
}

describe('workflow phase grouping', () => {
  it('assigns workflows to correct phases based on directory prefix', () => {
    const paths = [
      'workflows/1_mappings/AE.yaml',
      'workflows/1_mappings/DM.yaml',
      'workflows/2_metrics/kri0001.yaml',
      'workflows/3_reporting/report.yaml',
    ];
    const grouped = groupByPhase(paths);
    expect(grouped[1]).toHaveLength(2); // 1_mappings
    expect(grouped[2]).toHaveLength(1); // 2_metrics
    expect(grouped[3]).toHaveLength(1); // 3_reporting
  });

  it('assigns each workflow to exactly one phase', () => {
    const paths = [
      'workflows/0_config/setup.yaml',
      'workflows/1_mappings/AE.yaml',
      'workflows/2_metrics/kri0001.yaml',
      'workflows/4_modules/output.yaml',
    ];
    const grouped = groupByPhase(paths);
    const totalAssigned = Object.values(grouped).flat().length;
    expect(totalAssigned).toBe(paths.length);
  });

  it('handles empty path list', () => {
    expect(groupByPhase([])).toEqual({});
  });

  it('counts match the number of paths with each prefix', () => {
    const paths = [
      'workflows/2_metrics/kri0001.yaml',
      'workflows/2_metrics/kri0002.yaml',
      'workflows/2_metrics/kri0003.yaml',
    ];
    const grouped = groupByPhase(paths);
    expect(grouped[2]).toHaveLength(3);
  });
});


// ── Snapshot data loading tests ──────────────────────────────────────────────

describe('loadSnapshots', () => {
  it('fetches snapshots.json for the given branch and returns an array', async () => {
    const mockSnapshots = [
      { snapshot_id: 'ps-001', created_at: '2025-01-15T10:30:00Z', input_data_version: 'v1', package_snapshot: 'ss-dev' },
      { snapshot_id: 'ps-002', created_at: '2025-02-15T10:30:00Z', input_data_version: 'v2', package_snapshot: 'ss-dev' },
    ];
    globalThis.fetch = async (url) => {
      if (url === 'data/ss-dev/snapshots.json') {
        return { ok: true, json: async () => mockSnapshots };
      }
      return { ok: false };
    };
    const result = await loadSnapshots('ss-dev');
    expect(Array.isArray(result)).toBe(true);
    expect(result).toHaveLength(2);
    expect(result[0].snapshot_id).toBe('ps-001');
    expect(result[1].snapshot_id).toBe('ps-002');
  });

  it('returns snapshot objects with snapshot_id, created_at, input_data_version, package_snapshot', async () => {
    const mockSnapshots = [
      { snapshot_id: 'ps-001', created_at: '2025-01-15T10:30:00Z', input_data_version: 'Q1 cut', package_snapshot: 'ss-demo' },
    ];
    globalThis.fetch = async (url) => {
      if (url === 'data/ss-demo/snapshots.json') {
        return { ok: true, json: async () => mockSnapshots };
      }
      return { ok: false };
    };
    const result = await loadSnapshots('ss-demo');
    expect(result[0]).toHaveProperty('snapshot_id');
    expect(result[0]).toHaveProperty('created_at');
    expect(result[0]).toHaveProperty('input_data_version');
    expect(result[0]).toHaveProperty('package_snapshot');
  });

  it('throws an error when snapshots.json is not found', async () => {
    globalThis.fetch = async () => ({ ok: false, status: 404 });
    await expect(loadSnapshots('ss-missing')).rejects.toThrow();
  });
});

describe('loadSnapshotStatus', () => {
  it('fetches status.json for the given branch and snapshot, returns workflow status map', async () => {
    const mockStatus = {
      snapshot_id: 'ps-001',
      pipeline_status: 'completed',
      workflows: {
        Mapping_AE: {
          workflow_id: 'AE',
          workflow_type: 'Mapping',
          status: 'completed',
          steps: [{ name: 'gsm.mapping::AE_Map_Raw', output: 'Mapped_AE', status: 'completed', error: null }],
        },
      },
    };
    globalThis.fetch = async (url) => {
      if (url === 'data/ss-dev/ps-001/status.json') {
        return { ok: true, json: async () => mockStatus };
      }
      return { ok: false };
    };
    const result = await loadSnapshotStatus('ss-dev', 'ps-001');
    expect(result).toHaveProperty('workflows');
    expect(result.workflows).toHaveProperty('Mapping_AE');
    expect(result.workflows.Mapping_AE.status).toBe('completed');
  });

  it('throws an error when status.json is not found', async () => {
    globalThis.fetch = async () => ({ ok: false, status: 404 });
    await expect(loadSnapshotStatus('ss-dev', 'ps-999')).rejects.toThrow();
  });
});
