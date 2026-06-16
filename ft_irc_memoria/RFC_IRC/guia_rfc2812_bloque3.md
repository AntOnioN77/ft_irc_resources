# Guía bilingüe RFC 2812 — Bloque 3: Envío de mensajes y mantenimiento de conexión

*Guía de lectura del RFC 2812 (Internet Relay Chat: Client Protocol) para ft_irc.
Las citas del RFC, la gramática ABNF, los nombres de comandos y de replies se mantienen
en inglés tal cual aparecen en el original. La explicación está en castellano.*

**Cubre:** sección 3.3 (PRIVMSG, NOTICE) y sección 3.7 (PING 3.7.2, PONG 3.7.3,
ERROR 3.7.4) del RFC 2812.
**Prerrequisito:** Bloques 1 y 2. Glosario, notación ABNF, formato de numeric replies
y el patrón de reenvío con prefix se dan por conocidos.
**Original:** https://www.rfc-editor.org/rfc/rfc2812.txt

---

## 0. Por qué este bloque cierra el subject

Con los Bloques 1 y 2 ya tienes el registro y las operaciones de canal. Falta lo que
el subject describe como núcleo: *"send and receive private messages"* y *"all the
messages sent from one client to a channel have to be forwarded to every other client"*.
Eso es **PRIVMSG**. Añadimos **NOTICE** por ser su gemelo, y **PING/PONG** porque los
clientes reales (irssi, HexChat...) lo usan para mantener viva la conexión: si tu
servidor no responde al PING, el cliente puede desconectarse, y eso te penaliza en la
evaluación con el cliente de referencia.

| Comando | RFC | Lo pide el subject |
|---|---|---|
| PRIVMSG | 3.3.1 | Sí (mensajes privados y a canal) |
| NOTICE | 3.3.2 | No explícito, pero los clientes lo esperan |
| PING / PONG | 3.7.2 / 3.7.3 | No explícito, pero el cliente de referencia lo usa |
| ERROR | 3.7.4 | Lo necesitas para QUIT y cierres (ver Bloque 1) |

---

## 1. Términos nuevos de este bloque

| Inglés | Castellano / explicación |
|---|---|
| msgtarget | Destinatario del mensaje: un nick o un canal |
| recipient | Destinatario |
| text to be sent / text | El texto del mensaje (va siempre como trailing) |
| delivery | Entrega (de un mensaje de un cliente a otro) |
| automatic reply | Respuesta automática (la que NOTICE prohíbe generar) |
| loop | Bucle (de respuestas automáticas entre clientes) |
| automaton / bot | Cliente controlado por un programa |
| to test the presence | Comprobar que el otro extremo sigue vivo |
| at regular intervals | A intervalos regulares |
| as soon as possible | Lo antes posible |
| origin | Origen (parámetro de PING) |
| to forward | Reenviar |
| fatal error | Error grave/irrecuperable |
| to terminate a connection | Cerrar una conexión |

---

## 2. Sección 3.3 — Sending messages (idea general)

El RFC abre así:

> The main purpose of the IRC protocol is to provide a base for clients to
> communicate with each other. PRIVMSG, NOTICE and SQUERY [...] are the only
> messages available which actually perform delivery of a text message from one
> client to another - the rest just make it possible.

Traducción: el propósito central de IRC es que los clientes se comuniquen, y
PRIVMSG/NOTICE (SQUERY es de servicios, fuera de tu subject) son los **únicos** comandos
que realmente entregan texto de un cliente a otro. Todo lo demás —registro, canales,
modos— existe para hacer posible esa entrega de forma fiable y estructurada.

---

## 3. Sección 3.3.1 — PRIVMSG

Bloque original:

```
   Command: PRIVMSG
Parameters: <msgtarget> <text to be sent>
```

Del original:

> PRIVMSG is used to send private messages between users, as well as to send messages
> to channels. <msgtarget> is usually the nickname of the recipient of the message,
> or a channel name.

Dos parámetros, y son el caso de uso central de tu servidor:
1. `<msgtarget>` — a quién: un **nickname** (mensaje privado) o un **nombre de canal**
   (mensaje al canal).
2. `<text to be sent>` — qué: el texto, que va siempre como **trailing** (con `:`),
   porque casi siempre contiene espacios.

### 3.1 Las dos rutas de entrega

El comportamiento depende de qué sea el target:

- **Target = canal** (`PRIVMSG #sala :hola`): el servidor reenvía el mensaje a **todos
  los miembros del canal excepto al emisor**. Esto es literalmente el requisito del
  subject: *"all the messages sent from one client to a channel have to be forwarded
  to every other client that joined the channel."* Normalmente exige ser miembro del
  canal para poder escribir en él.
- **Target = nick** (`PRIVMSG Wiz :hola`): el servidor entrega el mensaje solo a ese
  usuario.

En ambos casos, el mensaje llega al destinatario con el **prefix del emisor**, igual
que el patrón del Bloque 2. Ejemplo del original:

```
:Angel!wings@irc.org PRIVMSG Wiz :Are you receiving this message ?
```

Es decir: Angel envía `PRIVMSG Wiz :Are you receiving this message ?` (sin prefix), y
Wiz **recibe** `:Angel!wings@irc.org PRIVMSG Wiz :Are you receiving this message ?`.
Tu servidor construye ese prefix y encola el mensaje hacia el destinatario.

### 3.2 La parte que NO implementas

El RFC describe targets avanzados —host masks (`#<mask>`), server masks (`$<mask>`),
rutas tipo `user%host@server`— que sirven en redes multi-servidor y solo están
disponibles para operadores. Tu subject prohíbe la comunicación servidor-a-servidor,
así que **ignora todo esto**: tus targets son un nick o un canal, nada más. Los ejemplos
del original con `$*.fi`, `#*.edu` o `kalt%millennium...` no te conciernen.

### 3.3 Errores aplicables a ft_irc

De la lista del RFC, filtrando los de masks/red:
- `411 ERR_NORECIPIENT` — PRIVMSG sin destinatario. Formato: `":No recipient given (PRIVMSG)"`.
- `412 ERR_NOTEXTTOSEND` — destinatario pero sin texto. Formato: `":No text to send"`.
- `401 ERR_NOSUCHNICK` — el nick destino no existe.
- `404 ERR_CANNOTSENDTOCHAN` — no puedes escribir en ese canal (p. ej. no eres miembro).

(Quedan fuera: `ERR_NOTOPLEVEL`, `ERR_WILDTOPLEVEL`, `ERR_TOOMANYTARGETS`, que son de
las masks que no implementas. `RPL_AWAY` solo aplica si implementas el comando AWAY,
que no está en tu subject.)

> Detalle de diseño: cuando PRIVMSG va a un canal, **no** confirmas nada al emisor
> (no recibe su propio mensaje de vuelta). El cliente ya muestra localmente lo que el
> usuario escribe. Reenviar al emisor causaría duplicados en su pantalla.

---

## 4. Sección 3.3.2 — NOTICE

Bloque original:

```
   Command: NOTICE
Parameters: <msgtarget> <text>
```

NOTICE es casi idéntico a PRIVMSG, con **una diferencia crítica** que el original
recalca:

> The difference between NOTICE and PRIVMSG is that automatic replies MUST NEVER be
> sent in response to a NOTICE message. This rule applies to servers too - they MUST
> NOT send any error reply back to the client on receipt of a notice.

Traducción: ante un NOTICE **nunca** se generan respuestas automáticas, y eso incluye
a tu servidor: **no debes enviar ningún error en respuesta a un NOTICE**. La razón
(del original): evitar bucles en los que dos clientes se respondan automáticamente
hasta el infinito.

Consecuencia práctica para tu código: NOTICE se procesa como PRIVMSG (misma entrega a
nick o canal, mismo reenvío con prefix), pero si algo falla —target inexistente, sin
texto, sin permiso— **callas**. No mandas 401, ni 411, ni 412, ni nada. Simplemente
descartas el mensaje.

El original cierra: *"This is typically used by services, and automatons (clients with
either an AI or other interactive program controlling their actions). See PRIVMSG for
more details on replies and examples."* — Por eso NOTICE es el comando natural para
respuestas de un **bot** (parte bonus de tu subject): un bot responde con NOTICE
precisamente para no arrancar bucles.

---

## 5. Sección 3.7.2 — PING

Bloque original:

```
   Command: PING
Parameters: <server1> [ <server2> ]
```

Del original:

> The PING command is used to test the presence of an active client or server at the
> other end of the connection. [...] When a PING message is received, the appropriate
> PONG message MUST be sent as reply to <server1> [...] as soon as possible.

En castellano: PING comprueba que el otro extremo sigue vivo. Hay dos direcciones:

- **El servidor envía PING al cliente** a intervalos regulares si no detecta actividad.
  Si el cliente no responde con PONG en un tiempo, el servidor cierra la conexión.
- **El cliente envía PING al servidor**: tu servidor **debe** responder con el PONG
  correspondiente lo antes posible.

Para ft_irc, lo mínimo robusto es: **cuando recibas `PING <token>`, responde
inmediatamente `PONG <token>`** (con el prefix de tu servidor). Eso mantiene contentos
a los clientes de referencia. Opcionalmente, puedes además emitir PINGs tú mismo para
detectar clientes muertos, pero no es imprescindible para aprobar.

Error aplicable:
- `409 ERR_NOORIGIN` — PING sin parámetro de origen. Formato: `":No origin specified"`.

Ejemplos del original:
```
PING tolsun.oulu.fi     ; PING a un servidor
PING :irc.funet.fi      ; PING enviado por el servidor irc.funet.fi
```

Ejemplo de intercambio en tu servidor: el cliente manda `PING :LAG1234567`, tu servidor
responde `:ircserv PONG ircserv :LAG1234567`.

---

## 6. Sección 3.7.3 — PONG

Bloque original:

```
   Command: PONG
Parameters: <server> [ <server2> ]
```

Del original: *"PONG message is a reply to ping message. [...] The <server> parameter
is the name of the entity who has responded to PING message and generated this message."*

PONG es la respuesta a un PING. El parámetro identifica quién responde. Para ti, dos
situaciones:
- Si **tú** envías PING al cliente, esperas recibir su PONG y con eso marcas la conexión
  como viva.
- Si el cliente te envía PING, **tú** generas el PONG (sección 5).

El token del PING debe devolverse en el PONG: así el que hizo el PING empareja la
respuesta con su solicitud.

---

## 7. Sección 3.7.4 — ERROR

Bloque original:

```
   Command: ERROR
Parameters: <error message>
```

En redes reales, ERROR sirve para reportar fallos graves entre servidores, y el original
avisa: *"MUST NOT be accepted from any normal unknown clients"* — no aceptes ERROR
enviado por clientes. Pero hay un uso que **sí** te afecta:

> The ERROR message is also used before terminating a client connection.

Es decir, ERROR se envía al cliente **justo antes de cerrar su conexión**. Esto enlaza
con QUIT del Bloque 1, donde el RFC decía que el servidor confirma el QUIT con un mensaje
ERROR. Patrón típico en tu servidor: ante un QUIT (o un cierre por contraseña incorrecta,
o un fallo), envías algo como `ERROR :Closing link` y luego cierras el fd —respetando,
eso sí, tu regla de vaciar el buffer de escritura antes de cerrar el socket.

ERROR no tiene numeric replies asociadas (es un comando con nombre, no un número).

---

## 8. Replies numéricas de este bloque (referencia)

Formato del RFC: número, nombre simbólico, y la parte `<params> :trailing` que envías
tras `:<prefix> <código> <target>`.

### Errores (ERR)
```
401    ERR_NOSUCHNICK       "<nickname> :No such nick/channel"
404    ERR_CANNOTSENDTOCHAN "<channel name> :Cannot send to channel"
409    ERR_NOORIGIN         ":No origin specified"
411    ERR_NORECIPIENT      ":No recipient given (<command>)"
412    ERR_NOTEXTTOSEND     ":No text to send"
```

Significado:
- **401** — el nick destino de un PRIVMSG no existe.
- **404** — no puedes enviar al canal indicado (normalmente porque no eres miembro).
- **409** — PING sin origen.
- **411** — PRIVMSG sin destinatario.
- **412** — PRIVMSG con destinatario pero sin texto.

> Recordatorio NOTICE: ninguno de estos errores se envía en respuesta a un NOTICE.
> Esa es la única excepción del bloque al patrón "siempre responde".

---

## 9. Checklist de implementación (envío y conexión)

Interpretación práctica (no literal del RFC) para guiar tu desarrollo:

1. **Precondición**: PRIVMSG/NOTICE exigen estar registrado (`451 ERR_NOTREGISTERED`
   si no). PING/PONG suelen aceptarse también antes del registro completo.
2. **PRIVMSG a canal**: comprobar que existe y que eres miembro (404 si no) → reenviar
   `:<emisor> PRIVMSG #canal :texto` a **todos los miembros menos a ti**.
3. **PRIVMSG a nick**: comprobar que el nick existe (401 si no) → entregar
   `:<emisor> PRIVMSG <nick> :texto` a ese usuario.
4. **Validación previa común**: sin destinatario → 411; con destinatario y sin texto
   → 412.
5. **NOTICE**: misma lógica de entrega que PRIVMSG, pero **sin emitir ningún error**
   ante cualquier fallo: descartar en silencio.
6. **PING**: ante `PING <token>` → responder `:<servidor> PONG <servidor> :<token>`
   de inmediato. Sin token → 409.
7. **PONG entrante**: si implementas detección de inactividad, úsalo para marcar la
   conexión como viva; si no, puedes ignorarlo sin más.
8. **ERROR / cierre**: antes de cerrar un fd (QUIT, contraseña incorrecta, fallo),
   encolar `ERROR :<motivo>` y cerrar solo tras vaciar el buffer de escritura.

---

## 10. Cierre del recorrido y siguientes pasos

Con estos tres bloques tienes el conjunto de comandos que tu subject necesita:

- **Bloque 1** — formato de mensajes, ABNF, registro (PASS, NICK, USER, QUIT).
- **Bloque 2** — canales (JOIN, PART, MODE i/t/k/o/l, TOPIC, INVITE, KICK).
- **Bloque 3** — entrega (PRIVMSG, NOTICE) y conexión (PING, PONG, ERROR).

A partir de aquí el RFC original ya debería resultarte legible: el resto de secciones
(WHOIS, WHO, LIST, OPER, AWAY, comandos de servidor, servicios) **no** forman parte de
tu subject. Si en la defensa o al probar con el cliente de referencia aparece un comando
que el cliente envía y que no reconoces, búscalo por su nombre en el índice del RFC; con
el vocabulario de estos bloques podrás leer su sección directamente.

Dos recursos para cuando el RFC 2812 se quede corto o ambiguo:
- **modern.ircdocs.horse** — especificación moderna no oficial, mucho mejor redactada,
  que refleja cómo se comportan hoy los clientes y servidores reales. Útil cuando el
  RFC 2812 es vago (p. ej. el comportamiento exacto de algunos modos).
- El comportamiento observado de **tu cliente de referencia**, que es la autoridad
  final en la evaluación: cuando el RFC y el cliente discrepen, el cliente manda.

