# erllan/volume-slider — popup de volume (Terminal Soviético)

Popup compacto com **um único slider horizontal** de volume de saída. É aberto
pelo clique no widget nativo `volume` da barra (`20-barra.toml`:
`left = "panel-toggle erllan/volume-slider:panel"`). Fecha com novo clique,
clique fora ou Esc.

- Escrita: `wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ N%` (PipeWire/WirePlumber,
  limite de 100 % como o Noctalia).
- Leitura: `wpctl get-volume` ao abrir e a cada evento de sink. `watch-sink.sh`
  roda `pactl subscribe` até a primeira mudança e sai; o painel o rearma só
  enquanto está aberto. Com o popup fechado, nada roda.
- Mudo: slider atenuado.
- Sem daemon e sem segundo gerenciador de áudio.

Arquivos: `plugin.toml`, `panel.luau`, `watch-sink.sh`. API de plugin 24 (Noctalia 5.0.1).
