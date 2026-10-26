#!/usr/bin/env bash
# dropshot-vnc — display the Mac's desktop on a Linux desktop.
#
# The Mac does the phone-facing work (iPhone Mirroring is wireless; rPlayHub
# needs the USB cable there). This window is the Mac's desktop, so the phone
# window runs on the Linux screen with the Linux mouse and keyboard.
#
# Credentials: macOS Screen Sharing authenticates with the Mac account password.
# Store it in vncpasswd format, never in a repository:
#
#   mkdir -p ~/.vnc && chmod 700 ~/.vnc
#   vncpasswd -f > ~/.vnc/dropshot.passwd <<< 'the-mac-account-password'
#   chmod 600 ~/.vnc/dropshot.passwd
#
# Usage: dropshot-vnc [HOST]        (default dropshot.local::5900)
set -euo pipefail

HOST="${1:-${VNC_HOST:-dropshot.local::5900}}"
PASS="${VNC_PASSFILE:-$HOME/.vnc/dropshot.passwd}"

if command -v vncviewer >/dev/null 2>&1; then
  VNC_BIN="$(command -v vncviewer)"
else
  VNC_BIN="${VNC_BIN:-/nix/store/n5cs6czkq5f00parkjzax3plbdh2crkg-tigervnc-1.16.1/bin/vncviewer}"
fi

[ -x "$VNC_BIN" ] || { echo "vncviewer not found; install tigervnc" >&2; exit 1; }
[ -r "$PASS" ] || { echo "password file missing: $PASS (see header)" >&2; exit 1; }

exec "$VNC_BIN" -PasswordFile "$PASS" "$HOST"
