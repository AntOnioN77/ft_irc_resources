// irc_test_client <host> <port> <idle_timeout_ms>
//
// stdin  -> comandos IRC, uno por línea (sin \r\n; los añade el cliente).
// stdout -> todo lo recibido del servidor, tal cual.
//
// El cliente sale cuando:
//   - se cierra stdin Y han pasado <idle_timeout_ms> sin recibir nada del servidor, o
//   - el servidor cierra la conexión.
//
// Compilar:
//   c++ -Wall -Wextra -Werror -std=c++98 -o irc_test_client irc_test_client.cpp

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <iostream>
#include <unistd.h>
#include <poll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/time.h>

static long now_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static int connect_to(const char *host, const char *port) {
    struct addrinfo hints;
    struct addrinfo *res = NULL;
    std::memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    int rc = getaddrinfo(host, port, &hints, &res);
    if (rc != 0) {
        std::fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rc));
        return -1;
    }

    int fd = -1;
    for (struct addrinfo *ai = res; ai != NULL; ai = ai->ai_next) {
        fd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (fd < 0)
            continue;
        if (connect(fd, ai->ai_addr, ai->ai_addrlen) == 0)
            break;
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    if (fd < 0) {
        std::perror("connect");
        return -1;
    }
    return fd;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        std::fprintf(stderr, "usage: %s <host> <port> <idle_timeout_ms>\n", argv[0]);
        return 2;
    }
    const char *host = argv[1];
    const char *port = argv[2];
    long idle_timeout_ms = std::atol(argv[3]);
    if (idle_timeout_ms <= 0) idle_timeout_ms = 400;

    int sock = connect_to(host, port);
    if (sock < 0) return 1;

    // stdin no bloqueante para poder leer línea a línea sin colgarnos.
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (flags >= 0) fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

    std::string stdin_buf;     // acumula stdin hasta encontrar '\n'
    bool stdin_closed = false;
    long last_recv_ms = now_ms();

    while (true) {
        struct pollfd pfds[2];
        int nfds = 0;

        pfds[nfds].fd = sock;
        pfds[nfds].events = POLLIN;
        pfds[nfds].revents = 0;
        int idx_sock = nfds++;

        int idx_stdin = -1;
        if (!stdin_closed) {
            pfds[nfds].fd = STDIN_FILENO;
            pfds[nfds].events = POLLIN;
            pfds[nfds].revents = 0;
            idx_stdin = nfds++;
        }

        int timeout = (int)idle_timeout_ms;
        int pr = poll(pfds, nfds, timeout);
        if (pr < 0) {
            if (errno == EINTR) continue;
            std::perror("poll");
            break;
        }

        if (pr == 0) {
            // Sin actividad durante idle_timeout_ms.
            // Si stdin ya se cerró, salimos: no esperamos más respuestas.
            if (stdin_closed) break;
            // Si stdin sigue abierto pero el usuario tarda en mandar, seguimos esperando.
            continue;
        }

        // 1) Datos del servidor
        if (pfds[idx_sock].revents & (POLLIN | POLLHUP)) {
            char buf[4096];
            ssize_t n = recv(sock, buf, sizeof(buf), 0);
            if (n > 0) {
                std::fwrite(buf, 1, (size_t)n, stdout);
                std::fflush(stdout);
                last_recv_ms = now_ms();
            } else if (n == 0) {
                // Servidor cerró.
                break;
            } else {
                if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    std::perror("recv");
                    break;
                }
            }
        }
        if (pfds[idx_sock].revents & (POLLERR | POLLNVAL)) {
            break;
        }

        // 2) stdin -> servidor
        if (idx_stdin != -1 && (pfds[idx_stdin].revents & POLLIN)) {
            char buf[1024];
            ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
            if (n > 0) {
                stdin_buf.append(buf, (size_t)n);
                // Extraer líneas completas y enviarlas con \r\n
                while (true) {
                    std::string::size_type pos = stdin_buf.find('\n');
                    if (pos == std::string::npos) break;
                    std::string line = stdin_buf.substr(0, pos);
                    stdin_buf.erase(0, pos + 1);
                    // Quitar \r final si lo hay
                    if (!line.empty() && line[line.size() - 1] == '\r')
                        line.erase(line.size() - 1);
                    line += "\r\n";
                    const char *p = line.c_str();
                    size_t remaining = line.size();
                    while (remaining > 0) {
                        ssize_t s = send(sock, p, remaining, 0);
                        if (s < 0) {
                            if (errno == EINTR) continue;
                            std::perror("send");
                            remaining = 0;
                            stdin_closed = true;
                            break;
                        }
                        p += s;
                        remaining -= (size_t)s;
                    }
                }
            } else if (n == 0) {
                // EOF en stdin: enviar lo que quede sin \n y marcar cerrado.
                if (!stdin_buf.empty()) {
                    stdin_buf += "\r\n";
                    send(sock, stdin_buf.c_str(), stdin_buf.size(), 0);
                    stdin_buf.clear();
                }
                stdin_closed = true;
                last_recv_ms = now_ms(); // reinicia el contador de idle
            } else {
                if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    stdin_closed = true;
                }
            }
        }
        if (idx_stdin != -1 && (pfds[idx_stdin].revents & POLLHUP)) {
            stdin_closed = true;
        }

        // 3) Si stdin cerrado y hemos superado el idle, salir.
        if (stdin_closed && (now_ms() - last_recv_ms) >= idle_timeout_ms) {
            break;
        }
    }

    close(sock);
    return 0;
}
