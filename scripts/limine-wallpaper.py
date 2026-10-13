#!/usr/bin/env python3
"""Terminal Soviético — papel de parede do menu do Limine (tela CRT).

Dois modos:
  * a partir da arte do fallout-grub-theme (baixada pelo instalador, por commit
    fixo e SHA-256; nunca versionada): remove o Vault Boy e o texto "ROBCO
    INDUSTRIES…" e deixa só o fundo CRT (linhas de varredura + moldura);
  * --gerar-do-zero: desenha varredura, vinheta e moldura arredondada sem usar
    arte nenhuma de terceiros.
Depois recolore para a variante (fosforo, ambar, fallout = cores originais),
escreve o título opcional com a própria fonte do boot e ajusta à resolução.

Remoção: as linhas de varredura são iguais em todas as colunas (desvio médio
de 0,28 da mediana da linha, medido na imagem 1920×1080). Dentro das caixas do
personagem (x 1380–1880, y 515–1045) e do texto (x 560–1310, y 35–140), os
pixels que diferem da mediana da linha são trocados por ela; a máscara é
dilatada em 4 px. A mediana vem de uma faixa limpa em todas as linhas
(x 100–560 e 1300–1380: a faixa x 300–1100 cruza o texto). A moldura fica fora
das caixas e não é tocada.

Uso:
  limine-wallpaper.py <saída.png> [--origem arte.png | --gerar-do-zero]
                      [--variante fosforo|ambar|fallout] [--resolucao 1920x1080]
                      [--titulo "TERMINAL SOVIETICO" --fonte fonte.f14 [--pagina cp866]]
Requer Pillow e numpy.
"""
import argparse
import sys

import numpy as np
from PIL import Image

BASE_W, BASE_H = 1920, 1080
FAIXA_LIMPA = [(100, 560), (1300, 1380)]
CAIXAS = [(1380, 515, 1880, 1045),   # Vault Boy (x0, y0, x1, y1)
          (560, 35, 1310, 140)]      # ROBCO INDUSTRIES… / -Display 1-
LIMIAR = 10      # diferença (0–255, por canal) que conta como "não é fundo"
DILATA = 4

# Variantes: (cor zero = moldura/preto, cor cheia). A intensidade sai do canal
# verde da tela original: o verde "cheio" do Fallout (G≈222) vira a cor cheia.
VARIANTES = {
    "fosforo": ("080908", "B8D58A"),
    "ambar": ("080908", "C9B26B"),
    "fallout": None,   # cores originais
}
G_CHEIO = 222.0
FALLOUT_VERDE = "16DE6D"   # term_palette_bright do upstream (verde)


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def remover_arte(img):
    a = np.asarray(img.convert("RGB")).astype(float)
    if a.shape[:2] != (BASE_H, BASE_W):
        sys.exit(f"arte com {a.shape[1]}x{a.shape[0]}; o recorte foi medido em {BASE_W}x{BASE_H}")
    ref = np.concatenate([a[:, x0:x1, :] for x0, x1 in FAIXA_LIMPA], axis=1)
    med = np.median(ref, axis=1)                       # H × 3
    mascara = np.zeros((BASE_H, BASE_W), dtype=bool)
    for x0, y0, x1, y1 in CAIXAS:
        dif = np.abs(a[y0:y1, x0:x1, :] - med[y0:y1, None, :]).max(axis=2)
        mascara[y0:y1, x0:x1] = dif > LIMIAR
    # Dilatação quadrada de DILATA px (sem scipy): deslocamentos acumulados.
    d = mascara.copy()
    for dy in range(-DILATA, DILATA + 1):
        for dx in range(-DILATA, DILATA + 1):
            d |= np.roll(np.roll(mascara, dy, axis=0), dx, axis=1)
    # A dilatação não sai das caixas (a moldura fica intacta).
    dentro = np.zeros_like(d)
    for x0, y0, x1, y1 in CAIXAS:
        dentro[y0:y1, x0:x1] = True
    d &= dentro
    ys, _ = np.nonzero(d)
    a[d] = med[ys]
    return a, int(d.sum())


def gerar_do_zero(w=BASE_W, h=BASE_H):
    """Fundo CRT sintético no mesmo espaço de cor da arte original (verde)."""
    y = np.arange(h, dtype=float)[:, None]
    x = np.arange(w, dtype=float)[None, :]
    # Varredura: período de 7,5 px, de G≈10 a G≈68, como a original.
    varre = 39 + 29 * np.cos(2 * np.pi * y / 7.5)
    # Vinheta suave (bordas ~25 % mais escuras).
    nx, ny = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    vinheta = 1 - 0.25 * np.clip(nx ** 2 * 0.6 + ny ** 2 * 0.8, 0, 1)
    g = varre * vinheta
    # Moldura: retângulo arredondado (margem 20 px, raio 42 px, borda de 3 px).
    m, r = 20.0, 42.0
    cx = np.clip(x, m + r, w - m - r)
    cy = np.clip(y, m + r, h - m - r)
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - r     # >0 fora
    g = g * np.clip(1 - dist / 3.0, 0, 1)
    verde = hexrgb(FALLOUT_VERDE) / G_CHEIO
    return np.clip(g[:, :, None] * verde[None, None, :], 0, 255)


def recolorir(a, variante):
    if VARIANTES[variante] is None:
        return a
    zero, cheia = (hexrgb(c) for c in VARIANTES[variante])
    t = np.clip(a[:, :, 1] / G_CHEIO, 0, 1)[:, :, None]
    return zero + (cheia - zero) * t


def ler_fonte(caminho):
    dados = open(caminho, "rb").read()
    if len(dados) % 256:
        sys.exit(f"{caminho}: tamanho {len(dados)} não é 256 glifos")
    return dados, len(dados) // 256


def escrever_titulo(a, texto, fonte, cor, escala, pagina="cp437"):
    dados, alt = ler_fonte(fonte)
    texto = texto.encode(pagina, "replace")
    larg = 9 * escala          # 8 px + 1 de espaço, como o term_font_spacing padrão
    x0 = (a.shape[1] - larg * len(texto)) // 2
    y0 = int(a.shape[0] * 0.045)
    cor = hexrgb(cor)
    for i, ch in enumerate(texto):
        g = dados[ch * alt:(ch + 1) * alt]
        for linha, byte in enumerate(g):
            for col in range(8):
                if byte & (0x80 >> col):
                    y, x = y0 + linha * escala, x0 + i * larg + col * escala
                    a[y:y + escala, x:x + escala, :] = cor
    return a


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("saida")
    ap.add_argument("--origem", help="PNG 1920×1080 do fallout-grub-theme (conferido pelo instalador)")
    ap.add_argument("--gerar-do-zero", action="store_true")
    ap.add_argument("--variante", choices=list(VARIANTES), default="fosforo")
    ap.add_argument("--resolucao", default="1920x1080")
    ap.add_argument("--titulo", default="")
    ap.add_argument("--fonte", help="fonte crua (para o título)")
    ap.add_argument("--pagina", choices=["cp437", "cp866"], default="cp437",
                    help="página de código da --fonte (cp866 para título em cirílico)")
    a = ap.parse_args()

    try:
        w, h = (int(v) for v in a.resolucao.lower().split("x"))
    except ValueError:
        sys.exit(f"resolução inválida: {a.resolucao} (use LxA, ex. 1920x1080)")
    if bool(a.origem) == a.gerar_do_zero:
        sys.exit("use --origem <arte.png> ou --gerar-do-zero")
    if a.titulo and not a.fonte:
        sys.exit("--titulo precisa de --fonte (a fonte do boot)")

    if a.gerar_do_zero:
        img = gerar_do_zero()
        trocados = 0
    else:
        img, trocados = remover_arte(Image.open(a.origem))
    img = recolorir(img, a.variante)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    if (w, h) != (BASE_W, BASE_H):
        out = out.resize((w, h), Image.LANCZOS)
    if a.titulo:
        cor = VARIANTES[a.variante][1] if VARIANTES[a.variante] else FALLOUT_VERDE
        arr = escrever_titulo(np.asarray(out).astype(float).copy(), a.titulo, a.fonte, cor,
                              max(1, round(h / 360)), a.pagina)
        out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    out.save(a.saida, optimize=True)
    print(f"{a.saida} {w}x{h} variante={a.variante} pixels_trocados={trocados}")


if __name__ == "__main__":
    main()
