# Fase 6: Privilegios y Comandos de Operador

- Gestión de roles: Diferenciar internamente entre usuarios regulares y operadores de canal.


- Comando KICK: Programar la función para expulsar a un cliente del canal.


- Comando INVITE: Programar la función para invitar a un cliente a un canal.


- Comando TOPIC: Implementar la visualización o el cambio del tema del canal.


- Comando MODE: Programar las banderas específicas para gestionar canales por invitación (i), restricciones del comando TOPIC (t), contraseñas de canal (k), privilegios de operador (o) y límite de usuarios (l).


---

### 1. Desglose de Subtareas

* **Subtarea 6.1: Arquitectura de Modos de Canal:** Extender la lógica del canal para que pueda "recordar" qué reglas tiene activas (ej. si tiene contraseña, si tiene límite de usuarios, etc.).
* **Subtarea 6.2: Comando `KICK` (Expulsión):** Implementar la lógica para que un operador pueda sacar a un usuario del canal. El servidor debe verificar que quien ejecuta el comando es operador, que el objetivo está en el canal, sacarlo y notificar a todos (incluyendo al expulsado).
* **Subtarea 6.3: Comando `INVITE` (Invitación):** Permitir a los usuarios (u operadores, dependiendo de los modos) invitar a otros al canal. Si el canal es "solo por invitación", el servidor debe guardar esta invitación en una lista blanca para permitir que el objetivo haga `JOIN` más tarde.
* **Subtarea 6.4: Comando `TOPIC` (Tema del canal):** Permitir ver o cambiar el tema del canal. Debe respetar el modo `+t` (si está activo, solo los operadores pueden cambiarlo; si no, cualquiera puede).
* **Subtarea 6.5: Comando `MODE` (El jefe final):** Parsear y aplicar los cambios de configuración del canal. Debes soportar añadir (`+`) o quitar (`-`) exactamente estas banderas exigidas por el proyecto:
    * `i`: Canal solo por invitación.
    * `t`: Restricciones del comando TOPIC (solo operadores).
    * `k`: Establecer/quitar contraseña del canal.
    * `o`: Dar/quitar privilegios de operador a un usuario.
    * `l`: Establecer/quitar un límite máximo de usuarios.

---

### 2. Archivos, Clases y Responsabilidades

En esta fase no necesitas crear archivos nuevos, sino **potenciar** enormemente tu clase `Channel` y añadir los enrutadores en `Server`.

**Expansión de la Clase `Channel` (`Channel.hpp` / `Channel.cpp`)**
* **Nuevos Atributos (Estados y Modos):**
    * `bool _inviteOnly;` (Para el modo `i`).
    * `bool _topicRestricted;` (Para el modo `t`).
    * `std::string _password;` (Para el modo `k`. Vacío si no hay clave).
    * `unsigned int _userLimit;` (Para el modo `l`. `0` si no hay límite).
    * `std::vector<int> _invitedUsers;` (Lista de FDs o nicknames que tienen permitido entrar si `_inviteOnly` es true).
* **Nuevos Métodos de Control:**
    * `bool isOperator(int client_fd);` (Verifica si el usuario está en el vector `_operators` que creaste en la Fase 5).
    * `void addOperator(int client_fd);` / `void removeOperator(int client_fd);` (Para el modo `o`).
    * Getters y setters para los modos (`setInviteOnly(bool state)`, `setPassword(std::string key)`, etc.).
    * `bool isInvited(int client_fd);`

**Expansión de la Clase `Server` (`Server.hpp` / `Server.cpp`)**
* **Nuevos Métodos (Manejadores de Comandos):**
    * `void handleKick(Client &client, Message &msg);`
    * `void handleInvite(Client &client, Message &msg);`
    * `void handleTopic(Client &client, Message &msg);`
    * `void handleMode(Client &client, Message &msg);`

---

### 3. Integración con las Fases Anteriores (El Flujo Completo)

La integración ocurre en dos lugares principales: el enrutador de comandos y una modificación crucial al comando `JOIN` de la Fase 5.

**A. En el Enrutador (`Server::processCommand`):**
1.  Como en la Fase 5, verificas que el cliente esté registrado (`PASS`, `NICK`, `USER` completados).
2.  El `Message` parseado indica, por ejemplo, que es un comando `KICK`.
3.  Llamas a `handleKick()`. Esta función debe hacer sus **validaciones de seguridad en este orden estricto**:
    * ¿El canal existe? (Si no, envía error `ERR_NOSUCHCHANNEL`).
    * ¿El cliente que ejecuta el comando está en el canal? (Error `ERR_NOTONCHANNEL`).
    * **LA REGLA DE ORO:** ¿El cliente es operador? Llamas a `canal.isOperator(client.getFd())`. (Si no lo es, envía error `ERR_CHANOPRIVSNEEDED`).
    * ¿El usuario objetivo está en el canal? (Error `ERR_USERNOTINCHANNEL`).
    * Si todo está bien: lo eliminas del canal (`canal.removeClient()`) y haces un `broadcast` del mensaje de expulsión para que las pantallas de todos se actualicen.

**B. Modificación obligatoria al `JOIN` (Retrofiting de la Fase 5):**
Ahora que los canales tienen modos, tu función `handleJoin()` debe volverse más inteligente antes de dejar entrar a alguien:
* Si el canal tiene contraseña (`_password` no está vacío), el `JOIN` del usuario debe incluir la contraseña correcta (`JOIN #canal miclave`). Si no, error `ERR_BADCHANNELKEY`.
* Si el canal es `+i` (`_inviteOnly` es true), debes verificar si el usuario está en la lista `_invitedUsers`. Si no, error `ERR_INVITEONLYCHAN`.
* Si el canal tiene límite `+l` (`_userLimit > 0`), verificas si el número actual de `_members` es menor al límite. Si está lleno, error `ERR_CHANNELISFULL`.
