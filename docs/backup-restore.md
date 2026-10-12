# Backup e restauração

Há três camadas, da mais pontual para a mais ampla. Nenhuma delas fica no
repositório (`.gitignore`).

## 1. Backups automáticos do instalador

`~/.local/state/terminal-soviet/install/`

| Arquivo | Conteúdo |
|---|---|
| `manifest.tsv` | cada item instalado: tipo, destino, SHA-256 (ou alvo do link) e backup do original |
| `backups/<data>/…` | **originais** que existiam antes da instalação (restaurados ao desinstalar) e cópias de arquivos do projeto editados localmente, sobrescritos com `--force` (só para consulta) |
| `shelljson.prev` | `bar.id` e `bar.position` anteriores |

```bash
./install.sh status                 # o que está instalado e o que diverge
./install.sh uninstall --dry-run    # o que seria removido/restaurado
./install.sh uninstall              # remove, restaura originais, reverte shell.json e o bloco do hyprland.lua
./install.sh uninstall --purge      # também apaga o estado da ilustração (seleção, modo de cores, índice)
```

A desinstalação:

* remove os arquivos instalados que estão **intactos**. Os editados depois são
  mantidos com aviso; `--force` remove/restaura também esses;
* restaura os originais que existiam antes;
* remove do `hyprland.lua` **só** o bloco marcado (e a linha em branco que a
  instalação inseriu), preservando edições posteriores;
* devolve `bar.id`/`bar.position` aos valores anteriores (`omarchy bar`);
* para `noctalia`/`soviet-bar-sync`, remove os links de habilitação e
  recarrega o Hyprland;
* **não** remove o arttime nem o omarchy-overview (são instalações próprias):
  ```bash
  rm -rf ~/.local/src/arttime ~/.local/share/arttime ~/.local/bin/{arttime,artprint} \
         ~/.local/share/man/man1/{arttime,artprint}.1.gz ~/.local/state/arttime
  omarchy plugin remove moorgrove.overview
  ```

Testado em HOME isolado (`tests/sandbox.sh`): depois de instalar e
desinstalar, o HOME volta **exatamente** ao estado anterior (conteúdo,
permissões, links e `shell.json`).

## 2. Backup da Fase 1 (estado anterior ao arttime)

`~/terminal-sovietico-backups/fase1-20261012-164725/`. Feito antes da Fase 1,
com `SHA256SUMS`, `SYMLINKS.txt`, `MANIFEST.txt` e `restore.sh` testado.

```bash
cd ~/terminal-sovietico-backups/fase1-20261012-164725
./restore.sh --verify     # confere checksums e links (não altera nada)
./restore.sh --dry-run    # lista o que seria restaurado/removido
./restore.sh              # volta ao estado anterior à Fase 1
```

Fora dele: as imagens do tema (`backgrounds/`, inalteradas). A linha de base de
desempenho (`BASELINE-recursos.txt`) também está ali.

## 3. Backups anteriores (Fase 0, implantação do Noctalia)

`~/.local/share/terminal-soviet/backups/20261012-003259/` (antes do Noctalia)
e `…/20261012-013033/` (antes da revisão 2), com `MANIFEST.txt` e `SHA256SUMS`.
O procedimento está no README dessa pasta (`~/.local/share/terminal-soviet/README.md`).

## Recomendações

* Antes de `./install.sh --force`, rode `./install.sh --dry-run` e compare os
  conflitos (`diff ~/<destino> <repo>/<origem>`).
* Os backups das fases 0 e 1 são operacionais e locais. Não os apague antes de
  validar o projeto numa instalação nova, e não os coloque no repositório.
