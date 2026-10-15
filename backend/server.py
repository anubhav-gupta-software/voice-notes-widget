#!/usr/bin/env python3
"""Tiny sync server for Voice Notes.

No accounts and no API keys. Notes are JSON files on disk. Run it on a
computer your phones can reach, then paste the address into the app.

    python3 backend/server.py
    python3 backend/server.py --token something-secret

Do not put an open server on the public internet. Pass --token if
anything other than your own Wi-Fi can reach it, and prefer HTTPS in
front of it if it is not on that Wi-Fi.
"""

from __future__ import annotations

import argparse
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
MAX_BODY = 8 * 1024 * 1024


def load_notes() -> dict[str, dict]:
    notes = {}
    if not DATA.exists():
        return notes
    for path in DATA.glob("*.json"):
        try:
            payload = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        note_id = str(payload.get("id") or path.stem)
        notes[note_id] = payload
    return notes


NOTES = load_notes()
TOKEN = ""
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    server_version = "VoiceNotesSync/1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send(200, {"ok": True})
            return
        if parsed.path != "/v1/notes":
            self._send(404, {"error": "not found"})
            return
        if not self._authorized():
            return
        query = parse_qs(parsed.query)
        recipient = (query.get("recipient") or [""])[0].strip().upper()
        try:
            since = float((query.get("since") or ["0"])[0])
        except ValueError:
            since = 0
        with LOCK:
            matches = []
            for note in NOTES.values():
                if recipient and str(note.get("recipientCode", "")).upper() != recipient:
                    continue
                created = float(note.get("createdAt") or 0)
                if created < since:
                    continue
                matches.append(note)
        matches.sort(key=lambda note: float(note.get("createdAt") or 0))
        self._send(200, {"notes": matches})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/v1/notes":
            self._send(404, {"error": "not found"})
            return
        if not self._authorized():
            return
        length = int(self.headers.get("Content-Length") or "0")
        if length <= 0 or length > MAX_BODY:
            self._send(413, {"error": "body is missing or too large"})
            return
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self._send(400, {"error": "body must be JSON"})
            return
        note_id = str(payload.get("id") or "").strip()
        if not note_id or not payload.get("recipientCode") or not payload.get("audioBase64"):
            self._send(400, {"error": "id, recipientCode, and audioBase64 are required"})
            return
        DATA.mkdir(parents=True, exist_ok=True)
        path = DATA / f"{note_id}.json"
        with LOCK:
            if note_id not in NOTES:
                path.write_text(json.dumps(payload))
                NOTES[note_id] = payload
        self._send(200, {"ok": True, "id": note_id})

    def log_message(self, fmt: str, *args) -> None:
        print("%s - %s" % (self.address_string(), fmt % args))

    def _authorized(self) -> bool:
        if not TOKEN:
            return True
        header = self.headers.get("Authorization") or ""
        if header == f"Bearer {TOKEN}":
            return True
        self._send(401, {"error": "bad token"})
        return False

    def _send(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser(description="Voice Notes sync server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--token", default=os.environ.get("VOICENOTES_TOKEN", ""))
    args = parser.parse_args()
    global TOKEN
    TOKEN = args.token
    DATA.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    where = "open" if not TOKEN else "token required"
    print(f"Voice Notes sync listening on http://{args.host}:{args.port} ({where})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
