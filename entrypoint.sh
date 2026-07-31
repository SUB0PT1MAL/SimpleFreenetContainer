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
# FREENET_EXTRA_ARGS
read -r -a EXTRA_ARGS <<< "${FREENET_EXTRA_ARGS:-}"

# restart supervisor
EXIT_UPDATE_NEEDED=42
EXIT_ALREADY_RUNNING=43

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
    FREENET_SUPERVISED=1 freenet \
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

    if [ "$exit_code" -eq "$EXIT_ALREADY_RUNNING" ]; then
        echo "[supervisor] freenet exited $EXIT_ALREADY_RUNNING (already running) -- not restarting." >&2
        exit "$exit_code"
    fi

    if [ "$exit_code" -eq "$EXIT_UPDATE_NEEDED" ]; then
        echo "[supervisor] update available, applying via 'freenet update'..." >&2
        # Forward the exit status so freenet's own crash-loop/rollback logic
        FREENET_POST_STOP_EXIT_CODE="$exit_code" freenet update --quiet \
            || echo "[supervisor] 'freenet update' failed; relaunching existing binary." >&2
        delay="$MIN_RESTART_DELAY"
        echo "[supervisor] restarting freenet..." >&2
        continue
    fi

    if [ "$exit_code" -eq 0 ]; then
        delay="$MIN_RESTART_DELAY"
        echo "[supervisor] freenet exited cleanly, restarting..." >&2
    else
        echo "[supervisor] freenet exited with code $exit_code, restarting in ${delay}s..." >&2
        # Give freenet's own crash-loop rollback a chance
        FREENET_POST_STOP_EXIT_CODE="$exit_code" freenet update --quiet >/dev/null 2>&1 || true
        sleep "$delay"
        delay=$(( delay * 2 ))
        [ "$delay" -gt "$MAX_RESTART_DELAY" ] && delay="$MAX_RESTART_DELAY"
    fi
done
