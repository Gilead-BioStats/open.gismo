import { describe, it, expect, beforeEach } from 'vitest';
import {
  DEFAULT_CONFIG,
  getRunnerConfig,
  saveRunnerConfig,
  statusBadge,
  hasActiveRun,
} from './runner.js';

describe('statusBadge', () => {
  it('maps completed+success to a success badge', () => {
    expect(statusBadge('completed', 'success')).toEqual({ label: 'success', cssClass: 'run-success' });
  });

  it('maps completed+failure to a failure badge', () => {
    expect(statusBadge('completed', 'failure')).toEqual({ label: 'failure', cssClass: 'run-failure' });
  });

  it('maps completed with other conclusions to a neutral badge', () => {
    expect(statusBadge('completed', 'cancelled')).toEqual({ label: 'cancelled', cssClass: 'run-neutral' });
  });

  it('maps in_progress to an active badge', () => {
    expect(statusBadge('in_progress', null)).toEqual({ label: 'running', cssClass: 'run-active' });
  });

  it('treats missing status as queued', () => {
    expect(statusBadge(undefined, null)).toEqual({ label: 'queued', cssClass: 'run-neutral' });
  });
});

describe('hasActiveRun', () => {
  it('is true when a run is queued or in progress', () => {
    expect(hasActiveRun([{ status: 'completed' }, { status: 'queued' }])).toBe(true);
    expect(hasActiveRun([{ status: 'in_progress' }])).toBe(true);
  });

  it('is false when all runs are completed or the list is empty', () => {
    expect(hasActiveRun([{ status: 'completed' }])).toBe(false);
    expect(hasActiveRun([])).toBe(false);
  });
});

describe('runner config storage', () => {
  beforeEach(() => localStorage.clear());

  it('returns defaults when nothing is stored', () => {
    expect(getRunnerConfig()).toEqual(DEFAULT_CONFIG);
  });

  it('round-trips saved config merged over defaults', () => {
    saveRunnerConfig({ token: 'ghp_x', repo: 'org/repo' });
    const cfg = getRunnerConfig();
    expect(cfg.token).toBe('ghp_x');
    expect(cfg.repo).toBe('org/repo');
    expect(cfg.workflow).toBe(DEFAULT_CONFIG.workflow);
  });

  it('falls back to defaults on corrupted storage', () => {
    localStorage.setItem('gismo.runner.config', '{not json');
    expect(getRunnerConfig()).toEqual(DEFAULT_CONFIG);
  });
});
