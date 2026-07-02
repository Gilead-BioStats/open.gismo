#!/usr/bin/env node
// generate-manifest.js — generate _index.json and status.json for a local
// site preview, from a directory containing workflows/ and output/.
//
// Adapted from the project's build-site.sh (used to build the deployed
// `demo` branch), parameterized to target any directory so it can be run
// against site/public/ for local development.
//
// Usage:
//   node scripts/generate-manifest.js [targetDir]
// Default targetDir: public

import fs from 'fs';
import path from 'path';

const targetDir = process.argv[2] || 'public';
const workflowsDir = path.join(targetDir, 'workflows');
const outputDir = path.join(targetDir, 'output');
const indexPath = path.join(targetDir, '_index.json');
const statusPath = path.join(targetDir, 'status.json');

function listYamlFiles(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...listYamlFiles(full));
    } else if (/\.(yaml|yml)$/.test(entry.name)) {
      results.push(full);
    }
  }
  return results;
}

let index = [];
if (fs.existsSync(workflowsDir)) {
  index = listYamlFiles(workflowsDir)
    .map(f => path.relative(targetDir, f).split(path.sep).join('/'))
    .sort();
}
fs.writeFileSync(indexPath, JSON.stringify(index));
console.log(`Generated ${indexPath} (${index.length} entries)`);

function parseMeta(text) {
  const meta = {};
  const metaMatch = text.match(/^meta:\n((?:  .+\n)*)/m);
  if (metaMatch) {
    metaMatch[1].split('\n').forEach(line => {
      const m = line.match(/^  (\w+):\s*(.+)/);
      if (m) meta[m[1]] = m[2].replace(/["']/g, '').trim();
    });
  }
  return meta;
}

function parseSteps(text) {
  const steps = [];
  const stepsMatch = text.match(/^steps:\n((?:[\s#].+\n)*)/m);
  if (!stepsMatch) return steps;
  const lines = stepsMatch[1].split('\n');
  let current = null;
  for (const line of lines) {
    const outputMatch = line.match(/^  - output:\s*(.+)/);
    const nameMatch = line.match(/^    name:\s*(.+)/);
    if (outputMatch) {
      current = { output: outputMatch[1].trim(), name: '' };
      steps.push(current);
    } else if (nameMatch && current) {
      current.name = nameMatch[1].trim();
    }
  }
  return steps;
}

const PHASE_MAP = { '1_mappings': 'Mapped', '2_metrics': 'Analysis', '3_reporting': 'Reporting', '4_modules': 'Module' };
const workflows = {};

for (const yamlPath of index) {
  const text = fs.readFileSync(path.join(targetDir, yamlPath), 'utf8');
  const meta = parseMeta(text);
  const steps = parseSteps(text);
  const parts = yamlPath.split('/');
  const phase = parts[1]; // e.g. 1_mappings
  const stem = path.basename(yamlPath, path.extname(yamlPath));
  const wfType = meta.Type || PHASE_MAP[phase] || 'Unknown';
  const wfId = meta.ID || stem;
  const wfKey = wfType + '_' + wfId;

  const wfSteps = steps.length > 0 ? steps : [{ output: wfType + '_' + wfId, name: '=' }];

  const wfDir = path.join(outputDir, phase, wfId);
  const wfDirExists = fs.existsSync(wfDir);
  const dirFiles = wfDirExists ? fs.readdirSync(wfDir) : [];
  const wfCompleted = dirFiles.some(f => f.endsWith('.csv') || f.endsWith('.html'));

  const stepStatuses = [];
  for (const s of wfSteps) {
    const csvFile = s.output + '.csv';
    if (dirFiles.includes(csvFile)) {
      stepStatuses.push({ name: s.name, output: s.output, status: 'completed', error: null });
    }
  }

  if (phase === '4_modules') {
    for (const f of dirFiles.filter(f => f.endsWith('.html'))) {
      const name = f.replace('.html', '');
      stepStatuses.push({ name: 'html_report', output: name, status: 'completed', error: null });
    }
  }

  if (stepStatuses.length === 0 && !wfCompleted) {
    stepStatuses.push({ name: wfSteps[0]?.name || '?', output: wfSteps[0]?.output || '?', status: 'not_run', error: null });
  }

  const allCompleted = wfCompleted && stepStatuses.every(s => s.status === 'completed');
  const anyFailed = stepStatuses.some(s => s.status === 'failed');

  workflows[wfKey] = {
    workflow_id: wfId,
    workflow_type: wfType,
    phase,
    status: allCompleted ? 'completed' : anyFailed ? 'failed' : 'not_run',
    steps: stepStatuses,
  };
}

const status = { pipeline_status: 'completed', workflows };
fs.writeFileSync(statusPath, JSON.stringify(status, null, 2));
console.log(`Generated ${statusPath} (${Object.keys(workflows).length} workflows)`);
