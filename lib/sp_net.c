/* sp_net.c -- POSIX TCP / poll / process / shell primitives.
 * See sp_net.h. Pure C, no spinel-runtime dependency; no OpenSSL.
 *
 * Extracted from tep's lib/tep/sphttp.c (the POSIX-runtime core that
 * is generic across HTTP-shaped Spinel programs), per matz/spinel#1054
 * and OriPekelman/tep#12. HTTP framing + WebSocket accessors + TLS stay
 * framework-side. */
#include "sp_net.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <signal.h>

#define SP_NET_BUFSIZE 65536

/* ---------- graceful shutdown ---------- */

static volatile sig_atomic_t sp_net_term_flag = 0;

static void sp_net_term_signal(int sig) {
    (void)sig;
    sp_net_term_flag = 1;
}

int sp_net_install_term_handlers(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = sp_net_term_signal;
    sigemptyset(&sa.sa_mask);
    /* SA_RESETHAND: a second signal restores the default action so a
     * non-cooperative second Ctrl-C kills immediately. */
    sa.sa_flags = SA_RESETHAND;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT,  &sa, NULL);
    return 0;
}

int sp_net_shutdown_requested(void) {
    return (int)sp_net_term_flag;
}

/* ---------- TCP socket lifecycle ---------- */

int sp_net_listen(int port, int reuseport) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
#ifdef SO_REUSEPORT
    if (reuseport) {
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &one, sizeof(one));
    }
#endif
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
    signal(SIGPIPE, SIG_IGN);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons((unsigned short)port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) { close(fd); return -1; }
    if (listen(fd, 1024) < 0) { close(fd); return -1; }
    return fd;
}

int sp_net_accept(int sfd) {
    struct sockaddr_in caddr;
    socklen_t clen = sizeof(caddr);
    int fd;
    for (;;) {
        /* Honor a term signal that arrived between accepts (flag set
         * with no syscall in flight to interrupt) -- check before
         * blocking, not only on EINTR, or the next accept() blocks
         * forever with the flag already set. */
        if (sp_net_term_flag) return -1;
        fd = accept(sfd, (struct sockaddr *)&caddr, &clen);
        if (fd >= 0) return fd;
        if (errno == EINTR) {
            if (sp_net_term_flag) return -1;
            continue;   /* unrelated signal (SIGCHLD, ...) -- retry */
        }
        return -1;
    }
}

int sp_net_accept_nb(int sfd) {
    struct sockaddr_in caddr;
    socklen_t clen = sizeof(caddr);
    int fd;
    do {
        fd = accept(sfd, (struct sockaddr *)&caddr, &clen);
    } while (fd < 0 && errno == EINTR);
    return fd;
}

int sp_net_connect(const char *host, int port) {
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    char portbuf[16];
    snprintf(portbuf, sizeof(portbuf), "%d", port);
    if (getaddrinfo(host, portbuf, &hints, &res) != 0) return -1;

    int fd = -1;
    struct addrinfo *ai;
    for (ai = res; ai != NULL; ai = ai->ai_next) {
        fd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (fd < 0) continue;
        if (connect(fd, ai->ai_addr, ai->ai_addrlen) == 0) break;
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    if (fd < 0) return -1;

    int one = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
    return fd;
}

int sp_net_close(int fd) {
    return close(fd);
}

int sp_net_set_nonblock(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return -1;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

/* ---------- TCP I/O ---------- */

int sp_net_write_str(int fd, const char *s) {
    size_t len = strlen(s);
    size_t off = 0;
    while (off < len) {
        ssize_t n = send(fd, s + off, len - off, 0);
        if (n <= 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        off += (size_t)n;
    }
    return 0;
}

int sp_net_write_bytes(int fd, const char *data, int n) {
    size_t total = (n < 0) ? 0 : (size_t)n;
    size_t off = 0;
    while (off < total) {
        ssize_t w = send(fd, data + off, total - off, 0);
        if (w <= 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        off += (size_t)w;
    }
    return 0;
}

static char sp_net_recv_buf[SP_NET_BUFSIZE];
const char *sp_net_recv_some(int fd, int maxlen) {
    if (maxlen <= 0 || maxlen >= SP_NET_BUFSIZE) maxlen = SP_NET_BUFSIZE - 1;
    ssize_t n = recv(fd, sp_net_recv_buf, (size_t)maxlen, 0);
    if (n <= 0) {
        sp_net_recv_buf[0] = '\0';
        return sp_net_recv_buf;
    }
    sp_net_recv_buf[n] = '\0';
    return sp_net_recv_buf;
}

static char sp_net_recv_all_buf[SP_NET_BUFSIZE];
const char *sp_net_recv_all(int fd, int max_bytes) {
    if (max_bytes <= 0 || max_bytes >= SP_NET_BUFSIZE) max_bytes = SP_NET_BUFSIZE - 1;
    int total = 0;
    while (total < max_bytes) {
        ssize_t n = recv(fd, sp_net_recv_all_buf + total, (size_t)(max_bytes - total), 0);
        if (n <= 0) break;
        total += (int)n;
    }
    sp_net_recv_all_buf[total] = '\0';
    return sp_net_recv_all_buf;
}

/* ---------- poll(2) ---------- */

#define SP_NET_POLL_MAX 256
static struct pollfd sp_net_poll_set[SP_NET_POLL_MAX];
static int           sp_net_poll_n = 0;

int sp_net_poll_reset(void) {
    sp_net_poll_n = 0;
    return 0;
}

int sp_net_poll_add(int fd, int mode_bits) {
    if (sp_net_poll_n >= SP_NET_POLL_MAX) return -1;
    short ev = 0;
    if (mode_bits & 1) ev |= POLLIN;
    if (mode_bits & 2) ev |= POLLOUT;
    sp_net_poll_set[sp_net_poll_n].fd      = fd;
    sp_net_poll_set[sp_net_poll_n].events  = ev;
    sp_net_poll_set[sp_net_poll_n].revents = 0;
    return sp_net_poll_n++;
}

int sp_net_poll_run(int timeout_ms) {
    int r;
    do {
        r = poll(sp_net_poll_set, sp_net_poll_n, timeout_ms);
    } while (r < 0 && errno == EINTR);
    return r;
}

int sp_net_poll_ready(int slot) {
    if (slot < 0 || slot >= sp_net_poll_n) return 0;
    short rev = sp_net_poll_set[slot].revents;
    int out = 0;
    if (rev & (POLLIN | POLLHUP | POLLERR)) out |= 1;
    if (rev & POLLOUT)                      out |= 2;
    return out;
}

/* ---------- process (prefork) ---------- */

int sp_net_fork(void) {
    return (int)fork();
}

int sp_net_exit(int status) {
    _exit(status);
    return 0;   /* unreachable */
}

int sp_net_getpid(void) {
    return (int)getpid();
}

int sp_net_wait_any(void) {
    int status = 0;
    pid_t p = wait(&status);
    return (int)p;
}

/* ---------- shell ---------- */

static char sp_net_shell_buf[SP_NET_BUFSIZE];
const char *sp_net_shell_capture(const char *cmd, int max_bytes) {
    if (max_bytes <= 0 || max_bytes >= SP_NET_BUFSIZE) max_bytes = SP_NET_BUFSIZE - 1;
    sp_net_shell_buf[0] = '\0';
    FILE *fp = popen(cmd, "r");
    if (!fp) return sp_net_shell_buf;
    size_t total = 0;
    while (total < (size_t)max_bytes) {
        size_t n = fread(sp_net_shell_buf + total, 1, (size_t)max_bytes - total, fp);
        if (n == 0) break;
        total += n;
    }
    sp_net_shell_buf[total] = '\0';
    pclose(fp);
    return sp_net_shell_buf;
}
