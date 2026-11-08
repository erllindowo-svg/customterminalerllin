# Desempenho

Medições de 2026-10-12, na mesma sessão (Ryzen 5 1600, 12 threads, 16 GB,
um monitor). Dados brutos em `docs/perf-data/2026-10-12-fase2/` (e a linha de
base em `~/terminal-sovietico-backups/fase1-20261012-164725/BASELINE-recursos.txt`).

## Metodologia

* `scripts/perf-sample.sh N`: lê `/proc/<pid>/stat` (utime+stime) e `VmRSS` a
  cada 1 s. Mostra CPU média e pico (pior segundo) em **% de um núcleo**, RSS
  médio/máximo, CPU total do sistema (`/proc/stat`, todos os núcleos) e
  processos criados por segundo. O amostrador cria ~2 processos/s.
* `scripts/perf-run.sh`: cenários repetíveis. Atribuição por pausa
  (`SIGSTOP`/`SIGCONT`) de um processo durante a janela de medição.
* A Fase 1 usou um script equivalente com uma única janela de 60 s (só
  médias, sem picos).
* **Limites**: o uso interativo da máquina (Firefox, terminal com tmux,
  Claude Code) acontecia em paralelo e varia entre amostras. A linha de base
  foi tirada com o workspace 3 ativo (Firefox), e as medições da Fase 2 com o
  workspace 2. Diferenças pequenas entre amostras isoladas **não** são
  conclusivas.

## Linha de base × depois

CPU em % de um núcleo; RSS em MB. "Fase 2" = média das 3 amostras de 60 s de P1.

| Processo | Linha de base (antes da Fase 1) | Após a Fase 1 | Fase 2 (P1, 3×60 s) | Pico (1 s) na Fase 2 |
|---|---|---|---|---|
| Hyprland | 8,08 % · 246 | 7,18 % · 268 | 2,49 % (2,05–2,85) · 250 | 12 % |
| btop da central | 3,65 % · 32 | 3,97 % · 32 | 3,60 % (3,38–3,80) · 33 | 10 % |
| noctalia | 2,85 % · 206 | 2,20 % · 209 | 1,99 % (1,97–2,03) · 210 | 4 % |
| quickshell (shell do Omarchy) | 0,07 % · 399 | 0,05 % · 403 | ≈0,01 % · **496** | 1 % |
| soviet-ops-clock | 0,17 % · 4 | 0,15 % · 4 | 0,17 % · 4 | 2 % |
| foot (4 painéis) | ~0,3 % · 88 | ~0,1 % · 89 | ~0,1 % · 89 | 1 % |
| soviet-bar-sync + socat | ~0 · 9 | ~0 · 9 | ~0 · 9 | 0 |
| socat do plugin tarefas | — (consultava a cada 1 s) | ~0 · 5 | ~0 · 5 | 0 |
| **CPU total do sistema** | **11,43 %** | 10,48 % | **5,67 %** (5,20–6,07) | — |

Leitura:

* **Noctalia caiu de 2,85 % para ~2,0 %**, com variação pequena entre
  amostras. Coincide com a troca do plugin `tarefas`, que consultava
  `hyprctl clients` a cada 1 s e passou a reagir a eventos. A queda do
  **Hyprland** (8 % → 2,5 %) também é compatível com isso (cada `hyprctl` acorda
  o compositor), mas o workspace ativo e o uso do Firefox mudaram entre as
  medições. **A atribuição não é conclusiva.**
* **quickshell 399 → 496 MB** ao longo de ~1h30 de sessão. É o shell do Omarchy
  (o projeto só troca a barra dele por um plugin nulo). Não foi investigado se é
  crescimento normal de cache ou vazamento; recomenda-se acompanhar (abaixo).

## O que roda o tempo todo × sob demanda

| Permanente | Custo medido |
|---|---|
| noctalia (barra, sysmon a cada 2–5 s, clima a cada 30 min) | ~2 % CPU, 210 MB (medido com o sysmon ligado; desde 2026-10-13 ele está desligado, sem nova medição) |
| btop da central (`update_ms = 1000`) | ~3,6 % CPU, 33 MB — **maior consumidor do projeto** |
| soviet-ops-clock (laço de 1 s) | 0,17 % CPU, mas **cria processos a cada segundo** |
| soviet-ops-fetch (fastfetch a cada 30 min; arte só em SIGWINCH/SIGUSR1) | ~0 |
| soviet-bar-sync + 2 socat (eventos) | ~0 |
| 4 foot da central | ~0,1 % juntos, 89 MB |

Sob demanda (nada fica rodando depois de fechar, verificado nos testes):
`soviet-inspect` (btop flutuante), `soviet-arte` (menu/arttime),
`soviet-arte render` (só ao abrir o painel, redimensionar ou trocar arte/cores).

## Cenários específicos

| Cenário | Resultado | Fonte |
|---|---|---|
| Atribuição do btop da central (pausado 60 s × normal 60 s, central fora da tela) | btop 0 % → 3,88 %; Hyprland 2,88 % × 2,95 % (sem diferença: fora da tela o foot não pede quadros); total 5,17 % × 5,30 % | `atribuicao/P2*` |
| Atribuição do relógio (pausado 30 s × normal 30 s) | processos criados: 18,9/s × 31,5/s → o relógio cria **~10 processos/s** (`date`, `tput`, `jq`, `sed` a cada segundo). Indicativo: o protetor de tela do Omarchy entrou durante a amostra pausada | `atribuicao/P3*` |
| arttime interativo (pty, sem janela, 60 s) | zsh do arttime: 0,12 % CPU, 6,5 MB RSS; 0 processos após sair | `P4-interativo-pty.txt` |
| Troca de modos de cores | 10 trocas: 233 ms no total (~23 ms cada) + 20 ms de CPU de redesenho no painel; render 89×25: 30 ms (tema), 39 ms (originais); índice das 516 artes: 118 ms (só quando a coleção muda) | `P5-cores.txt` |
| Inicialização (journal) | `noctalia` e `soviet-bar-sync` ativos 14:36:40; central composta 14:36:41 (~1 s depois) | `P6-P7-*.txt` |
| Estabilidade (~1h50 de sessão) | 0 reinícios dos serviços; 0 avisos/erros do noctalia na última hora (antes da Fase 1: aviso `tooltip` várias vezes por segundo); o noctalia ainda registra ~5 000 linhas/h no nível informativo | `P6-P7-*.txt` |

### Não medidos (decisão do usuário: não era preciso medir tudo)

* Central **visível** em repouso (workspace 1 em tela).
* Abertura/fechamento do btop flutuante (tempo até a janela e consumo aberto).
  Funcionalmente, abrir/fechar sem duplicar e sem órfãos foi verificado na Fase 1.
* arttime interativo **em janela** (custo do foot e do compositor). Só foi
  medido em pty.
* Tempo de inicialização completo de um login novo (só os registros do journal).

Os comandos estão prontos: `scripts/perf-run.sh <dir> --only-disruptive`.

### Incidente durante a medição

Na primeira execução, P2/P3 escolheram o processo pelo `pgrep -f`, e a linha
de comando do **foot** contém a do programa que ele executa. O foot foi pausado
no lugar do btop e do relógio, e o Hyprland mostrou "Application Not
Responding" até o `SIGCONT`. Esses dados foram descartados.
`scripts/perf-run.sh` agora escolhe pelo nome do executável e aborta se o PID
for um `foot`; o mesmo erro de contagem foi corrigido em `tests/live.sh`.

## Recomendações (por impacto/custo)

| # | Ação | Impacto | Custo |
|---|---|---|---|
| 1 | btop da central com `update_ms = 2000` (ou 3000) em `btop/soviet-ops.conf` | ~−1,8 % de um núcleo (metade do maior consumidor) | trivial; os gráficos ficam menos detalhados |
| 2 | `soviet-ops-clock`: atualizar a cada minuto, ou o clima só quando `weather.json` mudar, e trocar `date`/`tput`/`jq` por `printf '%(…)T'` e leitura do clima a cada 60 s | −~10 processos/s; CPU desprezível | baixo |
| 3 | Acompanhar o RSS do quickshell (Omarchy) por algumas horas/dias; se crescer sem limite, reportar ao Omarchy | evita surpresa de memória | baixo |
| 4 | Reduzir o log informativo do noctalia (~5 000 linhas/h no journal) | I/O e journal menores | baixo; ver opções de log do Noctalia |
| 5 | Medir os cenários não realizados (`--only-disruptive`) antes de declarar uma versão estável | completa os dados | 5 min, mexe na tela |

Nenhuma dessas mudanças foi aplicada nesta fase.
