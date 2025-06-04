#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "[!] Error: Script must be run as root." >&2
  exit 1
fi

ASK_SUDO_PASS=0
SAVE_DIR=""
MAX_COPIES=0
DIRS=""
SUBDIRS=""
LOG_DIR="/var/log/scp-backup"
LOG_FILE=""

# Logging function with timestamp
log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a "$LOG_FILE"
    # Log rotation by lines (max 1000)
    local lines
    lines=$(wc -l < "$LOG_FILE")
    if [[ $lines -gt 1000 ]]; then
        tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

usage() {
    echo "Usage: $0 -r <remote_ip> -p <port> -u <user> [-d <dirs_comma_separated>] [-Sd <subdirs_comma_separated>] [-a] [-s <local_save_dir>] [-m <max_copies>]"
    echo
    echo "  -r   Remote server IP address"
    echo "  -p   SSH connection port"
    echo "  -u   User for SSH connection"
    echo "  -d   Comma-separated list of root directories to backup (e.g., etc,home,var)"
    echo "  -Sd  Comma-separated list of full-path subdirectories to backup (e.g., /home/user1,/var/log/nginx)"
    echo "  -a   Ask for sudo password to create archives (optional)"
    echo "  -s   Local directory to save backups (optional, default is current directory)"
    echo "  -m   Maximum number of saved backup copies (optional, no limit by default)"
    echo
    echo "Example:"
    echo "  $0 -r 192.168.0.100 -p 2222 -u webdev -d etc,home -Sd /home/user1,/var/log/nginx -a -s /mnt/backup -m 3"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r) REMOTE_HOST="$2"; shift ;;
        -p) PORT="$2"; shift ;;
        -u) USER="$2"; shift ;;
        -d) DIRS="$2"; shift ;;
        -Sd) SUBDIRS="$2"; shift ;;
        -s) SAVE_DIR="$2"; shift ;;
        -m) MAX_COPIES="$2"; shift ;;
        -a) ASK_SUDO_PASS=1 ;;
        *) usage ;;
    esac
    shift
done

if [[ -z "$REMOTE_HOST" || -z "$PORT" || -z "$USER" ]]; then
    usage
fi

if [[ -z "$DIRS" && -z "$SUBDIRS" ]]; then
    echo "[!] Error: You must specify at least -d or -Sd for backup."
    usage
fi

# Prepare logs
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$REMOTE_HOST.log"

log "[*] Starting backup for host $REMOTE_HOST"

if [[ "$ASK_SUDO_PASS" -eq 1 ]]; then
    echo -n "Enter sudo password for $USER@$REMOTE_HOST: "
    read -s SUDO_PASS
    echo
fi

log "[*] Checking access to $REMOTE_HOST..."
ssh -p "$PORT" -o BatchMode=yes -o ConnectTimeout=5 "$USER@$REMOTE_HOST" 'echo OK' >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    log "[!] Error: Cannot connect to $REMOTE_HOST as $USER. Check IP, port, or key access."
    exit 1
fi

if [[ "$ASK_SUDO_PASS" -eq 1 ]]; then
    log "[*] Verifying sudo password..."
    ssh -p "$PORT" "$USER@$REMOTE_HOST" "echo \"$SUDO_PASS\" | sudo -S -v" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        log "[!] Incorrect sudo password. Operation aborted."
        exit 1
    fi
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOCAL_BASE="${SAVE_DIR:-.}/$REMOTE_HOST/backup_${REMOTE_HOST}_all_${TIMESTAMP}"
mkdir -p "$LOCAL_BASE"

ARCHIVE_LIST=()

create_archive() {
    local remote_path="$1"
    local name_for_archive="$2"

    local remote_tmp="/tmp/backup_${name_for_archive}_${TIMESTAMP}.tar.gz"
    local local_tmp="$LOCAL_BASE/backup_${name_for_archive}_${TIMESTAMP}.tar.gz"
    ARCHIVE_LIST+=("$local_tmp")

    log "[*] Processing $remote_path ..."
    log "[*] Creating archive $remote_tmp on server..."

    if [[ "$ASK_SUDO_PASS" -eq 1 ]]; then
        ssh -p "$PORT" "$USER@$REMOTE_HOST" \
            "echo \"$SUDO_PASS\" | sudo -S -p '' tar -czf $remote_tmp $remote_path 2>/dev/null"
    else
        ssh -p "$PORT" "$USER@$REMOTE_HOST" \
            "tar -czf $remote_tmp $remote_path 2>/dev/null"
    fi

    if [[ $? -ne 0 ]]; then
        log "[!] Error: Failed to create archive for $remote_path"
        exit 1
    fi

    log "[*] Downloading archive to local machine..."
    scp -P "$PORT" "$USER@$REMOTE_HOST:$remote_tmp" "$local_tmp" >/dev/null
    if [[ $? -ne 0 ]]; then
        log "[!] Error: Failed to download archive $remote_tmp"
        exit 1
    fi

    log "[*] Removing temporary archive from server..."
    if [[ "$ASK_SUDO_PASS" -eq 1 ]]; then
        ssh -p "$PORT" "$USER@$REMOTE_HOST" \
            "echo \"$SUDO_PASS\" | sudo -S -p '' rm -f $remote_tmp" >/dev/null
    else
        ssh -p "$PORT" "$USER@$REMOTE_HOST" \
            "rm -f $remote_tmp" >/dev/null
    fi
}

if [[ -n "$DIRS" ]]; then
    IFS=',' read -ra DIR_ARRAY <<< "$DIRS"
    for DIR in "${DIR_ARRAY[@]}"; do
        create_archive "/$DIR" "${REMOTE_HOST}_$DIR"
    done
fi

if [[ -n "$SUBDIRS" ]]; then
    IFS=',' read -ra SUBDIR_ARRAY <<< "$SUBDIRS"
    for SUBDIR in "${SUBDIR_ARRAY[@]}"; do
        local_name=$(echo "$SUBDIR" | sed 's|^/||; s|/|-|g')
        create_archive "$SUBDIR" "${REMOTE_HOST}_$local_name"
    done
fi

if [[ "$MAX_COPIES" -gt 0 ]]; then
    log "[*] Checking and cleaning old backup copies (more than $MAX_COPIES)..."
    BACKUP_PARENT_DIR="${SAVE_DIR:-.}/$REMOTE_HOST"
    mapfile -t BACKUP_DIRS < <(ls -1dt "$BACKUP_PARENT_DIR"/backup_"${REMOTE_HOST}"_all_* 2>/dev/null)
    COUNT=${#BACKUP_DIRS[@]}

    if [[ $COUNT -gt $MAX_COPIES ]]; then
        DEL_COUNT=$((COUNT - MAX_COPIES))
        log "[*] Deleting $DEL_COUNT old directories..."
        for ((i=COUNT-1; i>=MAX_COPIES; i--)); do
            log "    Deleting: $(basename "${BACKUP_DIRS[i]}")"
            rm -rf "${BACKUP_DIRS[i]}"
        done
    fi
fi

log "[✓] Done! Archives saved in directory: $LOCAL_BASE"
log "Archives:"
for A in "${ARCHIVE_LIST[@]}"; do
    log " - $A"
done
