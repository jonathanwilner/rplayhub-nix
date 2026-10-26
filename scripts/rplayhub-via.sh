#!/usr/bin/env bash
# rplayhub-via — drive a phone attached to another machine, from this one.
#
#   rplayhub-via HOST [--user USER] [--gui PATH] [--no-gui]
#
# The engine (cdhost) must run on the machine the phone is plugged into; only
# that machine can hold the CoreDevice tunnel. The GUI is happy anywhere, so
# this forwards the engine's three localhost ports over SSH and points the
# local viewer at them.
#
# Ports: 9876 control, 9877 video, 9878 audio (engine side).
set -euo pipefail

HOST="${1:?usage: rplayhub-via HOST [--user USER] [--gui PATH] [--no-gui]}"
shift || true

SSH_USER="${USER:-jonathan}"
GUI="${RPLAYHUB_GUI:-@RPLAYHUB_GUI@}"
RUN_GUI=1

while [ $# -gt 0 ]; do
  case "$1" in
    --user) shift; SSH_USER="$1" ;;
    --gui) shift; GUI="$1" ;;
    --no-gui) RUN_GUI=0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ "$RUN_GUI" = 1 ] && [ -z "$GUI" ]; then
  echo "no rplayhub GUI on PATH; pass --gui PATH or --no-gui" >&2
  exit 1
fi

# Local ports offset by +10000 so an engine running on this machine does not
# collide with the forwarded one.
base=19876
video=$((base + 1))
audio=$((base + 2))

cleanup() {
  [ -n "${tunnel_pid:-}" ] && kill "$tunnel_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "== forwarding engine ports from $HOST =="
ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -N \
    -L "$base:127.0.0.1:9876" \
    -L "$video:127.0.0.1:9877" \
    -L "$audio:127.0.0.1:9878" \
    "$SSH_USER@$HOST" &
tunnel_pid=$!

# Wait for the control port to accept connections.
for _ in $(seq 1 40); do
  if (exec 3<>/dev/tcp/127.0.0.1/$base) 2>/dev/null; then exec 3>&-; break; fi
  sleep 0.25
done

echo "== engine reachable at 127.0.0.1:$base =="
if [ "$RUN_GUI" = 1 ]; then
  echo "== starting GUI =="
  exec "$GUI" -h 127.0.0.1 -A "$base" -p "$video"
fi
echo "tunnel up; keep this process alive to hold it"
wait "$tunnel_pid"
