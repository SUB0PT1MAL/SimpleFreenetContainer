#!/bin/bash
set -e

case "$1" in
  shell|bash|sh)
    shift
    exec bash "$@"
    ;;
esac

WS_API_ADDRESS="${WS_API_ADDRESS:-0.0.0.0}"
WS_API_PORT="${WS_API_PORT:-7509}"

# FREENET_EXTRA_ARGS: anything else you want to pass, as one string.
# ex:  FREENET_EXTRA_ARGS="--some-mode-flag --another-flag value"
read -r -a EXTRA_ARGS <<< "${FREENET_EXTRA_ARGS:-}"


FREENET_ARGS=(--ws-api-address "$WS_API_ADDRESS" --ws-api-port "$WS_API_PORT" "${EXTRA_ARGS[@]}" "$@")

# freenet exits with code 42 when it detects an update but finds no service
# supervisor to relaunch it afterward. This acts as a supervisor: apply the update and
# loop back to start freenet again, rather than letting the container just
# die on every update.
while true; do
  set +e
  freenet "${FREENET_ARGS[@]}"
  status=$?
  set -e

  if [ "$status" -eq 42 ]; then
    echo "[entrypoint] update detected, running 'freenet update' and relaunching..."
    freenet update
    continue
  fi

  exit "$status"
done
