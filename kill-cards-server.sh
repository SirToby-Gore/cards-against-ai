#!/usr/bin/env bash

PID_FILE="tunnel.pid"
LOG_FILE="tunnel.log"
SESSION_NAME="cards"

echo "---------------------------------------------------"
echo "Stopping Cards Against AI Services..."
echo "---------------------------------------------------"

# 1. Gracefully shut down LocalXpose using its saved PID
if [ -f "$PID_FILE" ]; then
    TUNNEL_PID=$(cat "$PID_FILE")
    if kill -0 "$TUNNEL_PID" 2>/dev/null; then
        echo "Killing LocalXpose tunnel (PID: $TUNNEL_PID)..."
        kill "$TUNNEL_PID"
    else
        echo "LocalXpose process ($TUNNEL_PID) was not running."
    fi
    rm -f "$PID_FILE"
else
    # Fallback safety: kill any orphaned localxpose processes if PID file is missing
    if pgrep -x "loclx" > /dev/null; then
        echo "Found orphaned LocalXpose instances. Cleaning up..."
        killall loclx
    fi
fi

# 2. Terminate the Dart server tmux session
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "Stopping Dart server tmux session ($SESSION_NAME)..."
    tmux kill-session -t $SESSION_NAME
else
    echo "No active tmux session named '$SESSION_NAME' found."
fi

# 3. Clean up the trailing log file
if [ -f "$LOG_FILE" ]; then
    rm -f "$LOG_FILE"
fi

echo "---------------------------------------------------"
echo "All services stopped successfully."
echo "==================================================="