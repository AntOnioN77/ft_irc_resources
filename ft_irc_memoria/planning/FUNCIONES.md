Te hago un resumen claro y útil (pensado para C++98 + sockets tipo Unix). Agrupo por categorías para que lo entiendas mejor en contexto real de un servidor tipo IRC 👇

---

# 🔌 1. Sockets básicos

![Image](https://images.openai.com/static-rsc-4/-CfXrjKEKqnv-BuPPxYSK-F4Aa_pTuoPK9d6qp1XHODw4HE3YcAQt0QS8-v1pbXi544ErSI9KGau8nDrXhdhmk-5pqRRRA85p-WMwlcL9c34tFXiPgmbCKmX-_uad1Ifs4kDu33Cnmrzn3gTyY5rNfSKGRMTAUeCpT0vBFvT2oF0hwAGaUeFCX4Qun5rUSOb?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/Vcdf69DUpCIThSSROoktEqqSYh0IKvQXIg_DFw4bqOnwTHUTPMcK7IJM-tLotjtWpU5t3A5HiO3h73Zj9kk3_cWWkr_g5YvMPA9AI_V9W7Rl2xWJfgpKNYoP2nKKpSRoxbtWooW75h-zFL6LNyhfu0eAIuZ2rsMQF7Pv1u-46SQhoCnLcLJTXd2cBtHt3m6i?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/hTmtH0zTPsZQcjmVP76NJxuSl3SUnpilYqFBaKl7622wD9cEyXcflo-wegek2hb-i_YUt64bNzXQz3d0uO3aRQof9jXPj--xasikhSytIvBQW9OnJy39t08oaow6J2I3H7IKwgjkuAlrVNSZIq_mYwFRXoBXu2zXKn_UTvGAOMnPJmzHWoU-nTEgwCP_9W45?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/peknC9uos6IX-pQkrGrx4zABx2bZ2_JNBUy6xVEa1qJ-YEPcNGVdhSYRFmf-iyoD3DyjN9Kpx08cnGOOB69qSWux2N6i0s4Zw0ohA1UG7eSfs0fRNhKp-BYEdSnF6z4pbhdsyXwgxJ80kBuM9fc7Zjkw8jCjDt5Ijjw97d-jQcC_gmM98eqeuBw-gajjnk8e?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/xm58zg4scoqjKg_YKegoW5oPxtnY-EJn10hZGttU2gT2s_aU2Ok9R2fgHxYETcMsftsvdm-dplIDyrVtxVN_H6P4xDDYqtdBr9hZfKwzDBijSD9j8H_evmqxNxgcRsyAQoPbzx1T3IjRVAdWn48HP70bF99cJAbpqvNWrRX70_J-EM0LVBDJ3Qxy96gHNEIj?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/sCCtcWkZcFYLIaQ80nNIjWjPU0UMaa8ucYAhmRFRREDJ4F0g3FLEA_PhytI3Yfkj6K9GVj8YIVG5DrsFjiTuAwEpRZQL1qdFIaAmZF0w2i2jKnONkgGyZK6PjFP0-SqwsFKuTWfbGAm1tOO6EY-ixNxaivkOKZsziphR8noUP_MgDDQP9I-1cbUubA00TJGy?purpose=fullsize)

### `socket`

**Header:** `<sys/socket.h>`
**Qué hace:** Crea un socket (endpoint de comunicación)

```cpp
int sockfd = socket(AF_INET, SOCK_STREAM, 0);
```

---

### `close`

**Header:** `<unistd.h>`
**Qué hace:** Cierra un descriptor (socket incluido)

```cpp
close(sockfd);
```

---

### `setsockopt`

**Header:** `<sys/socket.h>`
**Qué hace:** Configura opciones del socket (ej: reutilizar puerto)

```cpp
int opt = 1;
setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
```

---

### `getsockname`

**Header:** `<sys/socket.h>`
**Qué hace:** Obtiene la dirección asignada al socket

```cpp
struct sockaddr_in addr;
socklen_t len = sizeof(addr);
getsockname(sockfd, (struct sockaddr*)&addr, &len);
```

---

# 🌍 2. Resolución de direcciones

![Image](https://images.openai.com/static-rsc-4/G5vyYruNmoIG8z0_iwBCbf81-mOkuYDVb8o2gd83hfb0PG65vhCSUFuJvXx95uxUrGKkIBOtUnPjCb7XSPol-b2C3d9GXx2_83hLcp244qQi7xsG4JRp24hUOF_MNAhfk6w-Ad3pqNRMSmTbGBTZejzEHqh0iOUtW0O7OXRdoHtt_og18PZyM20sMvoe_cJU?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/HbHLUtAukb5282112Tg8gBDplII7qal3Ue4alKJsNwwfi0aqWjIF7TxYU66xiaJTvBL-V3Cl6lpJVbTIYA00alB4iM-gqEQBgRrh1DxTyErqZ_7qM4111gbFKx5QJXFKvbx6cPVQXkuslqJpZtqoTbFOm946IOlHGT-fJqROavYATujJi9UTvQCDTxyBQtLJ?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/ruIzbuuM9wkSXUgW7cew4aulf7ZV-10YGRPAjY0DBxYSlssdH1rhuZ4HsR3ekD31TzVQFSZPtDwuuEZTDidUF9JEoTgVBPLpAXv6C0hHAsOqarY0wMZqPlCgAqNqly_ZUEuo4Yq6VwEohe4FpWeialUpxTnLl8i2BxOff08oZa0AwKqJR-PDwO-G2hfX-Ae3?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/HBDyj-fEgscv5NvIZDVfFk2RODUZGWeIDYLhI4Vsj2wHAE2pLQ_CWsxsM--AW0jEU62-HnjmvAyJ-Xn43ZSkd_S0ERfrtsilT-wHoSHuT3NlAnl6LUgeKLv9EGUXs53mbkcXu8RUaxZ7QTVo2nuBmFy9q7yDxBkbB9Xu1nrWCCZkmAKZpDzH1nc9sne0boE6?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/IMaIkx9OicwNTttKRm6bdG8yjO4-lkRb7ktFuzAozA_39lsUaw9Rk4zS_duBQEaWHn_09aZj5RGamuA1M41SeTN2xpHjS7Lu8LDtP9lKlNa7Bt-K4m4xcWWOQwhzMw7-ysQNxkwU-EuSsyNH5PvUdD1uVnMF4M7pgaS1zpMVcTJFng5hKUtOaIhXLkCEu2hG?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/tnff_uH-300c84n8LSmFOOnDWYC2Z2hroGEc6vQhZ0HDhwFiKWisRxPSpnM_CSXX-wuaWA90d_YHAuoBSMRZ4PQQVOW902Y9K6r_r4iqtVNECqntXVrkJtiIkYhhmms0otuKdW0xphZrjwUkZ3z7zffPJV6MCWX77wkiooEOcXyfyvOF5CR2CdWDA9GUVm5i?purpose=fullsize)

### `getprotobyname`

**Header:** `<netdb.h>`
**Qué hace:** Obtiene info de protocolo (ej: "tcp")

```cpp
struct protoent *proto = getprotobyname("tcp");
```

---

### `gethostbyname` ⚠️ (obsoleta)

**Header:** `<netdb.h>`
**Qué hace:** Convierte hostname → IP

```cpp
struct hostent *host = gethostbyname("example.com");
```

---

### `getaddrinfo` (la correcta moderna)

**Header:** `<netdb.h>`
**Qué hace:** Resuelve host + puerto → estructuras usables

```cpp
struct addrinfo hints = {}, *res;

hints.ai_family = AF_INET;
hints.ai_socktype = SOCK_STREAM;

getaddrinfo("127.0.0.1", "8080", &hints, &res);
```

---

### `freeaddrinfo`

**Header:** `<netdb.h>`
**Qué hace:** Libera memoria de `getaddrinfo`

```cpp
freeaddrinfo(res);
```

---

# 🔗 3. Conexión (cliente/servidor)

### `bind`

**Header:** `<sys/socket.h>`
**Qué hace:** Asocia socket a IP/puerto

```cpp
bind(sockfd, (struct sockaddr*)&addr, sizeof(addr));
```

---

### `listen`

**Header:** `<sys/socket.h>`
**Qué hace:** Pone el socket en modo escucha

```cpp
listen(sockfd, 10);
```

---

### `accept`

**Header:** `<sys/socket.h>`
**Qué hace:** Acepta una conexión entrante

```cpp
int client = accept(sockfd, NULL, NULL);
```

---

### `connect`

**Header:** `<sys/socket.h>`
**Qué hace:** Conecta cliente a servidor

```cpp
connect(sockfd, (struct sockaddr*)&addr, sizeof(addr));
```

---

# 🔄 4. Conversión de bytes (endianness)

### `htons`, `htonl`, `ntohs`, `ntohl`

**Header:** `<arpa/inet.h>`
**Qué hacen:** Host ↔ Network byte order

```cpp
addr.sin_port = htons(8080);
```

---

# 🌐 5. IPs

### `inet_addr`

**Header:** `<arpa/inet.h>`
**Qué hace:** string → IP

```cpp
addr.sin_addr.s_addr = inet_addr("127.0.0.1");
```

---

### `inet_ntoa`

**Header:** `<arpa/inet.h>`
**Qué hace:** IP → string (antigua)

```cpp
printf("%s\n", inet_ntoa(addr.sin_addr));
```

---

### `inet_ntop` (mejor)

**Header:** `<arpa/inet.h>`
**Qué hace:** IP → string (moderna)

```cpp
char buffer[INET_ADDRSTRLEN];
inet_ntop(AF_INET, &addr.sin_addr, buffer, INET_ADDRSTRLEN);
```

---

# 📡 6. Envío de datos

### `send`

**Header:** `<sys/socket.h>`
**Qué hace:** Envía datos

```cpp
send(sockfd, "hola", 4, 0);
```

---

### `recv`

**Header:** `<sys/socket.h>`
**Qué hace:** Recibe datos

```cpp
char buf[1024];
recv(sockfd, buf, sizeof(buf), 0);
```

---

# ⚠️ 7. Señales

### `signal`

**Header:** `<signal.h>`
**Qué hace:** Manejo básico de señales

```cpp
signal(SIGINT, handler);
```

---

### `sigaction` (mejor)

**Header:** `<signal.h>`
**Qué hace:** Manejo avanzado de señales

```cpp
struct sigaction sa;
sa.sa_handler = handler;
sigaction(SIGINT, &sa, NULL);
```

---

### Manipulación de máscaras

**Header:** `<signal.h>`

```cpp
sigset_t set;
sigemptyset(&set);
sigaddset(&set, SIGINT);
```

---

# 📁 8. Sistema de archivos

### `lseek`

**Header:** `<unistd.h>`
**Qué hace:** Mueve cursor en archivo

```cpp
lseek(fd, 0, SEEK_SET);
```

---

### `fstat`

**Header:** `<sys/stat.h>`
**Qué hace:** Info de archivo

```cpp
struct stat st;
fstat(fd, &st);
```

---

### `fcntl`

**Header:** `<fcntl.h>`
**Qué hace:** Control de descriptor (ej: no bloqueante)

```cpp
fcntl(sockfd, F_SETFL, O_NONBLOCK);
```

---

# ⏱️ 9. Multiplexación

## `poll`

![Image](https://images.openai.com/static-rsc-4/ejcUtW8dA-FMd02HvPNQxCLW6EjkBU3cYKvvcYOKZCrJ7mRXkWlUlukRz_96azmJYJArB9XKjzlfkVUaMxGW7CowcUx33wXtlkGO48XJtdp9UQ3UtzoEZ4XthdQ3Hxpck_OJ_r55sea0_ud_7-J56RCUbggRWcShNHdiFjAngfoKN2Y0eb_iQrxb9zU-fZyN?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/-tU0dduxWACNcYyFlMqgny6r7urDQKMzomGEwR0Dz-SsGj5RzXidvDsTWHQziF5un7lQDySdennrLsZpoF8DBkMx96GrY6F8up9H8WZXHtcYa8gF-FSqMrLdawmboQLhzX0RdmGy7jvC5f1ZIcnnvZ6Unaaa6m-Lv--RatKUoFU2EruE4dJCdG3bzTDiJUs4?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/sbMhttu9EE5A0xCaIEl_v30xBXf1pWoC3_Y-K8NrnFNb8uJY0qWy9bBGhIXk96_in0dyfrg61kPZe0mhC_1fWbzXkur_ytW31DBwJArlBO9tNqbKnjtLFe1LIafXzXesxZ6PSyDbE9BnpeZOCfxxq-ci-PMC3456qNq-vRZb-SvIaf9A9DNr6eqG3v42Jaz2?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/UNd37GER8ASNN0A0KPWARitP2C8bfOEAljbwyxM6CefI9V0ohC_9Ex_dky-3mJUeQvYMvqnNpvc8yq7I1wUIlFcs56y75ts8W0nWWnZzJnvMRw5Y45s_LAoUG_kCENw6rVx0Y1MfdMbRu71BhzPCIDSPDYikGtRwSBSvuWtoBPqqBMR_8bTzREnr3qxC-fVd?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/z8pfBZVABxT9rY78_w-AwkuKZwMEUJnxNN3haG7zlg0qlvfHkwnD4i_BI3kSBcWwipuZQEWnIfZLrQWIXuKd2MZV_tKWgDVda8PPtnZF-FONhy2FmUcHHWhR3eIqjf47tWc_wFM63RAemp4Z3BSM1u8CaWfv5IQ_oX4KdChlsKJh0qVw1vwAY61n3vkfuv-J?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/w8a03K-Pp5yGxsqreH4DS-rtOTH_jX_5j-ZtQCE_Gc1Mgr2uX-fDxToauPIJWZmM-ClJUUKwjN7bCGCDHzrD1yrpY3zY0rfnWkPTkM2Yz2yUAMOrIWcqHYWch9idoOFrpKFkMkIsYx2Yg25GdhszSJ0tVLQkmhsilFyMXXZXPZYgaIbmZJfHJhL12vxCbFwm?purpose=fullsize)

**Header:** `<poll.h>`
**Qué hace:** Espera eventos en múltiples sockets

```cpp
struct pollfd fds[1];
fds[0].fd = sockfd;
fds[0].events = POLLIN;

poll(fds, 1, 1000);
```

---

# 💡 CONSEJO CLAVE (para tu proyecto tipo IRC)

Si estás haciendo un servidor:

* Usa `getaddrinfo` → SIEMPRE
* Usa `poll` → para múltiples clientes
* Usa `fcntl` → modo no bloqueante
* Usa `sigaction` → Ctrl+C limpio
* Evita `gethostbyname` e `inet_ntoa`
