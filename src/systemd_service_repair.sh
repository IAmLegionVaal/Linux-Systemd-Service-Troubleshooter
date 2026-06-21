#!/usr/bin/env bash
set -u

UNIT=""
ACTION="repair"
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: systemd_service_repair.sh UNIT [options]

Options:
  --action repair|restart|start|reload|enable|disable|reset-failed
  --dry-run        Show commands without changing the system.
  --yes            Skip confirmation prompts.
  --output DIR     Save logs and verification output in DIR.
  -h, --help       Show help.

The default repair action runs daemon-reload, clears the failed state, restarts
the selected unit and verifies its final state.
EOF
}

[ "$#" -gt 0 ] || { usage; exit 2; }
UNIT="$1"; shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --action) ACTION="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

command -v systemctl >/dev/null 2>&1 || { echo "systemd is required." >&2; exit 3; }
case "$ACTION" in repair|restart|start|reload|enable|disable|reset-failed) : ;; *) echo "Unsupported action: $ACTION" >&2; exit 2 ;; esac
systemctl cat "$UNIT" >/dev/null 2>&1 || { echo "Unit not found: $UNIT" >&2; exit 2; }

STAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${OUTPUT_DIR:-./systemd-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  read -r -p "$1 [y/N]: " answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  local description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then printf 'DRY-RUN:' >> "$LOG"; printf ' %q' "$@" >> "$LOG"; printf '\n' >> "$LOG"; return 0; fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
run_root() {
  local description="$1"; shift
  if [ "$(id -u)" -eq 0 ]; then run_action "$description" "$@"; else run_action "$description" sudo "$@"; fi
}
verify() {
  {
    echo "Collected: $(date -Is)"
    systemctl status "$UNIT" --no-pager -l 2>&1 || true
    echo
    systemctl show "$UNIT" -p ActiveState -p SubState -p UnitFileState -p Result -p NRestarts 2>&1 || true
    echo
    journalctl -u "$UNIT" -n 100 --no-pager 2>&1 || true
  } > "$VERIFY"
}

verify
confirm "Apply '$ACTION' to $UNIT?" || { log "Repair cancelled."; exit 10; }

case "$ACTION" in
  repair)
    run_root "Reloading systemd unit files" systemctl daemon-reload || true
    run_root "Clearing failed state for $UNIT" systemctl reset-failed "$UNIT" || true
    run_root "Restarting $UNIT" systemctl restart "$UNIT" || true
    ;;
  restart) run_root "Restarting $UNIT" systemctl restart "$UNIT" || true ;;
  start) run_root "Starting $UNIT" systemctl start "$UNIT" || true ;;
  reload) run_root "Reloading $UNIT" systemctl reload "$UNIT" || true ;;
  enable) run_root "Enabling and starting $UNIT" systemctl enable --now "$UNIT" || true ;;
  disable) run_root "Disabling and stopping $UNIT" systemctl disable --now "$UNIT" || true ;;
  reset-failed) run_root "Clearing failed state for $UNIT" systemctl reset-failed "$UNIT" || true ;;
esac

$DRY_RUN || sleep 2
verify
if [ "$ACTION" != "disable" ] && [ "$ACTION" != "reset-failed" ]; then
  systemctl is-active --quiet "$UNIT" || { FAILURES=$((FAILURES + 1)); log "WARNING: $UNIT is not active after repair."; }
fi

if [ "$FAILURES" -gt 0 ]; then exit 20; fi
log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
