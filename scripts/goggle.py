#!/usr/bin/env python3
"""Debug helper for the HDZero goggle over the serial console (no network).

Python stdlib only: talks to the serial port directly (termios), transfers
files with printf/hexdump on the goggle side, so it works against the stock
firmware's minimal busybox.

Subcommands:
  run "cmd ..."          run a shell command on the goggle, print output
  push FILE [DEST_DIR]   send a file (default dest: /tmp)
  pull REMOTE [LOCALDIR] fetch a file (default: cwd)
  deploy-ko MODULE.ko    push + md5 check + rmmod/insmod + dmesg tail
  dmesg                  print dmesg

Common options: --port /dev/ttyUSB0
"""

import argparse
import hashlib
import os
import re
import select
import sys
import termios
import time
from pathlib import Path

# stock busybox: "root@tina:/# ", NixOS bash: "...root@hdzero:~]#<SGR reset> "
PROMPT = re.compile(rb"root@\w+:[^\r\n]*#(?:\x1b\[[0-9;]*m)? $")
# OSC titles, CSI sequences (colors, bracketed paste) and BEL
ESCAPES = re.compile(rb"\x1b\][^\x07]*\x07|\x1b\[[0-9;?]*[A-Za-z]|\x07")
# bytes per push command line; octal escaping is 4 chars/byte and the
# busybox line editor on the stock firmware truncates lines around 512 chars
CHUNK = 96


class Console:
    def __init__(self, port: str, baud: int = 115200) -> None:
        self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        attrs = termios.tcgetattr(self.fd)
        attrs[0] = 0  # iflag
        attrs[1] = 0  # oflag
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL  # cflag
        attrs[3] = 0  # lflag (raw, no echo)
        speed = getattr(termios, f"B{baud}")
        attrs[4] = attrs[5] = speed
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        termios.tcflush(self.fd, termios.TCIOFLUSH)

    def write(self, data: bytes) -> None:
        # Pace writes to roughly the line rate. The console has no flow
        # control and echoes everything back; blasting long lines overruns
        # the goggle's UART and corrupts the command.
        for i in range(0, len(data), 64):
            piece = data[i : i + 64]
            while piece:
                select.select([], [self.fd], [])
                n = os.write(self.fd, piece)
                piece = piece[n:]
            time.sleep(0.006)

    def expect(self, pattern: re.Pattern[bytes], timeout: float = 15.0) -> bytes:
        buf = b""
        deadline = time.monotonic() + timeout
        while True:
            if pattern.search(buf):
                return buf
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(
                    f"timeout waiting for {pattern.pattern!r}, got: {buf[-200:]!r}"
                )
            r, _, _ = select.select([self.fd], [], [], min(remaining, 1.0))
            if r:
                buf += os.read(self.fd, 4096)

    def connect(self) -> None:
        # Recover from any half-typed line: ctrl-U clears the line, a quote
        # closes a dangling single-quoted string from an earlier aborted
        # transfer (the resulting junk command is harmless), ctrl-C aborts.
        any_prompt = re.compile(rb"(root@\w+:[^\r\n]*#(?:\x1b\[[0-9;]*m)? |> )$")
        for attempt in (b"\r", b"\x15\x03\r", b"'\r", b"\r"):
            self.write(attempt)
            out = self.expect(any_prompt, timeout=5)
            if PROMPT.search(out):
                return
        raise TimeoutError("could not get a shell prompt")

    def run(self, cmd: str, timeout: float = 30.0) -> str:
        self.write(cmd.encode() + b"\r")
        out = self.expect(PROMPT, timeout)
        # drop escape sequences, the echoed command line and the prompt
        lines = ESCAPES.sub(b"", out).replace(b"\r", b"").split(b"\n")
        return (
            b"\n".join(lines[1:-1]).decode(errors="replace") + "\n"
            if len(lines) > 2
            else ""
        )

    def push(self, local: Path, dest_dir: str = "/tmp") -> str:
        data = local.read_bytes()
        remote = f"{dest_dir}/{local.name}"
        print(f"sending {local} ({len(data)} bytes)", file=sys.stderr)
        self.run(f"rm -f {remote}")
        for i in range(0, len(data), CHUNK):
            chunk = data[i : i + CHUNK]
            escaped = "".join(f"\\{b:03o}" for b in chunk)
            self.run(f"printf '{escaped}' >> {remote}")
            print(f"\r{min(i + CHUNK, len(data))}/{len(data)}", end="", file=sys.stderr)
        print(file=sys.stderr)
        self._check_md5(data, remote)
        return remote

    def pull(self, remote: str, local_dir: Path) -> Path:
        out = self.run(f"hexdump -ve '1/1 \"%02x\"' {remote} && echo", timeout=300)
        data = bytes.fromhex(out.strip())
        self._check_md5(data, remote)
        local = local_dir / Path(remote).name
        local.write_bytes(data)
        return local

    def _check_md5(self, data: bytes, remote: str) -> None:
        md5 = hashlib.md5(data).hexdigest()
        if md5 not in self.run(f"md5sum {remote}"):
            sys.exit(f"md5 mismatch for {remote}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default="/dev/ttyUSB0")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("run", help="run a command on the goggle")
    p.add_argument("command")

    p = sub.add_parser("push", help="send a file to the goggle")
    p.add_argument("file", type=Path)
    p.add_argument("dest_dir", nargs="?", default="/tmp")

    p = sub.add_parser("pull", help="fetch a file from the goggle")
    p.add_argument("remote")
    p.add_argument("local_dir", nargs="?", type=Path, default=Path("."))

    p = sub.add_parser("deploy-ko", help="push a kernel module and reload it")
    p.add_argument("module", type=Path)

    sub.add_parser("dmesg", help="print dmesg")

    args = parser.parse_args()
    con = Console(args.port)
    con.connect()

    if args.cmd == "run":
        print(con.run(args.command), end="")
    elif args.cmd == "push":
        print(con.push(args.file, args.dest_dir))
    elif args.cmd == "pull":
        print(con.pull(args.remote, args.local_dir))
    elif args.cmd == "dmesg":
        print(con.run("dmesg"), end="")
    elif args.cmd == "deploy-ko":
        name = args.module.stem
        remote = con.push(args.module)
        con.run(f"rmmod {name} 2>/dev/null")
        print(con.run(f"insmod {remote}"), end="")
        print(con.run("dmesg | tail -20"), end="")


if __name__ == "__main__":
    main()
