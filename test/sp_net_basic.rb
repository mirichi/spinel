# sp_net.c -- ffi exposed to spinel programs.
#
# Deterministic smoke for the core surface, single-process:
#   - shell_capture runs a command and captures stdout.
#   - a 127.0.0.1 TCP loopback exercises listen / set_nonblock /
#     connect / accept_nb / write_str / recv_some / close in one
#     process (connect to our own listener; accept_nb picks the
#     pending connection off the queue).
#   - getpid returns a positive pid.
# poll / fork / wait_any are covered by consumer suites (tep) -- they
# need multi-process / timing setups that don't make a stable
# .expected.
module Net
  ffi_func :sp_net_listen,        [:int, :int], :int
  ffi_func :sp_net_set_nonblock,  [:int],       :int
  ffi_func :sp_net_connect,       [:str, :int], :int
  ffi_func :sp_net_accept_nb,     [:int],       :int
  ffi_func :sp_net_write_str,     [:int, :str], :int
  ffi_func :sp_net_recv_some,     [:int, :int], :str
  ffi_func :sp_net_close,         [:int],       :int
  ffi_func :sp_net_getpid,        [],           :int
  ffi_func :sp_net_shell_capture, [:str, :int], :str
end

# Shell capture: stdout of `printf hello` is exactly "hello".
puts Net.sp_net_shell_capture("printf hello", 64)

# TCP loopback on a fixed high port.
port = 53217
sfd = Net.sp_net_listen(port, 0)
Net.sp_net_set_nonblock(sfd)
cfd = Net.sp_net_connect("127.0.0.1", port)

# Loopback connect completes synchronously, so the connection is on
# the accept queue; bounded retry tolerates any scheduling slack
# without needing a sleep primitive.
afd = -1
tries = 0
while afd < 0 && tries < 100000
  afd = Net.sp_net_accept_nb(sfd)
  tries = tries + 1
end

Net.sp_net_write_str(cfd, "ping")
puts Net.sp_net_recv_some(afd, 64)

Net.sp_net_close(afd)
Net.sp_net_close(cfd)
Net.sp_net_close(sfd)

puts(Net.sp_net_getpid > 0 ? "pid-ok" : "pid-bad")
