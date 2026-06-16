## Guia para entender RFCs 
Enfocada en ft_irc, pero pensada como introducción a los verdaderos RFCs. Seguir esta guía no es una forma perezosa de evitar consultas a los RFC, sino un camino para empezar a entenderlos.
- [[guia_rfc2812_bloque1]] 
- [[guia_rfc2812_bloque2]]
- [[guia_rfc2812_bloque3]]

## RFCs principales
Enlaces directos a las especificaciones del protocolo IRC.

**RFC 1459** — Documento original (1993) que define todo el protocolo IRC de una sola vez: arquitectura, mensajes, comandos, comunicación cliente-servidor y servidor-servidor. Quedó parcialmente obsoleto por la serie 2810-2813, pero sigue siendo útil como contexto histórico.
- [RFC 1459 — Internet Relay Chat Protocol](https://www.rfc-editor.org/rfc/rfc1459)

**RFC 2810** — Describe la arquitectura general de una red IRC: cómo se conectan los servidores entre sí, propagación de mensajes, etc. Poco relevante para ft_irc (no hay server-to-server), pero da contexto general.
- [RFC 2810 — Architecture](https://www.rfc-editor.org/rfc/rfc2810)

**RFC 2811** — Gestión de canales: modos de canal (i, t, k, o, l...), operadores, listas de bans/invitaciones. Directamente relevante para la parte de MODE/KICK/INVITE/TOPIC.
- [RFC 2811 — Channel Management](https://www.rfc-editor.org/rfc/rfc2811)

**RFC 2812** — Protocolo cliente-servidor: formato exacto de los mensajes, lista completa de comandos (PASS, NICK, USER, JOIN, PRIVMSG...) y respuestas numéricas. Es la referencia principal para ft_irc.
- [RFC 2812 — Client Protocol](https://www.rfc-editor.org/rfc/rfc2812)
-  [RFC 2812 — mas claro](https://modern.ircdocs.horse/#client-messages)

**RFC 2813** — Protocolo servidor-servidor. No aplica a ft_irc (está prohibido implementarlo), pero puede ayudar a entender por qué ciertos campos o numéricos existen.
- [RFC 2813 — Server Protocol](https://www.rfc-editor.org/rfc/rfc2813)



