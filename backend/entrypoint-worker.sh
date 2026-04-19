#!/bin/sh
set -e

# Start Chromium in headless mode on the default DevTools port.
# The worker process will connect to it via ws://127.0.0.1:9222.
# We run Chromium as a non-root user if possible; falling back to
# --no-sandbox when running as root (common in containers).

CHROMIUM="/usr/bin/chromium-browser"
PORT="${CHROME_PORT:-9222}"

CHROMIUM_FLAGS="--headless --disable-gpu --disable-dev-shm-usage --remote-debugging-port=${PORT} --remote-debugging-address=127.0.0.1"

if [ "$(id -u)" = "0" ]; then
    CHROMIUM_FLAGS="${CHROMIUM_FLAGS} --no-sandbox"
fi

echo "Starting Chromium on port ${PORT}..."
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

# Export the WebSocket URL so the worker config picks it up.
export CHROME_WS_URL="ws://127.0.0.1:${PORT}"

# Execute the worker binary (passed as CMD).
# Run the worker and capture its exit code, then let the trap clean up.
echo "Starting worker with CHROME_WS_URL=${CHROME_WS_URL}..."
"$@"
WORKER_EXIT=$?

exit ${WORKER_EXIT}
