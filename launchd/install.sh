#!/usr/bin/env bash
# Install the rPlayHub engine as a launchd system daemon (macOS).
#
#   sudo ./install.sh [/path/to/cdhost]
#
# Default path matches docs/macos-engine.md: ~/rPlayHub/host-c/cdhost built by
# the owner of the checkout; the daemon runs it as root because the CoreDevice
# tunnel needs a utun.
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
engine="${1:-/Users/$(stat -f%Su /dev/console)/rPlayHub/host-c/cdhost}"
plist=/Library/LaunchDaemons/com.rplay.cdhost.plist
log=/var/log/rplay-cdhost.log

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 2; }
[ -x "$engine" ] || { echo "engine not found or not executable: $engine" >&2; exit 2; }

export ENGINE="$engine"
export PLIST="$plist"
envsubst '${ENGINE} ${PLIST}' < "$here/com.rplay.cdhost.plist.tmpl" > "$plist"
chown root:wheel "$plist"
chmod 644 "$plist"

launchctl bootout system/com.rplay.cdhost 2>/dev/null || true
launchctl bootstrap system "$plist"
sleep 3
launchctl print system/com.rplay.cdhost | grep -E "state|pid" | head -3
echo "log: $log"
