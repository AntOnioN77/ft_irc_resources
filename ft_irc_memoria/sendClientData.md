Bien, vamos paso a paso. Empezaré por entender el contexto general antes de llegar a `sendClientData()`.

## Concepto base: I/O no bloqueante con `poll()`

El servidor usa un patrón de **I/O multiplexado no bloqueante**. En lugar de tener un hilo por cliente (bloqueante), un único hilo monitorea múltiples conexiones simultáneamente.

**Lo clave:**
- `poll()` monitorea un array de sockets (el array `connections_`)
- Le dices qué **eventos te interesan** (lectura, escritura, desconexión)
- `poll()` retorna indicándote **cuál socket tiene qué evento**
- Tú respondes a ese evento sin bloquear a los demás

En `connections_`, cada elemento tiene:
```
fd       → descriptor del socket
events   → qué eventos QUIERO monitorear (POLLIN = lectura, POLLOUT = escritura)
revents  → qué eventos PASARON (información que retorna poll)
```

---

## En `run()`: la lógica general

```cpp
while (Server::signal_received_ == false)
{
    poll(&connections_[0], connections_.size(), -1);  // Espera eventos
    
    for (int i = connections_.size() - 1; i >= 0; i--)
    {
        // Revisa qué pasó en cada socket
        if (connections_[i].revents & (POLLIN | POLLHUP))  // ¿Hay datos para leer?
        {
            // (...)
            receiveClientData(i);
            // (...)
        }
        else if (connections_[i].revents & POLLOUT)  // ¿Puedo escribir?
        {
            sendClientData(i);  // Envía datos pendientes
        }
    }
}
```

**La idea:** después de procesar comandos recibidos (en `receiveClientData()`), el cliente tiene datos en su buffer de salida que quiere enviar. `sendClientData()` se encarga de eso cuando el socket está listo para escribir (`POLLOUT`).

---


## Flujo de envío de datos: la intención del programador

**Pregunta clave:** ¿Cuándo tiene datos para enviar un cliente?

Respuesta: **Cuando ejecuta un comando, el comando genera una respuesta que se debe enviar al cliente.**

### Paso 1: Un comando genera datos de salida

Mira en `receiveClientData()`:

```cpp
cmd->execute(&client, this);  // El comando se ejecuta
```

El comando (por ejemplo `PassCommand` o `NickCommand`) **usa el cliente y el servidor para generar respuestas**. Esas respuestas se guardan en el **buffer de escritura del cliente** usando algo como:

```cpp
client.appendToWriteBuf(respuesta);  // Ahora el cliente TIENE datos que enviar
```

---

### Paso 2: Activar el evento POLLOUT

Aquí viene lo interesante. Mira `queueueClientData()` (sí, está mal escrito 😄):

```cpp
void Server::queueueClientData(Client &client, const std::string &data)
{
    size_t id = findConnectionByFd(client.getFd());
    connections_[id].events |= POLLOUT;  // ← ACTIVA POLLOUT
    client.appendToWriteBuf(data);
}
```

La línea `|= POLLOUT` **activa el bit de POLLOUT** en ese socket. Ahora `poll()` **vigilará cuando ese socket esté listo para escribir**.

**¿Por qué no está habilitado desde el inicio?** Porque en `acceptNewClient()`:

```cpp
new_connection.events = POLLIN;  // ← Solo monitorea lectura
connections_.push_back(new_connection);
```

Solo pide que se monitoree lectura. **No tiene sentido vigilar "¿puedo escribir?" si no hay datos pendientes**. Es un desperdicio.

---

### Paso 3: poll() avisa que puedo escribir

En el siguiente ciclo de `run()`, cuando `poll()` retorna:

```cpp
else if (connections_[i].revents & POLLOUT)  // ¿Este socket está listo para escribir?
{
    sendClientData(i);
}
```

Si el socket está listo, llamamos a `sendClientData()`.

---

## sendClientData()
Ahora que ya tenemos claro el contexto vamos a comprender paso a paso sendClientData()
## Parte 1: Setup - Obtener referencias

```cpp
bool Server::sendClientData(size_t client_index)
{
	int fd = connections_[client_index].fd;
	Client &client = clients_[fd];
	const std::string &clientWriteBuf = client.getWriteBuf();
```

**¿Qué hace?**

- `client_index` es el **índice en el array `connections_`**
- Obtiene el file descriptor (`fd`) de ese socket
- Obtiene una **referencia** al objeto `Client` desde el map `clients_`
- Obtiene una **referencia al buffer de escritura** del cliente (lo que tiene pendiente por enviar)

**¿Por qué referencias?** Para no copiar datos enormes. Es eficiente.

---

## Parte 2: Check inicial

```cpp
	if (clientWriteBuf.empty())
	{
		return false;
	}
```

**¿Qué hace?**

Si el buffer de escritura **está vacío**, no hay nada que enviar. Retorna `false`.

**¿Cuándo pasa esto?**

En teoría, no debería pasar casi nunca. Se llama `sendClientData()` **cuando `poll()` indicó POLLOUT** (socket listo para escribir). Si llegamos aquí, es porque en algún momento alguien activó POLLOUT pero luego el buffer se vació. Puede ocurrir en casos raros de timing.

---

## Parte 3: El `send()` en sí

```cpp
ssize_t bytes_sent = send(fd, clientWriteBuf.c_str(), clientWriteBuf.size(), 0);
```

**¿Qué hace?**

Intenta enviar **todo el buffer** al socket `fd`. Es una llamada **no bloqueante** (porque el socket fue configurado con `O_NONBLOCK`).

**¿Qué retorna?**

- **`> 0`**: Número de bytes **realmente enviados** (puede ser **menos que el buffer completo**)
- **`0`**: Conexión cerrada (raro con sockets no bloqueantes)
- **`-1`**: Error

**Punto clave:** NO garantiza que envíe TODO el buffer. Envía **lo que el SO permite en ese momento**. Si el buffer tiene 1000 bytes, tal vez solo envía 256. El resto queda esperando.

---

## Parte 4: Caso éxito (`bytes_sent > 0`)

```cpp
if (bytes_sent > 0)
{
    client.eraseFromWriteBuf(bytes_sent);  // Borra los bytes que ya enviamos
    if (client.getWriteBuf().empty())      // ¿Se vació el buffer?
    {
        connections_[client_index].events &= ~POLLOUT;  // Desactiva POLLOUT
        if (client.getToDisconnect())
            disconnectClient(fd);           // Si estaba marcado para desconectar...
    }
}
```

**Lógica:**

1. Se enviaron `bytes_sent` bytes. Los **borra del buffer**
2. Si el buffer quedó **vacío**, desactiva POLLOUT (no hay más que enviar)
3. **Caso especial:** si el cliente estaba marcado con `toDisconnect_`, lo desconecta **ahora que terminó de enviar todo**

**¿Qué es `getToDisconnect()`?** Un flag que significa "desconecta después de enviar todo lo pendiente". Así se garantiza que el cliente reciba toda su respuesta antes de cerrar la conexión.

---

## Parte 5: Caso error (`bytes_sent == -1`)

```cpp
else if (bytes_sent == -1)
{
    //  TODO: This should not exists because the evals says so
//	if (errno == EAGAIN || errno == EWOULDBLOCK)
//	{
//		return false;
//	}
    disconnectClient(fd); //pipe roto probablemente??
    return true;
}
```

**¿Qué pasa?**

`send()` retornó `-1`, significa **error en el socket**. El código **desconecta inmediatamente** ese cliente.

**Aquí hay algo interesante:** el código comentado sugiere que en algún momento el programador **consideró diferenciar** entre:
- **EAGAIN/EWOULDBLOCK**: "No puedo escribir ahora, reintenta después" (error **temporal**, sin bloqueante)
- **Otros errores**: EPIPE, ECONNRESET, etc. (conexión realmente **rota**)

Pero lo comentó diciendo "esto no debería existir porque los evals lo dicen así".

**En la intención actual:**
- Cualquier error = desconectar
- Retorna `true` ("error")

---

## Parte 6: Caso final (ninguno de los anteriores)

```cpp
return false;
```

Solo se llega aquí si `bytes_sent == 0` (raro en no bloqueante), que significa conexión cerrada por el otro lado. Retorna `false`.

---

**Resumen del flujo completo:**

```
¿Buffer vacío?          → false (sin enviar)
¿Envío exitoso (>0)?    → false (se envió OK) 
¿Error (-1)?            → true (error, desconecta)
¿Otros casos (0)?       → false
```

Parece que hay cierta **inversión semántica** que dificulta comprender los retornos `true` = error, `false` = OK o sin nada que hacer.


************************************************

`send()` retornando **0 es prácticamente imposible** en un TCP socket normal. Veamos:
## ¿Cuándo retorna 0 `send()`?

- Cuando el **buffer tiene tamaño 0** (no es el caso)
- Cuando el socket está en **shutdown parcial** para escritura (muy raro)
- Condiciones muy específicas y extrañas

**En tu caso:** con un cliente que se desconecta:

- Si el cliente **cierra su extremo**, nosotros lo detectamos con `recv()` retornando 0, o con POLLHUP
- Si intentamos `send()` a una conexión cerrada, retorna **-1 con errno EPIPE** ("pipe roto")
- `send()` retornando 0 **no es el flujo normal**

---

## ¿Qué significa si ocurre?

Si `bytes_sent == 0`, sí, sería **algo inesperado**:

- Una caída del socket sin aviso previo
- O una condición de error que no es -1 (raro)

**El código actual:**

```cpp
else if (bytes_sent == -1)
{
    disconnectClient(fd);
    return true;
}
return false;  // ← Aquí cae si bytes_sent == 0
```

Llega aquí, retorna `false`, y en la siguiente iteración... nada. Vuelve a `poll()`. Es **silencioso**.

**Debería tratarse explícitamente:**

```cpp
else if (bytes_sent == -1)
{
    disconnectClient(fd);
    return true;
}
else if (bytes_sent == 0)
{
    std::cerr << "WARNING: send() returned 0 on fd " << fd << std::endl;
    // Posible acción: desconectar o investigar
}
return false;
```
