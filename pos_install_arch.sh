#!/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}>>> INICIANDO CONFIGURAÇÃO COMPLETA...${NC}"

if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}ERRO: Não rode como root. O script pedirá senha quando necessário.${NC}"
  exit 1
fi

echo -e "${BLUE}>>> Solicitando senha sudo...${NC}"
sudo -v

# ----------------------------------------------------------------------
# 1. Otimização do Pacman
# ----------------------------------------------------------------------
echo -e "${GREEN}>>> Configurando Pacman (Multilib e Downloads)...${NC}"
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sudo pacman -Syyu --noconfirm

# ----------------------------------------------------------------------
# 2. Rede de Segurança (Snapshots)
# ----------------------------------------------------------------------
echo -e "${GREEN}>>> Configurando Snapper (Backup Automático)...${NC}"
sudo pacman -S --noconfirm snapper snap-pac grub-btrfs
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

# ----------------------------------------------------------------------
# 3. Instalação de Pacotes
# ----------------------------------------------------------------------
echo -e "${GREEN}>>> Instalando Pacotes...${NC}"

PKGS=(
    # --- Base e Ferramentas ---
    base-devel git wget neofetch htop
    python python-pip python-pynvim
    hwinfo expac # Necessários para seus aliases 'hw' e 'big'
    
    # --- Compactadores ---
    7zip unrar zip unzip lz4 bzip2 gzip zstd
    
    # --- Terminal Moderno ---
    kitty
    eza   # Substituto do EXA
    bat
    neovim
    
    # --- Interface KDE ---
    kvantum
    
    # --- Produção ---
    obs-studio kdenlive vlc easyeffects gimp
    
    # --- Jogos e Wine ---
    steam gamemode mangohud goverlay gamescope
    lutris wine wine-gecko wine-mono winetricks
    
    # --- Navegador e Rede ---
    firefox uget
    bluez bluez-utils bluez-deprecated-tools
    
    # --- Docker ---
    docker docker-compose
)

sudo pacman -S --noconfirm "${PKGS[@]}"

# ----------------------------------------------------------------------
# 4. AUR (Compilação Manual)
# ----------------------------------------------------------------------
echo -e "${GREEN}>>> Compilando pacotes do AUR...${NC}"

install_aur() {
    PACKAGE=$1
    if pacman -Qi $PACKAGE &> /dev/null; then
        echo -e "${BLUE} -> $PACKAGE já instalado.${NC}"
    else
        echo -e "${BLUE} -> Compilando $PACKAGE...${NC}"
        cd /tmp
        rm -rf "$PACKAGE"
        git clone "https://aur.archlinux.org/$PACKAGE.git"
        cd "$PACKAGE"
        makepkg -si --noconfirm
        cd ~
    fi
}

install_aur "anydesk-bin"

# ----------------------------------------------------------------------
# 5. Configuração do ZSH + Seus Aliases
# ----------------------------------------------------------------------
echo -e "${GREEN}>>> Configurando ZSH + Aliases...${NC}"

sudo pacman -S --noconfirm zsh

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Plugins e Powerlevel10k
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k 2>/dev/null
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions 2>/dev/null
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting 2>/dev/null
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM}/plugins/zsh-history-substring-search 2>/dev/null

# Criando .zshrc COM SEUS ALIASES
cat <<EOF > ~/.zshrc
# Powerlevel10k Instant Prompt
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git archlinux docker zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search command-not-found)

source \$ZSH/oh-my-zsh.sh

# --- SEUS ALIASES PERSONALIZADOS ---
# (Adaptados para Zsh e Eza)

alias ls='eza -al --color=always --group-directories-first --icons'
alias la='eza -a --color=always --group-directories-first --icons'
alias ll='eza -l --color=always --group-directories-first --icons'
alias lt='eza -aT --color=always --group-directories-first --icons'
alias l.="eza -a | grep -e '^\.'"

alias jctl="journalctl -p 3 -xb"
alias cleanup='sudo pacman -Rns \$(pacman -Qtdq)' # Corrigido para Zsh syntax
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '

# Navegação
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Cores e Info
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias hw='hwinfo --short'
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias update='sudo pacman -Syu'

# Carregar config P10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

chsh -s $(which zsh)

# ----------------------------------------------------------------------
# 6. Finalização
# ----------------------------------------------------------------------
echo -e "${GREEN}>>> Ativando Serviços...${NC}"
sudo systemctl enable --now docker
sudo systemctl enable --now bluetooth
sudo systemctl enable --now anydesk
sudo usermod -aG docker $USER

echo -e "${GREEN}>>> INSTALAÇÃO FINALIZADA! REINICIE O SISTEMA.${NC}"
