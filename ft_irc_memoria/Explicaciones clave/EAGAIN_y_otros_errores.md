**EAGAIN** — literalmente "E" (error) + "AGAIN" (otra vez). El mensaje es: "no pude hacerlo *esta vez*, pero **inténtalo de nuevo**". Es el único errno cuyo nombre te dice directamente qué hacer como respuesta: reintentar. Mnemotécnico: "*A-gain* = vuelve a intentarlo, no es un fallo permanente".

**EWOULDBLOCK** — "la operación *habría bloqueado*" (would block) si el socket fuera bloqueante. Es casi sinónimo de EAGAIN (en Linux son literalmente el mismo valor numérico); históricamente BSD usaba `EWOULDBLOCK` y System V usaba `EAGAIN` para el mismo caso, y por compatibilidad ambos quedaron. Mnemotécnico: "*would block* = me habría quedado dormido, pero como eres non-blocking, te aviso y sigo".

**EINTR** — "Interrupted" (interrumpido). La syscall estaba en medio de su trabajo cuando llegó una señal (como tu `SIGINT`) y el kernel la cortó antes de terminar. No significa que algo esté mal con el socket — significa "me interrumpieron a mitad de frase, repite la pregunta". Mnemotécnico: alguien tocó el timbre mientras hablabas por teléfono.

**EPIPE** — "Broken Pipe". Viene de los pipes de Unix (`|`): si escribes a un pipe cuyo lector ya no existe, el dato "no tiene a dónde ir" — es una tubería rota. Para sockets es análogo: escribes a una conexión donde el otro lado ya cerró todo. Mnemotécnico: imagina una tubería de agua cortada — viertes agua y se derrama porque no hay nada al otro lado.

**ECONNRESET** — "Connection Reset". El peer no cerró educadamente (FIN normal), sino que **resetió** la conexión abruptamente (RST de TCP) — como colgar el teléfono de golpe en vez de decir "adiós". Mnemotécnico: "reset" = se reinició/cortó de golpe, sin protocolo de despedida.

**ECONNABORTED** — "Connection Aborted". Específico de `accept()`: una conexión entrante llegó a estar en la cola de pendientes, pero el cliente la abortó *antes* de que tu `accept()` la recogiera. Mnemotécnico: alguien llamó a la puerta y se fue corriendo antes de que abrieras.

**EMFILE** — "Too Many open Files" (M = "many"/"max" files). Tu proceso llegó al límite de file descriptors abiertos simultáneamente. Mnemotécnico: "M-File" = *máximo* de files alcanzado — se acabaron los "cajones" disponibles para guardar fds.

**Patrón general para recordar la familia E-algo:**

Casi todos los nombres describen **la causa física del fallo en lenguaje llano**: "would block", "interrupted", "broken pipe", "reset", "aborted", "too many files". No son códigos arbitrarios — léelos como una frase corta y casi siempre describen exactamente lo que pasó en la red/kernel. La excepción mnemotécnica es **EAGAIN**, que en vez de describir la causa, te dice la *acción* a tomar (intenta otra vez) — por eso es el más fácil de recordar como "no es un error real".
