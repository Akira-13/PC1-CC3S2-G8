#!/usr/bin/env bash
set -uo pipefail


HOST="${1:-}"
PORT="${2:-443}"
OUT_DIR="${PWD}/out"
TMP_DIR="$(mktemp -d "${OUT_DIR}/tmp.tls.XXXXXX" 2>/dev/null || mktemp -d)"

usage(){
  cat <<EOF
Usage: $0 <host> [port]
Example:
  $0 example.com 443

Safety: Run only against hosts you own or have permission to test.
EOF
  exit 10
}

# deps
need(){
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 20; }
}
need openssl
need awk
need date || true   
need timeout || true

if [[ -z "$HOST" ]]; then usage; fi

mkdir -p "$OUT_DIR" "$TMP_DIR"

log(){ printf '[%s] %s\n' "$(date -u +'%F %T')" "$*"; }


run_openssl(){
  local args=("$@")
  if command -v timeout >/dev/null 2>&1; then
    timeout 8s openssl "${args[@]}"
  else
    # fallback to native openssl (may hang if network is slow)
    openssl "${args[@]}"
  fi
}


CERT_PEM="${TMP_DIR}/server_cert.pem"
log "Recolectando certificado de ${HOST}:${PORT} ..."

if ! run_openssl s_client -servername "$HOST" -connect "${HOST}:${PORT}" -showcerts </dev/null 2>/dev/null \
    | awk '/-----BEGIN CERTIFICATE-----/{p=1} p{print} /-----END CERTIFICATE-----/{print; exit}' \
    > "$CERT_PEM"; then
  log "ERROR: no se pudo obtener certificado (posible timeout o conexión rechazada)"
  rc=30
else
  rc=0
fi

if [[ $rc -ne 0 ]]; then
  log "Fallo al obtener certificado; saliendo con $rc"
  exit $rc
fi

CERT_SUBJECT="$(openssl x509 -noout -subject -in "$CERT_PEM" 2>/dev/null || true)"
CERT_ISSUER="$(openssl x509 -noout -issuer -in "$CERT_PEM" 2>/dev/null || true)"
CERT_NOTBEFORE="$(openssl x509 -noout -startdate -in "$CERT_PEM" 2>/dev/null | sed 's/notBefore=//')"
CERT_NOTAFTER="$(openssl x509 -noout -enddate -in "$CERT_PEM" 2>/dev/null | sed 's/notAfter=//')"
FINGERPRINT="$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_PEM" 2>/dev/null | sed 's/SHA256 Fingerprint=//')"


days_left="unknown"
if date --version >/dev/null 2>&1; then
  # GNU date
  if parsed="$(date -d "$CERT_NOTAFTER" +%s 2>/dev/null)"; then
    now="$(date +%s)"
    days_left=$(( (parsed - now) / 86400 ))
  fi
else

  if parsed="$(date -j -f "%b %e %T %Y %Z" "$CERT_NOTAFTER" +%s 2>/dev/null)"; then
    now="$(date +%s)"
    days_left=$(( (parsed - now) / 86400 ))
  fi
fi


CERT_REPORT="${OUT_DIR}/tls_cert_report_${HOST}_${PORT}.txt"
{
  echo "Host: ${HOST}:${PORT}"
  echo "Subject: ${CERT_SUBJECT}"
  echo "Issuer: ${CERT_ISSUER}"
  echo "NotBefore: ${CERT_NOTBEFORE}"
  echo "NotAfter: ${CERT_NOTAFTER}"
  echo "Days until expiry: ${days_left}"
  echo "SHA256 fingerprint: ${FINGERPRINT}"
} > "$CERT_REPORT"
log "Cert info guardada en $CERT_REPORT"

VERSIONS=("tls1_3" "tls1_2" "tls1_1" "tls1")
VERS_OUT="${OUT_DIR}/tls_versions_${HOST}_${PORT}.tsv"
printf 'version\tresult\n' > "$VERS_OUT"
log "Comprobando versiones TLS soportadas..."
for v in "${VERSIONS[@]}"; do
  case "$v" in
    tls1_3) flag="-tls1_3" ;;
    tls1_2) flag="-tls1_2" ;;
    tls1_1) flag="-tls1_1" ;;
    tls1)   flag="-tls1" ;;
    *) flag="";;
  esac

  if run_openssl s_client $flag -connect "${HOST}:${PORT}" -servername "$HOST" </dev/null >/dev/null 2>&1; then
    printf '%s\t%s\n' "$v" "OK" >> "$VERS_OUT"
  else
    printf '%s\t%s\n' "$v" "NO" >> "$VERS_OUT"
  fi
done
log "Resultados de versiones en $VERS_OUT"


CIPHERS=("RC4-SHA" "DES-CBC3-SHA" "ECDHE-RSA-DES-CBC3-SHA" "AES128-SHA" "AES256-SHA")
CIPH_OUT="${OUT_DIR}/tls_weak_ciphers_${HOST}_${PORT}.tsv"
printf 'cipher\taccepted\n' > "$CIPH_OUT"
log "Probando negociación con algunos cifrados legacy (solo prueba rápida)..."
for c in "${CIPHERS[@]}"; do
  if run_openssl s_client -cipher "$c" -connect "${HOST}:${PORT}" -servername "$HOST" </dev/null >/dev/null 2>&1; then
    printf '%s\t%s\n' "$c" "ACCEPTED" >> "$CIPH_OUT"
  else
    printf '%s\t%s\n' "$c" "REJECTED" >> "$CIPH_OUT"
  fi
done
log "Resultados cifrados en $CIPH_OUT"


SUMMARY="${OUT_DIR}/tls_summary_${HOST}_${PORT}.txt"
{
  echo "TLS probe summary for ${HOST}:${PORT}"
  echo "-----------------------------------"
  echo "Cert: ${CERT_REPORT}"
  echo
  echo "Supported TLS versions:"
  cat "$VERS_OUT"
  echo
  echo "Cipher negotiation (selected legacy list):"
  cat "$CIPH_OUT"
} > "$SUMMARY"
log "Resumen guardado en $SUMMARY"

rm -rf "$TMP_DIR"

log "Hecho. Revisar ${SUMMARY} y los archivos en ${OUT_DIR}."
exit 0
