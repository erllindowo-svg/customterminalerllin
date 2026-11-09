#!/usr/bin/env python3
"""Aciona o prompt.py num pty: <token> <confdir> <senha1> [<senha2> ...].
Imprime a saída e termina com o código do prompt, ou 99 se ele seguir pedindo senha."""
import os, pty, select, sys, time

token, confdir, senhas = sys.argv[1], sys.argv[2], sys.argv[3:]
here = os.path.dirname(os.path.abspath(__file__))
prompt = os.path.join(here, "..", "share", "terminal-soviet", "lock", "prompt.py")
env = dict(os.environ, SOVIET_LOCK_TOKEN=token, SOVIET_LOCK_PAM_SERVICE="t",
           SOVIET_LOCK_PAM_CONFDIR=confdir, PYTHONDONTWRITEBYTECODE="1")
pid, fd = pty.fork()
if pid == 0:
    os.execvpe("python3", ["python3", "-I", prompt], env)

def drain(t):
    out, end = b"", time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
    return out.decode(errors="replace")

saida = drain(1.5)
for s in senhas:
    os.write(fd, (s + "\n").encode())
    saida += drain(3.5)
print(saida)
done, status = os.waitpid(pid, os.WNOHANG)
if done == 0:
    os.kill(pid, 9); os.waitpid(pid, 0)
    sys.exit(99)
sys.exit(os.waitstatus_to_exitcode(status))
