#!/usr/bin/env bash
# Install Stay Awake for the current user. No root required.
#
#   curl -fsSL https://raw.githubusercontent.com/jatinkrmalik/stay-awake/main/install.sh | bash
#
set -euo pipefail

REPO_URL="${STAY_AWAKE_REPO:-https://github.com/jatinkrmalik/stay-awake.git}"
SRC_DIR="${STAY_AWAKE_SRC:-$HOME/.local/src/stay-awake}"

resolve_repo_root() {
  local src="${BASH_SOURCE[0]:-}"
  [[ -n "$src" && -f "$src" ]] || return 1
  local dir
  dir="$(dirname "$(readlink -f "$src" 2>/dev/null || printf '%s\n' "$src")")" || return 1
  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 1
  [[ -f "$dir/bin/stay-awake" ]] || return 1
  printf '%s\n' "$dir"
}

bootstrap_from_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required for the curl installer. Install git and re-run." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$SRC_DIR")"
  if [[ -d "$SRC_DIR/.git" ]]; then
    echo "Updating Stay Awake in $SRC_DIR"
    git -C "$SRC_DIR" pull --ff-only
  else
    echo "Cloning Stay Awake into $SRC_DIR"
    git clone --depth 1 "$REPO_URL" "$SRC_DIR"
  fi
  exec "$SRC_DIR/install.sh" "$@"
}

REPO_ROOT=""
if ! REPO_ROOT="$(resolve_repo_root)"; then
  bootstrap_from_git "$@"
fi

BIN_DIR="${STAY_AWAKE_BIN_DIR:-$HOME/.local/bin}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$DATA_HOME/stay-awake"
ICON_DIR="$STATE_DIR/icons"
HICOLOR_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
APP_DIR="$DATA_HOME/applications"
AUTOSTART_DIR="$CONFIG_HOME/autostart"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -n "$DESKTOP_DIR" ]] || DESKTOP_DIR="$HOME/Desktop"

START_INDICATOR=1
INSTALL_DESKTOP_SHORTCUT=1
for arg in "$@"; do
  case "$arg" in
    --no-start) START_INDICATOR=0 ;;
    --no-desktop) INSTALL_DESKTOP_SHORTCUT=0 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./install.sh [--no-start] [--no-desktop]

Installs Stay Awake into ~/.local for the current user.

  curl -fsSL https://raw.githubusercontent.com/jatinkrmalik/stay-awake/main/install.sh | bash

  --no-start     Do not launch the top-bar icon after installing
  --no-desktop   Do not add a Desktop shortcut
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    MISSING=1
  fi
}

MISSING=0
need python3
need gsettings
need systemd-inhibit
if ! python3 - <<'PY'
import gi
gi.require_version("Gtk", "3.0")
try:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3  # noqa: F401
except ValueError:
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3  # noqa: F401
PY
then
  echo "Missing Python GObject bindings for Gtk 3 and AppIndicator." >&2
  echo "On Ubuntu/Debian: sudo apt install python3-gi gir1.2-appindicator3-0.1 gnome-shell-extension-appindicator" >&2
  echo "On Fedora:        sudo dnf install python3-gobject libappindicator-gtk3" >&2
  MISSING=1
fi
if ! gsettings list-keys org.gnome.desktop.session >/dev/null 2>&1; then
  echo "This looks like it is not a GNOME session. Stay Awake uses gsettings keys from GNOME." >&2
  MISSING=1
fi
if [[ "$MISSING" -eq 1 ]]; then
  exit 1
fi

mkdir -p "$BIN_DIR" "$ICON_DIR" "$HICOLOR_DIR" "$APP_DIR" "$AUTOSTART_DIR"

install -m 0755 "$REPO_ROOT/bin/stay-awake" "$BIN_DIR/stay-awake"
install -m 0755 "$REPO_ROOT/bin/stay-awake-indicator" "$BIN_DIR/stay-awake-indicator"
install -m 0755 "$REPO_ROOT/uninstall.sh" "$BIN_DIR/stay-awake-uninstall"

cp "$REPO_ROOT/data/icons/"*.svg "$ICON_DIR/"
cp "$REPO_ROOT/data/icons/stay-awake-on.svg" "$HICOLOR_DIR/stay-awake-on.svg"
cp "$REPO_ROOT/data/icons/stay-awake-off.svg" "$HICOLOR_DIR/stay-awake-off.svg"

if [[ -f "$REPO_ROOT/data/icons/stay-awake-panel-on.png" ]]; then
  cp "$REPO_ROOT/data/icons/stay-awake-panel-on.png" "$ICON_DIR/"
  cp "$REPO_ROOT/data/icons/stay-awake-panel-off.png" "$ICON_DIR/"
fi

python3 - <<PY
import os
try:
    import gi
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf
except Exception:
    raise SystemExit(0)
icon_dir = os.path.expanduser("$ICON_DIR")
for name in ("stay-awake-panel-on", "stay-awake-panel-off"):
    svg = os.path.join(icon_dir, name + ".svg")
    png = os.path.join(icon_dir, name + ".png")
    if not os.path.isfile(svg):
        continue
    pb = GdkPixbuf.Pixbuf.new_from_file_at_size(svg, 48, 48)
    pb.savev(png, "png", [], [])
PY

write_desktop() {
  local dest="$1"
  local name="$2"
  local exec_line="$3"
  local comment="$4"
  cat >"$dest" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$exec_line
Icon=$HICOLOR_DIR/stay-awake-on.svg
Terminal=false
StartupNotify=false
Categories=Utility;
Keywords=sleep;idle;caffeine;awake;screen;
EOF
  chmod +x "$dest"
}

write_desktop \
  "$APP_DIR/stay-awake.desktop" \
  "Stay Awake" \
  "$BIN_DIR/stay-awake-indicator" \
  "Show a top-bar icon to keep the screen on and block idle sleep"

write_desktop \
  "$AUTOSTART_DIR/stay-awake-indicator.desktop" \
  "Stay Awake" \
  "$BIN_DIR/stay-awake-indicator" \
  "Top-bar toggle for screen blanking and idle sleep"
{
  echo "X-GNOME-Autostart-enabled=true"
  echo "X-GNOME-Autostart-Delay=2"
} >>"$AUTOSTART_DIR/stay-awake-indicator.desktop"

if [[ "$INSTALL_DESKTOP_SHORTCUT" -eq 1 && -d "$DESKTOP_DIR" ]]; then
  write_desktop \
    "$DESKTOP_DIR/Stay Awake.desktop" \
    "Stay Awake" \
    "$BIN_DIR/stay-awake toggle" \
    "Double-click to toggle screen blanking, auto-lock, and idle sleep"
  python3 - <<PY || true
from gi.repository import Gio
path = "$DESKTOP_DIR/Stay Awake.desktop"
f = Gio.File.new_for_path(path)
info = Gio.FileInfo()
info.set_attribute_string("metadata::trusted", "true")
try:
    import hashlib
    data = open(path, "rb").read()
    info.set_attribute_string("metadata::xfce-exe-checksum", hashlib.sha256(data).hexdigest())
except Exception:
    pass
f.set_attributes_from_info(info, Gio.FileQueryInfoFlags.NONE, None)
PY
fi

gtk-update-icon-cache -f "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Note: $BIN_DIR is not on your PATH. Add this to your shell config:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

if [[ "$START_INDICATOR" -eq 1 ]]; then
  pkill -f "$BIN_DIR/stay-awake-indicator" >/dev/null 2>&1 || true
  nohup "$BIN_DIR/stay-awake-indicator" >/dev/null 2>&1 &
  disown $! 2>/dev/null || true
fi

echo "Stay Awake installed."
echo "  CLI:        $BIN_DIR/stay-awake"
echo "  Top bar:    coffee-cup icon (click Keep awake)"
echo "  Uninstall:  stay-awake-uninstall"
if [[ "$INSTALL_DESKTOP_SHORTCUT" -eq 1 && -d "$DESKTOP_DIR" ]]; then
  echo "  Desktop:    $DESKTOP_DIR/Stay Awake.desktop"
fi
echo "It will start again the next time you log in."
