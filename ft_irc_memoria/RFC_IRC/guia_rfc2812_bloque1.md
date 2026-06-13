# Guía bilingüe RFC 2812 — Bloque 1: Formato de mensajes y registro de conexión

*Guía de lectura del RFC 2812 (Internet Relay Chat: Client Protocol) para ft_irc.
Las citas del RFC, la gramática ABNF, los nombres de comandos y de replies se mantienen
en inglés tal cual aparecen en el original. La explicación está en castellano.*

**Cubre:** secciones 2.3, 2.3.1, 2.4 y 3.1 del RFC 2812.
**Original:** https://www.rfc-editor.org/rfc/rfc2812.txt

---

## 0. Cómo leer un RFC (lo mínimo imprescindible)

Antes de entrar en materia, tres convenciones que verás constantemente:

**Palabras en mayúsculas con significado normativo** (definidas en el RFC 2119):

| Término | Significado |
|---|---|
| `MUST` / `SHALL` / `REQUIRED` | Obligatorio. Si no lo cumples, no eres conforme al protocolo. |
| `MUST NOT` / `SHALL NOT` | Prohibido. |
| `SHOULD` / `RECOMMENDED` | Muy recomendable; solo te lo saltas si tienes una buena razón. |
| `SHOULD NOT` | Desaconsejado. |
| `MAY` / `OPTIONAL` | Opcional, a tu criterio. |

**Los ángulos `<asi>`** indican un *placeholder*: `<nickname>` significa "aquí va un nickname",
no la palabra literal "nickname".

**ABNF (Augmented BNF)** es la notación formal de gramáticas que usan los RFC.
La descifraremos en la sección 2.3.1, porque es la parte que más cuesta y la más útil
para escribir tu parser.

---

## 1. Glosario de términos recurrentes

Estos términos aparecen una y otra vez. Apréndelos en inglés: los verás en el RFC,
en los mensajes de error de los clientes y en la defensa.

| Inglés | Castellano / explicación |
|---|---|
| message | Mensaje: una línea completa terminada en `\r\n` |
| prefix | Prefijo: parte opcional al inicio (`:origen`) que indica quién origina el mensaje |
| command | Comando: palabra (`NICK`, `JOIN`...) o número de 3 dígitos (`001`, `433`...) |
| parameter / params | Parámetro(s) del comando |
| trailing | Último parámetro, precedido de `:`, que puede contener espacios |
| middle | Parámetro "normal", sin espacios |
| numeric reply | Respuesta numérica: mensaje cuyo comando son 3 dígitos |
| to register / registered | Registrarse / registrado: completar PASS+NICK+USER; hasta entonces la conexión no es un usuario válido |
| nickname / nick | Apodo del usuario, único en el servidor |
| target | Destinatario de un mensaje (un nick o un canal) |
| connection password | Contraseña de conexión (la que pasas a `./ircserv <port> <password>`) |
| reply | Respuesta del servidor |
| leading / trailing (adjetivos) | Al principio / al final ("leading colon" = dos puntos inicial) |
| whitespace / gap | Espacio en blanco / hueco |
| octet | Octeto = byte |
| stream of octets | Flujo de bytes (lo que te llega por `recv()`: SIN garantía de líneas completas) |
| to parse / parsing | Analizar sintácticamente / análisis |
| case-insensitive | Sin distinción de mayúsculas/minúsculas |
| wildcard / mask | Comodín (`*`, `?`) / patrón con comodines |
| upon success | En caso de éxito |
| It is assumed... | Se asume que... |
| as follows | de la siguiente manera |

---

## 2. Sección 2.3 — Messages (formato de mensajes)

### Lo que dice el RFC (ideas clave, traducidas)

Un mensaje IRC tiene hasta **tres partes**: el **prefix** (opcional), el **command**,
y los **parameters** (máximo 15). Las tres se separan entre sí por **un** espacio ASCII (0x20).

Sobre el prefix, el original dice:

> The presence of a prefix is indicated with a single leading ASCII colon
> character (':'), which MUST be the first character of the message itself.

Es decir: la presencia del prefix se indica con un `:` que **debe** ser el primer
carácter del mensaje, sin espacio entre el `:` y el prefix. El servidor usa el prefix
para indicar el **origen real** del mensaje. Si falta, se asume que el origen es la
conexión por la que llegó. Los clientes normalmente **no** envían prefix
(*"Clients SHOULD NOT use a prefix when sending a message"*) — esto te simplifica
el parser: lo que recibes de tus clientes casi nunca llevará prefix, pero lo que
**tú envías** a los clientes sí debe llevarlo.

El command debe ser o un comando IRC válido **o un número de 3 dígitos** en ASCII.

Y la regla más importante para tu buffer:

> IRC messages are always lines of characters terminated with a CR-LF
> (Carriage Return - Line Feed) pair, and these messages SHALL NOT
> exceed 512 characters in length, counting all characters including
> the trailing CR-LF.

Traducción: todo mensaje termina en `\r\n` (CR-LF) y mide **como máximo 512
caracteres incluyendo el `\r\n`** (510 útiles para comando + parámetros).
No existe continuación de líneas.

### Conexión directa con tu ft_irc

Esto es exactamente lo que comprueba el test del `nc -C` de tu subject: los datos
llegan como *stream of octets* fragmentado (`com`, luego `man`, luego `d\n`).
Tu servidor debe **acumular** lo recibido en un buffer por cliente y solo procesar
un comando cuando encuentre el separador de mensaje.

---

## 3. Sección 2.3.1 — Message format in Augmented BNF

Esta es la sección que define formalmente tu parser. Primero, cómo se lee ABNF:

| Notación ABNF | Se lee como |
|---|---|
| `=` | "se define como" |
| `/` | "o" (alternativa) |
| `[ x ]` | x es opcional (0 o 1 vez) |
| `*x` | x repetido 0 o más veces |
| `1*x` | x repetido 1 o más veces |
| `*14x` | x repetido entre 0 y 14 veces |
| `3x` | x exactamente 3 veces |
| `"abc"` | literal (los caracteres tal cual) |
| `%x41-5A` | rango de bytes en hexadecimal (aquí: de 0x41 'A' a 0x5A 'Z') |
| `; comentario` | comentario |

### La gramática del mensaje (original, intacta)

```abnf
message    =  [ ":" prefix SPACE ] command [ params ] crlf
prefix     =  servername / ( nickname [ [ "!" user ] "@" host ] )
command    =  1*letter / 3digit
params     =  *14( SPACE middle ) [ SPACE ":" trailing ]
           =/ 14( SPACE middle ) [ SPACE [ ":" ] trailing ]

nospcrlfcl =  %x01-09 / %x0B-0C / %x0E-1F / %x21-39 / %x3B-FF
                ; any octet except NUL, CR, LF, " " and ":"
middle     =  nospcrlfcl *( ":" / nospcrlfcl )
trailing   =  *( ":" / " " / nospcrlfcl )

SPACE      =  %x20        ; space character
crlf       =  %x0D %x0A   ; "carriage return" "linefeed"
```

### Línea a línea, en castellano

- **message** — Un mensaje es: opcionalmente `:prefix` seguido de espacio, luego el
  comando, luego opcionalmente parámetros, y termina en `crlf` (`\r\n`).
- **prefix** — El prefix es o un nombre de servidor, o un nickname opcionalmente
  seguido de `!user` y `@host`. La forma completa `nick!user@host` se llama
  *full client identifier* y la usarás constantemente al reenviar mensajes:
  `:wiz!jto@host PRIVMSG #canal :hola`.
- **command** — Una o más letras, **o** exactamente 3 dígitos.
- **params** — Hasta 14 parámetros `middle` separados por espacio, y opcionalmente
  un último parámetro `trailing` introducido por ` :`. (La segunda línea con `=/`
  añade una alternativa: si ya hay 14 middle, el 15º puede ir sin `:`; en la
  práctica casi nadie llega a 15 parámetros.)
- **nospcrlfcl** — El nombre es una abreviatura: **no** **sp**ace, **cr**, **lf**,
  **c**o**l**on. Cualquier byte excepto NUL, CR, LF, espacio y `:`.
- **middle** — Un parámetro normal: empieza por un carácter `nospcrlfcl` (o sea,
  no puede *empezar* por `:`) pero **sí puede contener** `:` después del primer carácter.
- **trailing** — El parámetro final: puede contener espacios y `:` libremente.
  Por eso necesita el `:` delimitador delante.

### La nota más importante del RFC para tu diseño

> 1) After extracting the parameter list, all parameters are equal
>    whether matched by <middle> or <trailing>. <trailing> is just a
>    syntactic trick to allow SPACE within the parameter.

Traducción: una vez parseado, **trailing no es especial**: es un parámetro más.
El `:` es solo un truco sintáctico para permitir espacios. Consecuencia práctica:
tu parser puede devolver un simple `std::vector<std::string>` de parámetros, y
`PRIVMSG #canal :hola que tal` produce `params = {"#canal", "hola que tal"}`.

La nota 2 dice que el byte NUL (`\0`) **no está permitido** dentro de mensajes,
porque complicaría el manejo de strings en C. Te viene bien: puedes usar
`std::string` sin miedo.

### Sintaxis de parámetros que ya te conviene conocer

Del mismo apartado, las definiciones que usarás en este bloque (original):

```abnf
nickname   =  ( letter / special ) *8( letter / digit / special / "-" )
user       =  1*( %x01-09 / %x0B-0C / %x0E-1F / %x21-3F / %x41-FF )
                ; any octet except NUL, CR, LF, " " and "@"
letter     =  %x41-5A / %x61-7A       ; A-Z / a-z
digit      =  %x30-39                 ; 0-9
special    =  %x5B-60 / %x7B-7D
                ; "[", "]", "\", "`", "_", "^", "{", "|", "}"
```

En castellano: un **nickname** empieza por letra o por uno de los caracteres
*special* (corchetes, barra invertida, acento grave, guion bajo, circunflejo,
llaves y barra vertical), seguido de hasta 8 caracteres más (letras, dígitos,
especiales o `-`). Es decir, **máximo 9 caracteres** según el RFC y **no puede
empezar por dígito ni por `-`**. (Muchos servidores reales relajan el límite de
longitud; para ft_irc, decidid un criterio y sed coherentes — esto es justo el tipo
de decisión que defenderéis en la evaluación.)

---

## 4. Sección 2.4 — Numeric replies

Texto clave del original:

> The numeric reply MUST be sent as one message consisting of the sender
> prefix, the three-digit numeric, and the target of the reply.

En castellano: la mayoría de mensajes enviados al servidor generan una respuesta,
y la más común es la **numeric reply**, usada tanto para errores como para
respuestas normales. Se envía como un mensaje normal cuyo "comando" son 3 dígitos,
y consta de: el **prefix del emisor** (tu servidor), el **número de 3 dígitos**,
y el **target** (el nick del cliente al que respondes).

Anatomía de una numeric reply real:

```
:irc.example.com 433 pepe wiz :Nickname is already in use
└─────┬────────┘ └┬┘ └─┬┘ └┬┘ └──────────┬───────────────┘
   prefix del   código target  parámetro  trailing (texto humano)
   servidor     (433)  (pepe)  (wiz)
```

Rangos (sección 5 del RFC):

- `001`–`099`: solo para conexiones cliente-servidor (registro, etc.)
- `200`–`399`: respuestas a comandos (`RPL_*`)
- `400`–`599`: errores (`ERR_*`)

Cada código tiene un nombre simbólico (`RPL_WELCOME`, `ERR_NICKNAMEINUSE`...).
El RFC los lista en la sección 5 con su formato; los clientes solo ven el número,
los nombres son para humanos. En tu código te conviene definirlos como constantes
con su nombre del RFC: hará tu código legible y la defensa más fácil.

---

## 5. Sección 3.1 — Connection Registration

### Idea general

Los comandos de esta sección sirven para **registrar** una conexión como usuario.
El orden RECOMENDADO es:

```
1. Pass message
2. Nick message
3. User message
```

El original dice sobre PASS:

> A "PASS" command is not required for a client connection to be
> registered, but it MUST precede the latter of the NICK/USER combination

Es decir: PASS no es obligatorio en IRC genérico, pero si se usa **debe preceder**
a NICK/USER. **En ft_irc tu servidor exige contraseña** (es un argumento del
programa), así que para ti PASS sí es de facto obligatorio antes de completar el registro.

Y sobre el éxito:

> Upon success, the client will receive an RPL_WELCOME (for users) [...]
> The reply message MUST contain the full client identifier.

En caso de éxito, el cliente recibe `RPL_WELCOME` (001) indicando que la conexión
está registrada, y ese mensaje debe contener el *full client identifier*
(`nick!user@host`).

> Nota práctica: el RFC no fija si NICK debe ir antes que USER o al revés:
> el orden 1-2-3 es RECOMMENDED, no REQUIRED. Los clientes reales pueden
> enviarlos en cualquier orden tras PASS. Lo robusto es: aceptar ambos órdenes
> y completar el registro cuando tengas PASS correcto + NICK + USER.

### 3.1.1 — Password message

Bloque original:

```
   Command: PASS
Parameters: <password>

Numeric Replies:
        ERR_NEEDMOREPARAMS              ERR_ALREADYREGISTRED

Example:
        PASS secretpasswordhere
```

El comando PASS establece la *connection password*. Debe enviarse **antes** de
cualquier intento de registro (antes de la combinación NICK/USER).

Errores posibles:
- `461 ERR_NEEDMOREPARAMS` — si llega `PASS` sin parámetro.
- `462 ERR_ALREADYREGISTRED` — si un cliente ya registrado intenta enviar PASS otra vez.

Fíjate en que **no hay reply de éxito**: si la contraseña llega bien, el servidor
calla y espera NICK/USER. ¿Y si la contraseña es incorrecta? El RFC asocia
`464 ERR_PASSWDMISMATCH` al proceso de registro (ver sección 6 de esta guía).
Una estrategia habitual es responder 464 y cerrar la conexión cuando el cliente
intenta completar el registro con PASS incorrecto o ausente.

### 3.1.2 — Nick message

Bloque original:

```
   Command: NICK
Parameters: <nickname>

Numeric Replies:
        ERR_NONICKNAMEGIVEN             ERR_ERRONEUSNICKNAME
        ERR_NICKNAMEINUSE               ERR_NICKCOLLISION
        ERR_UNAVAILRESOURCE             ERR_RESTRICTED

Examples:
NICK Wiz                ; Introducing new nick "Wiz" if session is
                        still unregistered, or user changing his
                        nickname to "Wiz"

:WiZ!jto@tolsun.oulu.fi NICK Kilroy
                        ; Server telling that WiZ changed his
                        nickname to Kilroy.
```

NICK da un nickname al usuario **o cambia el existente**. Fíjate en el segundo
ejemplo: cuando un usuario ya registrado cambia de nick, el servidor lo notifica
a los demás con el prefix del *antiguo* identificador y el nick nuevo como parámetro.

Errores que te afectan (los otros tres son de redes multi-servidor, fuera de tu subject):
- `431 ERR_NONICKNAMEGIVEN` — `NICK` sin parámetro.
- `432 ERR_ERRONEUSNICKNAME` — el nick contiene caracteres fuera del conjunto
  válido (ver gramática `nickname` en la sección 3 de esta guía).
- `433 ERR_NICKNAMEINUSE` — el nick ya está en uso por otro cliente. Importante:
  la comparación de nicks es *case-insensitive*.

### 3.1.3 — User message

Bloque original:

```
   Command: USER
Parameters: <user> <mode> <unused> <realname>

Numeric Replies:
        ERR_NEEDMOREPARAMS              ERR_ALREADYREGISTRED

Example:
USER guest 0 * :Ronnie Reagan   ; User registering themselves with a
                                username of "guest" and real name
                                "Ronnie Reagan".
```

USER especifica el *username* y el *realname* del nuevo usuario, al principio
de la conexión. Cuatro parámetros:

1. `<user>` — el username (formará parte de `nick!user@host`).
2. `<mode>` — un número usado como máscara de bits para modos de usuario
   iniciales (`i`, `w`). Para ft_irc no implementas modos de usuario, así que
   puedes aceptarlo y no hacer nada con él.
3. `<unused>` — sin uso; los clientes envían `*`.
4. `<realname>` — *"may contain space characters"*: puede contener espacios,
   por eso siempre llega como **trailing** (con `:` delante).

Errores: `461` si faltan parámetros, `462` si un usuario ya registrado reenvía USER
(no se permite cambiar el username después del registro, a diferencia del nick).

### 3.1.7 — Quit

Bloque original:

```
   Command: QUIT
Parameters: [ <Quit Message> ]

Example:
QUIT :Gone to have lunch        ; Preferred message format.
```

Termina la sesión del cliente; el parámetro (mensaje de despedida) es opcional
— por eso va entre `[ ]`. El original añade:

> The server acknowledges this by sending an ERROR message to the client.

El servidor confirma enviando un mensaje `ERROR` al cliente antes de cerrar.
Además (lo verás en el bloque de canales), debes notificar el QUIT a todos los
canales donde estaba el usuario.

---

## 6. Numeric replies de este bloque (referencia)

Formato del RFC: número, nombre simbólico, y entre comillas la parte
`<parámetros> :trailing` que tu servidor debe enviar tras `:<prefix> <código> <target>`.

### Registro con éxito (001–004)

El RFC indica: *"The server sends Replies 001 to 004 to a user upon successful
registration."* — se envían las cuatro, en orden, al completar el registro.

```
001    RPL_WELCOME
       "Welcome to the Internet Relay Network <nick>!<user>@<host>"
002    RPL_YOURHOST
       "Your host is <servername>, running version <ver>"
003    RPL_CREATED
       "This server was created <date>"
004    RPL_MYINFO
       "<servername> <version> <available user modes> <available channel modes>"
```

Ejemplo real de lo que enviaría tu servidor:

```
:ircserv 001 pepe :Welcome to the Internet Relay Network pepe!pepe@localhost
```

### Errores de registro

```
431    ERR_NONICKNAMEGIVEN     ":No nickname given"
432    ERR_ERRONEUSNICKNAME    "<nick> :Erroneous nickname"
433    ERR_NICKNAMEINUSE       "<nick> :Nickname is already in use"
461    ERR_NEEDMOREPARAMS      "<command> :Not enough parameters"
462    ERR_ALREADYREGISTRED    ":Unauthorized command (already registered)"
464    ERR_PASSWDMISMATCH      ":Password incorrect"
```

Significado de cada uno, según el RFC:
- **431** — se esperaba un nickname como parámetro y no llegó.
- **432** — el nick recibido contiene caracteres fuera del conjunto definido.
- **433** — intento de cambiar a un nick que ya existe.
- **461** — lo devuelven "numerosos comandos" cuando el cliente no proporcionó
  suficientes parámetros. Lo reutilizarás en casi todos los comandos.
- **462** — alguien intenta cambiar datos del registro (p. ej. segundo USER, o PASS
  tras registrarse).
- **464** — intento fallido de registrar una conexión que requería contraseña y
  esta no se dio o era incorrecta.

---

## 7. Checklist de implementación del registro (ft_irc)

Una posible máquina de estados por cliente, derivada de todo lo anterior:

1. Cliente conecta (accept) → estado `CONNECTED`, sin registrar.
2. Acumulas bytes en su buffer; extraes mensajes completos al ver el separador.
3. `PASS <pwd>` → guardas si coincide con la del servidor. Si ya registrado → 462.
4. `NICK <nick>` → validas sintaxis (432), unicidad case-insensitive (433),
   presencia (431). Guardas el nick.
5. `USER <user> <mode> <unused> :<realname>` → validas nº de parámetros (461).
   Si ya registrado → 462.
6. Cuando tienes contraseña correcta + nick + user → estado `REGISTERED`,
   envías 001–004. Si la contraseña falta o es incorrecta → 464 y cierras.
7. Antes de estar `REGISTERED`, rechaza el resto de comandos (cuando llegues a
   ellos verás `451 ERR_NOTREGISTERED`, que existe exactamente para esto).
8. `QUIT [:msg]` → ERROR al cliente, limpieza, cierre del fd.

---

## 8. Autocomprobación de lectura

Para validar que ya puedes con el original: abre el RFC y lee la sección **3.7.2
(Ping message)** sin traductor — es corta y usa solo vocabulario de esta guía.
Deberías poder responder: ¿quién envía PING, qué debe responder el otro extremo,
y qué error existe si PONG no lleva parámetro?

Cuando lo tengas, el siguiente bloque natural es **3.2 Channel operations**
(JOIN, PART, MODE, TOPIC, INVITE, KICK) + la gramática `channel` que ya
apareció en 2.3.1.
