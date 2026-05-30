#!/usr/bin/env bash
# ax-attach.sh <file> [message-text] [parent_msg_id]
# Attach a file (audio/image/doc) to an aX MESSAGE so it renders inline.
# Proven path (peach 2026-05-30): upload → post message with the upload dict.
#
# Auth: reads the agent's access token from $AX_TOKEN_FILE (each agent's
#   ~/.ax/<handle>-listener.json). space_id is omitted → defaults to the
#   agent's current space (the safe default).
#
#   ax-attach.sh recap.mp3 "Here's the audio recap"
#   ax-attach.sh chart.png "" <parent_id>   # threaded reply with an image
set -euo pipefail
file="${1:?usage: ax-attach.sh <file> [text] [parent_msg_id]}"
text="${2:-}"; parent="${3:-}"
tokfile="${AX_TOKEN_FILE:-$HOME/.ax/$(whoami)-listener.json}"
base="${AX_BASE:-https://paxai.app}"
[ -f "$file" ] || { echo "no such file: $file" >&2; exit 1; }
[ -f "$tokfile" ] || { echo "no token file: $tokfile (set AX_TOKEN_FILE)" >&2; exit 1; }

python3 - "$file" "$text" "$parent" "$tokfile" "$base" <<'PY'
import sys, json, uuid, mimetypes, urllib.request, urllib.error
fpath, text, parent, tokfile, base = sys.argv[1:6]
at = json.load(open(tokfile))["access_token"]
mime = mimetypes.guess_type(fpath)[0] or "application/octet-stream"

# 1) upload (multipart)
b = "----ax" + uuid.uuid4().hex
import os
body = (f"--{b}\r\n".encode()
        + f'Content-Disposition: form-data; name="file"; filename="{os.path.basename(fpath)}"\r\n'.encode()
        + f"Content-Type: {mime}\r\n\r\n".encode()
        + open(fpath, "rb").read() + b"\r\n" + f"--{b}--\r\n".encode())
req = urllib.request.Request(base + "/api/v1/uploads/", data=body, method="POST",
    headers={"Authorization": "Bearer " + at, "Content-Type": f"multipart/form-data; boundary={b}"})
try:
    up = json.load(urllib.request.urlopen(req, timeout=60))
except urllib.error.HTTPError as e:
    print("upload failed:", e.code, e.read()[:200].decode(errors="replace")); sys.exit(1)
print("uploaded:", up.get("url"), "(" + up.get("content_type","?") + ")")

# 2) post message with the FULL upload dict as the attachment (NOT the id string)
payload = {"content": text, "channel": "main", "message_type": "text", "attachments": [up]}
if parent: payload["parent_id"] = parent
req = urllib.request.Request(base + "/api/v1/messages", data=json.dumps(payload).encode(),
    method="POST", headers={"Authorization": "Bearer " + at, "Content-Type": "application/json"})
try:
    d = json.load(urllib.request.urlopen(req, timeout=30)); m = d.get("message") or d
    print("posted message:", m.get("id"), "with attachment ✓")
except urllib.error.HTTPError as e:
    print("post failed:", e.code, e.read()[:200].decode(errors="replace")); sys.exit(1)
PY
