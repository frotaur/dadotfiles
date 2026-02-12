#!/bin/bash
# Start debugpy in tmux and wait for it to be ready by checking verbose output

FILE="$1"

# Get compute node and port from launch.json
LAUNCH_JSON=".vscode/launch.json"

if [ ! -f "$LAUNCH_JSON" ]; then
    echo "ERROR: Could not find $LAUNCH_JSON"
    exit 1
fi

COMPUTE_NODE=$(grep -oP '"host":\s*"\K[^"]+' "$LAUNCH_JSON" | head -1)
PORT=$(grep -oP '"port":\s*\K[0-9]+' "$LAUNCH_JSON" | head -1)

if [ -z "$COMPUTE_NODE" ]; then
    echo "ERROR: Could not read compute node from $LAUNCH_JSON"
    exit 1
fi

if [ -z "$PORT" ]; then
    echo "ERROR: Could not read port from $LAUNCH_JSON"
    exit 1
fi

echo "Starting debugpy on $COMPUTE_NODE:$PORT (with cleanup)..."

# First, aggressively clean up any old debugpy processes
tmux send-keys -t pydev C-c 2>/dev/null
sleep 0.3
tmux send-keys -t pydev "pkill -9 -f debugpy" Enter 2>/dev/null
sleep 0.3

# Clear screen and scrollback to prevent matching old output
tmux send-keys -t pydev "clear" Enter
sleep 0.1
tmux clear-history -t pydev
sleep 0.2

# Send the debugpy command to tmux with verbose logging
tmux send-keys -t pydev "python -m debugpy --listen 0.0.0.0:$PORT --wait-for-client --log-to-stderr $FILE" Enter

# Wait for debugpy to show ready signal in output
MAX_ATTEMPTS=40
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Capture recent tmux output and look for ready signal
    OUTPUT=$(tmux capture-pane -t pydev -p -S -100 2>/dev/null)

    # Check if debugpy is waiting for client connection
    if echo "$OUTPUT" | grep -q "wait_for_client()"; then
        echo "✓ Debugpy ready and waiting on $COMPUTE_NODE:$PORT"
        # Small delay to ensure port is fully bound before VS Code tries to connect
        sleep 0.5
        exit 0
    fi

    ATTEMPT=$((ATTEMPT + 1))
    sleep 0.2
done

echo "Warning: Timeout waiting for debugpy ready signal (but may still work)"
exit 0
