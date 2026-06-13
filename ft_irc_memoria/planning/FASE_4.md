# Fase 4: Protocolo IRC (Autenticación) - WIP

- Seleccionar cliente de referencia: Elegir un cliente IRC oficial (como irssi o hexchat) que se utilizará para todas las pruebas y evaluaciones.


- Comando PASS: Verificar que la contraseña enviada por el cliente coincide con la configurada al lanzar el servidor.


- Comandos NICK y USER: Implementar la lógica para que el cliente pueda establecer su apodo y su nombre de usuario de forma exitosa.

----

### 1. Desglose de Subtareas

* **Subtarea 4.1: Parseo (Análisis) de Comandos:** El string que extrajimos en la Fase 3 (ej. `"NICK mi_apodo\r\n"`) debe dividirse en partes lógicas: el comando (`NICK`) y sus parámetros (`mi_apodo`).
* **Subtarea 4.2: Máquina de Estados del Cliente:** Debes rastrear qué pasos del registro ha completado cada cliente. No puedes aceptar un `NICK` o `USER` si el cliente no ha enviado primero el `PASS` correcto.
* **Subtarea 4.3: Implementar el comando `PASS`:** Verificar si la contraseña enviada coincide con la del servidor. Si es incorrecta, se debe enviar un error y desconectar al cliente.
* **Subtarea 4.4: Implementar el comando `NICK`:** Asignar el apodo al cliente. Debes verificar dos cosas: que el apodo no contenga caracteres inválidos (como espacios) y que no esté ya en uso por otro cliente conectado (evitar colisiones).
* **Subtarea 4.5: Implementar el comando `USER`:** Guardar el nombre de usuario y el nombre real que envía el cliente.
* **Subtarea 4.6: El Mensaje de Bienvenida (RPL_WELCOME):** Cuando el cliente ha enviado un `PASS` válido, un `NICK` válido y un `USER` válido, el servidor **debe** responder con el código numérico `001` (RPL_WELCOME). Sin este mensaje, clientes reales como HexChat o irssi se quedarán cargando infinitamente y no te mostrarán la interfaz.

---

### 2. Archivos, Clases y Responsabilidades

Para mantener el código de C++98 limpio y escalable (ya que luego vendrán muchos más comandos), te recomiendo introducir una nueva clase y expandir las anteriores:

**Nueva Clase: `Message` (o `CommandParser`)** (`Message.hpp` / `Message.cpp`)
* **Responsabilidad:** Tomar el string crudo del buffer y trocearlo.
* **Atributos:**
    * `std::string _command;` (ej. "NICK")
    * `std::vector<std::string> _parameters;` (ej. ["mi_apodo"])
* **Métodos:**
    * `parse(std::string raw_string);`: Divide el string por espacios, ignorando los prefijos si los hay, y llenando los atributos.

**Expansión de la Clase `Client`** (`Client.hpp` / `Client.cpp`)
* **Nuevos Atributos de Estado:**
    * `bool _hasPassed;` (¿Envió la contraseña correcta?)
    * `std::string _nickname;`
    * `std::string _username;`
    * `std::string _realname;`
    * `bool _isRegistered;` (Se vuelve `true` cuando tiene PASS, NICK y USER).
* **Nuevos Métodos:** Getters y setters para estos atributos.

**Expansión de la Clase `Server`** (`Server.hpp` / `Server.cpp`)
* **Nuevos Métodos (El Enrutador de Comandos):**
    * `void processCommand(Client &client, Message &msg);`: Actúa como un "switch". Si `msg._command == "PASS"`, llama a `handlePass()`. Si es "NICK", llama a `handleNick()`, etc.
    * `void handlePass(Client &client, Message &msg);`
    * `void handleNick(Client &client, Message &msg);`
    * `void handleUser(Client &client, Message &msg);`
    * `void sendWelcomeMessage(Client &client);`

---

### 3. ¿Cómo se conecta con la Fase 3? (El Flujo Completo)

En la Fase 3, nos quedamos en el punto donde extraías un comando completo (`\r\n`) del `_readBuffer` y lo imprimías. Ahora, el ciclo de vida dentro de tu bucle principal (`poll()`) se actualiza así:

1. `poll()` detecta actividad de lectura.
2. `Server` lee los datos y los mete en `_readBuffer` del `Client`.
3. `Server` detecta que hay un comando completo (ej. `"PASS 1234\r\n"`).
4. **¡Aquí entra la Fase 4!** El `Server` extrae el string y crea un objeto `Message`.
5. `Message::parse()` lo divide: `_command = "PASS"`, `_parameters = ["1234"]`.
6. El `Server` pasa este `Message` a `processCommand()`.
7. `processCommand()` identifica que es "PASS" y ejecuta `handlePass()`.
8. `handlePass()` verifica la contraseña. Si es correcta, marca `client._hasPassed = true`.
9. **MUY IMPORTANTE (Escritura no bloqueante):** Si el servidor necesita responderle algo al cliente (ej. un error porque el NICK está en uso, o el RPL_WELCOME), **NO usas `send()` directamente**. Añades la respuesta al `_writeBuffer` del cliente.
10. En tu bucle de `poll()`, debes empezar a vigilar el evento `POLLOUT` (listo para escribir). Cuando `poll()` indique que puedes escribirle a ese cliente, tomas su `_writeBuffer` y ahora sí ejecutas `send()`, vaciando el buffer.

### Criterios de Prueba para la Fase 4

Para comprobar que esta fase es un éxito, debes usar un **cliente IRC real** (te sugiero **irssi** por consola, o **HexChat** si prefieres interfaz gráfica).

1. Lanzas tu servidor: `./ircserv 6667 mipass`.
2. Abres tu cliente IRC y configuras la conexión a `127.0.0.1` en el puerto `6667` con la contraseña `mipass`.
3. **Resultado Exitoso:** El cliente IRC se conectará, no se quedará colgado, y verás en tu interfaz el mensaje de bienvenida (001) que programaste. A partir de ese momento, la terminal de tu cliente estará lista para escribir mensajes.
4. **Prueba de fallo:** Intenta conectarte con una contraseña incorrecta desde el cliente. Tu servidor debería rechazar la conexión limpiamente sin cerrarse (sin crash).
