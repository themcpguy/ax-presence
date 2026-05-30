#!/usr/bin/env bash
# ax-file-dataurl.sh <file> [mime]
# Emit a data: URL for a local file, for attaching to aX as a context artifact.
#
# Usage in an agent: generate the data URL, then call the aX context tool:
#   context.set(key="clip.mp3", value="<this output>", content_type="audio/mpeg")
# → aX stores it as a playable file_upload artifact (share the key).
#
# Only the MCP context.set path produces a renderable artifact (the raw REST
# /api/v1/context stores the value as a plain string). Keep clips SHORT —
# the base64 is inlined into the tool call, so large files bloat context;
# for big media we need a real multipart upload endpoint (platform ask).
set -euo pipefail
f="${1:?usage: ax-file-dataurl.sh <file> [mime]}"
mime="${2:-}"
if [ -z "$mime" ]; then
  case "$f" in
    *.mp3) mime=audio/mpeg ;; *.ogg) mime=audio/ogg ;; *.wav) mime=audio/wav ;;
    *.m4a) mime=audio/mp4 ;; *.png) mime=image/png ;; *.jpg|*.jpeg) mime=image/jpeg ;;
    *.pdf) mime=application/pdf ;; *) mime=application/octet-stream ;;
  esac
fi
sz=$(stat -c %s "$f")
if [ "$sz" -gt 200000 ]; then
  echo "WARN: $f is ${sz}B — base64 will be ~$((sz*4/3))B inlined; too big for a tool call. Use a short clip." >&2
fi
printf 'data:%s;base64,%s\n' "$mime" "$(base64 -w0 "$f")"
