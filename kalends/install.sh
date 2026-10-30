#!/usr/bin/env bash
# Install Kalends for the current user — no root, nothing outside $HOME.
#
#   ./install.sh              build and install (or update) everything
#   ./install.sh --uninstall  remove what this script installed (your calendars stay)
#
# Puts:
#   ~/.local/bin/kalends                    the CLI (Rust) — the one door to the calendar
#   ~/.local/bin/kalends-gui                starts the window
#   ~/.local/share/kalends-app/             the window (QML, run by quickshell)
#   ~/.local/share/applications/kalends.desktop, and its icon
#   ~/.config/systemd/user/kalends-{sync,remind}.{service,timer}
#
# Your calendars are not touched: ~/.local/share/kalends/calendars (iCalendar files).
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
SRC=$PWD
BIN=${XDG_BIN_HOME:-$HOME/.local/bin}
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
CONF=${XDG_CONFIG_HOME:-$HOME/.config}
APP=$DATA/kalends-app
UNITS=$CONF/systemd/user

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

for a in "$@"; do
    case $a in
        --uninstall)
            say "removing Kalends"
            for u in kalends-sync.timer kalends-remind.timer; do systemctl --user disable --now "$u" 2>/dev/null || true; done
            rm -f -- "$UNITS"/kalends-sync.{service,timer} "$UNITS"/kalends-remind.{service,timer}
            rm -f -- "$BIN/kalends" "$BIN/kalends-gui" "$DATA/applications/kalends.desktop" "$DATA/icons/hicolor/scalable/apps/kalends.svg"
            [ -n "${APP:-}" ] && rm -rf -- "${APP:?}"
            say "done — calendars and settings were left in place"
            exit 0 ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) die "unknown option $a (try --help)" ;;
    esac
done

command -v cargo >/dev/null || die "cargo is needed to build kalends (https://rustup.rs)"
command -v qs >/dev/null || command -v quickshell >/dev/null || warn "quickshell (qs) is not installed: the CLI will work, the window will not"

say "building"
(cd .. && nice -n 19 cargo build --release --quiet -j 4 -p kalends)
TARGET=${CARGO_TARGET_DIR:-$SRC/../target}/release/kalends
[ -x "$TARGET" ] || die "build produced no binary at $TARGET"

say "installing the CLI to $BIN"
mkdir -p "$BIN"
cp -f "$TARGET" "$BIN/kalends.new"; chmod 755 "$BIN/kalends.new"; mv -f "$BIN/kalends.new" "$BIN/kalends"

say "installing the window to $APP"
mkdir -p "$APP"
rm -rf -- "${APP:?}/gui.new"
mkdir -p "$APP/gui.new"
cp -rL "$SRC/kalends.qml" "$SRC/modules" "$SRC/ui" "$APP/gui.new/"
rm -rf -- "${APP:?}/gui"
mv "$APP/gui.new" "$APP/gui"
cat > "$BIN/kalends-gui" <<EOF
#!/bin/sh
# Starts the Kalends window (installed by $SRC/install.sh).
QS=\$(command -v qs || command -v quickshell) || { echo "kalends-gui: quickshell (qs) is not installed" >&2; exit 1; }
exec "\$QS" -p "$APP/gui/kalends.qml" "\$@"
EOF
chmod 755 "$BIN/kalends-gui"

say "installing the launcher entry and icon"
mkdir -p "$DATA/applications" "$DATA/icons/hicolor/scalable/apps"
# a new file swapped in, never rewritten in place: a launcher reading it mid-copy
# cached a blank icon for the rest of the session (2026-10-16)
cp -f packaging/kalends.svg "$DATA/icons/hicolor/scalable/apps/.kalends.svg.new" && mv -f "$DATA/icons/hicolor/scalable/apps/.kalends.svg.new" "$DATA/icons/hicolor/scalable/apps/kalends.svg"
sed "s|^Exec=.*|Exec=$BIN/kalends-gui|; s|^Icon=.*|Icon=kalends|" packaging/kalends.desktop > "$DATA/applications/kalends.desktop"
grep -q '^Icon=' "$DATA/applications/kalends.desktop" || sed -i "s|^Exec=.*|&\nIcon=kalends|" "$DATA/applications/kalends.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true

say "sync and reminder timers"
mkdir -p "$UNITS"
for u in kalends-sync.service kalends-sync.timer kalends-remind.service kalends-remind.timer; do cp -f "packaging/$u" "$UNITS/$u"; done
systemctl --user daemon-reload
systemctl --user enable --now kalends-sync.timer kalends-remind.timer >/dev/null 2>&1 || true

say "installed: 'kalends' in a terminal, 'kalends-gui' or Kalends in your launcher"
