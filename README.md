# Proyecto 7 – Tester de vulnerabilidades en protocolos TLS

**Práctica Calificada – Sección B**

## Descripción general
Este proyecto implementa un tester en Bash para analizar vulnerabilidades relacionadas con protocolos TLS, integrando chequeos de HTTP/HTTPS y DNS. El objetivo es generar evidencias reproducibles en `out/` y automatizar su validación con Makefile y Bats.

## Requisitos
- Bash
- curl
- dig
- cut, grep

## Scripts

### `http_check.sh`

Realiza una revisión de respuesta HTTP/HTTPS con curl y genera archivos en `out/` para revisión.

### `dns_check.sh`

Verifica registros A/CNAME y escribe salidas en `out/` para revisión.

## Variables de entorno

- `TARGET_URL`: URL objetivo para chequeos HTTP/HTTPS

- `DNS_SERVER`: Servidor DNS para consultas
