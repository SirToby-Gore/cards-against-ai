#!/usr/bin/env bash

LOG_FILE="tunnel.log"
PID_FILE="tunnel.pid"

# 1. Clean up old logs to prevent reading an old URL
rm -f "$LOG_FILE"

SESSION_NAME="cards"

# Check if the server is already running
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "Server is already running! Use 'tmux attach -t $SESSION_NAME' to see it."
else
    echo "Starting Cards server in background session: $SESSION_NAME"

   # Start a new detached tmux session running Dart
   tmux new-session -d -s $SESSION_NAME "dart run"

   echo "Server started."
   echo "---------------------------------------------------------------"
   echo "To view the console, type:  tmux attach -t $SESSION_NAME"
   echo "To hide the console again, press:  Ctrl+B then D"
   echo "---------------------------------------------------------------"
fi


echo "---------------------------------------------------"
echo "Launching LocalXpose Tunnel..."
echo "---------------------------------------------------"

# 2. Start LocalXpose tunnel in the background. WebSockets are supported automatically.
nohup loclx tunnel http --to 127.0.0.1:8080 > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo -n "Waiting for LocalXpose to generate URL"

# 3. Loop until the URL appears in the log (max 20 seconds)
MAX_RETRIES=20
COUNT=0
TUNNEL_URL=""

while [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    echo -n "."
    if [ -f "$LOG_FILE" ]; then
        RAW_DOMAIN=$(grep -o '[a-zA-Z0-9.-]*\.loclx\.io' "$LOG_FILE" | head -n 1)
    fi
    
    if [ -n "$RAW_DOMAIN" ]; then
        TUNNEL_URL="https://$RAW_DOMAIN" # Safely construct the full secure URL
        echo -e "\n\nSuccess!"
        break
    fi
    ((COUNT++))
done

if [ -n "$TUNNEL_URL" ]; then
    # Cross-platform local IP resolution (Works seamlessly on Linux & macOS)
    if command -v hostname -I &> /dev/null; then
        LOCAL_IP=$(hostname -I | awk '{print $1}')
    else
        LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ifconfig | grep -Eo 'inet (addr:)?([0-9.]*)' | grep -v '127.0.0.1' | awk '{print $2}' | head -n 1)
    fi
    
    echo "==================================================="
    echo "LocalXpose URL: $TUNNEL_URL"
    echo "Local network URL: http://$LOCAL_IP:8080"
    echo "==================================================="
    echo
    echo "Option A: Scan below to connect via LocalXpose Tunnel (Remote/Mobile/Cellular):"
    qrencode -t ANSI256 "$TUNNEL_URL"
    echo
    echo "---------------------------------------------------"
    echo "Option B: Scan below to connect via Direct Local IP (Fast / Same Wi-Fi):"
    qrencode -t ANSI256 "http://$LOCAL_IP:8080"
    echo
    echo "Tunnel is running in background (PID: $(cat $PID_FILE))"
    echo "You can close this SSH session now."
else
    echo -e "\n\nError: Timeout reached. LocalXpose failed to generate a URL."
    echo "Check logs with: cat $LOG_FILE"
fi