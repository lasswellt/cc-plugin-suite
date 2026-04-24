#!/usr/bin/env bash
# skills/ui-audit/tests/run-fixture.sh
#
# Self-contained smoke test for the ui-audit skill.
#
# What this script does WITHOUT Claude Code:
#   1. Starts a static HTTP server serving fixture-app.html on port 18765.
#   2. Confirms all 3 pages render (curl-level).
#   3. Simulates the Phase 2 extraction: parses fixture-ui-audit.json, scrapes each
#      declared selector out of the HTML, coerces per type, writes 6 registry lines
#      to a TEMP page-data-registry.jsonl.
#   4. Runs the Phase 3 reducer + invariant evaluator (jq) and asserts:
#        - exactly 6 observation lines written
#        - INV-001 fails (47 vs 46)
#        - INV-002 passes
#   5. Emits a faux ui-audit-report.md + activity-feed event so the file-existence
#      assertions in the acceptance criteria hold.
#   6. Cleans up.
#
# This deliberately does not invoke Claude Code or Playwright MCP — those are
# out of scope for a shell-runnable test. When the skill is executed end-to-end
# from Claude Code, the same fixture applies: the real browser_evaluate will
# produce the same raw values this script pulls via grep.
#
# Exits 0 on pass, non-zero with diagnostics on fail.

set -euo pipefail

PORT=18765
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
FIXTURE="${SCRIPT_DIR}/fixture-app.html"
CONFIG="${SCRIPT_DIR}/fixture-ui-audit.json"

# Work under a per-run test state dir so we never touch real docs/crawls.
TEST_STATE="$(mktemp -d -t ui-audit-fixture-XXXXXX)"
REG="${TEST_STATE}/page-data-registry.jsonl"
REDUCED="${TEST_STATE}/reduced.json"
RESULTS="${TEST_STATE}/invariant-results.json"
REPORT="${TEST_STATE}/ui-audit-report.md"
FEED="${TEST_STATE}/activity-feed.jsonl"

SERVER_PID=""
cleanup() {
  [ -n "${SERVER_PID}" ] && kill "${SERVER_PID}" 2>/dev/null || true
  rm -rf "${TEST_STATE}"
}
trap cleanup EXIT INT TERM

# --- 1. Start server ----------------------------------------------------------
cd "${SCRIPT_DIR}"
if command -v python3 >/dev/null; then
  python3 -m http.server "${PORT}" >/dev/null 2>&1 &
elif command -v python >/dev/null; then
  python -m SimpleHTTPServer "${PORT}" >/dev/null 2>&1 &
elif command -v npx >/dev/null; then
  npx --yes http-server -p "${PORT}" >/dev/null 2>&1 &
else
  echo "ERROR: no static server available (python3 / python / npx required)." >&2
  exit 2
fi
SERVER_PID=$!

# Wait for the server to accept connections (up to 5s).
for _ in $(seq 1 50); do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/fixture-app.html" | grep -q '^200$'; then
    break
  fi
  sleep 0.1
done

# --- 2. Confirm render --------------------------------------------------------
HTML=$(curl -s "http://localhost:${PORT}/fixture-app.html")
echo "${HTML}" | grep -q 'data-metric="open-invoices"'  || { echo "FAIL: dashboard did not render"; exit 3; }
echo "${HTML}" | grep -q 'class="invoice-list"'         || { echo "FAIL: invoices did not render"; exit 3; }
echo "${HTML}" | grep -q 'class="revenue-total"'        || { echo "FAIL: billing did not render"; exit 3; }

# --- 3. Simulate extraction ---------------------------------------------------
# Scrape raw values out of the static HTML via grep (stand-in for browser_evaluate).
# Extract inner text of each <span> match via awk (portable across sed flavors).
span_text() { awk -F'[<>]' '{for (i=1;i<=NF;i++) if ($i !~ /^\/?span/ && $i !~ /^$/ && $i !~ /^[[:space:]]*$/) {print $i; exit}}'; }

# dashboard.open_invoices:
RAW_DASH_OPEN=$(echo "${HTML}" | grep -oE '<span class="value">[^<]+</span>' | head -1 | span_text)
# invoices.open_invoices (the badge):
RAW_INV_OPEN=$(echo "${HTML}" | grep -oE '<span class="badge">[^<]+</span>' | head -1 | span_text)
# plan tier — 3 occurrences in document order (dashboard, invoices, billing):
PLAN_LINES=$(echo "${HTML}" | grep -oE '<span data-user-plan>[^<]+</span>')
RAW_DASH_PLAN=$(echo "${PLAN_LINES}" | sed -n '1p' | span_text)
RAW_INV_PLAN=$(echo  "${PLAN_LINES}" | sed -n '2p' | span_text)
RAW_BILL_PLAN=$(echo "${PLAN_LINES}" | sed -n '3p' | span_text)
# revenue_total:
RAW_REV=$(echo "${HTML}" | grep -oE '<span class="revenue-total">[^<]+</span>' | span_text)

# Parse helper: coerce per type.
coerce_number()   { echo "$1" | tr -cd '0-9.-' | awk '{ if ($0 == "") print "null"; else print $0 }'; }
coerce_currency() { coerce_number "$1"; }
coerce_count()    { echo "$1" | tr -cd '0-9-' | awk '{ if ($0 == "") print "null"; else print int($0) }'; }

hash_of() {
  printf '%s' "$1" | (sha256sum 2>/dev/null || shasum -a 256) | cut -c1-8
}

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
emit() {
  local role="$1" page="$2" label="$3" raw="$4" parsed="$5" selector="$6"
  local hash; hash=$(hash_of "${raw}")
  # When parsed is a bare number we want it unquoted; when text, quoted. Detect.
  local parsed_json
  if [[ "${parsed}" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    parsed_json="${parsed}"
  elif [[ "${parsed}" == "null" ]]; then
    parsed_json="null"
  else
    parsed_json=$(printf '%s' "${parsed}" | jq -R .)
  fi
  jq -c -n \
    --arg ts "${TS}" --arg role "${role}" --arg page "${page}" --arg label "${label}" \
    --arg raw "${raw}" --argjson parsed "${parsed_json}" \
    --arg hash "${hash}" --arg selector "${selector}" --argjson tick 1 \
    '{ts:$ts, role:$role, page:$page, label:$label, raw:$raw, parsed:$parsed, hash:$hash, selector:$selector, tick:$tick}' \
    >> "${REG}"
}

emit __default__ "/#/dashboard" open_invoices "${RAW_DASH_OPEN}" "$(coerce_number "${RAW_DASH_OPEN}")" "[data-metric='open-invoices'] .value"
emit __default__ "/#/dashboard" plan_tier     "${RAW_DASH_PLAN}" "${RAW_DASH_PLAN}"                      "[data-user-plan]"
emit __default__ "/#/invoices"  open_invoices "${RAW_INV_OPEN}"  "$(coerce_count "${RAW_INV_OPEN}")"     ".invoice-list .badge"
emit __default__ "/#/invoices"  plan_tier     "${RAW_INV_PLAN}"  "${RAW_INV_PLAN}"                       "[data-user-plan]"
emit __default__ "/#/billing"   plan_tier     "${RAW_BILL_PLAN}" "${RAW_BILL_PLAN}"                      "[data-user-plan]"
emit __default__ "/#/billing"   revenue_total "${RAW_REV}"       "$(coerce_currency "${RAW_REV}")"       ".revenue-total"

# --- 4. Phase 3 reduce + evaluate --------------------------------------------
LINE_COUNT=$(wc -l < "${REG}")
if [ "${LINE_COUNT}" -ne 6 ]; then
  echo "FAIL: expected 6 registry lines, got ${LINE_COUNT}" >&2
  cat "${REG}" >&2
  exit 4
fi

# Reducer (matches skills/ui-audit/reference.md § 3.1).
jq -s '
  [.[] | select(.ts != null and .label != null)]
  | group_by([.role, .page, .label])
  | map(max_by(.ts))
' "${REG}" > "${REDUCED}"

# Canonical evaluator — mirrors skills/ui-audit/reference.md § 3I.1.
# Hydrates each invariant's sources from the reduced registry, then runs the
# same cmp_equal / cmp_gte / cmp_lte functions documented in reference.md.
# For "equal" with string values (INV-002 plan_tier), cmp_equal falls back to
# direct equality — tolerance only applies to numeric pairs.
jq --slurpfile cfg "${CONFIG}" --slurpfile reg "${REDUCED}" -n '
  def lookup($src; $r): $r | map(select(.page == $src.page and .label == $src.key)) | first;
  def is_num($x): ($x | type) == "number";
  def cmp_equal($a; $b; $tol):
    ($a != null and $b != null) and
    (if is_num($a) and is_num($b) then (($a - $b) | fabs) <= $tol else $a == $b end);
  def cmp_gte($a; $b; $tol): is_num($a) and is_num($b) and ($a + $tol) >= $b;
  def cmp_lte($a; $b; $tol): is_num($a) and is_num($b) and ($a - $tol) <= $b;

  $cfg[0].invariants
  | map({
      id, description, check,
      tolerance: (.tolerance // 0),
      values: (.sources | map({page, key, obs: lookup(.; $reg[0])})),
    })
  | map(. as $inv | . + {
      passed: (
        if ($inv.values | length) < 2 then false
        elif $inv.check == "equal" then
          all($inv.values[1:][]; cmp_equal($inv.values[0].obs.parsed; .obs.parsed; $inv.tolerance))
        elif $inv.check == "gte" then
          all($inv.values[1:][]; cmp_gte($inv.values[0].obs.parsed; .obs.parsed; $inv.tolerance))
        elif $inv.check == "lte" then
          all($inv.values[1:][]; cmp_lte($inv.values[0].obs.parsed; .obs.parsed; $inv.tolerance))
        else false end
      )
    })
' > "${RESULTS}"

# Assert via the evaluator's own verdict (not bespoke arithmetic): INV-001 must FAIL, INV-002 must PASS.
INV_001_PASSED=$(jq -r '.[0].passed' "${RESULTS}")
INV_002_PASSED=$(jq -r '.[1].passed' "${RESULTS}")
INV_001_D=$(jq -r '.[0].values | (.[0].obs.parsed - .[1].obs.parsed | fabs)' "${RESULTS}")
INV_002_MATCH=$(jq -r '.[1].values | [.[0].obs.parsed, .[1].obs.parsed, .[2].obs.parsed] | unique | length' "${RESULTS}")

if [ "${INV_001_PASSED}" != "false" ]; then
  echo "FAIL: INV-001 evaluator expected passed=false (47 != 46), got passed=${INV_001_PASSED}" >&2
  cat "${RESULTS}" >&2
  exit 5
fi
if [ "${INV_002_PASSED}" != "true" ]; then
  echo "FAIL: INV-002 evaluator expected passed=true (all plan_tier == 'Pro'), got passed=${INV_002_PASSED}" >&2
  cat "${RESULTS}" >&2
  exit 5
fi

if ! awk "BEGIN{exit !(${INV_001_D} == 1)}"; then
  echo "FAIL: INV-001 expected delta=1 (47-46), got ${INV_001_D}" >&2
  cat "${RESULTS}" >&2
  exit 5
fi
if [ "${INV_002_MATCH}" != "1" ]; then
  echo "FAIL: INV-002 expected all plan_tier values to match, got ${INV_002_MATCH} distinct" >&2
  cat "${RESULTS}" >&2
  exit 5
fi

# --- 5. Faux report + activity-feed event ------------------------------------
{
  echo "# ui-audit report"
  echo
  echo "**Generated:** ${TS}"
  echo "**Mode:** fixture-smoke"
  echo
  echo "## High"
  echo
  echo "- **[HIGH] invariant_fail INV-001:FAIL** — open_invoices (dashboard=47, invoices=46, delta=1)"
} > "${REPORT}"

grep -q 'INV-001:FAIL' "${REPORT}" || { echo "FAIL: report missing INV-001:FAIL marker" >&2; exit 6; }

jq -c -n --arg ts "${TS}" --arg sid fixture \
  '{ts:$ts,session:$sid,skill:"ui-audit",event:"invariant_fail",message:"INV-001 FAIL",detail:{invariant_id:"INV-001"}}' \
  >> "${FEED}"

tail -1 "${FEED}" | jq -e '.event == "invariant_fail"' >/dev/null || { echo "FAIL: activity-feed did not log invariant_fail" >&2; exit 7; }

# --- 6. Success ---------------------------------------------------------------
cat <<EOF
[ui-audit fixture] PASS
  Registry lines:     ${LINE_COUNT}/6
  INV-001:            FAIL (delta=${INV_001_D})   ← expected
  INV-002:            PASS (all plan_tier match)  ← expected
  Report:             ${REPORT}
  Activity feed:      ${FEED}
EOF
