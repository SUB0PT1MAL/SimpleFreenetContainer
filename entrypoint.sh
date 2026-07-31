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

read -r -a EXTRA_ARGS <<< "${FREENET_EXTRA_ARGS:-}"

# minimal supervisor
MIN_RESTART_DELAY="${SUPERVISOR_MIN_RESTART_DELAY:-1}"
MAX_RESTART_DELAY="${SUPERVISOR_MAX_RESTART_DELAY:-30}"

terminate=0
child_pid=

_shutdown() {
    terminate=1
    if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
        kill -TERM "$child_pid" 2>/dev/null || true
    fi
}
trap _shutdown TERM INT

delay="$MIN_RESTART_DELAY"

while :; do
    freenet \
        --ws-api-address "$WS_API_ADDRESS" \
        --ws-api-port "$WS_API_PORT" \
        "${EXTRA_ARGS[@]}" \
        "$@" &
    child_pid=$!

    set +e
    wait "$child_pid"
    exit_code=$?
    set -e
    child_pid=

    if [ "$terminate" -eq 1 ]; then
        exit "$exit_code"
    fi

    if [ "$exit_code" -eq 0 ]; then
        # clean exit
        delay="$MIN_RESTART_DELAY"
        echo "[supervisor] freenet exited cleanly (likely self-update), restarting..." >&2
    else
        echo "[supervisor] freenet exited with code $exit_code, restarting in ${delay}s..." >&2
        sleep "$delay"
        delay=$(( delay * 2 ))
        [ "$delay" -gt "$MAX_RESTART_DELAY" ] && delay="$MAX_RESTART_DELAY"
    fi
done
