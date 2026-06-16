# Guía bilingüe RFC 2812 — Bloque 2: Operaciones de canal

*Guía de lectura del RFC 2812 (Internet Relay Chat: Client Protocol) para ft_irc.
Las citas del RFC, la gramática ABNF, los nombres de comandos y de replies se mantienen
en inglés tal cual aparecen en el original. La explicación está en castellano.*

**Cubre:** sección 3.2 del RFC 2812 (JOIN, PART, MODE, TOPIC, INVITE, KICK) más la
gramática `channel` de 2.3.1 y NAMES (3.2.5) por su relación con la respuesta de JOIN.
**Prerrequisito:** Bloque 1 (formato de mensajes, ABNF, registro). El glosario y la
notación ABNF de aquel bloque se dan por conocidos.
**Original:** https://www.rfc-editor.org/rfc/rfc2812.txt

---

## 0. Mapa de este bloque y tu subject

De los ocho comandos de la sección 3.2, tu subject pide seis:

| Comando | RFC | Lo pide el subject | Específico de operador |
|---|---|---|---|
| JOIN | 3.2.1 | Sí (unirse a canal) | No |
| PART | 3.2.2 | Implícito (salir) | No |
| MODE | 3.2.3 | Sí (i, t, k, o, l) | Sí (cambiar modos) |
| TOPIC | 3.2.4 | Sí | Depende del modo `t` |
| INVITE | 3.2.7 | Sí | Sí (si canal `+i`) |
| KICK | 3.2.8 | Sí | Sí |
| NAMES | 3.2.5 | No directamente, pero JOIN responde con `RPL_NAMREPLY` | No |
| LIST | 3.2.6 | No | No |

NAMES y LIST no son obligatorios, pero **NAMES** aparece aquí porque una unión
exitosa a un canal debe enviar la lista de miembros usando su misma reply
(`RPL_NAMREPLY` + `RPL_ENDOFNAMES`). LIST queda fuera.

> Aviso importante sobre los modos: la sección 3.2.3 del RFC describe la **sintaxis**
> del comando MODE, pero remite los modos concretos a otro documento
> ("Internet Relay Chat: Channel Management", IRC-CHAN). Por eso muchos de los
> ejemplos del RFC usan modos (`b`, `e`, `v`, `s`, `m`...) que **no** están en tu
> subject. Tú implementas exactamente cinco: `i`, `t`, `k`, `o`, `l`. Ignora el resto.

---

## 1. Términos nuevos de este bloque

Amplía el glosario del Bloque 1:

| Inglés | Castellano / explicación |
|---|---|
| channel | Canal: sala donde varios clientes intercambian mensajes |
| channel operator / chanop | Operador de canal: usuario con privilegios sobre el canal |
| channel mode / channel flag | Modo de canal: propiedad activable (`i`, `t`, `k`, `o`, `l`) |
| key | Clave/contraseña del canal (modo `k`) |
| topic | Tema del canal (texto descriptivo) |
| to grant / to deny a request | Conceder / denegar una petición |
| member / to be on a channel | Miembro / estar dentro de un canal |
| to forward | Reenviar (un mensaje a los miembros) |
| comment / reason | Comentario o motivo (en KICK) |
| invite-only | Solo por invitación (modo `i`) |
| user limit | Límite de usuarios del canal (modo `l`) |
| backward compatibility | Compatibilidad hacia atrás (con clientes antiguos) |

---

## 2. La gramática `channel` (de la sección 2.3.1)

Antes de los comandos, qué es un nombre de canal válido. Del Bloque 1 recuperamos
la definición original:

```abnf
channel    =  ( "#" / "+" / ( "!" channelid ) / "&" ) chanstring
              [ ":" chanstring ]
chanstring =  %x01-07 / %x08-09 / %x0B-0C / %x0E-1F / %x21-2B
chanstring =/ %x2D-39 / %x3B-FF
                ; any octet except NUL, BELL, CR, LF, " ", "," and ":"
channelid  = 5( %x41-5A / digit )   ; 5( A-Z / 0-9 )
```

En castellano: un nombre de canal empieza por un prefijo (`#`, `+`, `&`, o `!` con
un id), seguido de una `chanstring`. La `chanstring` puede ser casi cualquier byte
**excepto** NUL, BELL, CR, LF, espacio, coma `,` y dos puntos `:`. La coma está
excluida porque separa elementos en las listas de canales; el espacio porque separa
parámetros.

Para ft_irc lo razonable es aceptar canales que empiecen por `#` (y opcionalmente `&`),
validar que no contengan los caracteres prohibidos, y devolver el error
correspondiente si no. Decidid el criterio en equipo y sed coherentes.

---

## 3. Nota general de la sección 3.2 (importante)

El RFC abre la sección con una regla que aplica a **todos** estos comandos:

> All of these messages are requests which will or will not be granted by
> the server. The server MUST send a reply informing the user whether the
> request was granted, denied or generated an error. When the server grants
> the request, the message is typically sent back (eventually reformatted)
> to the user with the prefix set to the user itself.

Traducción y consecuencias para tu diseño:

1. Cada comando es una **petición** que el servidor concede o no.
2. El servidor **debe** responder siempre: concedido, denegado o error.
3. Cuando se concede, el mensaje se reenvía (a veces reformateado) **con el prefix
   puesto al propio usuario** que lo originó.

Ese punto 3 es el patrón que repetirás en todo el bloque: cuando Wiz hace JOIN y
se le concede, el servidor envía a los miembros del canal
`:wiz!user@host JOIN #canal`. El prefix identifica quién hizo la acción. Esto enlaza
directamente con tu `ResponseBuilder` y con `queueMessage`: construyes el mensaje con
el prefix del autor y lo encolas hacia cada destinatario.

---

## 4. Sección 3.2.1 — JOIN

Bloque original:

```
   Command: JOIN
Parameters: ( <channel> *( "," <channel> ) [ <key> *( "," <key> ) ] )
            / "0"
```

JOIN solicita "empezar a escuchar" un canal. Puntos del original que te importan:

- *"Servers MUST be able to parse arguments in the form of a list of target, but
  SHOULD NOT use lists when sending JOIN messages to clients."* — Tu parser **debe**
  aceptar listas separadas por comas (`JOIN #a,#b clave1,clave2`), pero cuando tú
  reenvías el JOIN a los clientes, lo haces de uno en uno, no en lista.
- Sobre lo que recibe quien se une, el original dice:

> If a JOIN is successful, the user receives a JOIN message as confirmation and is
> then sent the channel's topic (using RPL_TOPIC) and the list of users who are on
> the channel (using RPL_NAMREPLY), which MUST include the user joining.

Es decir, una unión exitosa produce, en este orden:
1. El mensaje `JOIN` de confirmación (reenviado a todos los miembros, incl. el nuevo).
2. El topic con `RPL_TOPIC` (332) — o `RPL_NOTOPIC` (331) si no hay.
3. La lista de miembros con `RPL_NAMREPLY` (353) + `RPL_ENDOFNAMES` (366),
   **incluyendo al que acaba de entrar**.

- El argumento especial `"0"`: *"a special request to leave all channels"*.
  `JOIN 0` equivale a hacer PART de todos los canales. Es un detalle fino; impleméntalo
  si quieres ser fiel, pero no es el núcleo del subject.

**Errores que aplican a ft_irc** (de la lista del RFC, filtrando los de red/ban):
- `461 ERR_NEEDMOREPARAMS` — JOIN sin canal.
- `473 ERR_INVITEONLYCHAN` — canal en modo `+i` y no estás invitado.
- `475 ERR_BADCHANNELKEY` — canal con `+k` y clave incorrecta o ausente.
- `471 ERR_CHANNELISFULL` — canal con `+l` y lleno.
- `476 ERR_BADCHANMASK` / `ERR_NOSUCHCHANNEL` — nombre de canal inválido.

(Quedan fuera por no implementarse: `ERR_BANNEDFROMCHAN`, `ERR_TOOMANYCHANNELS`,
`ERR_TOOMANYTARGETS`, `ERR_UNAVAILRESOURCE`.)

Ejemplo del original del mensaje reenviado:
```
:WiZ!jto@tolsun.oulu.fi JOIN #Twilight_zone
```

> Detalle de diseño que conviene fijar: el RFC no lo dice, pero por convención el
> **primer usuario que crea un canal** (el primer JOIN) se convierte en su operador.
> De ahí saldrá el primer chanop que luego puede dar `+o` a otros. Es una decisión de
> implementación: justifícala en la defensa.

---

## 5. Sección 3.2.2 — PART

Bloque original:

```
   Command: PART
Parameters: <channel> *( "," <channel> ) [ <Part Message> ]
```

PART elimina al emisor de los canales indicados. Del original:

- *"If a 'Part Message' is given, this will be sent instead of the default message,
  the nickname."* — El mensaje de despedida es opcional; si no se da, se usa el nick.
- *"This request is always granted by the server."* — A diferencia de JOIN, PART
  siempre se concede (si el canal existe y estás en él).

Errores aplicables:
- `461 ERR_NEEDMOREPARAMS` — PART sin canal.
- `403 ERR_NOSUCHCHANNEL` — el canal no existe.
- `442 ERR_NOTONCHANNEL` — no estás en ese canal.

El mensaje PART, igual que JOIN, se reenvía a los miembros con el prefix del autor:
```
:WiZ!jto@tolsun.oulu.fi PART #playzone :I lost
```

---

## 6. Sección 3.2.3 — MODE de canal (el corazón del bloque)

Bloque original:

```
   Command: MODE
Parameters: <channel> *( ( "-" / "+" ) *<modes> *<modeparams> )
```

El RFC dice: *"The MODE command is provided so that users may query and change the
characteristics of a channel."* Y añade una restricción clave:

> Note that there is a maximum limit of three (3) changes per command for modes
> that take a parameter.

Es decir: máximo **3 cambios con parámetro** por comando.

### 6.1 Cómo se lee la sintaxis de MODE

La parte `*( ( "-" / "+" ) *<modes> *<modeparams> )` significa: tras el canal viene
una secuencia de bloques, cada uno con un signo (`+` o `-`) y una o más letras de modo,
seguidos de los parámetros que esos modos necesiten. Ejemplos del propio RFC:

```
MODE #42 +k oulu        ; poner la clave del canal a "oulu"
MODE #42 -k oulu        ; quitar la clave
MODE #eu-opers +l 10    ; limitar a 10 usuarios
MODE #Finnish +o Kilroy ; dar privilegio de operador a Kilroy
```

Si MODE llega **sin** modos (solo el canal), el servidor devuelve los modos actuales
con `RPL_CHANNELMODEIS` (324). Eso es la parte "query" del comando.

### 6.2 Los cinco modos de tu subject

El RFC remite los modos concretos a otro documento, así que aquí los explico según
lo que pide tu subject. Dos categorías importan para el parsing:

| Modo | Significado | ¿Lleva parámetro? | Parámetro |
|---|---|---|---|
| `i` | invite-only: solo se entra por invitación | No | — |
| `t` | topic restringido a operadores | No | — |
| `k` | channel key (contraseña) | Sí al poner (`+k <key>`); al quitar (`-k`) varía | la clave |
| `o` | dar/quitar privilegio de operador | Sí | el nick afectado |
| `l` | user limit | Sí al poner (`+l <n>`); no al quitar (`-l`) | el número |

Esa columna "¿lleva parámetro?" es la que gobierna tu parser de MODE: tras leer cada
letra, debes saber si consumir el siguiente argumento o no. Y recuerda el límite de 3
cambios con parámetro por comando.

Comportamiento esperado de cada uno:
- **`+i` / `-i`** — activa/desactiva invite-only. Con `+i`, un JOIN sin invitación
  previa devuelve `473 ERR_INVITEONLYCHAN`.
- **`+t` / `-t`** — con `+t`, solo los operadores pueden cambiar el topic; sin `t`,
  cualquiera del canal puede. (Ver TOPIC, sección 7.)
- **`+k <key>` / `-k`** — fija o elimina la clave. Con clave puesta, JOIN sin la clave
  correcta devuelve `475 ERR_BADCHANNELKEY`. Si intentas `+k` sobre un canal que ya
  tiene clave, el RFC define `467 ERR_KEYSET`.
- **`+o <nick>` / `-o <nick>`** — concede o retira el estatus de operador a un miembro.
  Si ese nick no está en el canal: `441 ERR_USERNOTINCHANNEL`.
- **`+l <n>` / `-l`** — fija o elimina el límite de usuarios. Con el límite alcanzado,
  JOIN devuelve `471 ERR_CHANNELISFULL`.

### 6.3 Errores de MODE aplicables a ft_irc

- `461 ERR_NEEDMOREPARAMS` — falta un parámetro que el modo requería (p. ej. `+o` sin nick).
- `482 ERR_CHANOPRIVSNEEDED` — quien envía MODE no es operador del canal. El RFC dice:
  *"Any command requiring 'chanop' privileges MUST return this error if the client
  making the attempt is not a chanop."*
- `472 ERR_UNKNOWNMODE` — letra de modo desconocida (algo fuera de `itkol`).
- `441 ERR_USERNOTINCHANNEL` — el `+o`/`-o` apunta a alguien que no está en el canal.
- `467 ERR_KEYSET` — intento de `+k` sobre un canal que ya tiene clave.
- `324 RPL_CHANNELMODEIS` — respuesta de consulta (MODE sin cambios).

Cuando un cambio se aplica con éxito, se reenvía a los miembros con el prefix del autor,
como todo en 3.2:
```
:WiZ!jto@tolsun.oulu.fi MODE #eu-opers +o Kilroy
```

> Sobre los modos de tu subject y el parsing combinado (`MODE #c +itk-l clave`):
> el RFC permite agrupar modos y signos. Decidid en equipo hasta dónde queréis soportar
> combinaciones; lo mínimo robusto es procesar las letras de izquierda a derecha,
> arrastrando el signo actual, y consumir un parámetro por cada modo que lo requiera.

---

## 7. Sección 3.2.4 — TOPIC

Bloque original:

```
   Command: TOPIC
Parameters: <channel> [ <topic> ]
```

Comportamiento, del original:

> The topic for channel <channel> is returned if there is no <topic> given.
> If the <topic> parameter is present, the topic for that channel will be changed,
> if this action is allowed for the user requesting it. If the <topic> parameter
> is an empty string, the topic for that channel will be removed.

Tres casos según los parámetros:
1. `TOPIC #c` (sin topic) → **consulta**: devuelve `RPL_TOPIC` (332) si hay topic,
   o `RPL_NOTOPIC` (331) si no.
2. `TOPIC #c :nuevo tema` → **cambia** el topic, si al usuario se le permite.
3. `TOPIC #c :` (topic vacío) → **borra** el topic.

El "si se le permite" del caso 2 conecta con el modo `t`: con `+t`, solo operadores
cambian el topic (y un no-operador recibe `482 ERR_CHANOPRIVSNEEDED`); sin `t`,
cualquier miembro puede.

Errores aplicables:
- `461 ERR_NEEDMOREPARAMS` — TOPIC sin canal.
- `442 ERR_NOTONCHANNEL` — no estás en el canal.
- `482 ERR_CHANOPRIVSNEEDED` — intentas cambiarlo con `+t` activo sin ser operador.
- `331 RPL_NOTOPIC` / `332 RPL_TOPIC` — respuestas de consulta.

Ejemplos del original:
```
:WiZ!jto@tolsun.oulu.fi TOPIC #test :New topic   ; Wiz fija el topic
TOPIC #test :another topic                       ; fijar topic
TOPIC #test :                                     ; borrar topic
TOPIC #test                                       ; consultar topic
```

---

## 8. Sección 3.2.7 — INVITE

Bloque original:

```
   Command: INVITE
Parameters: <nickname> <channel>
```

Orden de parámetros: **primero el nick** a invitar, **luego el canal**. Reglas del original:

> However, if the channel exists, only members of the channel are allowed to invite
> other users. When the channel has invite-only flag set, only channel operators
> may issue INVITE command.

Es decir:
- Si el canal existe, solo sus **miembros** pueden invitar.
- Si el canal tiene `+i`, solo los **operadores** pueden invitar.
- El RFC permite invitar a un canal que aún no existe (no es requisito que exista).

Y sobre quién se entera:

> Only the user inviting and the user being invited will receive notification of
> the invitation. Other channel members are not notified.

A diferencia de MODE/JOIN, la invitación **no** se anuncia al canal: solo la reciben
el que invita y el invitado. El invitado recibe un mensaje `INVITE` con el prefix del
que invita; el que invita recibe `RPL_INVITING` (341) como confirmación.

Errores aplicables:
- `461 ERR_NEEDMOREPARAMS` — faltan parámetros.
- `401 ERR_NOSUCHNICK` — el nick invitado no existe.
- `442 ERR_NOTONCHANNEL` — el que invita no está en el canal.
- `443 ERR_USERONCHANNEL` — el invitado ya está en el canal.
- `482 ERR_CHANOPRIVSNEEDED` — canal `+i` y el que invita no es operador.
- `341 RPL_INVITING` — confirmación al que invita.

Ejemplos del original:
```
:Angel!wings@irc.org INVITE Wiz #Dust   ; mensaje que recibe Wiz al ser invitado
INVITE Wiz #Twilight_Zone               ; comando para invitar a Wiz
```

> Detalle de implementación: una invitación a un canal `+i` normalmente crea una
> "invitación pendiente" que permite a ese nick saltarse el `473` en su próximo JOIN.
> Tendrás que almacenar esa lista de invitados por canal. Es justo el tipo de estructura
> que la evaluación puede pedirte modificar en vivo.

---

## 9. Sección 3.2.8 — KICK

Bloque original:

```
   Command: KICK
Parameters: <channel> *( "," <channel> ) <user> *( "," <user> )
            [<comment>]
```

KICK fuerza la salida de un usuario de un canal. Del original:

> It causes the <user> to PART from the <channel> by force. For the message to be
> syntactically correct, there MUST be either one channel parameter and multiple user
> parameter, or as many channel parameters as there are user parameters.

Es decir, KICK equivale a un PART forzado. Para que la sintaxis sea correcta: o un canal
con varios usuarios, o tantos canales como usuarios. Si hay `comment`, se envía en lugar
del mensaje por defecto (el nick de quien expulsa).

> The server MUST NOT send KICK messages with multiple channels or users to clients.

Igual que JOIN/PART: aceptas listas al parsear, pero reenvías de uno en uno por
compatibilidad con clientes antiguos.

KICK es una acción **de operador**: solo un chanop puede expulsar. Errores aplicables:
- `461 ERR_NEEDMOREPARAMS` — faltan parámetros.
- `403 ERR_NOSUCHCHANNEL` — el canal no existe.
- `482 ERR_CHANOPRIVSNEEDED` — quien expulsa no es operador.
- `441 ERR_USERNOTINCHANNEL` — el objetivo no está en el canal.
- `442 ERR_NOTONCHANNEL` — quien expulsa no está en el canal.

El KICK se reenvía a los miembros con el prefix del operador que lo ejecuta:
```
:WiZ!jto@tolsun.oulu.fi KICK #Finnish John :Speaking English
```

---

## 10. Sección 3.2.5 — NAMES (solo lo necesario para JOIN)

No es un comando obligatorio de tu subject, pero su reply se usa al completar un JOIN.
Bloque original de las replies (sección 5):

```
353    RPL_NAMREPLY
       "( "=" / "*" / "@" ) <channel>
        :[ "@" / "+" ] <nick> *( " " [ "@" / "+" ] <nick> )"
366    RPL_ENDOFNAMES
       "<channel> :End of NAMES list"
```

Para responder a NAMES (y tras un JOIN), se envía un par
`RPL_NAMREPLY` + `RPL_ENDOFNAMES`. En el `353`:
- El primer carácter indica el tipo de canal: `=` público, `*` privado, `@` secreto.
  Para ft_irc, `=` es suficiente.
- Cada nick puede llevar prefijo: `@` si es operador del canal, `+` si tiene voz.
  Tú solo manejas operadores, así que usarás `@` para los chanops y nada para el resto.

Ejemplo de lo que enviaría tu servidor tras un JOIN a `#test` donde `wiz` es operador:
```
:ircserv 353 pepe = #test :@wiz pepe
:ircserv 366 pepe #test :End of NAMES list
```

---

## 11. Replies numéricas de este bloque (referencia)

Formato del RFC: número, nombre simbólico, y la parte `<params> :trailing` que envías
tras `:<prefix> <código> <target>`.

### Respuestas normales (RPL)
```
324    RPL_CHANNELMODEIS    "<channel> <mode> <mode params>"
331    RPL_NOTOPIC          "<channel> :No topic is set"
332    RPL_TOPIC            "<channel> :<topic>"
341    RPL_INVITING         "<channel> <nick>"
353    RPL_NAMREPLY         "( "=" / "*" / "@" ) <channel> :[ "@" / "+" ] <nick> ..."
366    RPL_ENDOFNAMES       "<channel> :End of NAMES list"
```

### Errores (ERR)
```
401    ERR_NOSUCHNICK        "<nickname> :No such nick/channel"
403    ERR_NOSUCHCHANNEL     "<channel name> :No such channel"
441    ERR_USERNOTINCHANNEL  "<nick> <channel> :They aren't on that channel"
442    ERR_NOTONCHANNEL      "<channel> :You're not on that channel"
443    ERR_USERONCHANNEL     "<user> <channel> :is already on channel"
461    ERR_NEEDMOREPARAMS    "<command> :Not enough parameters"
467    ERR_KEYSET            "<channel> :Channel key already set"
471    ERR_CHANNELISFULL     "<channel> :Cannot join channel (+l)"
472    ERR_UNKNOWNMODE       "<char> :is unknown mode char to me for <channel>"
473    ERR_INVITEONLYCHAN    "<channel> :Cannot join channel (+i)"
475    ERR_BADCHANNELKEY     "<channel> :Cannot join channel (+k)"
476    ERR_BADCHANMASK       "<channel> :Bad Channel Mask"
482    ERR_CHANOPRIVSNEEDED  "<channel> :You're not channel operator"
```

Significado de los que más usarás:
- **441** — un comando apunta a un usuario que no está en el canal (típico en `+o`/KICK).
- **442** — intentas operar sobre un canal del que no eres miembro.
- **443** — invitas a alguien que ya está dentro.
- **467** — `+k` sobre un canal que ya tiene clave.
- **471/473/475** — los tres rechazos de JOIN, correspondientes a `+l`, `+i`, `+k`.
- **482** — la clave de la autorización de operador: cualquier comando que requiera
  chanop debe devolver esto si quien lo intenta no lo es.

---

## 12. Checklist de implementación (operaciones de canal)

Interpretación práctica (no literal del RFC) para guiar tu desarrollo:

1. **Estructura de canal**: nombre, topic, clave (`k`), límite (`l`), flags (`i`, `t`),
   conjunto de miembros, conjunto de operadores, conjunto de invitados pendientes.
2. **Precondición común**: casi todos estos comandos exigen estar registrado
   (`451 ERR_NOTREGISTERED` si no) y, salvo JOIN/INVITE, ser miembro del canal.
3. **JOIN**: validar nombre → comprobar `+k`/`+i`/`+l` → añadir miembro (primer
   miembro = operador) → reenviar JOIN a todos → enviar 332/331 → enviar 353+366.
4. **PART**: comprobar pertenencia → reenviar PART → eliminar miembro → si el canal
   queda vacío, decidir si se destruye.
5. **MODE**: si no hay modos → 324. Si hay → verificar chanop (482) → procesar letras
   `itkol` de izquierda a derecha arrastrando signo, consumiendo parámetros donde toque,
   máx. 3 con parámetro → reenviar el cambio.
6. **TOPIC**: sin topic → 332/331. Con topic → respetar `+t` (482 si procede) → fijar
   y reenviar.
7. **INVITE**: verificar pertenencia (442), `+i`→chanop (482), nick existe (401), no
   está ya dentro (443) → registrar invitación pendiente → notificar al invitado +
   341 al que invita.
8. **KICK**: verificar chanop (482), objetivo en canal (441) → reenviar KICK →
   eliminar al objetivo.

---

## 13. Autocomprobación de lectura

Para validar tu autonomía con el original, abre el RFC en la sección **3.3.1 (PRIVMSG)**
—la primera de "Sending messages"— y léela sin traductor. Con el vocabulario de los dos
bloques deberías poder responder: ¿cuál es el orden de parámetros de PRIVMSG, qué error
existe si no hay destinatario, y qué error si no hay texto que enviar?

El siguiente bloque natural es **3.3 (PRIVMSG y NOTICE)** + **3.7.2 (PING/PONG)**,
que cierra el conjunto de comandos que tu subject necesita.
