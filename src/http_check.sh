#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
TMP_DIR="$(mktemp -d "${OUT_DIR}/tmp.http.XXXXXXXX")"
mkdir -p "$OUT_DIR"

# Codigos de salida
# 10 - configuracion o variables ausentes
# 20 - dependencias ausentes
# 30 - fallo de red
# 50 - fallo generico

########################
# Funciones auxiliares
########################

# Para tener logs
log() { printf '[%s] %s\n' "$(date -u +'%F %T')" "$*"; }

# Para registrar salidas
die() {
    log "ERROR: $*"
    exit "${2:-50}"
}

# Para verificar dependencias
need() { command -v "$1" >/dev/null || die "Falta dependencia: $1" 20; }

# Para limpiar directorio temporal
cleanup() { [[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }

# Para registrar errores
on_error() {
    local e=$?
    log "Fallo en línea ${BASH_LINENO[0]} (exit=$e)"
    cleanup
    exit "$e"
}

# Traps - para manejar salidas adecuadamente
trap on_error ERR
trap 'log "INT";  cleanup; exit 130' SIGINT
trap 'log "TERM"; cleanup; exit 143' SIGTERM
trap cleanup EXIT

########################
# Script principal
########################

: "${TARGET_URL:?Define TARGET_URL}" || die 'Variable de entorno no definida' 10
need curl

proto="$(printf '%s' "$TARGET_URL" | cut -d: -f1)"
hdr_file="$OUT_DIR/${proto}_headers.txt"
trace_file="$OUT_DIR/${proto}_trace.txt"

curl -sS --retry 5 -D - -o /dev/null "$TARGET_URL" >"$TMP_DIR/hdr" || true
mv "$TMP_DIR/hdr" "$hdr_file"

(curl -v --retry 5 "$TARGET_URL" -o /dev/null) >"$TMP_DIR/trace" 2>&1 || true
mv "$TMP_DIR/trace" "$trace_file"

log "OK: evidencias ${proto} en $OUT_DIR"
