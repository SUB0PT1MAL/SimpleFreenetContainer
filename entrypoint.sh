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

exec freenet \
  --ws-api-address "$WS_API_ADDRESS" \
  --ws-api-port "$WS_API_PORT" \
  "${EXTRA_ARGS[@]}" \
  "$@"
