#!/bin/bash

set -e

NGROK_AUTH_TOKEN="$3"

echo "=== SYSTEM ==="
sw_vers
uname -m
whoami
id

echo "=== GUI SESSION ==="
console_user=$(stat -f '%Su' /dev/console)
echo "Console user: $console_user"

echo "=== DISPLAY ==="
launchctl print "gui/$(id -u)" >/dev/null
echo "Aqua session detected"

echo "=== SCREEN CAPTURE TEST ==="
mkdir -p "$RUNNER_TEMP/capture"
screencapture -x "$RUNNER_TEMP/capture/test.png"
ls -lh "$RUNNER_TEMP/capture/test.png"

echo "=== REMOTE MANAGEMENT ==="

KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"

if [ -x "$KICKSTART" ]; then
    echo "kickstart found"

    sudo "$KICKSTART" \
        -configure \
        -allowAccessFor \
        -allUsers \
        -privs \
        -all

    sudo "$KICKSTART" \
        -activate

    sudo "$KICKSTART" \
        -restart \
        -agent \
        -console

else
    echo "ERROR: kickstart not found"
    exit 1
fi

echo "=== SCREEN SHARING PROCESS ==="
pgrep -fl screensharing || true
pgrep -fl ARDAgent || true

echo "=== VNC PORT ==="
sleep 3
nc -zv 127.0.0.1 5900

echo "=== INSTALL NGROK ==="

if ! command -v ngrok >/dev/null 2>&1; then
    brew install ngrok
fi

echo "=== CONFIGURE NGROK ==="
ngrok config add-authtoken "$NGROK_AUTH_TOKEN"

echo "=== START NGROK ==="
nohup ngrok tcp 5900 >"$RUNNER_TEMP/ngrok.log" 2>&1 &

sleep 5

echo "=== NGROK STATUS ==="
cat "$RUNNER_TEMP/ngrok.log" || true

echo "=== NGROK API ==="
curl --silent http://127.0.0.1:4040/api/tunnels | jq '.tunnels'
