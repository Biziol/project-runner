#!/bin/bash

# --- 1. FUNZIONE CONTROLLO DIPENDENZE (Copiata dallo script principale) ---
check_dependencies() {
    local MISSING_DEPS=()
    command -v jq >/dev/null 2>&1 || MISSING_DEPS+=("jq")
    command -v tmux >/dev/null 2>&1 || MISSING_DEPS+=("tmux")

    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo "Installazione dipendenze necessarie: ${MISSING_DEPS[*]}..."
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y "${MISSING_DEPS[@]}"
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}"
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm "${MISSING_DEPS[@]}"
        else
            echo "Package manager non riconosciuto. Installa manualmente: ${MISSING_DEPS[*]}"
            exit 1
        fi
    fi
}

# --- 2. LOGICA DI INSTALLAZIONE DELLO SCRIPT ---
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="pjrunner"
REPO_URL="https://raw.githubusercontent.com/Biziol/project-runner/main/pjrunner.sh"

echo "Avvio installazione di $SCRIPT_NAME..."

# Esegui il controllo dipendenze prima di installare lo script
check_dependencies

# Scarica lo script
sudo curl -fsSL "$REPO_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Configura il PATH se necessario
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Esporto il PATH nel .bashrc..."
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bashrc"
fi

echo "Installazione riuscita!"