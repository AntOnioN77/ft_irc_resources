# Fase 3: Gestión de Conexiones y Datos

- Aceptar nuevas conexiones: Registrar los nuevos clientes y sus file descriptors en la estructura de tu función poll().


- Lectura/Escritura segura: Implementar recv y send asegurando que pasen por poll() u otra función equivalente; de lo contrario, tu calificación será 0.


- Agregador de paquetes: Programar un sistema de buffers para acumular datos parciales recibidos hasta reconstruir un comando IRC completo.

---

### 1. Desglose de Subtareas

Para gestionar los clientes y sus datos de forma segura, dividiremos el trabajo así:

* **Subtarea 3.1: Aceptación y registro del cliente:** Cuando `poll()` detecta actividad en el socket del servidor, significa que hay una nueva conexión. Debes usar `accept()` para obtener un nuevo File Descriptor (FD) para ese cliente, configurarlo en modo no bloqueante usando *únicamente* `fcntl(fd, F_SETFL, O_NONBLOCK)`, y agregarlo a tu array/vector de `pollfd`.
* **Subtarea 3.2: Lectura segura y no bloqueante:** Cuando `poll()` detecta actividad (`POLLIN`) en el FD de un *cliente ya conectado*, debes llamar a `recv()`. Debes manejar tres escenarios:
    * `recv() > 0`: Se recibieron datos correctamente.
    * `recv() == 0`: El cliente se ha desconectado limpiamente.
    * `recv() < 0`: Hubo un error de lectura.
* **Subtarea 3.3: Agregación de paquetes (Buffering):** Esta es la regla de oro de `ft_irc`. No puedes asumir que un comando IRC llegará completo en un solo `recv()`. Debes acumular (concatenar) los bytes recibidos en un "buffer" personal del cliente hasta detectar el delimitador final de comando (en el protocolo IRC, los comandos terminan en `\r\n` o al menos `\n`).
* **Subtarea 3.4: Desconexión y limpieza:** Si un cliente se desconecta (por `recv() == 0` o un error), debes eliminar su FD de la estructura de `poll()`, cerrar el FD con `close()` y borrar sus datos de las estructuras del servidor para evitar fugas de memoria.
* **Subtarea 3.5: Extracción de comandos:** Una vez que el buffer del cliente contiene un `\r\n`, debes extraer esa cadena completa para procesarla, dejando en el buffer cualquier fragmento extra que corresponda al inicio de un siguiente comando.

---

### 2. Archivos, Clases y Responsabilidades

En lugar de crear archivos nuevos, vamos a **expandir drásticamente** las clases `Server` y `Client` que definiste en la Fase 2.

**Clase `Client` (`Client.hpp` / `Client.cpp`)**
* **Nueva Responsabilidad:** Actuar como un contenedor seguro para el estado y los datos en tránsito de un usuario.
* **Nuevos Atributos:**
    * `std::string _readBuffer;`: Fundamental. Aquí concatenarás todo lo que leas con `recv()`.
    * `std::string _writeBuffer;`: Aquí almacenarás las respuestas que el servidor quiere enviarle al cliente (porque el `send()` también debe ser no bloqueante y guiado por `poll()`).
* **Nuevos Métodos:**
    * `void appendToReadBuffer(std::string data);`: Añade datos nuevos al final del buffer.
    * `bool hasCompleteCommand();`: Verifica si `_readBuffer` contiene un `\r\n`.
    * `std::string extractCommand();`: Saca el primer comando completo del `_readBuffer` y lo borra de ahí, devolviéndolo para que el servidor lo analice.

**Clase `Server` (`Server.hpp` / `Server.cpp`)**
* **Nueva Responsabilidad:** Coordinar las lecturas/escrituras y gestionar el ciclo de vida de los clientes.
* **Nuevos Métodos:**
    * `void acceptNewClient();`: Ejecuta el `accept()`, configura el FD en no bloqueante, crea una instancia de `Client` y lo guarda en su diccionario (ej. `std::map<int, Client>`).
    * `void readClientData(int client_fd);`: Hace el `recv()`. Si recibe datos, llama a `cliente.appendToReadBuffer()`. Si recibe 0, llama a `disconnectClient()`.
    * `void disconnectClient(int client_fd);`: Cierra el FD, lo elimina del vector de `pollfd` y del mapa de clientes.

---

### 3. ¿Cómo se une esto con la Fase 2? (El Bucle Principal)

En la Fase 2 creaste un bucle `while(true)` con `poll()`. Ahora, ese bucle cobrará vida. La estructura lógica de tu `Server::run()` debería verse exactamente así:

1.  Llamas a `poll()` (el programa se pausa aquí hasta que pase algo).
2.  Iteras sobre tu lista de `pollfd` para ver *quién* generó el evento.
3.  **Si el evento es en el FD del Servidor:**
    * ¡Alguien nuevo quiere entrar!
    * Llamas a `acceptNewClient()`.
4.  **Si el evento es en el FD de un Cliente:**
    * ¡Un cliente envió datos (o se desconectó)!
    * Llamas a `readClientData(client_fd)`.
    * Luego, verificas: `if (cliente.hasCompleteCommand())`.
    * Si es así, extraes el comando (`extractCommand()`) y (por ahora) lo imprimes en la consola para confirmar que la agregación funcionó.

### Criterios de Prueba para la Fase 3

Para asegurarte de que esta fase está perfecta antes de avanzar, debes realizar la prueba del PDF usando `nc` (netcat):
1.  Te conectas: `nc -C 127.0.0.1 <puerto>`
2.  Escribes "com", presionas `Ctrl+D` (esto envía el paquete sin salto de línea).
3.  Escribes "man", presionas `Ctrl+D`.
4.  Escribes "d" y presionas *Enter* (esto envía la 'd' y el `\r\n`).
5.  **Resultado esperado:** Tu servidor no debe imprimir nada en los primeros dos pasos. Solo en el paso 4 debe imprimir "Comando recibido: command".
