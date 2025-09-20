SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ===== Vars existentes =====
TARGET_URL ?=
DNS_SERVER ?=

SRC_DIR  := src
OUT_DIR  := out
TEST_DIR := tests

REQUIRED_TOOLS := bash curl dig

HTTP_SCRIPT := $(SRC_DIR)/http_check.sh
DNS_SCRIPT  := $(SRC_DIR)/dns_check.sh

# ===== S3: Cache e idempotencia =====
CACHE_DIR := $(OUT_DIR)/.cache
STAMP     := $(CACHE_DIR)/config.stamp
SRC_HTTP  := $(HTTP_SCRIPT)
SRC_DNS   := $(DNS_SCRIPT)

# Artefactos DNS
DNS_A     := $(OUT_DIR)/dns_a.txt
DNS_CNAME := $(OUT_DIR)/dns_cname.txt

# Derivar protocolo a partir de TARGET_URL (http|https)
PROTO := $(shell echo "$(TARGET_URL)" | cut -d: -f1)
HDR   := $(OUT_DIR)/$(PROTO)_headers.txt
TRACE := $(OUT_DIR)/$(PROTO)_trace.txt

.PHONY: help tools build run test clean out

help:
	@echo "Targets: tools, build, run, test, clean"
	@echo "Requiere scripts en: $(HTTP_SCRIPT), $(DNS_SCRIPT)"
	@echo "Variables: TARGET_URL=https://example.com  DNS_SERVER=1.1.1.1"

tools:
	@missing=""; \
	for t in $(REQUIRED_TOOLS); do command -v $$t >/dev/null 2>&1 || missing="$$missing $$t"; done; \
	if [ -n "$$missing" ]; then echo "Faltan herramientas:${missing}"; exit 1; fi; \
	if [ ! -x "$(HTTP_SCRIPT)" ]; then echo "Falta o no es ejecutable: $(HTTP_SCRIPT)"; exit 1; fi; \
	if [ ! -x "$(DNS_SCRIPT)" ]; then echo "Falta o no es ejecutable: $(DNS_SCRIPT)"; exit 1; fi; \
	echo "OK herramientas y scripts."

$(CACHE_DIR):
	@mkdir -p $@

$(STAMP): | $(CACHE_DIR)
	@if [ -z "$(strip $(TARGET_URL))" ]; then echo "Define TARGET_URL (ej. https://example.com)"; exit 2; fi
	@printf "TARGET_URL=%s\nDNS_SERVER=%s\n" "$(TARGET_URL)" "$(DNS_SERVER)" > $@.tmp
	@cmp -s $@.tmp $@ 2>/dev/null || mv $@.tmp $@
	@rm -f $@.tmp

out: ; @mkdir -p "$(OUT_DIR)"

$(DNS_A) $(DNS_CNAME): $(SRC_DNS) $(STAMP) | out
	@echo "[S3] DNS: comprobando caché…"
	@DNS_SERVER="$(DNS_SERVER)" TARGET_URL="$(TARGET_URL)" "$(DNS_SCRIPT)"

$(HDR) $(TRACE): $(SRC_HTTP) $(STAMP) | out
	@echo "[S3] HTTP($(PROTO)): comprobando caché…"
	@TARGET_URL="$(TARGET_URL)" "$(HTTP_SCRIPT)"


build: tools $(DNS_A) $(DNS_CNAME) $(HDR) $(TRACE)
	@echo "Build: cache OK."

run: tools build
	@echo "== Resumen de $(OUT_DIR)/ =="
	@set -e; \
	for f in "$(OUT_DIR)"/dns_a.txt "$(OUT_DIR)"/dns_cname.txt; do \
	  if [ -f "$$f" ]; then echo "--- $$f ---"; head -n 10 "$$f"; fi; \
	done; \
	for f in "$(OUT_DIR)"/*_headers.txt "$(OUT_DIR)"/*_trace.txt; do \
	  if [ -f "$$f" ]; then echo "--- $$f ---"; head -n 15 "$$f"; fi; \
	done

test:
	@if [ ! -d "$(TEST_DIR)" ]; then echo "No hay $(TEST_DIR). Agrega pruebas .bats."; exit 2; fi
	@if ! command -v bats >/dev/null 2>&1; then echo "Falta 'bats' para ejecutar pruebas."; exit 2; fi
	@bats "$(TEST_DIR)"

clean:
	@rm -rf "$(OUT_DIR)"
	@echo "Limpieza completa."

