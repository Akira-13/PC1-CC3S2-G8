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

Realiza una revisión de respuesta HTTP/HTTPS con curl y genera archivos en `out/` para revisión.

### `dns_check.sh`

Verifica registros A/CNAME y escribe salidas en `out/` para revisión.

## Variables de entorno

- `TARGET_URL`: URL objetivo para chequeos HTTP/HTTPS

- `DNS_SERVER`: Servidor DNS para consultas

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
