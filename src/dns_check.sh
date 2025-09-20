#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
mkdir -p "$OUT_DIR"                                   # <-- crear antes de mktemp
TMP_DIR="$(mktemp -d "${OUT_DIR}/tmp.dns.XXXXXXXX")"

# Códigos de salida:
# 10 - configuración/variables ausentes
# 20 - dependencias ausentes
# 30 - fallo de red
# 50 - fallo genérico

########################
# Funciones auxiliares
########################

log() { printf '[%s] %s\n' "$(date -u +'%F %T')" "$*"; }
die() { log "ERROR: $1"; exit "${2:-50}"; }
need() { command -v "$1" >/dev/null || die "Falta dependencia: $1" 20; }
cleanup() { [[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
on_error() {
    local e=$?
    log "Fallo en línea ${BASH_LINENO[0]} (exit=$e)"
    cleanup
    exit "$e"
}
trap on_error ERR
trap 'log "INT";  cleanup; exit 130' SIGINT
trap 'log "TERM"; cleanup; exit 143' SIGTERM
trap cleanup EXIT

########################
# Script principal
########################

: "${DNS_SERVER:=}"; [ -n "$DNS_SERVER" ] || die 'Servidor DNS no definido (DNS_SERVER)' 10
: "${TARGET_URL:=}"; [ -n "$TARGET_URL" ] || die 'URL no definida (TARGET_URL)' 10

need dig
need awk

a_file="$OUT_DIR/dns_a.txt"
cname_file="$OUT_DIR/dns_cname.txt"

host="$(printf '%s' "$TARGET_URL" | cut -d/ -f3 | cut -d: -f1)"
[ -n "$host" ] || die "No se pudo extraer host desde TARGET_URL" 10

# DNS A
if ! dig @"$DNS_SERVER" +noall +answer +tries=3 +time=3 "$host" A >"$TMP_DIR/a_raw"; then
    die "DNS A falló para $host (servidor $DNS_SERVER)" 30
fi
awk '$4=="A"' "$TMP_DIR/a_raw" >"$TMP_DIR/a"

# DNS CNAME 
dig @"$DNS_SERVER" +noall +answer +tries=3 +time=3 "$host" CNAME >"$TMP_DIR/cname" || true

mv "$TMP_DIR/a"     "$a_file"
mv "$TMP_DIR/cname" "$cname_file"

log "OK: DNS evidencias en $OUT_DIR para $host"
