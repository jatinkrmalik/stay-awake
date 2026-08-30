#!/usr/bin/env bash
# Remove Stay Awake from the current user account.
set -euo pipefail

BIN_DIR="${STAY_AWAKE_BIN_DIR:-$HOME/.local/bin}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$DATA_HOME/stay-awake"
HICOLOR_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
APP_DIR="$DATA_HOME/applications"
AUTOSTART_DIR="$CONFIG_HOME/autostart"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -n "$DESKTOP_DIR" ]] || DESKTOP_DIR="$HOME/Desktop"

KEEP_STATE=0
for arg in "$@"; do
  case "$arg" in
    --keep-state) KEEP_STATE=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./uninstall.sh [--keep-state]

Turns Stay Awake off (restoring your previous idle settings), then
removes the installed files.

  --keep-state   Leave ~/.local/share/stay-awake in place
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ -x "$BIN_DIR/stay-awake" ]]; then
  "$BIN_DIR/stay-awake" off --quiet 2>/dev/null || true
fi

pkill -f "$BIN_DIR/stay-awake-indicator" >/dev/null 2>&1 || true
pkill -f "/stay-awake-indicator" >/dev/null 2>&1 || true

rm -f \
  "$BIN_DIR/stay-awake" \
  "$BIN_DIR/stay-awake-indicator" \
  "$APP_DIR/stay-awake.desktop" \
  "$APP_DIR/stay-awake-indicator.desktop" \
  "$AUTOSTART_DIR/stay-awake-indicator.desktop" \
  "$HICOLOR_DIR/stay-awake-on.svg" \
  "$HICOLOR_DIR/stay-awake-off.svg" \
  "$DESKTOP_DIR/Stay Awake.desktop"

if [[ "$KEEP_STATE" -eq 0 ]]; then
  rm -rf "$STATE_DIR"
fi

update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
echo "Stay Awake removed."
