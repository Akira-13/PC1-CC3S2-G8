set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
TMP_DIR="$(mktemp -d "${OUT_DIR}/tmp.dns.XXXXXXXX")"
mkdir -p "$OUT_DIR"

# Codigos de salida
# 10 - configuracion o variables ausentes
# 20 - dependencias ausentes
# 30 - fallo de red
# 50 - fallo generico

########################
# Funciones auxiliares
########################

log() { printf '[%s] %s\n' "$(date -u +'%F %T')" "$*"; }
die() {
    log "ERROR: $*"
    exit "${2:-50}"
}
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

: "${DNS_SERVER:?Define DNS_SERVER}" || die 'Servidor DNS no definido' 10
: "${TARGET_URL:?Define TARGET_URL}" || die 'URL no definido' 10
need dig
need awk

a_file="$OUT_DIR/dns_a.txt"
cname_file="$OUT_DIR/dns_cname.txt"

host="$(printf '%s' "$TARGET_URL" | cut -d/ -f3 | cut -d: -f1)"
[[ -n "$host" ]] || die "No se pudo extraer host desde TARGET_URL" 10

if ! dig @"$DNS_SERVER" +noall +answer +tries=3 +time=3 "$host" A >"$TMP_DIR/a_raw"; then
    die "DNS A falló para $host (servidor $DNS_SERVER)" 30
fi

awk '$4=="A"' "$TMP_DIR/a_raw" >"$TMP_DIR/a"

dig @"$DNS_SERVER" +noall +answer +tries=3 +time=3 "$host" CNAME >"$TMP_DIR/cname" || true

mv "$TMP_DIR/a" "$a_file"
mv "$TMP_DIR/cname" "$cname_file"

log "OK: DNS evidencias en $OUT_DIR para $host"
