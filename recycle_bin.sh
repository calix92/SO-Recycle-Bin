#!/bin/bash
#################################################
# Linux Recycle Bin Simulation
# Author: David Cálix & Diogo Ruivo
# Date: 2025-10-22
# Description: Shell-based recycle bin system for Sistemas Operativos (SO-2526)
# Version: 1.0
#################################################

# ==============================
# Global Configuration
# ==============================
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

set -euo pipefail

# ==============================
# Function: log_message
# Description: Appends a message to the log file with timestamp
# ==============================
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $message" >> "$LOG_FILE"
}

# ==============================
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# ==============================
generate_unique_id() {
    local timestamp=$(date +%s%N)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    echo "${timestamp}_${random}"
}

# ==============================
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# ==============================
initialize_recyclebin() {
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then
        mkdir -p "$FILES_DIR"
        echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
        touch "$LOG_FILE"
        echo -e "${GREEN}Recycle bin initialized at $RECYCLE_BIN_DIR${NC}"
        log_message "Initialized recycle bin structure"
    fi
}

# ==============================
# Function: delete_file
# Description: Moves file(s)/directory(ies) to recycle bin
# ==============================
delete_file() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No file specified${NC}"
        return 1
    fi

    for file_path in "$@"; do
        if [ ! -e "$file_path" ]; then
            echo -e "${RED}Error: File '$file_path' does not exist${NC}"
            continue
        fi

        if [[ "$file_path" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${RED}Error: Cannot delete recycle bin itself${NC}"
            continue
        fi

        local abs_path
        abs_path=$(realpath "$file_path")
        local filename
        filename=$(basename "$file_path")
        local id
        id=$(generate_unique_id)
        local dest="$FILES_DIR/$id"
        local deletion_date
        deletion_date=$(date "+%Y-%m-%d %H:%M:%S")
        local file_size
        file_size=$(stat -c %s "$file_path" 2>/dev/null || du -sb "$file_path" | awk '{print $1}')
        local file_type="file"
        [ -d "$file_path" ] && file_type="directory"
        local perms
        perms=$(stat -c %a "$file_path")
        local owner
        owner=$(stat -c %U:%G "$file_path")

        mv "$file_path" "$dest"

        echo "$id,$filename,$abs_path,$deletion_date,$file_size,$file_type,$perms,$owner" >> "$METADATA_FILE"
        echo -e "${GREEN}✓ Moved to recycle bin:${NC} $filename (ID: $id)"
        log_message "Deleted '$abs_path' -> ID: $id"
    done
}

# ==============================
# Function: list_recycled
# Description: Lists contents of recycle bin
# ==============================
list_recycled() {
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]; then
        echo -e "${YELLOW}Recycle bin is empty.${NC}"
        return
    fi

    if [[ "${1:-}" == "--detailed" ]]; then
        echo "=== Recycle Bin Contents (Detailed) ==="
        tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
            echo "ID: $id"
            echo "Name: $name"
            echo "Original Path: $path"
            echo "Deleted On: $date"
            echo "Size: $size bytes"
            echo "Type: $type | Perms: $perms | Owner: $owner"
            echo "--------------------------------------"
        done
    else
        printf "%-25s %-25s %-20s %-10s\n" "ID" "NAME" "DATE" "SIZE(B)"
        echo "--------------------------------------------------------------------------------"
        tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
            printf "%-25s %-25s %-20s %-10s\n" "${id:0:20}" "$name" "$date" "$size"
        done
    fi
}

# ==============================
# Function: restore_file
# Description: Restores a file from recycle bin
# ==============================
restore_file() {
    local search="$1"
    if [ -z "$search" ]; then
        echo -e "${RED}Error: Must provide file ID or name${NC}"
        return 1
    fi

    local line
    line=$(grep "$search" "$METADATA_FILE" | head -n 1)
    if [ -z "$line" ]; then
        echo -e "${RED}Error: No matching file found${NC}"
        return 1
    fi

    IFS=',' read -r id name path date size type perms owner <<< "$line"
    local src="$FILES_DIR/$id"
    local dest_dir
    dest_dir=$(dirname "$path")

    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi

    if [ -e "$path" ]; then
        local alt="${path}_restored_$(date +%s)"
        echo -e "${YELLOW}File already exists. Restoring as:${NC} $alt"
        path="$alt"
    fi

    mv "$src" "$path"
    chmod "$perms" "$path"
    sed -i "/^$id,/d" "$METADATA_FILE"
    echo -e "${GREEN}✓ Restored:${NC} $path"
    log_message "Restored '$path' (ID: $id)"
}

# ==============================
# Function: search_recycled
# Description: Search files in recycle bin
# ==============================
search_recycled() {
    local pattern="$1"
    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: Please specify a search pattern${NC}"
        return 1
    fi

    echo "=== Search Results for '$pattern' ==="
    grep -i "$pattern" "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
        printf "%-25s %-25s %-20s %-10s\n" "${id:0:20}" "$name" "$date" "$size"
    done || echo -e "${YELLOW}No matches found.${NC}"
}

# ==============================
# Function: empty_recyclebin
# Description: Permanently delete all or specific items
# ==============================
empty_recyclebin() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        read -p "Empty entire recycle bin? (yes/NO): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Cancelled."
            return
        fi
        rm -rf "$FILES_DIR"/*
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
        log_message "Recycle bin emptied."
        echo -e "${GREEN}Recycle bin emptied successfully.${NC}"
    else
        grep -v "^$id," "$METADATA_FILE" > "$METADATA_FILE.tmp" && mv "$METADATA_FILE.tmp" "$METADATA_FILE"
        rm -f "$FILES_DIR/$id"
        log_message "Deleted item with ID $id"
        echo -e "${GREEN}Deleted item with ID:${NC} $id"
    fi
}

# ==============================
# Function: display_help
# Description: Show usage
# ==============================
display_help() {
    cat << EOF
Linux Recycle Bin - Usage Guide

Usage: ./recycle_bin.sh <command> [arguments]

Commands:
  delete <file> [...]      Move file(s)/directory(ies) to recycle bin
  list [--detailed]        List contents of recycle bin
  restore <id|name>        Restore file from recycle bin
  search <pattern>         Search files by name or path
  empty [<id>]             Empty recycle bin or delete one file
  help                     Show this help message

Examples:
  ./recycle_bin.sh delete file.txt
  ./recycle_bin.sh list --detailed
  ./recycle_bin.sh restore 1696234567_abc123
  ./recycle_bin.sh search "report"
  ./recycle_bin.sh empty
EOF
}

# ==============================
# Main
# ==============================
main() {
    initialize_recyclebin

    case "${1:-}" in
        delete) shift; delete_file "$@" ;;
        list) shift || true; list_recycled "$@" ;;
        restore) restore_file "${2:-${1:-}}" ;;
        search) search_recycled "${2:-}" ;;
        empty) empty_recyclebin "${2:-}" ;;
        help|--help|-h|"") display_help ;;
        *) echo -e "${RED}Invalid command. Use 'help' for usage.${NC}"; exit 1 ;;
    esac
}

main "$@"
