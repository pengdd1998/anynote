#!/bin/sh
set -e

# If CHROME_WS_URL is already set (external Chrome container), skip local startup.
if [ -n "${CHROME_WS_URL}" ]; then
    echo "Using external Chrome: ${CHROME_WS_URL}"
    exec "$@"
fi

# Otherwise, start a local Chromium instance (development mode).
# Requires chromium-browser installed in the container image.

CHROMIUM="/usr/bin/chromium-browser"
PORT="${CHROME_PORT:-9222}"

CHROMIUM_FLAGS="--headless --disable-gpu --disable-dev-shm-usage --remote-debugging-port=${PORT} --remote-debugging-address=127.0.0.1"

if [ "$(id -u)" = "0" ]; then
    CHROMIUM_FLAGS="${CHROMIUM_FLAGS} --no-sandbox"
fi

echo "Starting local Chromium on port ${PORT}..."
${CHROMIUM} ${CHROMIUM_FLAGS} &
CHROME_PID=$!

# Give Chromium a moment to start and open the DevTools port.
sleep 2

# Verify Chromium started successfully.
if ! kill -0 ${CHROME_PID} 2>/dev/null; then
    echo "ERROR: Chromium failed to start" >&2
    exit 1
fi

# Set up cleanup: when the worker exits, terminate Chromium.
cleanup() {
    echo "Cleaning up Chromium (PID ${CHROME_PID})..."
    kill ${CHROME_PID} 2>/dev/null
    wait ${CHROME_PID} 2>/dev/null
}
trap cleanup EXIT INT TERM

export CHROME_WS_URL="ws://127.0.0.1:${PORT}"

echo "Starting worker with CHROME_WS_URL=${CHROME_WS_URL}..."
"$@"
WORKER_EXIT=$?

exit ${WORKER_EXIT}
