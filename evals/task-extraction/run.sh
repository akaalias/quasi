#!/bin/sh
# Runs the task-extraction eval against the app's own extractor and prints the scores.
#
#   evals/task-extraction/run.sh [variant] [reps]
#
# variant: "baseline" (default) or v1, v2, ... - the folder the answers go to, under
#          .claude/hillclimb/task-extraction/. Re-running a variant resumes it; delete its folder to start over.
# reps:    how many times each case is run (default 1).
#
# Needs ANTHROPIC_API_KEY in the repository's .env. Each run sends every case to Claude: about 200 requests per rep.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
variant=${1:-baseline}
reps=${2:-1}
flow="$root/.claude/hillclimb/task-extraction"
out="$flow/$variant"
mkdir -p "$out" "$flow/bin"

python3 "$here/make_cases.py" >/dev/null
python3 "$here/grade.py" "$here/cases.jsonl" --selftest
swiftc -O -parse-as-library "$root/app/Shared/TaskExtractor.swift" "$here/runner.swift" -o "$flow/bin/runner" 2>&1 | grep -E "error" || true
cat > "$flow/_state.json" <<JSON
{"metrics": [{"id": "exact", "kind": "binary", "label": "Read right"},
             {"id": "detect", "kind": "binary", "label": "Task or not"},
             {"id": "count", "kind": "binary", "label": "How many"},
             {"id": "fields", "kind": "float", "label": "Fields right"}],
 "perf_fields": [{"id": "latency_s", "label": "Latency", "unit": "s"}]}
JSON
"$flow/bin/runner" "$root/.env" "$here/cases.jsonl" "$out" "$reps"
python3 "$here/grade.py" "$here/cases.jsonl" "$out"
if command -v node >/dev/null; then node "$here/build-report-lite.mjs" "$flow/" >/dev/null && echo "Report: $flow/report.html"; fi
