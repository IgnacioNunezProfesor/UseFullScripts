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

# 2. Instalar una Nerd Font (Meslo LGM NF es la recomendada)
echo -e "${GREEN}Instalando Nerd Font (Meslo LGM NF)...${NC}"
oh-my-posh font install meslo

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