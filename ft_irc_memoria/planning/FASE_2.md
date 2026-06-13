# Fase 2: Redes y Core del Servidor - DONE ✅

- Manejar argumentos de entrada: Configurar el ejecutable para recibir obligatoriamente el formato ./ircserv <port> <password>

- Inicializar Sockets: Implementar la creación del socket del servidor para establecer comunicación vía TCP/IP (v4 o v6).

- Configurar I/O no bloqueante: Usar fcntl(fd, F_SETFL, O_NONBLOCK) (es la única bandera permitida de fcntl(), especialmente crucial si trabajas en MacOS).


- Implementar el bucle principal: Configurar la función poll() (o equivalentes permitidos como select, kqueue, epoll) para poder manejar múltiples clientes simultáneamente sin que el servidor se cuelgue.


---

### 1\. Desglose de Subtareas

Para construir el núcleo del servidor, debes seguir esta secuencia lógica:

  * **Validación de Argumentos:** Leer el puerto (debe ser un número válido, usualmente entre 1024 y 65535) y la contraseña al ejecutar `./ircserv <port> <password>`.
  * **Creación del Socket del Servidor:** Usar `socket()` para crear un punto de enlace de red TCP/IP (AF\_INET, SOCK\_STREAM).
  * **Configuración de Opciones del Socket:** Usar `setsockopt()` con `SO_REUSEADDR` para evitar errores de "puerto en uso" si tienes que reiniciar el servidor rápidamente durante tus pruebas.
  * **Modo No Bloqueante (Crucial):** Configurar el socket del servidor para que no se quede "congelado" esperando conexiones. Debes usar exactamente `fcntl(fd, F_SETFL, O_NONBLOCK)`.
  * **Vinculación y Escucha:** Usar `bind()` para atar el socket al puerto especificado y `listen()` para decirle al sistema operativo que este socket aceptará conexiones entrantes.
  * **Configuración de Multiplexación:** Crear una estructura (generalmente un array o un `std::vector` de `struct pollfd`) para vigilar múltiples File Descriptors (FDs). Añadir el socket del servidor a esta estructura para vigilar eventos de lectura (`POLLIN`).
  * **El Bucle Principal (The Event Loop):** Implementar un bucle `while(true)` que llame a `poll()` (o equivalente) continuamente. Solo puedes tener un `poll()` en todo el proyecto.
  * **Aceptación de Clientes:** Dentro del bucle, si `poll()` indica que hay actividad en el socket del servidor, usar `accept()` para dejar entrar al nuevo cliente. **Importante:** Al nuevo FD del cliente también debes aplicarle `fcntl()` en modo no bloqueante y añadirlo a tu estructura de vigilancia.
  * **Lectura Inicial:** Si `poll()` indica actividad en el FD de un cliente ya conectado, usar `recv()` para leer los datos que envió y, por ahora, simplemente imprimirlos en tu terminal.

-----

### 2\. Archivos y Clases Recomendadas

Dado que debes usar C++98, una buena arquitectura orientada a objetos te ahorrará muchos dolores de cabeza. Aquí tienes una propuesta de estructura inicial:

  * **`main.cpp`**
      * **Responsabilidad:** Punto de entrada. Valida que haya exactamente 2 argumentos (puerto y contraseña), inicializa la clase `Server` y llama a su método de inicio. Atrapa excepciones generales (bloques try-catch).
  * **`Server.hpp` / `Server.cpp`**
      * **Responsabilidad:** Es el gestor principal. Contiene la lógica de red.
      * **Atributos clave:** Puerto, contraseña, el FD del socket del servidor, un `std::vector<struct pollfd>` para vigilar conexiones, y un mapa o vector para almacenar a los clientes conectados (ej. `std::map<int, Client>`).
      * **Métodos clave:** `init()` (configura el socket principal), `run()` (contiene el bucle infinito con `poll()`), `acceptNewClient()`, y `receiveData(int client_fd)`.
  * **`Client.hpp` / `Client.cpp`**
      * **Responsabilidad:** Representa a un usuario individual conectado a tu servidor.
      * **Atributos clave:** Su File Descriptor (FD), su dirección IP. Más adelante, aquí guardarás su nickname, si está autenticado, y sus buffers de lectura/escritura (vitales porque usarás redes no bloqueantes y puedes recibir comandos a medias).

-----

### 3\. ¿Qué deberías tener al finalizar la Fase 2? (Criterios de Éxito)

Al terminar esta fase, tu programa no será todavía un servidor IRC completo, pero será un servidor TCP robusto. Debería funcionar de la siguiente manera:

1.  **Arranque:** Compilas tu proyecto con `make` y ejecutas `./ircserv 6667 mipassword`. El programa se queda ejecutándose sin consumir el 100% de la CPU (gracias a que `poll()` duerme el proceso hasta que hay eventos).
2.  **Conexión Externa:** Abres una nueva terminal y usas netcat para simular un cliente: `nc -C 127.0.0.1 6667`.
3.  **Recepción:** Escribes "Hola servidor" en la terminal de netcat y presionas Enter.
4.  **Reacción del Servidor:** En la terminal donde se ejecuta `./ircserv`, deberías ver un mensaje impreso como: *"[Servidor] Cliente \<FD\> dice: Hola servidor"*.
5.  **Resiliencia:** Si abres 5 terminales con netcat a la vez, el servidor debe aceptar a todos sin bloquearse. Si cierras un netcat abruptamente (`Ctrl+C`), tu servidor debe detectar la desconexión, eliminar el FD de su lista vigilada, y **no cerrarse inesperadamente**[.

