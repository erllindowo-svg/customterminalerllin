#!/usr/bin/env python3
"""Terminal Soviético — fonte do menu do Limine a partir de uma fonte PSF.

O Limine (term_font) só aceita fonte crua: 256 glifos consecutivos de 8 px de
largura (1 byte por linha), na ordem da página de código 437 (CONFIG.md v12).
As fontes de console livres (Terminus, kbd) vêm em PSF1/PSF2 com outra ordem e
uma tabela Unicode. Este script põe cada posição da página de código no lugar
certo procurando o caractere Unicode dela na tabela da fonte.

Uso:
  limine-font.py <saída> <fonte.psf[.gz]>… [--pagina cp437|cp866]

Com várias fontes (mesma altura), cada glifo vem da primeira que o tiver:
o padrão do projeto é ter-i14n (IBM-437, cobre o CP437 inteiro) e, para o teste
de cirílico em CP866, ter-k14n + ter-i14n.

Imprime "<altura> <glifos ausentes>" (ex.: "14 0"); term_font_size = 8x<altura>.
Glifo ausente na fonte vira o "?" da própria fonte (ou vazio).
Nada é baixado: a fonte de origem é um pacote do sistema (terminus-font, OFL 1.1).
"""
import argparse
import gzip
import struct
import sys

# 0x00–0x1F e 0x7F na forma gráfica do IBM PC (o codec cp437 do Python os trata
# como controle). Iguais em CP437 e CP866.
BAIXOS = "\u0000☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼"
DEL = "⌂"


def pagina(nome):
    """Lista dos 256 caracteres Unicode da página de código, em ordem."""
    chars = []
    for i in range(256):
        if i < 0x20:
            chars.append(BAIXOS[i])
        elif i == 0x7F:
            chars.append(DEL)
        else:
            chars.append(bytes([i]).decode(nome))
    return chars


def ler_psf(caminho):
    """Devolve (altura, glifos: list[bytes], mapa: dict[str, int])."""
    with open(caminho, "rb") as f:
        dados = f.read()
    if dados[:2] == b"\x1f\x8b":
        dados = gzip.decompress(dados)

    mapa = {}
    if dados[:2] == b"\x36\x04":  # PSF1
        modo, altura = dados[2], dados[3]
        n = 512 if modo & 0x01 else 256
        largura = 8
        inicio = 4
        glifos = [dados[inicio + i * altura: inicio + (i + 1) * altura] for i in range(n)]
        if modo & 0x06:  # tabela Unicode (UCS-2)
            pos = inicio + n * altura
            g = 0
            seq = False
            while g < n and pos + 1 < len(dados):
                (u,) = struct.unpack_from("<H", dados, pos)
                pos += 2
                if u == 0xFFFF:
                    g += 1
                    seq = False
                elif u == 0xFFFE:
                    seq = True
                elif not seq:
                    mapa.setdefault(chr(u), g)
    elif dados[:4] == b"\x72\xb5\x4a\x86":  # PSF2
        _, cab, flags, n, tam, altura, largura = struct.unpack_from("<7I", dados, 4)
        glifos = [dados[cab + i * tam: cab + (i + 1) * tam] for i in range(n)]
        if flags & 0x01:  # tabela Unicode (UTF-8)
            pos = cab + n * tam
            for g in range(n):
                fim = dados.index(b"\xff", pos)
                entrada = dados[pos:fim]
                pos = fim + 1
                simples = entrada.split(b"\xfe")[0]  # sequências combinadas ficam fora
                for c in simples.decode("utf-8", "ignore"):
                    mapa.setdefault(c, g)
    else:
        sys.exit(f"{caminho}: não é PSF1 nem PSF2")

    if largura != 8:
        sys.exit(f"{caminho}: largura {largura}; o Limine só aceita 8")
    return altura, glifos, mapa


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("saida")
    ap.add_argument("fontes", nargs="+")
    ap.add_argument("--pagina", choices=["cp437", "cp866"], default="cp437")
    a = ap.parse_args()

    fontes = [ler_psf(f) for f in a.fontes]
    altura = fontes[0][0]
    if any(f[0] != altura for f in fontes):
        sys.exit("as fontes de origem têm alturas diferentes")
    if not fontes[0][2]:  # sem tabela Unicode: já está na ordem da página
        glifos = fontes[0][1][:256]
    else:
        glifos = None

    def achar(c):
        for _, gl, mapa in fontes:
            if c in mapa:
                return gl[mapa[c]]
        return None

    vazio = bytes(altura)
    reserva = achar("?") or vazio
    saida, ausentes = [], 0
    for i, c in enumerate(pagina(a.pagina)):
        if glifos is not None:
            saida.append(glifos[i])
            continue
        g = achar(c)
        if g is None and i != 0:
            ausentes += 1
        saida.append(g if g is not None else (vazio if i == 0 else reserva))
    with open(a.saida, "wb") as f:
        f.write(b"".join(g[:altura].ljust(altura, b"\0") for g in saida))
    print(altura, ausentes)


if __name__ == "__main__":
    main()
