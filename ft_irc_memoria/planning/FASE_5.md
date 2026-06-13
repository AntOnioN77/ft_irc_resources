# Fase 5: Canales y Mensajería

- Comando JOIN: Permitir a los usuarios unirse a canales de chat.


- Comando PRIVMSG: Implementar el envío y recepción de mensajes privados directos entre usuarios.


- Broadcasting: Asegurar que todos los mensajes enviados desde un cliente hacia un canal se reenvíen a todos los demás clientes que estén en ese mismo canal.

---

### 1. Desglose de Subtareas

* **Subtarea 5.1: Comando `JOIN` (Unirse/Crear Canales):** Si un cliente envía `JOIN #general`, debes verificar si el canal `#general` existe. Si no existe, el servidor lo crea y el cliente se convierte en el operador inicial. Si ya existe, el cliente simplemente se añade a la lista de miembros del canal.
* **Subtarea 5.2: Notificaciones de Ingreso:** Cuando alguien hace `JOIN`, el servidor debe avisar a **todos** los miembros actuales del canal que alguien nuevo entró. Además, el servidor debe enviarle al nuevo miembro el tema del canal (RPL_TOPIC) y la lista de usuarios conectados (RPL_NAMREPLY).
* **Subtarea 5.3: Comando `PRIVMSG` (Mensajería):** A pesar de su nombre, `PRIVMSG` se usa tanto para mensajes privados entre dos usuarios (`PRIVMSG juan :Hola Juan`) como para mensajes a canales completos (`PRIVMSG #general :Hola a todos`). Debes programar la lógica para distinguir si el destinatario empieza con `#` (canal) o no (usuario regular).
* **Subtarea 5.4: Comando `PART` (Salir del canal):** Permite a un usuario abandonar un canal específico. Se debe notificar al resto del canal que el usuario se fue y eliminarlo de la lista interna del canal.
* **Subtarea 5.5: Comando `QUIT` (Desconexión global):** Si el usuario cierra el cliente o envía `QUIT`, debes sacarlo de **todos** los canales en los que esté, notificar a esos canales, y luego ejecutar la lógica de desconexión que creaste en la Fase 3.

---

### 2. Archivos, Clases y Responsabilidades

Necesitamos introducir una entidad que agrupe a los clientes.

**Nueva Clase: `Channel` (`Channel.hpp` / `Channel.cpp`)**
* **Responsabilidad:** Mantener el estado de una sala de chat y saber quiénes están dentro.
* **Atributos:**
    * `std::string _name;` (ej. "#general").
    * `std::string _topic;` (El tema del canal).
    * `std::map<int, Client*> _members;` (Un mapa de los clientes conectados. Usar punteros `Client*` es vital en C++98 para referenciar a los clientes que ya existen en el `Server` sin duplicarlos en memoria).
    * `std::vector<int> _operators;` (Guarda los FDs de los usuarios que tienen privilegios de administrador en este canal).
* **Métodos:**
    * `void addClient(Client* client);`
    * `void removeClient(int client_fd);`
    * `void broadcast(std::string message, int sender_fd);` (Envía el string a los `_writeBuffer` de todos los `_members`, exceptuando al `sender_fd`).
    * `bool isMember(int client_fd);`

**Expansión de la Clase `Server` (`Server.hpp` / `Server.cpp`)**
* **Nuevos Atributos:**
    * `std::map<std::string, Channel> _channels;` (Un diccionario que relaciona el nombre del canal, como "#general", con su objeto `Channel`).
* **Nuevos Métodos:**
    * `void handleJoin(Client &client, Message &msg);`
    * `void handlePrivmsg(Client &client, Message &msg);`
    * `void handlePart(Client &client, Message &msg);`
    * `void handleQuit(Client &client, Message &msg);`

---

### 3. ¿Cómo se unifica con las Fases 3 y 4? (El Flujo)

El proceso sigue naciendo en tu bucle `poll()`, pero ahora añadimos un "filtro de seguridad" y nuevas ramas en tu enrutador de comandos.

1.  Tu bucle `poll()` detecta actividad y reconstruye un comando completo en la Fase 3.
2.  Tu clase `Message` (Fase 4) parsea el string: `_command = "JOIN"`, `_parameters = ["#general"]`.
3.  Entra a `Server::processCommand(Client &client, Message &msg)`.
4.  **Capa de Seguridad:** Aquí debes añadir una validación: `if (!client.isRegistered() && msg.getCommand() != "PASS" && msg.getCommand() != "NICK" && msg.getCommand() != "USER")`. Si el cliente no está autenticado, no puede usar `JOIN` ni `PRIVMSG`. Le envías un error al `_writeBuffer` y detienes la ejecución.
5.  Si está registrado, el `switch` o cadena de `if` dirige el flujo a `handleJoin()`.
6.  `handleJoin()` busca "#general" en `_channels`.
    * Si no existe: crea el `Channel`, lo mete en el mapa, y usa `canal.addClient(&client)`.
    * Si existe: usa `canal.addClient(&client)`.
7.  Finalmente, `handleJoin()` genera las respuestas IRC requeridas (RPL_JOIN, RPL_NAMREPLY) y las añade al `_writeBuffer` de todos los involucrados.
8.  En la siguiente vuelta de tu `poll()`, los eventos `POLLOUT` se dispararán y todos los clientes recibirán los mensajes.
