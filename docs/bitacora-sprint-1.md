# Bitácora de sprint 1

## Desarrollo de checkers HTTP/HTTPS y DNS

### Comandos usados

- dig: Permite recopilar información de DNS del dominio pasado como variable de entorno. Se utilizan las banderas `+noall` y `+answer` para obtener solo el resultado de `answer`, que es lo relevante en este proyecto.

- curl: Según su manual, permite comunicarse y enviar o recibir datos de un servidor. En los scripts iniciales permiten recuperar información HTTP/HTTPS de un dominio.

### Motivación

Estos scripts están presentes para un análisis inicial básico de la respuesta del servidor y de su dominio. `http_check.sh` permitirá comparar el resultado entre respuestas HTTP y HTTPS y detectar errores TLS. `dns_check` permite validar nombres y direcciones IP que pueden resultar útiles en el tester para validar endpoints.
