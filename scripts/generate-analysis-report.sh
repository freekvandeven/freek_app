#!/usr/bin/env bash
# Generate an HTML static analysis report from dart analyze output.
# Usage: ./scripts/generate-analysis-report.sh <output-dir>

set -euo pipefail

OUTPUT_DIR="${1:-.}"
REPORT_FILE="$OUTPUT_DIR/index.html"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')

mkdir -p "$OUTPUT_DIR"

# Run dart analyze in machine-readable format and capture output
# Format: SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE
set +e
ANALYZE_OUTPUT=$(dart analyze --format=machine lib/ 2>&1)
ANALYZE_EXIT=$?
set -e

# Count issues by severity
ERRORS=$(echo "$ANALYZE_OUTPUT" | grep -c '^ERROR|' || true)
WARNINGS=$(echo "$ANALYZE_OUTPUT" | grep -c '^WARNING|' || true)
INFOS=$(echo "$ANALYZE_OUTPUT" | grep -c '^INFO|' || true)
TOTAL=$((ERRORS + WARNINGS + INFOS))

if [ "$TOTAL" -eq 0 ]; then
  STATUS_BADGE="✅ Clean"
  STATUS_COLOR="#22c55e"
else
  STATUS_BADGE="⚠️ $TOTAL issue(s)"
  STATUS_COLOR="#ef4444"
fi

# Get line/file counts
DART_FILES=$(find lib/ -name '*.dart' | wc -l | tr -d ' ')
DART_LINES=$(find lib/ -name '*.dart' -exec cat {} + | wc -l | tr -d ' ')

# Generate HTML report
cat > "$REPORT_FILE" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter Static Analysis — Freek App</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      max-width: 900px;
      margin: 40px auto;
      padding: 0 20px;
      line-height: 1.6;
    }
    h1 { margin-bottom: 0.25em; }
    .subtitle { color: #666; margin-top: 0; }
    .badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 12px;
      font-weight: bold;
      color: white;
    }
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 16px;
      margin: 24px 0;
    }
    .card {
      border: 1px solid #ddd;
      border-radius: 8px;
      padding: 16px;
      text-align: center;
    }
    .card .value { font-size: 2em; font-weight: bold; }
    .card .label { color: #666; font-size: 0.9em; }
    .error { color: #ef4444; }
    .warning { color: #f59e0b; }
    .info { color: #3b82f6; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 24px 0;
      font-size: 0.9em;
    }
    th, td {
      padding: 8px 12px;
      border: 1px solid #ddd;
      text-align: left;
    }
    th { background: #f5f5f5; }
    @media (prefers-color-scheme: dark) {
      th { background: #333; }
      .subtitle, .card .label { color: #999; }
    }
    .severity-ERROR { background: #fef2f2; }
    .severity-WARNING { background: #fffbeb; }
    .severity-INFO { background: #eff6ff; }
    @media (prefers-color-scheme: dark) {
      .severity-ERROR { background: #450a0a; }
      .severity-WARNING { background: #451a03; }
      .severity-INFO { background: #172554; }
    }
    .back-link { margin-bottom: 16px; display: inline-block; }
    .rules-list { list-style: none; padding: 0; }
    .rules-list li { margin: 4px 0; }
    .rules-list code {
      padding: 2px 6px;
      border-radius: 4px;
      background: #f5f5f5;
      font-size: 0.85em;
    }
    @media (prefers-color-scheme: dark) {
      .rules-list code { background: #333; }
    }
  </style>
</head>
<body>
  <a class="back-link" href="../">← Back to docs</a>
  <h1>Flutter Static Analysis Report</h1>
  <p class="subtitle">Generated on $TIMESTAMP</p>

  <p>
    Status: <span class="badge" style="background:$STATUS_COLOR">$STATUS_BADGE</span>
  </p>

  <div class="summary">
    <div class="card">
      <div class="value error">$ERRORS</div>
      <div class="label">Errors</div>
    </div>
    <div class="card">
      <div class="value warning">$WARNINGS</div>
      <div class="label">Warnings</div>
    </div>
    <div class="card">
      <div class="value info">$INFOS</div>
      <div class="label">Info / Lints</div>
    </div>
    <div class="card">
      <div class="value">$DART_FILES</div>
      <div class="label">Dart files</div>
    </div>
    <div class="card">
      <div class="value">$DART_LINES</div>
      <div class="label">Lines of code</div>
    </div>
  </div>

  <h2>Analysis Configuration</h2>
  <ul>
    <li>Analyzer: <code>dart analyze</code> (strict-casts, strict-raw-types)</li>
    <li>Lint ruleset: <code>package:flutter_lints/flutter.yaml</code> + custom rules</li>
  </ul>
HTMLEOF

if [ "$TOTAL" -gt 0 ]; then
  cat >> "$REPORT_FILE" <<'TABLEHEADER'
  <h2>Issues</h2>
  <table>
    <thead>
      <tr>
        <th>Severity</th>
        <th>Code</th>
        <th>File</th>
        <th>Line</th>
        <th>Message</th>
      </tr>
    </thead>
    <tbody>
TABLEHEADER

  echo "$ANALYZE_OUTPUT" | grep -E '^(ERROR|WARNING|INFO)\|' | while IFS='|' read -r severity type code file line col length message; do
    # Strip leading path prefix for cleaner display
    short_file=$(echo "$file" | sed 's|^lib/||')
    cat >> "$REPORT_FILE" <<ROWEOF
      <tr class="severity-$severity">
        <td class="$(echo "$severity" | tr '[:upper:]' '[:lower:]')">$severity</td>
        <td><code>$code</code></td>
        <td>$short_file</td>
        <td>$line:$col</td>
        <td>$message</td>
      </tr>
ROWEOF
  done

  cat >> "$REPORT_FILE" <<'TABLEFOOTER'
    </tbody>
  </table>
TABLEFOOTER
else
  cat >> "$REPORT_FILE" <<'CLEANMSG'
  <h2>Issues</h2>
  <p>🎉 No issues found! All Dart code passes static analysis.</p>
CLEANMSG
fi

cat >> "$REPORT_FILE" <<'HTMLFOOTER'
</body>
</html>
HTMLFOOTER

echo "Analysis report generated: $REPORT_FILE (${TOTAL} issues)"
