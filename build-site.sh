#!/usr/bin/env bash
set -euo pipefail

# Build the open.gismo site for the current project branch.
#
# This script:
#   1. Extracts site source files from a source branch (default: dev) using git show
#   2. Generates _index.json from workflow YAML files
#   3. Generates status.json from workflow YAMLs + output/ directory
#   4. Runs npm ci + npm run build to produce a single index.html
#
# Usage:
#   ./build-site.sh              # uses dev as source branch
#   ./build-site.sh main         # uses main as source branch

SOURCE_BRANCH="${1:-dev}"

echo "=== Building site from source branch: $SOURCE_BRANCH ==="

# --- 1. Extract site files from source branch ---

# List of files to extract (no tests, no public data, no node_modules)
SITE_FILES=(
  site/index.html
  site/package.json
  site/package-lock.json
  site/vite.config.js
  site/src/artifacts.js
  site/src/constants.js
  site/src/data.js
  site/src/datatable.js
  site/src/detail.js
  site/src/explorer.js
  site/src/filters.js
  site/src/logs.js
  site/src/main.js
  site/src/packages.js
  site/src/parsers.js
  site/src/pipeline.js
  site/src/snapshots.js
  site/src/status.js
  site/src/style.css
  site/src/utils.js
)

mkdir -p site/src

for f in "${SITE_FILES[@]}"; do
  git show "${SOURCE_BRANCH}:${f}" > "$f" 2>/dev/null || echo "  WARN: $f not found on $SOURCE_BRANCH"
done

echo "  Extracted ${#SITE_FILES[@]} site files from $SOURCE_BRANCH"

# --- 2. Generate _index.json ---

if [ -d workflows ]; then
  find workflows -name "*.yaml" -o -name "*.yml" | sort | \
    node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.stringify(d.trim().split('\n').filter(Boolean))))" > _index.json
  COUNT=$(node -e "console.log(JSON.parse(require('fs').readFileSync('_index.json','utf8')).length)")
  echo "  Generated _index.json ($COUNT entries)"
else
  echo "[]" > _index.json
  echo "  Generated empty _index.json (no workflows/ directory)"
fi

# --- 3. Generate status.json ---

node -e "
const fs = require('fs');
const path = require('path');

// Simple YAML parser for our workflow files (key: value in meta block + steps array)
function parseMeta(text) {
  const meta = {};
  const metaMatch = text.match(/^meta:\\n((?:  .+\\n)*)/m);
  if (metaMatch) {
    metaMatch[1].split('\\n').forEach(line => {
      const m = line.match(/^  (\\w+):\\s*(.+)/);
      if (m) meta[m[1]] = m[2].replace(/[\"']/g, '').trim();
    });
  }
  return meta;
}

function parseSteps(text) {
  const steps = [];
  const stepsMatch = text.match(/^steps:\\n((?:[\\s#].+\\n)*)/m);
  if (!stepsMatch) return steps;
  const lines = stepsMatch[1].split('\\n');
  let current = null;
  for (const line of lines) {
    const outputMatch = line.match(/^  - output:\\s*(.+)/);
    const nameMatch = line.match(/^    name:\\s*(.+)/);
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
const index = JSON.parse(fs.readFileSync('_index.json', 'utf8'));
const workflows = {};

for (const yamlPath of index) {
  const text = fs.readFileSync(yamlPath, 'utf8');
  const meta = parseMeta(text);
  const steps = parseSteps(text);
  const parts = yamlPath.split('/');
  const phase = parts[1]; // e.g. 1_mappings
  const stem = path.basename(yamlPath, '.yaml');
  const wfType = meta.Type || PHASE_MAP[phase] || 'Unknown';
  const wfId = meta.ID || stem;
  const wfKey = wfType + '_' + wfId; // e.g. Mapped_AE, Analysis_kri0001

  // For mappings (no explicit steps), create a single synthetic step
  const wfSteps = steps.length > 0 ? steps : [{ output: wfType + '_' + wfId, name: '=' }];

  // Determine workflow completion by checking output/{phase}/{workflowId}/
  const wfDir = path.join('output', phase, wfId);
  const wfDirExists = fs.existsSync(wfDir);
  const dirFiles = wfDirExists ? fs.readdirSync(wfDir) : [];
  const wfCompleted = dirFiles.some(f => f.endsWith('.csv') || f.endsWith('.html'));

  // Only include steps that have actual files on disk
  const stepStatuses = [];

  // Check each YAML step for a matching CSV
  for (const s of wfSteps) {
    const csvFile = s.output + '.csv';
    if (dirFiles.includes(csvFile)) {
      stepStatuses.push({ name: s.name, output: s.output, status: 'completed', error: null });
    }
  }

  // For modules: also list HTML files as outputs
  if (phase === '4_modules') {
    for (const f of dirFiles.filter(f => f.endsWith('.html'))) {
      const name = f.replace('.html', '');
      stepStatuses.push({ name: 'html_report', output: name, status: 'completed', error: null });
    }
  }

  // If no files found at all, mark as not_run with a single placeholder step
  if (stepStatuses.length === 0 && !wfCompleted) {
    stepStatuses.push({ name: wfSteps[0]?.name || '?', output: wfSteps[0]?.output || '?', status: 'not_run', error: null });
  }

  const allCompleted = wfCompleted && stepStatuses.every(s => s.status === 'completed');
  const anyFailed = stepStatuses.some(s => s.status === 'failed');

  workflows[wfKey] = {
    workflow_id: wfId,
    workflow_type: wfType,
    phase: phase,
    status: allCompleted ? 'completed' : anyFailed ? 'failed' : 'not_run',
    steps: stepStatuses
  };
}

const status = { pipeline_status: 'completed', workflows };
fs.writeFileSync('status.json', JSON.stringify(status, null, 2));
console.log('  Generated status.json (' + Object.keys(workflows).length + ' workflows)');
"

# --- 4. Install deps and build ---

cd site
npm ci --silent
npm run build
cd ..

echo ""
echo "=== Site built successfully ==="
echo "Output: index.html ($(wc -c < index.html | tr -d ' ') bytes)"
