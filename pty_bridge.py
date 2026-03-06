#!/usr/bin/env python3
"""PTY-to-TCP bridge for VICE RS232 emulation.

Creates a pseudo-terminal that VICE can use as an RS232 device,
and bridges data bidirectionally to a TCP server.

Usage:
    python3 pty_bridge.py
    Then configure VICE: RsDevice1 = /tmp/c64modem (no IP232)
"""

import os
import pty
import select
import socket
import sys
import time

PTY_LINK = "/tmp/c64modem"
TCP_HOST = "127.0.0.1"
TCP_PORT = 6400


def main():
    # Create pseudo-terminal
    master_fd, slave_fd = pty.openpty()
    slave_name = os.ttyname(slave_fd)
    print(f"PTY slave: {slave_name}")

    # Create symlink for easy VICE config
    if os.path.exists(PTY_LINK):
        os.unlink(PTY_LINK)
    os.symlink(slave_name, PTY_LINK)
    print(f"Symlink: {PTY_LINK} -> {slave_name}")

    tcp_sock = None
    print(f"Waiting for data on PTY (VICE connects via {PTY_LINK})...")
    print(f"Will bridge to TCP {TCP_HOST}:{TCP_PORT}")

    try:
        while True:
            # Wait for data from PTY (VICE) or TCP (server)
            read_fds = [master_fd]
            if tcp_sock:
                read_fds.append(tcp_sock)

            readable, _, _ = select.select(read_fds, [], [], 1.0)

            for fd in readable:
                if fd == master_fd:
                    # Data from VICE via PTY
                    data = os.read(master_fd, 4096)
                    if not data:
                        continue
                    hexdump = " ".join(f"{b:02x}" for b in data)
                    ascii_repr = "".join(
                        chr(b) if 32 <= b < 127 else "." for b in data
                    )
                    print(f"VICE->SRV ({len(data)}): {hexdump}  |{ascii_repr}|")

                    # Connect to TCP server on first data
                    if tcp_sock is None:
                        try:
                            tcp_sock = socket.socket(
                                socket.AF_INET, socket.SOCK_STREAM
                            )
                            tcp_sock.connect((TCP_HOST, TCP_PORT))
                            tcp_sock.setblocking(False)
                            print(f"TCP connected to {TCP_HOST}:{TCP_PORT}")
                        except Exception as e:
                            print(f"TCP connect failed: {e}")
                            tcp_sock = None
                            continue

                    if tcp_sock:
                        try:
                            tcp_sock.sendall(data)
                        except Exception as e:
                            print(f"TCP send error: {e}")
                            tcp_sock.close()
                            tcp_sock = None

                elif fd == tcp_sock:
                    # Data from server via TCP
                    try:
                        data = tcp_sock.recv(4096)
                        if not data:
                            print("TCP server closed connection")
                            tcp_sock.close()
                            tcp_sock = None
                            continue
                        hexdump = " ".join(f"{b:02x}" for b in data)
                        ascii_repr = "".join(
                            chr(b) if 32 <= b < 127 else "." for b in data
                        )
                        print(f"SRV->VICE ({len(data)}): {hexdump}  |{ascii_repr}|")
                        os.write(master_fd, data)
                    except Exception as e:
                        print(f"TCP recv error: {e}")
                        tcp_sock.close()
                        tcp_sock = None

    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        if os.path.exists(PTY_LINK):
            os.unlink(PTY_LINK)
        os.close(master_fd)
        os.close(slave_fd)
        if tcp_sock:
            tcp_sock.close()


if __name__ == "__main__":
    main()
