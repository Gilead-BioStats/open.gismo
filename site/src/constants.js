export const PHASES = [
  { prefix: '0_', label: 'Config',    idx: 0, color: '#9ca3af', countLabel: 'files' },
  { prefix: '1_', label: 'Mappings',  idx: 1, color: '#60a5fa', countLabel: 'data mappings' },
  { prefix: '2_', label: 'Metrics',   idx: 2, color: '#a78bfa', countLabel: 'analysis workflows' },
  { prefix: '3_', label: 'Reporting', idx: 3, color: '#34d399', countLabel: 'reporting workflows' },
  { prefix: '4_', label: 'Modules',   idx: 4, color: '#fb923c', countLabel: 'output modules' },
];

export const METRIC_GROUP_LABELS = {
  kri: 'KRI — Site Level',
  cou: 'Country Level',
  qtl: 'QTL — Study Level',
  end: 'Endpoints — Subject Level',
  srs: 'Composite',
};

export const METRIC_GROUP_ORDER = ['kri', 'cou', 'qtl', 'end', 'srs', 'other'];
