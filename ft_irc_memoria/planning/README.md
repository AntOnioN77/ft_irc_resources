# Resumen de las Fases de desarrollo del ft_irc

### Fase 1: Preparación y Configuración Inicial
* **Crear repositorio y estructura:** Configurar Git y la estructura base de archivos fuente cumpliendo con el estándar C++98.
* **Escribir el Makefile:** Debe compilar tu código sin relinking innecesario e incluir estrictamente las reglas `$(NAME)`, `all`, `clean`, `fclean` y `re`.
* **Redactar el README.md:** Añadir obligatoriamente la frase de la escuela 42 en cursiva en la primera línea.
* **Estructurar README.md:** Completar las secciones "Description", "Instructions" y "Resources", detallando cómo se utilizó la IA para apoyar el proyecto.

### Fase 2: Redes y Core del Servidor
* **Manejar argumentos de entrada:** Configurar el ejecutable para recibir obligatoriamente el formato `./ircserv <port> <password>`.
* **Inicializar Sockets:** Implementar la creación del socket del servidor para establecer comunicación vía TCP/IP (v4 o v6).
* **Configurar I/O no bloqueante:** Usar `fcntl(fd, F_SETFL, O_NONBLOCK)` (es la única bandera permitida de `fcntl()`, especialmente crucial si trabajas en MacOS).
* **Implementar el bucle principal:** Configurar la función `poll()` (o equivalentes permitidos como `select`, `kqueue`, `epoll`) para poder manejar múltiples clientes simultáneamente sin que el servidor se cuelgue[cite: 92, 98, 100].

### Fase 3: Gestión de Conexiones y Datos
* **Aceptar nuevas conexiones:** Registrar los nuevos clientes y sus file descriptors en la estructura de tu función `poll()`.
* **Lectura/Escritura segura:** Implementar `recv` y `send` asegurando que pasen por `poll()` u otra función equivalente; de lo contrario, tu calificación será 0.
* **Agregador de paquetes:** Programar un sistema de buffers para acumular datos parciales recibidos hasta reconstruir un comando IRC completo.

### Fase 4: Protocolo IRC (Autenticación)
* **Seleccionar cliente de referencia:** Elegir un cliente IRC oficial (como irssi o hexchat) que se utilizará para todas las pruebas y evaluaciones.
* **Comando PASS:** Verificar que la contraseña enviada por el cliente coincide con la configurada al lanzar el servidor.
* **Comandos NICK y USER:** Implementar la lógica para que el cliente pueda establecer su apodo y su nombre de usuario de forma exitosa.

### Fase 5: Canales y Mensajería
* **Comando JOIN:** Permitir a los usuarios unirse a canales de chat.
* **Comando PRIVMSG:** Implementar el envío y recepción de mensajes privados directos entre usuarios.
* **Broadcasting:** Asegurar que todos los mensajes enviados desde un cliente hacia un canal se reenvíen a todos los demás clientes que estén en ese mismo canal.

### Fase 6: Privilegios y Comandos de Operador
* **Gestión de roles:** Diferenciar internamente entre usuarios regulares y operadores de canal.
* **Comando KICK:** Programar la función para expulsar a un cliente del canal.
* **Comando INVITE:** Programar la función para invitar a un cliente a un canal.
* **Comando TOPIC:** Implementar la visualización o el cambio del tema del canal.
* **Comando MODE:** Programar las banderas específicas para gestionar canales por invitación (`i`), restricciones del comando TOPIC (`t`), contraseñas de canal (`k`), privilegios de operador (`o`) y límite de usuarios (`l`).

### Fase 7: Pruebas Rigurosas y Bonus (Opcional)
* **Pruebas de estrés:** Verificar que el programa no se bloquee ni se cierre inesperadamente bajo ninguna circunstancia, incluso si se queda sin memoria, para evitar una calificación de 0.
* **Pruebas de red con netcat:** Usar `nc -C 127.0.0.1 <port>` enviando comandos fragmentados manualmente con `Ctrl+D` para verificar que tu agregador de paquetes funciona correctamente.
* **Desarrollo de Bonus (Opcional):** Implementar la transferencia de archivos o un Bot automatizado, recordando que esto solo se evaluará si la parte obligatoria funciona de manera perfecta.
