#!/usr/bin/env bash
set -u

SERVICE="${1:-}"
[[ -z "$SERVICE" || "$SERVICE" == "-h" || "$SERVICE" == "--help" ]] && { echo "Usage: $0 UNIT [--output DIRECTORY]"; exit 0; }
shift
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v systemctl >/dev/null 2>&1 || { echo "systemctl is required." >&2; exit 1; }
STAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_NAME="${SERVICE//[^A-Za-z0-9_.-]/_}"
OUTPUT_DIR="${OUTPUT_DIR:-./systemd-triage-${SAFE_NAME}-${STAMP}}"
mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/service-triage.txt"
JSON="$OUTPUT_DIR/service-summary.json"
ERRORS="$OUTPUT_DIR/command-errors.log"
: > "$REPORT"; : > "$ERRORS"

section() {
  local title="$1"; shift
  { printf '\n===== %s =====\n' "$title"; "$@"; } >> "$REPORT" 2>> "$ERRORS" || true
}

section "Collection metadata" bash -c 'date -Is; hostname -f 2>/dev/null || hostname; id'
section "Unit status" systemctl status "$SERVICE" --no-pager -l
section "Unit properties" systemctl show "$SERVICE" --no-pager
section "Unit definition" systemctl cat "$SERVICE"
section "Dependencies" systemctl list-dependencies "$SERVICE" --all --no-pager
section "Reverse dependencies" systemctl list-dependencies "$SERVICE" --reverse --all --no-pager
section "Recent journal" journalctl -u "$SERVICE" --since "24 hours ago" --no-pager -n 500
section "Boot blame" systemd-analyze blame
section "Critical chain" systemd-analyze critical-chain "$SERVICE"
if systemctl help security >/dev/null 2>&1; then
  section "Security exposure" systemd-analyze security "$SERVICE" --no-pager
fi

LOAD_STATE="$(systemctl show "$SERVICE" -p LoadState --value 2>/dev/null || echo unknown)"
ACTIVE_STATE="$(systemctl show "$SERVICE" -p ActiveState --value 2>/dev/null || echo unknown)"
SUB_STATE="$(systemctl show "$SERVICE" -p SubState --value 2>/dev/null || echo unknown)"
RESULT="$(systemctl show "$SERVICE" -p Result --value 2>/dev/null || echo unknown)"
RESTARTS="$(systemctl show "$SERVICE" -p NRestarts --value 2>/dev/null || echo 0)"
ENABLED="$(systemctl is-enabled "$SERVICE" 2>/dev/null || echo unknown)"

cat > "$JSON" <<EOF
{
  "collected_at": "$(date -Is)",
  "unit": "$SERVICE",
  "load_state": "${LOAD_STATE:-unknown}",
  "active_state": "${ACTIVE_STATE:-unknown}",
  "sub_state": "${SUB_STATE:-unknown}",
  "result": "${RESULT:-unknown}",
  "restart_count": ${RESTARTS:-0},
  "enabled_state": "${ENABLED:-unknown}"
}
EOF

printf '\nService triage completed. Output: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
