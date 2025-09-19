#!/usr/bin/env bash

: "${DNS_SERVER:?Define DNS_SERVER}"
: "${TARGET_URL:?Define TARGET_URL}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
host="$(echo "$TARGET_URL" | cut -d/ -f3)"

mkdir -p "$OUT_DIR"

dig @"$DNS_SERVER" +noall +answer "$(echo $host | cut -d. -f2-)" A >"$OUT_DIR/dns_a.txt"
echo "Registro A en out/dns_a.txt"
dig @"$DNS_SERVER" +noall +answer "$host" CNAME >"$OUT_DIR/dns_cname.txt"
echo "Registro CNAME en out/dns_cname.txt"
