#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_HOST="127.0.0.1"
SERVER_PORT="8766"
SERVER_URL="http://$SERVER_HOST:$SERVER_PORT"

/usr/bin/python3 "$SCRIPT_DIR/scripts/build_dashboard_data.py"

# Always restart server so code/header changes are applied immediately.
/usr/bin/pkill -f "$SCRIPT_DIR/scripts/dashboard_server.py" >/dev/null 2>&1 || true
nohup /usr/bin/python3 "$SCRIPT_DIR/scripts/dashboard_server.py" >/tmp/health_dashboard_server.log 2>&1 &
sleep 0.6

/usr/bin/open "$SERVER_URL/?ts=$(/bin/date +%s)"
