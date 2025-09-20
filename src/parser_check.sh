#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Pipeline que corre dns_check + http_check y hace parsing
# con awk / cut / grep.
# Lee de repo_root/out y escribe parseos en repo_root/src/out.
# Códigos: 10 cfg | 20 deps | 30 red | 50 gen
# ============================================================

# Rutas 
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="${ROOT_DIR}/src"           # aquí viven dns_check.sh y http_check.sh
OUT_READ="${ROOT_DIR}/out"             # ENTRADAS (artefactos crudos)
OUT_WRITE="${SCRIPT_DIR}/out"          # SALIDAS (parseos)
mkdir -p "${OUT_WRITE}"
TMP_DIR="$(mktemp -d "${OUT_WRITE}/tmp.pipeline.XXXXXX")"

#  Utilidades 
log(){ printf '[%s] %s\n' "$(date -u +'%F %T')" "$*"; }
die(){ log "ERROR: $1"; exit "${2:-50}"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Falta dependencia: $1" 20; }
cleanup(){ [[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
on_error(){ local e=$?; log "Fallo en línea ${BASH_LINENO[0]} (exit=$e)"; cleanup; exit "$e"; }
trap on_error ERR; trap 'log "INT";cleanup;exit 130' INT; trap 'log "TERM";cleanup;exit 143' TERM; trap cleanup EXIT

#  Configuración y dependencias 
[[ -n "${DNS_SERVER:-}" ]] || die "DNS_SERVER no definido" 10
[[ -n "${TARGET_URL:-}"  ]] || die "TARGET_URL no definido" 10
need awk; need cut; need grep

# Detecta protocolo y host
proto="$(printf '%s' "$TARGET_URL" | cut -d: -f1)"
host="$(printf '%s' "$TARGET_URL" | cut -d/ -f3 | cut -d: -f1)"
[[ -n "$proto" && -n "$host" ]] || die "No se pudo extraer proto/host del TARGET_URL" 10

# Job 1: Ejecuta checks existentes 
dns_ec=0; http_ec=0

if [[ -x "${SCRIPT_DIR}/dns_check.sh" ]]; then
  log "Ejecutando dns_check…"
  if ! DNS_SERVER="$DNS_SERVER" TARGET_URL="$TARGET_URL" "${SCRIPT_DIR}/dns_check.sh"; then
    dns_ec=$?; log "dns_check terminó con exit=${dns_ec}"
  fi
else
  log "Aviso: ${SCRIPT_DIR}/dns_check.sh no es ejecutable o no existe"; dns_ec=20
fi

if [[ -x "${SCRIPT_DIR}/http_check.sh" ]]; then
  log "Ejecutando http_check…"
  if ! TARGET_URL="$TARGET_URL" "${SCRIPT_DIR}/http_check.sh"; then
    http_ec=$?; log "http_check terminó con exit=${http_ec}"
  fi
else
  log "Aviso: ${SCRIPT_DIR}/http_check.sh no es ejecutable o no existe"; http_ec=20
fi

#  Job 2: Parsing DNS (leer de OUT_READ, escribir en OUT_WRITE) 
a_raw="${OUT_READ}/dns_a.txt"
cname_raw="${OUT_READ}/dns_cname.txt"

if [[ -s "$a_raw" || -s "$cname_raw" ]]; then
  # Formato TSV: NAME TTL CLASS TYPE DATA  
  (
    if [[ -s "$a_raw" ]]; then
      awk 'BEGIN{OFS="\t"} $4=="A"{print $1,$2,$3,$4,$5}' "$a_raw"
    fi
    if [[ -s "$cname_raw" ]]; then
      awk 'BEGIN{OFS="\t"} $4=="CNAME"{print $1,$2,$3,$4,$5}' "$cname_raw"
    fi
  ) | awk 'BEGIN{OFS="\t"}
       { gsub(/\.$/,"",$1); gsub(/\.$/,"",$5); key=$1 FS $4 FS $5 }
       !seen[key]++ { print $1,$2,$3,$4,$5 }' > "${OUT_WRITE}/dns_parsed.tsv"

  # IPs únicas 
  if [[ -s "$a_raw" ]]; then
    awk '$4=="A"{print $5}' "$a_raw" | awk '!seen[$0]++' > "${OUT_WRITE}/dns_ips.txt"
  else
    : > "${OUT_WRITE}/dns_ips.txt"
  fi

  # Reporte DNS
  {
    echo "Host: ${host}"
    echo "Servidor DNS: ${DNS_SERVER}"
    echo "---- Conteos ----"
    printf "A: %s\n"     "$( (awk '$4=="A"{c++} END{print c+0}' "$a_raw" 2>/dev/null) || echo 0 )"
    printf "CNAME: %s\n" "$( (awk '$4=="CNAME"{c++} END{print c+0}' "$cname_raw" 2>/dev/null) || echo 0 )"
    echo "---- IPs únicas ----"
    if [[ -s "${OUT_WRITE}/dns_ips.txt" ]]; then
      cat "${OUT_WRITE}/dns_ips.txt"
    else
      printf '%s\n' "(ninguna)"
    fi
  } > "${OUT_WRITE}/dns_report.txt"
else
  log "Aviso: no hay artefactos DNS para parsear en ${OUT_READ}"
fi


# Job 3: Parsing HTTP 
hdr_file="${OUT_READ}/${proto}_headers.txt"
trace_file="${OUT_READ}/${proto}_trace.txt"

if [[ -s "$hdr_file" ]]; then
  # Formato TSV: KEY VALUE  
  awk '
    BEGIN{IGNORECASE=1; OFS="\t"}
    /^HTTP\/[0-9.]+ [0-9]{3}/ { split($0,a," "); print "http_version", a[1]; print "status_code", a[2] }
    /^[A-Za-z0-9-]+:[[:space:]]/ {
      key=$1; sub(/:$/,"",key); $1=""; sub(/^[[:space:]]+/,"");
      gsub(/[[:space:]]+/," "); print tolower(key), $0
    }' "$hdr_file" \
  | awk -F'\t' 'BEGIN{OFS="\t"} !seen[$1]++' > "${OUT_WRITE}/http_headers_parsed.tsv"

  # Reporte HTTP
  awk -F'\t' '
    BEGIN{OFS="\t"; kv["server"]=kv["content-type"]=kv["content-length"]=kv["cache-control"]=kv["status_code"]=kv["http_version"]=""; kv["set-cookie.count"]=0}
    { if($1=="server") kv["server"]=$2;
      else if($1=="content-type") kv["content-type"]=$2;
      else if($1=="content-length") kv["content-length"]=$2;
      else if($1=="cache-control") kv["cache-control"]=$2;
      else if($1=="set-cookie") kv["set-cookie.count"]++;
      else if($1=="status_code") kv["status_code"]=$2;
      else if($1=="http_version") kv["http_version"]=$2; }
    END{
      print "http_version", kv["http_version"];
      print "status_code", kv["status_code"];
      print "server", kv["server"];
      print "content_type", kv["content-type"];
      print "content_length", kv["content-length"];
      print "cache_control", kv["cache-control"];
      print "set_cookie_count", kv["set-cookie.count"];
    }' "${OUT_WRITE}/http_headers_parsed.tsv" > "${OUT_WRITE}/http_report.tsv"

  # Nombres de cookies
  grep -i '^set-cookie:' "$hdr_file" 2>/dev/null \
    | awk -F': ' '{print $2}' | awk -F';' '{print $1}' | awk -F'=' '{print $1}' \
    | awk 'NF' > "${OUT_WRITE}/http_cookies.txt" || true
else
  log "Aviso: no hay headers HTTP para parsear en ${hdr_file}"
fi

if [[ -s "$trace_file" ]]; then
  # Formato TSV: connect HOP HOST IP PORT / status HOP VER CODE / location HOP "" "" URL
  awk '
    BEGIN{OFS="\t"; IGNORECASE=1; hop=0}
    /^\* Connected to / {
      host=$3; ip=""; port=""
      if (match($0,/\(([0-9a-fA-F\.:]+)\)/,m)) ip=m[1]
      if (match($0,/ port ([0-9]+)/,p)) port=p[1]
      print "connect", ++hop, host, ip, port
    }
    /^< HTTP\/[0-9.]+ [0-9]{3}/ {
      split($0,a," "); ver=a[2]; code=a[3]; gsub(/^</,"",ver)
      print "status", hop, ver, code, ""
    }
    /^< [Ll]ocation:/ {
      sub(/^< [Ll]ocation:[[:space:]]*/,""); print "location", hop, "", "", $0
    }' "$trace_file" > "${OUT_WRITE}/http_chain.tsv"
else
  log "Aviso: no hay trace HTTP para parsear en ${trace_file}"
fi

# Job 4: Resumen combinado (escribir en OUT_WRITE) 
{
  echo "# Summary"
  echo "target_url: ${TARGET_URL}"
  echo "host: ${host}"
  echo
  echo "## DNS"
  if [[ -s "${OUT_WRITE}/dns_report.txt" ]]; then
    cat "${OUT_WRITE}/dns_report.txt"
  else
    echo "(sin datos DNS)"
  fi
  echo
  echo "## HTTP"
  if [[ -s "${OUT_WRITE}/http_report.tsv" ]]; then
    awk -F'\t' 'BEGIN{printf "status: "} $1=="status_code"{print $2}' "${OUT_WRITE}/http_report.tsv"
    awk -F'\t' '$1=="server"{printf "server: %s\n",$2}' "${OUT_WRITE}/http_report.tsv"
    awk -F'\t' '$1=="content_type"{printf "content_type: %s\n",$2}' "${OUT_WRITE}/http_report.tsv"
    awk -F'\t' '$1=="set_cookie_count"{printf "set_cookie_count: %s\n",$2}' "${OUT_WRITE}/http_report.tsv"
  else
    echo "(sin datos HTTP)"
  fi
  if [[ -s "${OUT_WRITE}/http_chain.tsv" ]]; then
    echo "redirect_hops: $(awk '$1=="status"' "${OUT_WRITE}/http_chain.tsv" | wc -l | awk '{print $1}')"
    last_loc="$(awk -F'\t' '$1=="location"{loc=$5} END{print loc}' "${OUT_WRITE}/http_chain.tsv")"
    [[ -n "$last_loc" ]] && echo "last_location: ${last_loc}"
  fi
} > "${OUT_WRITE}/summary_report.txt"

log "OK: pipeline completada. Lee de ${OUT_READ} y escribe en ${OUT_WRITE}"

# Política de salida 
# Si alguno falla, propagamos el código con prioridad: 10 > 20 > 30 > 50
if (( dns_ec!=0 || http_ec!=0 )); then
  for code in 10 20 30 50; do
    if [[ $dns_ec -eq $code || $http_ec -eq $code ]]; then exit "$code"; fi
  done
fi
exit 0
