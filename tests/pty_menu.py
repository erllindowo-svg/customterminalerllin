"""Roda `soviet-arte menu` num pseudo-terminal (sem janela) e envia teclas.

Uso: python3 -I tests/pty_menu.py <soviet-arte> <cenário>
  cores : c 2 (Cores originais), c 1 (Tema do terminal), q
  hup   : Enter (abre o arttime), j (sorteio nativo), y (escolhe) e fecha o
          terminal (SIGHUP), como fechar a janela pelo atalho.
Imprime a saída do terminal sem sequências ANSI; código 0 se o menu terminou.
"""
import os, pty, re, select, signal, struct, sys, termios, fcntl, time

exe, scenario = sys.argv[1], sys.argv[2]
pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM'] = 'xterm-256color'
    os.execv(exe, [exe, 'menu'])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 50, 140, 0, 0))
os.kill(pid, signal.SIGWINCH)
out = b''

def drain(t):
    global out
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                out += os.read(fd, 65536)
            except OSError:
                return

drain(1.5)
steps = {'cores': [('c', .6), ('2', 1.0), ('c', .6), ('1', 1.0), ('q', .8)],
         'hup': [('\r', 3.0), ('j', 1.5), ('y', 1.5)]}[scenario]
for k, w in steps:
    os.write(fd, k.encode()); drain(w)
if scenario == 'hup':
    os.close(fd); time.sleep(1.5)
done = False
for _ in range(20):
    try:
        if os.waitpid(pid, os.WNOHANG)[0]:
            done = True; break
    except ChildProcessError:
        done = True; break
    time.sleep(0.1)
sys.stdout.write(re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', out).decode('utf-8', 'replace'))
sys.exit(0 if done else 1)
