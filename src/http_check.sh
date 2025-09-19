#!/usr/bin/env bash

: "${TARGET_URL:?Define TARGET_URL}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
proto=$(echo "$TARGET_URL" | cut -d: -f1)

mkdir -p "$OUT_DIR"

curl -sS -D - -o /dev/null "$TARGET_URL" >"$OUT_DIR/${proto}_headers.txt" || true
echo "Headers escritos en out/"
curl -v "$TARGET_URL" -o /dev/null >"$OUT_DIR/${proto}_trace.txt" 2>&1 || true
echo "Traza escrita en out/"
