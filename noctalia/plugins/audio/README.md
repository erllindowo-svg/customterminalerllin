# erllan/audio — áudio da barra (Terminal Soviético)

Substitui o widget nativo `volume` e o antigo `erllan/volume-slider`.

* **Ícone**: fone (`headphones`) ou alto-falante (`device-speaker`) conforme a
  saída padrão, com o volume ao lado. No mudo, o glifo fica riscado e vermelho.
* **Gestos**: esquerdo = popup · **direito = alterna fone ↔ alto-falante** ·
  meio = mudo · rolagem = ±5 %.
* **Popup**: botão de mudo, slider (limite de 100 %) e a lista de saídas
  (sinks do PipeWire) com nome legível. Clicar numa saída a torna padrão
  (`wpctl set-default`) e move os fluxos que estão tocando
  (`pactl move-sink-input`, em `trocar-saida.sh`).
* **Tipo da saída**: porta ativa Headphones/Headset, `device.form_factor`
  headphone/headset ou Bluetooth = fone; o resto (HDMI, linha, alto-falante) =
  alto-falante.
* **Sem daemon**: um único `pactl subscribe` (service `fonte`, filho do
  Noctalia) dispara a releitura só em eventos de sink, card e servidor.
* Linha de comando: `noctalia msg plugin erllan/audio:fonte all <alternar|mudo|mais|menos|saida <nome>|volume <n>>`.

Arquivos: `plugin.toml`, `fonte.luau`, `bar.luau.in`, `painel.luau`,
`trocar-saida.sh`. API de plugin 24 (Noctalia 5.0.1).
