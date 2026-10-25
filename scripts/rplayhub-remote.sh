#!/usr/bin/env bash
# rplayhub-remote — run rPlayHub over Wi-Fi using CoreDevice RemotePairing.
#
#   rplayhub-remote [--pair] [--no-gui] [--udid PREFIX]
#
# First run (or --pair): the phone must be unlocked and on the same network.
# A 6-digit code appears on the phone; confirm it here. The pairing is saved
# and reused.
#
# The classic RemoteXPC tunnel needs root to create its interface, so this
# script runs only that step under sudo and drops back to the user for the
# engine and the GUI.
set -euo pipefail

PMD3="@PMD3@"
RPLAYHUB_BIN="@RPLAYHUB@"
SELF="$(readlink -f "$0")"

PAIR=0
GUI=1
UDID="${RPLAY_UDID:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --pair) PAIR=1 ;;
    --no-gui) GUI=0 ;;
    --udid) shift; UDID="$1" ;;
    --tunnel-ready) break ;;
    --root-step) break ;;
    *) echo "usage: rplayhub-remote [--pair] [--no-gui] [--udid PREFIX]" >&2; exit 2 ;;
  esac
  shift
done

state_dir="${XDG_DATA_HOME:-$HOME/.local/share}/rplayhub"
state="$state_dir/remote-state"
run_user="${SUDO_USER:-$USER}"

# ---- phase 1 (user): pairing ------------------------------------------------
if [ "${1:-}" != "--root-step" ] && [ "${1:-}" != "--tunnel-ready" ]; then
  mkdir -p "$state_dir"
  if [ "$PAIR" = 1 ] || [ ! -f "$state_dir/.remote-paired" ]; then
    echo "== Pairing over the network (RemotePairing) =="
    echo "   The phone must be unlocked and on the same Wi-Fi network."
    "$PMD3" remote pair
    touch "$state_dir/.remote-paired"
  fi
  exec sudo "$0" --root-step
fi

# ---- phase 2 (root): create the tunnel --------------------------------------
if [ "${1:-}" = "--root-step" ]; then
  echo "== Creating the wireless RemoteXPC tunnel (root) =="
  udid_args=()
  [ -n "$UDID" ] && udid_args=(--udid "$UDID")
  endpoint="$("$PMD3" remote start-tunnel -t wifi --script-mode "${udid_args[@]}")"
  host="${endpoint%% *}"
  port="${endpoint##* }"
  install -d -o "$run_user" -g "$(id -gn "$run_user")" "$state_dir"
  printf '%s %s\n' "$host" "$port" > "$state"
  chown "$run_user:$(id -gn "$run_user")" "$state"
  exec su "$run_user" -s /bin/sh -c 'exec "$1" --tunnel-ready' sh "$SELF"
fi

# ---- phase 3 (user): run the engine and GUI over the tunnel -----------------
read -r host port < "$state"
echo "== Wireless tunnel: $host:$port =="
export RPLAY_ATTACH_TUNNEL=1
export RPLAY_ATTACH_RSD="$port"
if [ "$GUI" = 1 ]; then
  "$RPLAYHUB_BIN/bin/rplayhub" &
  gui_pid=$!
  trap 'kill "$gui_pid" 2>/dev/null || true' EXIT
fi
exec "$RPLAYHUB_BIN/bin/rplayhub-engine"
