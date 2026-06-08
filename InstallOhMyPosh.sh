#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Iniciando instalación de Oh My Posh...${NC}"

# 1. Descargar e instalar el binario de Oh My Posh
echo -e "${GREEN}Descargando binario...${NC}"
sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
sudo chmod +x /usr/local/bin/oh-my-posh

# 2. Instalar una Nerd Font (MesloLGS NF es la recomendada)
echo -e "${GREEN}Instalando Nerd Font MesloLGS NF...${NC}"
FONT_DIR="$HOME/.local/share/fonts/MesloLGS NF"
mkdir -p "$FONT_DIR"
wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip -O /tmp/meslo.zip
unzip -o /tmp/meslo.zip -d "$FONT_DIR"
fc-cache -f "$FONT_DIR"
rm /tmp/meslo.zip

echo -e "${GREEN}Configurando terminal para usar MesloLGS NF...${NC}"
if command -v gsettings &> /dev/null; then
    PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
    if [ -n "$PROFILE" ]; then
        gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/" font 'MesloLGS NF 12'
        gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/" use-system-font false
    fi
fi

# 3. Crear directorio de temas y descargar temas predeterminados
mkdir -p ~/.poshthemes

# Asegurar que unzip esté instalado
if ! command -v unzip &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y unzip
fi

wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O ~/.poshthemes/themes.zip
unzip -o ~/.poshthemes/themes.zip -d ~/.poshthemes
chmod u+rw ~/.poshthemes/*.json
rm ~/.poshthemes/themes.zip

# 4. Configurar el archivo .bashrc (o .zshrc)
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
fi




echo -e "${GREEN}Configurando $SHELL_RC...${NC}"

# Evitar duplicados si se corre el script varias veces
if ! grep -q "oh-my-posh init" "$SHELL_RC"; then
    echo 'eval "$(oh-my-posh init bash --config ~/.poshthemes/takuya.omp.json)"' >> "$SHELL_RC"
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}Instalación completada con éxito.${NC}"
echo -e "1. Reinicia tu terminal o ejecuta: ${BLUE}source $SHELL_RC${NC}"
echo -e "2. Asegúrate de configurar tu terminal para usar 'MesloLGM Nerd Font'."
echo -e "3. Puedes cambiar el tema editando tu $SHELL_RC"
echo -e "${BLUE}====================================================${NC}"