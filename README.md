# 🚀 PJRunner (Project Runner)

**PJRunner** è un'utility da riga di comando per Linux progettata per automatizzare l'avvio di progetti complessi (es. Microservizi, Full-stack app) utilizzando **tmux**.

Permette di gestire più azioni (backend, frontend, database, ecc.) all'interno di un'unica sessione organizzata, garantendo lo scorrimento dei log tramite mouse e la persistenza dei processi.

## ✨ Caratteristiche

- 📦 **Installazione One-Liner**: Si installa e si aggiorna direttamente da GitHub.
- 🗂️ **Gestione Multi-Tab**: Ogni componente del progetto ha la sua tab dedicata in tmux.
- 🖱️ **Mouse Support**: Scorrimento dei log fluido con la rotella del mouse abilitato di default.
- 🛠️ **Configurazione Dinamica**: Aggiungi nuovi progetti in modo interattivo senza toccare il codice.
- 📂 **Storage JSON**: Tutte le configurazioni sono salvate in un file JSON leggibile e portabile.
- 🐧 **Universale**: Compatibile con Fedora (Ptyxis), Ubuntu, Arch e le principali distro.

## 📥 Installazione

Puoi installare PJRunner eseguendo il seguente comando nel tuo terminale:

```bash
curl -fsSL https://raw.githubusercontent.com/Biziol/project-runner/Dev/install.sh | bash
```

> **Nota**: L'installer verificherà e installerà automaticamente le dipendenze necessarie (`jq` e `tmux`) dopo aver chiesto il tuo permesso.

## 🚀 Utilizzo rapidi

### 1. Aggiungere un nuovo progetto

Lancia il comando di configurazione interattiva:

```bash
pjrunner add
```

Ti verrà chiesto:

- L'**ID** del progetto (es: `roadmap`).
- Il **Titolo** dell'azione (es: `backend`).
- Il **Comando** da eseguire (es: `cd ~/project/backend && ./mvnw spring-boot:run`).
- Se vuoi eseguirlo in una **nuova tab** separata.

### 2. Avviare un progetto

```bash
pjrunner roadmap
```

### 3. Aggiornare lo script

Per scaricare l'ultima versione del codice dal repository:

```bash
pjrunner update
```

## ⌨️ Scorciatoie utili in Tmux

Una volta avviato un progetto, ti troverai all'interno di una sessione `tmux`. Ecco come muoverti:

- **Passare alla tab successiva**: `Ctrl + b` seguito da `n`
- **Passare alla tab precedente**: `Ctrl + b` seguito da `p`
- **Scorrere i log**: Usa semplicemente la **rotella del mouse**.
- **Uscire (senza spegnere i server)**: `Ctrl + b` seguito da `d` (detach).
- **Rientrare in una sessione**: `tmux a -t nome_progetto`.

## ⚙️ Configurazione manuale

Le configurazioni dei tuoi progetti sono salvate in:
`~/.run_config.json`

Puoi modificare questo file manualmente con VS Code o qualsiasi editor per cambiare percorsi o comandi senza dover rieseguire il comando `add`.

## 🛠️ Requisiti

- **Bash**
- **tmux** (gestore di sessioni terminale)
- **jq** (processore JSON da riga di comando)

---

Realizzato con ❤️ per semplificare il workflow degli sviluppatori Linux.
