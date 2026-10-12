# Noctalia — Terminal Soviético

Configuração em arquivos, mesclados em ordem alfabética:

| Arquivo | Conteúdo |
|---|---|
| `00-coexistencia-omarchy.toml` | desliga no Noctalia o que o shell Omarchy já faz (notificações, OSD, papel de parede, lock, clipboard, polkit, templates de tema, plugins automáticos) |
| `10-tema-sovietico.toml` + `palettes/SovietTerminal.json` | paleta fósforo/oliva/âmbar/vermelho (valores do tema Omarchy soviet-terminal), JetBrainsMono Nerd Font, cantos retos, sem sombras |
| `20-barra.toml` (modelo `.in`) | barra `estacao` (topo, 26 px) e widgets |
| `30-monitoramento-clima.toml` (modelo `.in`) | limiares e polling do sysmon; endereço do clima de `WEATHER_ADDRESS`, métrico |
| `40-integracao-hyprland.toml` | hook `started` → `soviet-bar-sync --apply` |

Ajustes feitos pela GUI vão para `~/.local/state/noctalia/settings.toml` e
**vencem** estes arquivos. Apague esse arquivo para voltar ao que está aqui.

Validação: `noctalia config validate`. Serviço: `systemctl --user status noctalia`.
Documentação completa: repositório do projeto (README.md e docs/). Estes arquivos são
gerados/copiados por `install.sh`: edite no repositório, não aqui.

## Plugins locais (`~/.local/share/noctalia/plugins/`, habilitados em `00-*.toml`)

| Plugin | Função |
|---|---|
| `erllan/volume-slider` | popup só com o slider de volume (clique no ícone de volume) |
| `erllan/spotify-media` | Spotify na barra: capa, artista/título rolando, ⏮ ⏯ ⏭, foca/abre o Spotify. Fork local de `azokyen/spotify-media` |
| `erllan/tarefas` | favoritos (lista `PINNED` em `bar.luau`) + apps em execução fora do WS 1, ícones reais, traço = em execução/focado; atualiza por eventos do socket2 do Hyprland (Fase 1) |

Cada um tem um README no próprio diretório.
