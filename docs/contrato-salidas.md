# Contrato de salidas

## Scripts

### `http_check.sh`

#### `http_headers.txt` - `https_headers.txt`

Incluyen las cabeceras de respuesta HTTP/HTTPS a modo de texto plano en varias líneas

#### Validación

Debe empezar con "HTTP/{version} {código de respuesta}"

### `http_trace.txt` - `https_trace.txt`

Traza detallada de la conexión en texto plano.

#### Validación

Debe contener la misma información que las cabeceras en algún punto.

### `dns_a.txt`

Respuesta DNS tipo A en texto plano con una o más líneas que incluyan el dominio, clase, TTL, tipo, IP.

#### Validación

Debe contener al menos una línea con "IN A".

### `dns_cname.txt`

Respuesta DNS tipo CNAME en texto plano con una o más líneas con alias.

#### Validación

Contiene al menos una línea con "IN CNAME".
