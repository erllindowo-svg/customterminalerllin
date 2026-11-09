#!/usr/bin/env python3
"""Terminal Soviético — pedido de senha da tela de bloqueio.

Roda dentro do foot `soviet-lock` aberto por bin/soviet-lock, no lugar do
terminal da central. Aparência de pedido de senha do sudo. A senha é
validada pelo PAM, no serviço `omarchy-lock-password` (o mesmo do bloqueio do
Omarchy; inclui pam_faillock: 10 erros bloqueiam por 120 s).

Só o sucesso do PAM cria o arquivo-testemunho ($SOVIET_LOCK_TOKEN), e é por ele
que o supervisor sabe que pode liberar a sessão. Qualquer outra saída (erro,
sinal, janela fechada) deixa o bloqueio de pé.

Variáveis de ambiente (usadas pelos testes):
  SOVIET_LOCK_TOKEN        arquivo-testemunho (obrigatório)
  SOVIET_LOCK_PAM_SERVICE  serviço PAM (padrão: omarchy-lock-password)
  SOVIET_LOCK_PAM_CONFDIR  diretório de serviços PAM alternativo (só testes)
  SOVIET_LOCK_USER         usuário (padrão: o do processo)
"""
import ctypes
import ctypes.util
import os
import pwd
import signal
import sys
import termios
import time

PAM_SUCCESS = 0
PAM_PROMPT_ECHO_OFF, PAM_PROMPT_ECHO_ON, PAM_ERROR_MSG, PAM_TEXT_INFO = 1, 2, 3, 4


class PamMessage(ctypes.Structure):
    _fields_ = [("msg_style", ctypes.c_int), ("msg", ctypes.c_char_p)]


class PamResponse(ctypes.Structure):
    _fields_ = [("resp", ctypes.c_void_p), ("resp_retcode", ctypes.c_int)]


CONV_FUNC = ctypes.CFUNCTYPE(
    ctypes.c_int,
    ctypes.c_int,
    ctypes.POINTER(ctypes.POINTER(PamMessage)),
    ctypes.POINTER(ctypes.POINTER(PamResponse)),
    ctypes.c_void_p,
)


class PamConv(ctypes.Structure):
    _fields_ = [("conv", CONV_FUNC), ("appdata_ptr", ctypes.c_void_p)]


def _libs():
    pam = ctypes.CDLL(ctypes.util.find_library("pam") or "libpam.so.0")
    libc = ctypes.CDLL(ctypes.util.find_library("c") or "libc.so.6")
    libc.calloc.restype = ctypes.c_void_p
    libc.calloc.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
    libc.strdup.restype = ctypes.c_void_p
    libc.strdup.argtypes = [ctypes.c_char_p]
    pam.pam_start.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(PamConv),
                              ctypes.POINTER(ctypes.c_void_p)]
    pam.pam_authenticate.argtypes = [ctypes.c_void_p, ctypes.c_int]
    pam.pam_acct_mgmt.argtypes = [ctypes.c_void_p, ctypes.c_int]
    pam.pam_end.argtypes = [ctypes.c_void_p, ctypes.c_int]
    if hasattr(pam, "pam_start_confdir"):
        pam.pam_start_confdir.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(PamConv),
                                          ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p)]
    return pam, libc


def pam_check(user, password, service, confdir=None):
    """True se o PAM aceita a senha (autenticação e conta)."""
    pam, libc = _libs()
    secret = password.encode()

    def conv(n_msg, msgs, resp, _data):
        arr = libc.calloc(n_msg, ctypes.sizeof(PamResponse))
        if not arr:
            return 5  # PAM_BUF_ERR
        out = ctypes.cast(arr, ctypes.POINTER(PamResponse))
        for i in range(n_msg):
            if msgs[i].contents.msg_style in (PAM_PROMPT_ECHO_OFF, PAM_PROMPT_ECHO_ON):
                out[i].resp = libc.strdup(secret)
        resp[0] = out
        return PAM_SUCCESS

    conv_struct = PamConv(CONV_FUNC(conv), None)  # mantém a referência viva até pam_end
    handle = ctypes.c_void_p()
    if confdir:
        rc = pam.pam_start_confdir(service.encode(), user.encode(), ctypes.byref(conv_struct),
                                   confdir.encode(), ctypes.byref(handle))
    else:
        rc = pam.pam_start(service.encode(), user.encode(), ctypes.byref(conv_struct),
                           ctypes.byref(handle))
    if rc != PAM_SUCCESS:
        return False
    try:
        ok = pam.pam_authenticate(handle, 0) == PAM_SUCCESS and pam.pam_acct_mgmt(handle, 0) == PAM_SUCCESS
    finally:
        pam.pam_end(handle, 0)
    return ok


def read_secret(prompt):
    """Lê a linha sem eco (como o sudo). Devolve None em fim de arquivo."""
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    new = termios.tcgetattr(fd)
    new[3] &= ~(termios.ECHO | termios.ISIG)  # sem eco e sem Ctrl+C/Ctrl+Z
    try:
        termios.tcsetattr(fd, termios.TCSAFLUSH, new)
        sys.stdout.write(prompt)
        sys.stdout.flush()
        line = sys.stdin.readline()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        sys.stdout.write("\n")
        sys.stdout.flush()
    if line == "":
        return None
    return line.rstrip("\n")


def main():
    token = os.environ.get("SOVIET_LOCK_TOKEN")
    if not token:
        sys.stderr.write("SOVIET_LOCK_TOKEN ausente\n")
        return 2
    service = os.environ.get("SOVIET_LOCK_PAM_SERVICE", "omarchy-lock-password")
    confdir = os.environ.get("SOVIET_LOCK_PAM_CONFDIR")
    user = os.environ.get("SOVIET_LOCK_USER") or pwd.getpwuid(os.getuid()).pw_name

    for sig in (signal.SIGINT, signal.SIGTSTP, signal.SIGQUIT, signal.SIGTERM):
        signal.signal(sig, signal.SIG_IGN)

    sys.stdout.write("\x1b[2J\x1b[H")
    sys.stdout.write("СТАНЦИЯ // ДОСТУП RESTRITO\n")
    sys.stdout.write(f"Sessão bloqueada às {time.strftime('%H:%M')}. Autentique-se para continuar.\n\n")
    sys.stdout.flush()

    failures = 0
    while True:
        password = read_secret(f"[sudo] senha de {user}: ")
        if password is None:       # Ctrl+D ou terminal fechado: continua pedindo
            time.sleep(0.5)
            continue
        if password and pam_check(user, password, service, confdir):
            fd = os.open(token, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            os.close(fd)
            return 0
        password = ""
        failures += 1
        time.sleep(min(2.0, 0.5 * failures))  # atraso crescente, além do pam_faillock
        sys.stdout.write("Desculpe, tente novamente.\n")
        sys.stdout.flush()


if __name__ == "__main__":
    sys.exit(main())
