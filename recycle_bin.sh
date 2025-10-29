#!/bin/bash
#################################################
# Linux Recycle Bin Simulation
# Author: David Cálix & Diogo Ruivo
# Date: 2025-10-22
# Description: Shell-based recycle bin system for Sistemas Operativos (SO-2526)
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
VERBOSE=0


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
# Function: verbose_echo
# Description: Prints detailed messages only if verbose mode is enabled
# ==============================
verbose_echo() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${YELLOW}[VERBOSE]${NC} $1"
    fi
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

        verbose_echo "Moving '$file_path' → '$dest'"
        verbose_echo "Metadata: type=$file_type, size=${file_size}B, perms=$perms, owner=$owner"


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

    verbose_echo "Restoring '$src' → '$path'"
    verbose_echo "Restored permissions: $perms | Owner: $owner"


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
# Description: Shows usage information
# ==============================
display_help() {
    cat << 'EOF'
===============================================================
 Linux Recycle Bin Simulation — Help Menu
===============================================================

Usage:
  ./recycle_bin.sh <command> [arguments]

Commands:
  ─────────────────────────────────────────────────────────────
  delete <file(s)>          Move one or more files/directories to recycle bin
  list [--detailed]         List all items currently in recycle bin
  restore <id|name>         Restore a file by its unique ID or name
  search <pattern>          Search for files in recycle bin by name or pattern
  empty [<id>]              Empty the recycle bin (or delete a specific item)

  stats                     Display overall statistics (total size, count, etc.)
  auto_cleanup              Remove files older than RETENTION_DAYS (from config)
  check_quota               Check current recycle bin usage vs MAX_SIZE_MB
  preview <id>              Preview text content or type of a recycled file

  help | -h | --help        Show this help message
  version                   Display project version and author info
  --verbose                 Enable detailed output for debugging


Examples:
  ./recycle_bin.sh delete file.txt
  ./recycle_bin.sh delete file1.txt file2.txt
  ./recycle_bin.sh list --detailed
  ./recycle_bin.sh restore 1696234567_ab12cd
  ./recycle_bin.sh search ".pdf"
  ./recycle_bin.sh stats
  ./recycle_bin.sh check_quota
  ./recycle_bin.sh auto_cleanup
  ./recycle_bin.sh preview 1696234567_ab12cd
  ./recycle_bin.sh empty

Notes:
  • All operations are logged in ~/.recycle_bin/recyclebin.log
  • Metadata stored in ~/.recycle_bin/metadata.db
  • Configurable values (quota and retention) are in ~/.recycle_bin/config
  • Use quotes when dealing with filenames containing spaces.

===============================================================
EOF
}


# ==============================
# Function: show_statistics
# Description: Display statistics of the recycle bin
# ==============================
show_statistics() {
    echo "=== Recycle Bin Statistics ==="
    if [ "$(wc -l < "$METADATA_FILE")" -le 1 ]; then
        echo "No items in recycle bin."
        return
    fi

    verbose_echo "Calculating statistics from metadata.db"

    local total_items total_size files_count dirs_count oldest newest avg_size
    total_items=$(($(wc -l < "$METADATA_FILE") - 1))
    total_size=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{sum+=$5} END {print sum}')
    files_count=$(tail -n +2 "$METADATA_FILE" | grep -c ",file,")
    dirs_count=$(tail -n +2 "$METADATA_FILE" | grep -c ",directory,")
    oldest=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{print $4}' | sort | head -n 1)
    newest=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{print $4}' | sort | tail -n 1)
    avg_size=$((total_size / total_items))

    echo "Total items: $total_items"
    echo "Total size: ${total_size} bytes ($(numfmt --to=iec $total_size))"
    echo "Files: $files_count | Directories: $dirs_count"
    echo "Oldest deletion: $oldest"
    echo "Newest deletion: $newest"
    echo "Average size: ${avg_size} bytes"
    echo "==============================="
}

# ==============================
# Function: auto_cleanup
# Description: Delete items older than RETENTION_DAYS
# ==============================
auto_cleanup() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file missing${NC}"
        return 1
    fi

    verbose_echo "Checking retention ($retention days)... comparing $date → $diff days old"


    local retention
    retention=$(grep "RETENTION_DAYS" "$CONFIG_FILE" | cut -d'=' -f2)
    echo "Cleaning up items older than $retention days..."

    local now cutoff
    now=$(date +%s)
    tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
        local timestamp
        timestamp=$(date -d "$date" +%s 2>/dev/null || echo 0)
        local diff=$(( (now - timestamp) / 86400 ))
        if [ "$diff" -gt "$retention" ]; then
            rm -rf "$FILES_DIR/$id"
            sed -i "/^$id,/d" "$METADATA_FILE"
            log_message "Auto-cleanup: Deleted $name (older than $retention days)"
            echo -e "${YELLOW}Deleted old file:${NC} $name ($diff days old)"
        fi
    done
}

# ==============================
# Function: check_quota
# Description: Check if recycle bin exceeds MAX_SIZE_MB
# ==============================
check_quota() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file missing${NC}"
        return 1
    fi

    local quota total used_percent
    quota=$(grep "MAX_SIZE_MB" "$CONFIG_FILE" | cut -d'=' -f2)
    total=$(du -sm "$FILES_DIR" | awk '{print $1}')
    used_percent=$((100 * total / quota))

    verbose_echo "Quota check: total=${total}MB | limit=${quota}MB"

    echo "=== Storage Quota ==="
    echo "Quota: ${quota} MB"
    echo "Used: ${total} MB (${used_percent}%)"

    if [ "$total" -ge "$quota" ]; then
        echo -e "${RED}Warning: Recycle bin exceeds quota!${NC}"
        echo "Consider running: ./recycle_bin.sh auto_cleanup"
    else
        echo -e "${GREEN}Within safe limits.${NC}"
    fi
}


# ==============================
# Function: preview_file
# Description: Show first 10 lines for text files or type info for others
# ==============================
preview_file() {
    local id="$1"
    if [ -z "$id" ]; then
        echo -e "${RED}Error: Provide file ID${NC}"
        return 1
    fi

    local line
    line=$(grep "^$id," "$METADATA_FILE")
    if [ -z "$line" ]; then
        echo -e "${RED}No file found with ID $id${NC}"
        return 1
    fi

    IFS=',' read -r id name path date size type perms owner <<< "$line"
    local file="$FILES_DIR/$id"

    echo "=== Preview of $name (type: $type) ==="
    if file "$file" | grep -q "text"; then
        head -n 10 "$file"
    else
        file "$file"
    fi
    echo "==============================="
}


# ==============================
# Function: main_menu
# Description: Interactive menu displayed when no arguments are provided
# ==============================
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}==============================================${NC}"
        echo -e "        🗑️  Linux Recycle Bin Simulation"
        echo -e "${GREEN}==============================================${NC}"
        echo -e "1. Delete file(s)"
        echo -e "2. List recycle bin"
        echo -e "3. Restore file"
        echo -e "4. Search file"
        echo -e "5. Show statistics"
        echo -e "6. Auto cleanup"
        echo -e "7. Check quota"
        echo -e "8. Empty recycle bin"
        echo -e "9. Preview file"
        echo -e "10. Help"
        echo -e "0. Exit"
        echo -e "${GREEN}----------------------------------------------${NC}"
        read -rp "Choose an option: " opt

        case "$opt" in
            1)
                read -rp "Enter file(s) to delete (separated by spaces): " files
                delete_file $files
                ;;
            2)
                read -rp "Detailed mode? (y/n): " det
                if [[ "$det" == "y" ]]; then
                    list_recycled --detailed
                else
                    list_recycled
                fi
                ;;
            3)
                read -rp "Enter file ID or name to restore: " id
                restore_file "$id"
                ;;
            4)
                read -rp "Enter pattern to search: " pattern
                search_recycled "$pattern"
                ;;
            5)
                show_statistics
                ;;
            6)
                auto_cleanup
                ;;
            7)
                check_quota
                ;;
            8)
                read -rp "Enter ID to delete specific file (leave empty for all): " id
                empty_recyclebin "$id"
                ;;
            9)
                read -rp "Enter file ID to preview: " id
                preview_file "$id"
                ;;
            10)
                display_help
                ;;
            0)
                echo -e "${YELLOW}Exiting...${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                ;;
        esac
        echo
        read -rp "Press ENTER to return to the menu..."
    done
}

# ==============================
# Function: main
# ==============================
main() {
    # Check for verbose flag
    if [[ "${1:-}" == "--verbose" ]]; then
        VERBOSE=1
        shift
        verbose_echo "Verbose mode activated"
    fi

    initialize_recyclebin

    # If no arguments -> open interactive menu
    if [ $# -eq 0 ]; then
        main_menu
        exit 0
    fi

    case "${1:-}" in
        delete) shift; delete_file "$@" ;;
        list) shift || true; list_recycled "$@" ;;
        restore)
            shift
           restore_file "${1:-}"
           ;;
        search) search_recycled "${2:-}" ;;
        empty) empty_recyclebin "${2:-}" ;;
        stats|statistics) show_statistics ;;
        auto_cleanup) auto_cleanup ;;
        check_quota) check_quota ;;
        preview) preview_file "${2:-}" ;;
        help|--help|-h) display_help ;;
        version)
            echo "Linux Recycle Bin Simulation v1.0"
            echo "Authors: [Teu Nome] & [Colega]"
            echo "Sistemas Operativos — Universidade de Aveiro 2025/26"
            ;;
        *)
            echo -e "${RED}Invalid command. Use 'help' for usage.${NC}"
            ;;
    esac
}

main "$@"
