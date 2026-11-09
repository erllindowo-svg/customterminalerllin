# Terminal Soviético — todos os apps desta máquina, como comandos de instalação.
#
# Uma linha por app:  pN "para que serve e por que está nessa prioridade"  <comando>
# Cada linha é o comando real (dá para copiar da palavra sudo/yay/mise em diante).
# Quem executa: apps/instalar-apps.sh, na ordem deste arquivo. Inventário de 2026-11-08,
# a partir de `pacman -Qqe` (as dependências vêm sozinhas) e dos sinais de uso: janelas
# abertas, fixados na barra e última modificação da pasta de dados de cada app.
#
#   P0  sem isto o sistema ou o Terminal Soviético quebra
#   P1  sem isto o trabalho para
#   P2  necessário para viver no computador
#   P3  subutilizado: nunca abriu ou só serve a uma função ocasional
#   P4  já vem no Omarchy: só garantia (--base)

PAC="sudo pacman -S --needed --noconfirm"
AUR="yay -S --needed --noconfirm"

# ---------------------------------------------------------------- P0: sistema e projeto
p0 "Hyprland: o compositor"                                  $PAC hyprland
p0 "Noctalia: a barra e o control center do projeto"         $PAC noctalia
p0 "foot: os quatro painéis da central"                      $PAC foot
p0 "btop: painel de monitoramento e inspeção (SUPER+M)"      $PAC btop
p0 "jq: lê o JSON do hyprctl em todos os scripts"            $PAC jq
p0 "socat: eventos do Hyprland para a barra sumir na central" $PAC socat
p0 "uwsm: lança os painéis na sessão"                        $PAC uwsm
p0 "util-linux: flock e setsid dos scripts"                  $PAC util-linux
p0 "perl: índice e cores da ilustração"                      $PAC perl
p0 "zsh: exigido pelo arttime"                               $PAC zsh
p0 "git: instalador baixa arttime e omarchy-overview"        $PAC git
p0 "systemd: serviços do usuário"                            $PAC systemd
p0 "libpulse: áudio da barra"                                $PAC libpulse
p0 "wireplumber: saída padrão e volume da barra"             $PAC wireplumber
p0 "playerctl: controle do Spotify na barra"                 $PAC playerctl
p0 "fzf: busca do arttime"                                   $PAC fzf
p0 "lua: atalhos nos tooltips da barra (soviet-atalhos)"     $PAC lua
p0 "Spotify: a barra é o player (erllan/spotify-media)"      $PAC spotify

# ---------------------------------------------------------------- P1: trabalho
p1 "Orca: IDE de agentes, em uso diário no trabalho"         $AUR stably-orca-bin
p1 "Bruno: cliente de API do trabalho"                       $AUR bruno-bin
p1 "Postman: cliente de API do trabalho"                     $AUR postman-bin
p1 "Firefox: navegador principal; os webapps abrem nele"     $PAC firefox
p1 "Cursor: editor"                                          $PAC cursor-bin
p1 "VS Code: editor"                                         $PAC visual-studio-code-bin
p1 "fuse2: roda os AppImages (Orca, osu!, Go Live)"          $PAC fuse2
p1 "Claude Code"                                             mise install claude
p1 "Codex CLI"                                               mise install codex
p1 "OpenCode"                                                mise install opencode
p1 "GitHub CLI: repositórios e PRs"                          mise install gh
p1 "Node.js"                                                 mise install node
p1 "pnpm: gerenciador de pacotes dos projetos"               mise use -g pnpm@latest
p1 "uv: ambientes Python"                                    mise install uv

# ---------------------------------------------------------------- P2: viver no computador
p2 "Obsidian: notas (fixado na barra)"                       $PAC obsidian
p2 "Chromium: navegador secundário (fixado na barra)"        $PAC chromium
p2 "Nautilus: arquivos (fixado na barra)"                    $PAC nautilus
p2 "Voxtype: ditado por voz (SUPER+CTRL+X)"                  $PAC voxtype-bin
p2 "Steam: jogos; o botão de jogo da barra abre o Deadlock"  $PAC steam
p2 "osu!: jogo (fixado na barra)"                            $AUR osu-lazer-bin
p2 "osu-mime: abre mapas do osu!"                            $AUR osu-mime
p2 "Webapps no Firefox (WhatsApp, HEY, Zoom, YouTube, X...)" apps/webapps.sh

# ---------------------------------------------------------------- P3: subutilizados
p3 "Kdenlive: vídeo; nunca aberto nesta máquina"             $PAC kdenlive
p3 "OBS: gravação; nunca aberto nesta máquina"               $PAC obs-studio
p3 "Xournal++: anotação em PDF; sem uso recente"             $PAC xournalpp
p3 "Bitwarden: senhas; nunca aberto nesta máquina"           $PAC bitwarden
p3 "lazydocker: TUI do Docker; nunca aberto"                 $PAC lazydocker
p3 "cava: visualizador de áudio; nunca aberto"               $PAC cava
p3 "cloudflared: túneis pontuais"                            $PAC cloudflared
p3 "smartmontools: saúde dos discos, sob demanda"            $PAC smartmontools
p3 "ShellCheck: testes deste repositório"                    $PAC shellcheck
p3 "QEMU: testes do tema de boot em VM"                      $PAC qemu-base
p3 "edk2-ovmf: firmware UEFI da VM de testes"                $PAC edk2-ovmf
p3 "numpy: gera o papel de parede do tema de boot"           $PAC python-numpy
p3 "Pillow: gera o papel de parede do tema de boot"          $PAC python-pillow
p3 "Terminus: fonte do menu do tema de boot"                 $PAC terminus-font
p3 "clang: compilador; nada do dia a dia depende"            $PAC clang
p3 "LLVM: compilador; nada do dia a dia depende"             $PAC llvm
manual "Deadlock (botão de jogo da barra): entre na Steam e rode  steam steam://install/1422450"
manual "Go Live (compartilhar tela): AppImage sem download público; copie ~/Applications/Go-Live.AppImage e ~/.local/share/applications/golive.desktop do outro PC"

# ---------------------------------------------------------------- P4: já vem no Omarchy
p4 "Base do Omarchy" $PAC \
  aether alsa-utils asdcontrol base base-devel bash-completion bat bluez bluez-tools \
  bluez-utils bolt brightnessctl btrfs-progs cliamp cups cups-filters cups-pk-helper ddcutil \
  disktree-bin docker docker-buildx docker-compose dosfstools dotnet-runtime efibootmgr evince \
  exfatprogs expac eza fcitx5 fcitx5-chewing fcitx5-chinese-addons fcitx5-gtk fcitx5-hangul \
  fcitx5-mozc fcitx5-qt fd ffmpegthumbnailer gliff gnome-disk-utility gnome-keyring \
  gnome-themes-extra gpu-screen-recorder grim gst-plugin-pipewire gvfs-mtp gvfs-nfs gvfs-smb \
  herdr hype hyprland-guiutils hyprland-preview-share-picker hyprpicker hyprsunset imagemagick \
  imv inetutils inotify-tools inxi kernel-modules-hook lazygit less libreoffice-fresh libvips \
  libyaml limine localsend lua51 luarocks man-db mariadb-libs mise-bin mkinitcpio monologue \
  moonlight-qt mpv mpv-mpris nautilus-python networkmanager noto-fonts noto-fonts-cjk \
  noto-fonts-emoji nss-mdns omacalc omacut omarchy omarchy-hyprland-titlebars omarchy-keyring \
  omarchy-nvim omarchy-power-profiles-daemon omarchy-settings omasnap omawrite owe \
  owe-lockfeed pacman-contrib pamixer pinta pipewire pipewire-alsa pipewire-jack \
  pipewire-pulse plocate postgresql-libs python-gobject python-poetry-core \
  qemu-user-static-binfmt qrencode qt6-imageformats quickshell ripgrep ruby sddm signed slurp \
  starship sudo sushi system-config-printer tesseract tesseract-data-eng tldr tmux tobi-try \
  tree-sitter-cli ttf-ia-writer ttf-jetbrains-mono-nerd-basic ttfx tzupdate udiskie ufw \
  ufw-docker usage vi whois wireless-regdb wl-clipboard woff2-font-awesome wtype \
  xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-terminal-exec xorg-xsetroot \
  yaru-icon-theme yay yt-dlp zbar zoxide zram-generator

# Fora da lista de propósito: o instalador do Omarchy escolhe conforme o hardware.
# Nesta máquina: amd-ucode linux-firmware linux-omarchy linux-omarchy-headers
#                nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver
HARDWARE="amd-ucode linux-firmware linux-omarchy linux-omarchy-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver"
