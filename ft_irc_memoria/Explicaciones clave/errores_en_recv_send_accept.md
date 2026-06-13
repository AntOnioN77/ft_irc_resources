Con sockets no bloqueantes, `recv`, `send` y `accept` pueden devolver -1 sin que sea realmente un "error" en el sentido de fallo — simplemente significa "ahora no hay nada que hacer, intenta luego". Esto es central en tu proyecto porque determina qué se trata como desconexión y qué no.

**El concepto base: bloqueante vs no bloqueante**

En un socket bloqueante, si llamas `recv` y no hay datos, el hilo se queda *dormido* hasta que lleguen. Con `fcntl(fd, F_SETFL, O_NONBLOCK)` (que ya usas), en cambio, la syscall retorna inmediatamente con -1 y `errno` indicado a `EAGAIN`/`EWOULDBLOCK` si no había nada que hacer. Por eso necesitas `poll()`: te avisa *cuándo* sí hay algo, para no tener que estar llamando en bucle ("busy-waiting").

**`recv()` — valores de retorno:**

- **> 0**: bytes leídos correctamente. Caso normal.
- **0**: el peer cerró la conexión ordenadamente (hizo `close()` o FIN de TCP). Esto **no es un error**, es la señal de "adiós". Aquí debes desconectar al cliente, como ya haces.
- **-1**: hubo un problema. Mira `errno`:
  - `EAGAIN` / `EWOULDBLOCK`: no había datos disponibles ahora mismo. Con `poll()` esto en teoría no debería pasarte si solo llamas `recv` cuando `POLLIN` está activo — pero puede ocurrir en casos borde (ej. otro hilo/llamada ya consumió los datos). **No es un error real**, simplemente no hagas nada y espera al siguiente `poll()`.
  - `EINTR`: la syscall fue interrumpida por una señal (ej. tu `SIGINT`). Deberías reintentar la llamada, no tratarlo como desconexión.
  - Cualquier otro errno (`ECONNRESET`, etc.): error real de la conexión → desconectar al cliente.

**`send()` — análogo:**

- **> 0**: se enviaron N bytes (puede ser menos que el tamaño del buffer — "short write", normal en sockets). Por eso `eraseFromWriteBuf(bytes_sent)` que tienes es correcto: vas descontando lo enviado, no asumes que se manda todo de una vez.
- **-1** con `EAGAIN`/`EWOULDBLOCK`: el buffer de envío del socket está lleno (el peer no está leyendo rápido). No es un error — simplemente espera a `POLLOUT` para reintentar. Por eso el patrón correcto es: si `send` da `EAGAIN`, deja los datos en `writeBuf_` y activa `POLLOUT` para ese fd; cuando `poll()` te avise que `POLLOUT` está listo, reintenta el `send`.
- **-1** con `EPIPE` o `ECONNRESET`: el peer cerró la conexión y tú sigues intentando escribir → error real, desconectar.
- **`EINTR`**: igual que en recv, reintentar.

**`accept()`:**

- **>= 0**: nuevo fd del cliente, todo bien.
- **-1** con `EAGAIN`/`EWOULDBLOCK`: no hay conexiones pendientes en este momento (raro si solo llamas tras `POLLIN` en el listener, pero puede pasar si dos conexiones llegan casi simultáneas y solo una entra en el accept queue al momento del poll).
- **-1** con `EINTR`: reintentar.
- Otros errores (`ECONNABORTED`, `EMFILE` — sin file descriptors disponibles, etc.): aquí normalmente **no debes crashear ni cerrar el listener**; loguear y continuar el loop. Tu subject dice "el server no debe crashear nunca", así que `EMFILE` (límite de fds del proceso) debe manejarse con gracia, no con `throw`.

**Por qué importa para tu código actual**

Ahora mismo en `Server::acceptNewClient()`, si `accept()` falla haces `throw std::runtime_error`, lo cual **mataría el servidor entero** por un error de un solo cliente — eso viola la regla de "no debe crashear/quitar inesperadamente". Lo correcto sería: comprobar `errno`, si es `EAGAIN`/`EWOULDBLOCK`/`EINTR` simplemente `return` sin hacer nada, y para otros errores loguear pero **no** lanzar excepción (el servidor sigue corriendo para los demás clientes).

Lo mismo aplica conceptualmente a `sendClientData`: ya tienes el chequeo de `EAGAIN`/`EWOULDBLOCK` (devuelve `false`), pero el `else` (cualquier otro -1) hace `return true` sin desconectar realmente — eso probablemente sea un bug a revisar cuando implementes la lógica completa de `POLLOUT`.

