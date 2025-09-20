# Bitácora de sprint 2

## Mejora de checkers HTTP/HTTPS y DNS con manejo de errores y robustez

### Comandos usados

* **curl**: además de recuperar códigos de estado, cabeceras y trazas, ahora se ejecuta con parámetros de reintento (`--retry`, `--max-time`, `--connect-timeout`) para tolerar fallos de red y TLS. Se validan códigos HTTP/HTTPS y se guardan evidencias en archivos temporales que luego se mueven a `out/`.

* **dig**: se usa con las banderas `+noall +answer +tries +time` para limitar el número de intentos y el tiempo máximo por consulta. Se filtran los resultados de registros **A** y **CNAME** por tipo (`awk '$4=="A"'`, `awk '$4=="CNAME"'`) para separar la evidencia en archivos distintos. También se parsea el campo **TTL** para un reporte reducido.

* **awk**: empleado para parsear los resultados de DNS, extrayendo columnas específicas (`dominio TTL tipo valor`) para documentar el tiempo de vida de los registros.

* **trap**: utilizado para capturar señales (`ERR`, `INT`, `TERM`, `EXIT`) y asegurar que los directorios temporales se limpien, dejando siempre un estado consistente incluso ante fallos.

### Motivación

En Sprint 2 el objetivo fue **fortalecer los scripts** para que sean más robustos y se alineen con el contrato de la práctica:

* `http_check.sh` ahora maneja reintentos, timeouts y validación de códigos de estado, permitiendo evidenciar diferencias HTTP vs HTTPS incluso cuando hay errores TLS. Además, registra trazas detalladas que servirán para analizar protocolos y detectar vulnerabilidades en Sprint 3.

* `dns_check.sh` ahora controla fallos con códigos de salida claros, ejecuta consultas con reintentos internos de `dig` y separa adecuadamente las respuestas de A y CNAME. Esto evita confusiones cuando un dominio es alias de otro y prepara la base para validaciones más complejas.

Ambos scripts implementan **manejo de errores y limpieza automática** mediante `trap`, lo que asegura reproducibilidad de evidencias y facilita su validación en pruebas Bats. Esto cumple con el criterio de que, ante fallos, los scripts devuelvan código ≠ 0 y dejen un estado consistente.
