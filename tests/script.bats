#!/usr/bin/env bats

setup() {
  rm -rf out
  mkdir -p out
  TARGET_URL="https://example.com" DNS_SERVER="1.1.1.1" make build >/dev/null
}

@test "se genera dns_a.txt" {
  [ -s "out/dns_a.txt" ]
}

@test "se genera dns_cname.txt (puede estar vacío si no hay CNAME)" {
  [ -f "out/dns_cname.txt" ]
}

@test "headers contienen status HTTP" {
  grep -E '^HTTP/' out/*_headers.txt
}

@test "existe la traza de curl (-v)" {
  ls out/*_trace.txt >/dev/null
}
