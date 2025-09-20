# Proyecto 7 – Tester de vulnerabilidades en protocolos TLS

**Práctica Calificada – Sección B**

## Descripción general
Este proyecto implementa un tester en Bash para analizar vulnerabilidades relacionadas con protocolos TLS, integrando chequeos de HTTP/HTTPS y DNS. El objetivo es generar evidencias reproducibles en `out/` y automatizar su validación con Makefile y Bats.

## Requisitos
- Bash
- curl
- dig
- cut, grep


## Uso del makefile

```
# Requisitos y permisos
make tools
chmod +x src/dns_check.sh src/http_check.sh

# Medición (elige URL con esquema y resolver válido)
make build TARGET_URL=https://www.wikipedia.org DNS_SERVER=1.1.1.1

# Parsing y logs
make parse
make logs

# Sockets (ss o netstat según disponibilidad)
make sockets
```

## Scripts

### `http_check.sh`

Script robusto para validar conexiones HTTP/HTTPS:
- Obtiene código de estado, cabeceras y traza detallada (`curl -v`).
- Usa `set -euo pipefail` y `trap` para limpieza e idempotencia.
- Maneja errores de red con salidas intermedias en `tmp/` que solo se mueven a `out/` si son válidas.
- Devuelve códigos de salida diferenciados:
  - 10 = configuración ausente (`TARGET_URL`)
  - 20 = dependencia faltante (`curl`)
  - 30 = fallo de red
  - 50 = error interno
- Genera archivos reproducibles en `out/`:
  - `<proto>_code.txt` — código HTTP
  - `<proto>_headers.txt` — cabeceras
  - `<proto>_trace.txt` — traza de conexión

### `dns_check.sh`

Script robusto para validar resolución DNS de un host:
- Usa `set -euo pipefail` y `trap` para limpieza e idempotencia.
- Consulta registros **A** y **CNAME** usando `dig` con `+tries` y `+time`.
- Filtra salidas para separar correctamente A y CNAME en archivos distintos.
- Parseo de TTL con `awk` para reporte reducido.
- Maneja errores de red con salidas intermedias en `tmp/` que solo se mueven a `out/` si son válidas.
- Códigos de salida diferenciados:
  - 10 = configuración ausente (`DNS_SERVER` o `TARGET_URL`)
  - 20 = dependencia faltante (`dig`, `awk`)
  - 30 = fallo DNS/red
  - 50 = error interno
- Genera archivos reproducibles en `out/`:
  - `dns_a.txt` — registros A
  - `dns_cname.txt` — registros CNAME

## Variables de entorno

- `TARGET_URL`: URL objetivo para chequeos HTTP/HTTPS
- `DNS_SERVER`: Servidor DNS para consultas

> Nota: los códigos de salida de los scripts están documentados en `docs/contrato-salidas.md`.
---

## `app.py`

Aplicación demo hecha con Flask incluida para pruebas locales, contiene vulnerabilidades intencionales que los checkers deben detectar .

### Endpoints:
  - `GET /` — página principal con cabeceras intencionales y cookie de sesión sin flags.
  - `GET /headers` — devuelve en JSON las cabeceras de la petición.
  - `GET /boom` — fuerza una excepción para mostrar stacktrace cuando `debug=True`.
  - `GET /health` — healthcheck simple.


### Uso del programa
```bash

pip install -U pip flask
# Arrancar la app 
python3 app/app.py
```
