#!/usr/bin/env python3

import json
import subprocess
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent.parent
DASHBOARD_DIR = ROOT / "dashboard"
BUILD_SCRIPT = ROOT / "scripts" / "build_dashboard_data.py"
WATER_LOG_FILE = ROOT / "water_intake_log.txt"
TOILET_LOG_FILE = ROOT / "toilet_log.txt"
HOST = "127.0.0.1"
PORT = 8766


class DashboardHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DASHBOARD_DIR), **kwargs)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/rebuild":
            self.respond_json(self.run_build())
            return

        if parsed.path == "/api/log/water":
            self.append_timestamp(WATER_LOG_FILE)
            self.respond_json(self.run_build())
            return

        if parsed.path == "/api/log/toilet":
            self.append_timestamp(TOILET_LOG_FILE)
            self.respond_json(self.run_build())
            return

        self.send_error(404, "Not Found")
        return

    def append_timestamp(self, target: Path) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("a", encoding="utf-8") as fh:
            fh.write(datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "\n")

    def run_build(self) -> dict:
        result = subprocess.run(
            ["/usr/bin/python3", str(BUILD_SCRIPT)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
        )
        return {
            "ok": result.returncode == 0,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        }

    def respond_json(self, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200 if payload.get("ok") else 500)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # Always disable caching so local dashboard updates are visible immediately.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.path = "/index.html"
        return super().do_GET()


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), DashboardHandler)
    print(f"Dashboard server running at http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
