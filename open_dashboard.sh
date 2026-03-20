#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

/usr/bin/python3 "$SCRIPT_DIR/scripts/build_dashboard_data.py"
/usr/bin/open "$SCRIPT_DIR/dashboard/index.html"
