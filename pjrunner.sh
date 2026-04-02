#!/bin/bash

CONFIG_FILE="$HOME/.run_config.json"

# --- FUNZIONE: CONTROLLO DIPENDENZE UNIVERSALE ---
check_dependencies() {
    local MISSING_DEPS=()
    command -v jq >/dev/null 2>&1 || MISSING_DEPS+=("jq")
    command -v tmux >/dev/null 2>&1 || MISSING_DEPS+=("tmux")

    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo "Attenzione: Le seguenti dipendenze sono mancanti: ${MISSING_DEPS[*]}"
        read -p "Vuoi installarle ora? (y/n): " INSTALL_CONFIRM
        if [[ "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
            if command -v dnf >/dev/null 2>&1; then sudo dnf install -y "${MISSING_DEPS[@]}"
            elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}"
            elif command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm "${MISSING_DEPS[@]}"
            elif command -v zypper >/dev/null 2>&1; then sudo zypper install -y "${MISSING_DEPS[@]}"
            else echo "Package manager non trovato. Installa manualmente: ${MISSING_DEPS[*]}"; exit 1; fi
        else echo "Script interrotto."; exit 1; fi
    fi
}

# --- FUNZIONE: LISTA PROGETTI ---
list_projects() {
    if [ ! -f "$CONFIG_FILE" ] || [ "$(jq 'keys | length' "$CONFIG_FILE")" -eq 0 ]; then
        echo "Nessun progetto configurato. Usa 'pjrunner add' per crearne uno."
        return 1
    fi
    echo "--- Progetti configurati ---"
    jq -r 'keys[]' "$CONFIG_FILE" | sed 's/^/ - /'
}

# --- FUNZIONE: STAMPA DETTAGLI PROGETTO ---
print_project_details() {
    local ID=$1
    local DATA=$(jq -r ".\"$ID\"" "$CONFIG_FILE")
    
    echo -e "\nConfigurazione attuale per: \033[1;34m$ID\033[0m"
    echo "--------------------------------------"
    
    local COUNT=$(echo "$DATA" | jq '. | length')
    for ((i=0; i<$COUNT; i++)); do
        local TITOLO=$(echo "$DATA" | jq -r ".[$i].titolo")
        local COMANDO=$(echo "$DATA" | jq -r ".[$i].comando")
        local SEPARATO=$(echo "$DATA" | jq -r ".[$i].separato")
        
        local TAB_INFO="[Stessa Tab]"
        [[ "$SEPARATO" == "true" ]] && TAB_INFO="[Nuova Tab]"
        
        echo -e "\033[1m$((i+1)). $TITOLO\033[0m $TAB_INFO"
        echo -e "   Comando: \033[32m$COMANDO\033[0m"
    done
    echo "--------------------------------------"
}

# --- FUNZIONE: AGGIUNGI / MODIFICA LOGICA ---
configure_actions() {
    local ID=$1
    local AZIONI="[]"
    local CONTINUA="y"

    echo -e "\nInserimento nuove azioni per: \033[1;34m$ID\033[0m"
    while [[ "$CONTINUA" =~ ^[Yy]$ ]]; do
        read -e -p "Titolo azione (es: backend): " TITOLO
        read -e -p "Comando da eseguire: " COMANDO
        read -p "In una nuova tab tmux? (y/n): " SEPARATO
        
        local IS_SEP=false
        [[ "$SEPARATO" == "y" ]] && IS_SEP=true

        AZIONI=$(jq -n --arg t "$TITOLO" --arg c "$COMANDO" --argjson s "$IS_SEP" "$AZIONI + [{\"titolo\": \$t, \"comando\": \$c, \"separato\": \$s}]")
        read -p "Aggiungere un'altra azione? (y/n): " CONTINUA
    done

    jq ".\"$ID\" = $AZIONI" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\033[1;32mProgetto '$ID' salvato con successo!\033[0m"
}

# --- FUNZIONE: EDIT PROGETTO ---
edit_project() {
    if ! list_projects; then return 1; fi
    
    read -p "Inserisci l'ID del progetto da modificare: " ID
    
    # Verifica se esiste
    if [ "$(jq ".\"$ID\"" "$CONFIG_FILE")" == "null" ]; then
        echo "Errore: Progetto '$ID' non trovato."
        return 1
    fi

    # STAMPA IL PROGETTO PRIMA DI MODIFICARE
    print_project_details "$ID"

    echo -e "\033[1;33mATTENZIONE:\033[0m Le azioni esistenti verranno sovrascritte."
    read -p "Procedere con la modifica? (y/n): " CONFERMA
    if [[ "$CONFERMA" =~ ^[Yy]$ ]]; then
        configure_actions "$ID"
    else
        echo "Modifica annullata."
    fi
}

# --- FUNZIONE: DELETE PROGETTO ---
delete_project() {
    if ! list_projects; then return 1; fi
    
    echo ""
    read -e -p "Inserisci l'ID del progetto da ELIMINARE: " ID
    
    # Verifica se il progetto esiste
    if [ "$(jq ".\"$ID\"" "$CONFIG_FILE")" == "null" ]; then
        echo -e "\033[1;31mErrore: Progetto '$ID' non trovato.\033[0m"
        return 1
    fi

    # Richiesta di conferma
    echo -e "\033[1;33mATTENZIONE:\033[0m L'azione non sarà reversibile."
    read -p "Procedere con l'eliminazione di '$ID'? (y/n): " CONFERMA
    if [[ "$CONFERMA" =~ ^[Yy]$ ]]; then
        # Usa jq per eliminare la chiave specifica (del(."chiave"))
        jq "del(.\"$ID\")" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo -e "\033[1;32mProgetto '$ID' eliminato correttamente.\033[0m"
    else
        echo "Eliminazione annullata."
    fi
}

# --- FUNZIONE: ESEGUI PROGETTO ---
execute_project() {
    local ID=$1
    local PROGETTO_DATA=$(jq -r ".\"$ID\"" "$CONFIG_FILE")
    
    if [ "$PROGETTO_DATA" == "null" ]; then
        echo "Errore: Progetto '$ID' non trovato. Usa 'pjrunner list'."
        exit 1
    fi

    # 1. Recuperiamo il titolo della PRIMA azione per inizializzare la sessione
    local PRIMO_TITOLO=$(echo "$PROGETTO_DATA" | jq -r ".[0].titolo")

    # 2. Configurazione Tmux: creiamo la sessione usando il primo titolo invece di "Init"
    tmux kill-session -t "$ID" 2>/dev/null
    tmux new-session -d -s "$ID" -n "$PRIMO_TITOLO"
    tmux set-option -t "$ID" mouse on

    local COUNT=$(echo "$PROGETTO_DATA" | jq '. | length')

    for ((i=0; i<$COUNT; i++)); do
        local TITOLO=$(echo "$PROGETTO_DATA" | jq -r ".[$i].titolo")
        local COMANDO=$(echo "$PROGETTO_DATA" | jq -r ".[$i].comando")
        local SEPARATO=$(echo "$PROGETTO_DATA" | jq -r ".[$i].separato")

        if [ "$SEPARATO" == "true" ]; then
            if [ "$i" -eq 0 ]; then
                # La prima finestra esiste già (creata con new-session), 
                # dobbiamo solo inviare il comando
                tmux send-keys -t "$ID:0" "$COMANDO" C-m
            else
                # Crea una nuova finestra per le azioni successive "separate"
                tmux new-window -t "$ID" -n "$TITOLO"
                tmux send-keys -t "$ID:$TITOLO" "$COMANDO; exec bash" C-m
            fi
        else
            # Se NON è separato, invia il comando alla finestra principale (indice 0)
            # Aggiungiamo & per non bloccare se ci sono altri comandi nella stessa tab
            tmux send-keys -t "$ID:0" "$COMANDO &" C-m
        fi
    done

    # Rinomina la finestra esterna (Ptyxis/VS Code)
    echo -ne "\033]0;${ID^^}\007"
    
    # Seleziona la prima finestra e aggancia
    tmux select-window -t "$ID:0"
    tmux attach-session -t "$ID"
}

# --- MAIN ---
check_dependencies
[ ! -f "$CONFIG_FILE" ] && echo "{}" > "$CONFIG_FILE"

case $1 in
    list)
        list_projects
        ;;
    add)
        read -p "ID Progetto (es: roadmap): " NEW_ID
        configure_actions "$NEW_ID"
        ;;
    edit)
        edit_project
        ;;
    delete)
        delete_project
        ;;
    update)
        echo "Aggiornamento in corso..."
        REPO_URL="https://raw.githubusercontent.com/Biziol/project-runner/main/pjrunner.sh"
        if sudo curl -fsSL "$REPO_URL" -o "/usr/local/bin/pjrunner"; then
            sudo chmod +x /usr/local/bin/pjrunner
            echo "Aggiornamento completato!"
        else
            echo "Errore aggiornamento."; exit 1
        fi
        ;;
    "") echo "Uso: pjrunner [id] | list | add | edit | delete | update" ;;
    *)  execute_project "$1" ;;
esac