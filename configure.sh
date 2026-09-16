#!/bin/bash

set -e

VNC_USER_PASSWORD="$1"
VNC_PASSWORD="$2"

echo "========================================"
echo " macOS VNC CONFIGURATION"
echo "========================================"

echo
echo "=== SYSTEM ==="
sw_vers
uname -m
whoami

echo
echo "=== CONSOLE USER ==="
CONSOLE_USER=$(stat -f "%Su" /dev/console)
echo "Console user: $CONSOLE_USER"

echo
echo "=== GUI SESSION ==="
pgrep -fl WindowServer || true
pgrep -fl loginwindow || true

echo
echo "=== SCREEN TEST ==="
SCREENSHOT="/tmp/vnc-test.png"

if screencapture -x "$SCREENSHOT"; then
    echo "Screen capture: OK"
    ls -lh "$SCREENSHOT"
else
    echo "Screen capture: FAILED"
fi

echo
echo "=== ENABLE SCREEN SHARING / REMOTE MANAGEMENT ==="

KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"

if [ ! -x "$KICKSTART" ]; then
    echo "ERROR: kickstart not found"
    exit 1
fi

sudo "$KICKSTART" \
    -configure \
    -allowAccessFor \
    -allUsers \
    -privs \
    -all

echo
echo "=== ENABLE LEGACY VNC ==="

sudo "$KICKSTART" \
    -configure \
    -clientopts \
    -setvnclegacy \
    -vnclegacy yes

echo
echo "=== SET VNC PASSWORD ==="

if [ -n "$VNC_PASSWORD" ]; then
    echo "$VNC_PASSWORD" |
    perl -we '
        BEGIN {
            @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA";
        }

        $_ = <>;
        chomp;

        s/^(.{8}).*/$1/;

        @p = unpack "C*", $_;

        foreach (@k) {
            printf "%02X", $_ ^ (shift @p || 0);
        }

        print "\n";
    ' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt > /dev/null

    sudo chmod 600 /Library/Preferences/com.apple.VNCSettings.txt

    echo "VNC password configured."
else
    echo "No VNC password supplied."
fi

echo
echo "=== RESTART REMOTE MANAGEMENT ==="

sudo "$KICKSTART" \
    -restart \
    -agent \
    -console

sudo "$KICKSTART" \
    -activate

echo
echo "=== SCREEN SHARING PROCESSES ==="

pgrep -fl screensharing || true
pgrep -fl ARDAgent || true

echo
echo "=== WAIT FOR VNC SERVER ==="

sleep 3

echo
echo "=== CHECK VNC PORT ==="

if nc -zv 127.0.0.1 5900; then
    echo
    echo "========================================"
    echo " VNC SERVER IS READY"
    echo " Port: 5900"
    echo "========================================"
else
    echo
    echo "========================================"
    echo " ERROR: VNC SERVER NOT LISTENING"
    echo "========================================"
    exit 1
fi
