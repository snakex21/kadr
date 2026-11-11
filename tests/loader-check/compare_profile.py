"""Summarize warm iterations 1..3, retaining raw timings and cold iteration 0."""
from pathlib import Path
import csv
import json
import statistics

HERE = Path(__file__).resolve().parent
report = {}
for version in ('before', 'after'):
    with (HERE / f'profile-{version}.csv').open(newline='') as f:
        rows = list(csv.DictReader(f))
    report[version] = {}
    for kind in ('JPEG', 'PNG', 'QOI'):
        measured = [row for row in rows if row['format'] == kind and row['iteration'] != '0']
        assert len(measured) == 3
        report[version][kind] = {key: round(statistics.mean(float(row[key]) for row in measured), 3)
                                 for key in ('load_ms', 'preview_ms', 'access_ms', 'sample_ms', 'total_ms')}
print('12 MP, warm mean of 3 iterations; milliseconds; ReleaseSmall x86 Pentium III')
print('format | load before->after | preview before->after | access after | sampling after | request/result before->after')
for kind in ('JPEG', 'PNG', 'QOI'):
    a, b = report['before'][kind], report['after'][kind]
    print(f"{kind} | {a['load_ms']:.3f}->{b['load_ms']:.3f} | {a['preview_ms']:.3f}->{b['preview_ms']:.3f} | {b['access_ms']:.3f} | {b['sample_ms']:.3f} | {a['total_ms']:.3f}->{b['total_ms']:.3f}")
(HERE / 'profile-summary.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
