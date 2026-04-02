#!/bin/bash

CONFIG_FILE="$HOME/.run_config.json"

# --- FUNZIONE: CONTROLLO DIPENDENZE UNIVERSALE ---
check_dependencies() {
    local MISSING_DEPS=()
    
    # Verifica jq
    if ! command -v jq >/dev/null 2>&1; then
        MISSING_DEPS+=("jq")
    fi
    
    # Verifica tmux
    if ! command -v tmux >/dev/null 2>&1; then
        MISSING_DEPS+=("tmux")
    fi

    # Se ci sono dipendenze mancanti
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo "Attenzione: Le seguenti dipendenze sono mancanti: ${MISSING_DEPS[*]}"
        read -p "Vuoi installarle ora? (y/n): " INSTALL_CONFIRM
        
        if [[ "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
            echo "Rilevamento del sistema in corso..."
            
            # Identifica il package manager
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "${MISSING_DEPS[@]}"
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}"
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm "${MISSING_DEPS[@]}"
            elif command -v zypper >/dev/null 2>&1; then
                sudo zypper install -y "${MISSING_DEPS[@]}"
            else
                echo "Errore: Non è stato possibile trovare un package manager noto (apt, dnf, pacman, zypper)."
                echo "Per favore, installa manualmente: ${MISSING_DEPS[*]}"
                exit 1
            fi
            
            # Verifica finale post-installazione
            if [ $? -ne 0 ]; then
                echo "Errore durante l'installazione. Esco."
                exit 1
            fi
        else
            echo "Errore: Lo script richiede ${MISSING_DEPS[*]} per funzionare. Esco."
            exit 1
        fi
    fi
}

# Eseguiamo il controllo prima di ogni altra cosa
check_dependencies

# Inizializza il file JSON se non esiste
if [ ! -f "$CONFIG_FILE" ]; then
    echo "{}" > "$CONFIG_FILE"
fi

# --- FUNZIONE: AGGIUNGI PROGETTO ---
add_project() {
    read -p "ID Progetto (es: roadmap): " ID
    
    local AZIONI="[]"
    local CONTINUA="y"

    while [[ "$CONTINUA" =~ ^[Yy]$ ]]; do
        read -p "Titolo azione (es: backend): " TITOLO
        read -p "Comando da eseguire: " COMANDO
        read -p "In una nuova tab tmux? (y/n): " SEPARATO
        
        local IS_SEP=false
        [[ "$SEPARATO" == "y" ]] && IS_SEP=true

        # Costruisce l'oggetto azione in modo sicuro con jq
        AZIONI=$(jq -n \
            --arg t "$TITOLO" \
            --arg c "$COMANDO" \
            --argjson s "$IS_SEP" \
            "$AZIONI + [{\"titolo\": \$t, \"comando\": \$c, \"separato\": \$s}]")

        read -p "Aggiungere un'altra azione? (y/n): " CONTINUA
    done

    # Salva nel file JSON
    jq ".\"$ID\" = $AZIONI" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "Progetto '$ID' salvato con successo!"
}

# --- FUNZIONE: ESEGUI PROGETTO ---
execute_project() {
    local ID=$1
    local PROGETTO_DATA=$(jq -r ".\"$ID\"" "$CONFIG_FILE")

    if [ "$PROGETTO_DATA" == "null" ]; then
        echo "Errore: Progetto '$ID' non trovato. Usa 'pjrunner add' per crearlo."
        exit 1
    fi

    # Configurazione Tmux
    tmux kill-session -t "$ID" 2>/dev/null
    tmux new-session -d -s "$ID" -n "Init"
    tmux set-option -t "$ID" mouse on

    local COUNT=$(echo "$PROGETTO_DATA" | jq '. | length')

    for ((i=0; i<$COUNT; i++)); do
        local TITOLO=$(echo "$PROGETTO_DATA" | jq -r ".[$i].titolo")
        local COMANDO=$(echo "$PROGETTO_DATA" | jq -r ".[$i].comando")
        local SEPARATO=$(echo "$PROGETTO_DATA" | jq -r ".[$i].separato")

        if [ "$SEPARATO" == "true" ]; then
            if [ "$i" -eq 0 ]; then
                tmux rename-window -t "$ID:0" "$TITOLO"
                tmux send-keys -t "$ID:0" "$COMANDO" C-m
            else
                tmux new-window -t "$ID" -n "$TITOLO"
                tmux send-keys -t "$ID:$TITOLO" "$COMANDO; exec bash" C-m
            fi
        else
            tmux send-keys -t "$ID" "$COMANDO &" C-m
        fi
    done

    # Rinomina la finestra esterna (Ptyxis/VS Code/Altro)
    echo -ne "\033]0;${ID^^}\007"
    
    tmux select-window -t "$ID:0"
    tmux attach-session -t "$ID"
}

# --- MAIN ---
case $1 in
    add) add_project ;;
    update)
        echo "--- Controllo aggiornamenti su GitHub ---"
        # URL RAW del tuo script su GitHub
        REPO_URL="https://github.com/Biziol/project-runner/blob/Dev/pjrunner.sh"
        
        # Scarica la nuova versione sovrascrivendo quella attuale
        if sudo curl -fsSL "$REPO_URL" -o "/usr/local/bin/run"; then
            sudo chmod +x /usr/local/bin/run
            echo "Aggiornamento completato con successo!"
        else
            echo "Errore durante l'aggiornamento. Verifica la connessione o il link."
            exit 1
        fi
        ;;
    "")
        echo "Uso: run [id] | run add | run update"
        ;;
    *)   execute_project "$1" ;;
esac