#!/usr/bin/env bats

setup() {
  rm -rf out
  mkdir -p out
  TARGET_URL="${TARGET_URL:-https://www.wikipedia.org}" \
  DNS_SERVER="${DNS_SERVER:-1.1.1.1}" \
  make -s build >/dev/null
}

@test "HTTP: hay status code en *_headers.txt" {
  run bash -lc 'grep -Eh "^HTTP/" out/*_headers.txt | awk "{print \$2}" | head -n1'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{3}$ ]]
}

@test "DNS: TTL numérico en dns_a.txt (columna 2)" {
  run bash -lc 'awk "{print \$2}" out/dns_a.txt | head -n1'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "parse: genera reportes parseados" {
  run make -s parse
  [ "$status" -eq 0 ]
  [ -s "out/http_status_summary.txt" ]
  [ -s "out/dns_a_parsed.txt" ]
}

@test "sockets: genera out/sockets.txt" {
  run make -s sockets
  [ "$status" -eq 0 ]
  [ -s "out/sockets.txt" ]
}
