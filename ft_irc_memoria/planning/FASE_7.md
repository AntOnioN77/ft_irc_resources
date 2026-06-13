# Fase 7: Pruebas Rigurosas y Bonus (Opcional)

- Pruebas de estrés: Verificar que el programa no se bloquee ni se cierre inesperadamente bajo ninguna circunstancia, incluso si se queda sin memoria, para evitar una calificación de 0.


- Pruebas de red con netcat: Usar nc -C 127.0.0.1 <port> enviando comandos fragmentados manualmente con Ctrl+D para verificar que tu agregador de paquetes funciona correctamente.


- Desarrollo de Bonus (Opcional): Implementar la transferencia de archivos o un Bot automatizado, recordando que esto solo se evaluará si la parte obligatoria funciona de manera perfecta


---

### 1. Pruebas de Estrés (Rompiendo tu propio código)

El objetivo aquí es simular el comportamiento de usuarios maliciosos o conexiones inestables. Debes probar esto antes de presentarte a la evaluación:

* **Prueba de Fragmentación Extrema (El terror de `recv`):**
    * **Cómo se hace:** Usa `nc -C 127.0.0.1 <puerto>`. Escribe una letra de un comando (ej. `N`), presiona `Ctrl+D` (envía el paquete sin `\n`), escribe la siguiente (`I`), `Ctrl+D`, y así hasta formar `NICK juan\r\n`.
    * **Qué debe pasar:** El servidor no debe hacer nada hasta recibir el `\r\n`. Si procesa el comando a medias, fallaste. Tu buffer de la Fase 3 debe manejar esto a la perfección.
* **Prueba de Inundación (Flood & FD Limits):**
    * **Cómo se hace:** Crea un pequeño script en bash o python que abra 500 conexiones simultáneas por netcat hacia tu servidor en menos de un segundo y envíe basura.
    * **Qué debe pasar:** Tu servidor no debe cerrarse. Debe aceptar las conexiones hasta donde el sistema operativo se lo permita. Si se alcanza el límite máximo de FDs (suele ser 1024 en Unix), el servidor debe rechazar las nuevas conexiones limpiamente sin hacer *Segfault*.
* **Prueba de Desconexión Fantasma:**
    * **Cómo se hace:** Conecta un cliente real (como irssi), únete a un canal y luego "mata" el proceso del cliente desde la terminal (`kill -9 <pid_del_cliente>`) o desconecta tu internet.
    * **Qué debe pasar:** Tu `poll()` detectará un evento, y al hacer `recv()` devolverá `0` o `-1`. Tu servidor debe atrapar esto, hacer el proceso de `QUIT`, avisar al canal que el usuario "desapareció" y liberar la memoria sin colgarse.
* **Prueba de Comandos Malformados:**
    * **Cómo se hace:** Envía comandos sin parámetros (`JOIN \r\n`), con demasiados parámetros (`NICK a b c d \r\n`), o cadenas de texto gigantescas (para intentar causar un *Buffer Overflow*).
    * **Qué debe pasar:** Tu clase `Message` de la Fase 4 debe parsear esto de forma segura. El servidor simplemente debe responder con los errores numéricos correspondientes de IRC (ej. `ERR_NEEDMOREPARAMS`) y seguir funcionando.
* **Prueba de Fugas de Memoria (Leaks):**
    * **Cómo se hace:** Ejecuta tu servidor usando `valgrind ./ircserv <puerto> <pass>` (o `leaks` si estás en MacOS). Conecta clientes, crea canales, expulsa gente y cierra el servidor con `Ctrl+C`.
    * **Qué debe pasar:** Debes atrapar la señal `SIGINT` (Ctrl+C) para que tu programa salga del bucle infinito, recorra su lista de clientes y canales, haga `delete` de todo lo creado dinámicamente y cierre todos los FDs. El reporte de fugas debe ser exactamente 0.

---

### 2. El Bonus: Llevando el proyecto al siguiente nivel

**Importante:** Solo invierte tiempo en el bonus si la parte obligatoria es indestructible. Si tienes un solo *Segfault* en la evaluación, los bonus no se revisarán.

#### A. El Bot de IRC (Asistente Automático)
Un bot en IRC no es más que un "usuario" programado que reacciona automáticamente a ciertos mensajes. Tienes dos formas de implementarlo:

* **Opción 1: Bot Externo (La más realista y recomendada):**
    * **Cómo funciona:** Creas un programa completamente separado (puede ser otro ejecutable en C++, o incluso un script en Python si las normas de tu campus lo permiten para el bonus).
    * **Implementación:** Este programa se conecta a tu servidor IRC usando *sockets* normales, como si fuera irssi. Hace el `PASS`, `NICK Bot` y `USER`. Luego hace `JOIN #general`. Se queda en un bucle leyendo con `recv()`. Si lee que alguien escribió `PRIVMSG #general :!chiste`, el bot responde enviando al servidor `PRIVMSG #general :¿Qué le dice un bit al otro? Nos vemos en el bus.`.
* **Opción 2: Bot Interno (Integrado en el Servidor):**
    * **Cómo funciona:** El bot "vive" dentro del código de tu servidor. No usa una conexión de red real.
    * **Implementación:** En tu función `handlePrivmsg`, agregas una condición: si el destinatario es "Bot", no buscas el FD en la red. En su lugar, pasas el mensaje a una clase estática `Bot::respond(mensaje)`. El bot genera la respuesta y el servidor la pone directamente en el `_writeBuffer` del usuario que hizo la pregunta.

#### B. Transferencia de Archivos (DCC - Direct Client-to-Client)
Este es el bonus más incomprendido. En el protocolo IRC, **el servidor NO transfiere el archivo**. Si Juan le envía un archivo de 1GB a María, el archivo no pasa por tu servidor (eso colapsaría la red). Se usa el protocolo **DCC**.

* **Cómo funciona realmente el DCC:**
    1.  Juan quiere enviar `foto.jpg` a María.
    2.  El cliente de Juan (ej. HexChat) abre un puerto en su propia computadora para servir el archivo.
    3.  El cliente de Juan envía un `PRIVMSG` especial a María a través de tu servidor. Este mensaje se llama **CTCP** (Client-to-Client Protocol) y está envuelto en caracteres especiales `\001`.
    4.  El mensaje se ve así: `PRIVMSG Maria :\001DCC SEND foto.jpg 2130706433 5000 1024\001` (Los números son la IP de Juan en formato decimal, el puerto abierto y el peso del archivo).
    5.  **El rol de tu servidor:** Tu servidor solo tiene que procesar este `PRIVMSG` como cualquier otro mensaje privado y entregárselo a María sin alterar ni romper los caracteres `\001`.
    6.  El cliente de María recibe el mensaje, entiende que es una petición DCC, e inicia una conexión TCP *directa* hacia la IP y puerto de Juan para descargar el archivo.
* **Tu tarea de desarrollo:** Para cumplir este bonus, tu gestión de `PRIVMSG` (Fase 5) debe ser tan impecable y limpia que permita el tráfico de mensajes CTCP (que contienen caracteres invisibles `\001`) sin corromperlos. Al lograr esto, la transferencia de archivos funcionará "mágicamente" entre dos clientes reales conectados a tu servidor.
