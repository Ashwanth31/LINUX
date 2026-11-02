#!/usr/bin/env bash
# Linux School Computer Lab Setup - Bash Micro Project
# Uses standard Linux commands. Administrative actions request sudo when required.

set -u
IFS=$'\n\t'

PROJECT_NAME="Linux School Computer Lab Setup"
BASE_DIR="${HOME}/SchoolComputerLab"
STUDENT_DIR="${BASE_DIR}/students"
SHARED_DIR="${BASE_DIR}/shared"
BACKUP_DIR="${BASE_DIR}/backups"
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/lab_setup.log"

pause() {
    echo
    read -r -p "Press Enter to return to the main menu..." _
}

init_workspace() {
    mkdir -p "$STUDENT_DIR" "$SHARED_DIR" "$BACKUP_DIR" "$LOG_DIR" 2>/dev/null
    if [[ -d "$LOG_DIR" ]]; then
        touch "$LOG_FILE" 2>/dev/null || true
    fi
}

log_action() {
    local message="$1"
    local stamp
    stamp="$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ -w "$LOG_DIR" || -w "$LOG_FILE" ]]; then
        printf '[%s] %s\n' "$stamp" "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

header() {
    clear 2>/dev/null || true
    echo "============================================================"
    echo "             $PROJECT_NAME"
    echo "============================================================"
    echo "Workspace: $BASE_DIR"
    echo
}

show_system_info() {
    echo "--------------- SYSTEM INFORMATION ----------------"
    printf "Hostname       : "; hostname 2>/dev/null || echo "Unavailable"
    printf "Current user   : "; whoami 2>/dev/null || echo "Unavailable"
    printf "Date and time  : "; date 2>/dev/null || echo "Unavailable"
    printf "Kernel         : "; uname -r 2>/dev/null || echo "Unavailable"
    printf "Operating sys. : "
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-Linux}"
    else
        echo "Linux distribution information unavailable"
    fi
    echo
    echo "Memory summary:"
    free -h 2>/dev/null || echo "The 'free' command is unavailable."
    echo
    echo "Disk space:"
    df -h "$HOME" 2>/dev/null || df -h 2>/dev/null || echo "Disk information unavailable."
    log_action "Viewed system information"
}

check_lab_folders() {
    echo "--------------- LAB FOLDERS ----------------"
    mkdir -p "$STUDENT_DIR" "$SHARED_DIR" "$BACKUP_DIR" "$LOG_DIR" || {
        echo "ERROR: Could not create the lab workspace."
        log_action "ERROR: failed to create workspace folders"
        return 1
    }
    chmod 755 "$BASE_DIR"
    chmod 755 "$STUDENT_DIR"
    chmod 775 "$SHARED_DIR"
    chmod 700 "$BACKUP_DIR"
    touch "$LOG_FILE" 2>/dev/null || true
    echo "Lab workspace is ready."
    echo "Students : $STUDENT_DIR"
    echo "Shared   : $SHARED_DIR"
    echo "Backups  : $BACKUP_DIR (private to the current user)"
    echo "Logs     : $LOG_FILE"
    log_action "Created/verified lab folders and permissions"
}

create_student_folder() {
    local student
    read -r -p "Enter a student ID (letters, numbers, underscore, hyphen; 2-24 chars): " student
    if [[ ! "$student" =~ ^[a-zA-Z0-9_-]{2,24}$ ]]; then
        echo "ERROR: Invalid student ID. Use 2-24 letters, numbers, _ or -."
        log_action "ERROR: invalid student ID entered"
        return 1
    fi
    if [[ -e "$STUDENT_DIR/$student" ]]; then
        echo "ERROR: A folder for '$student' already exists."
        log_action "ERROR: duplicate student folder $student"
        return 1
    fi
    if mkdir -p "$STUDENT_DIR/$student"; then
        chmod 700 "$STUDENT_DIR/$student"
        printf 'Student workspace for %s\nCreated: %s\n' "$student" "$(date)" > "$STUDENT_DIR/$student/README.txt"
        echo "SUCCESS: Created private workspace: $STUDENT_DIR/$student"
        echo "Permissions are set to 700 (only the owner can access it)."
        log_action "Created student folder $student"
    else
        echo "ERROR: Could not create the student folder."
        log_action "ERROR: failed to create student folder $student"
        return 1
    fi
}

create_lab_user() {
    local username
    read -r -p "Enter Linux username to create (e.g. student01): " username
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{1,30}$ ]]; then
        echo "ERROR: Invalid username. Start with a lowercase letter or underscore."
        log_action "ERROR: invalid Linux username entered"
        return 1
    fi
    if ! command -v useradd >/dev/null 2>&1; then
        echo "ERROR: useradd is not available on this system."
        log_action "ERROR: useradd command unavailable"
        return 1
    fi
    if id "$username" >/dev/null 2>&1; then
        echo "ERROR: User '$username' already exists."
        log_action "ERROR: attempted duplicate Linux user $username"
        return 1
    fi
    echo "This operation creates a real Linux account and requires administrator privileges."
    read -r -p "Continue? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled; no Linux account was created."
        return 0
    fi
    if sudo useradd -m -s /bin/bash "$username"; then
        echo "SUCCESS: Account '$username' created."
        echo "Set its password with: sudo passwd $username"
        log_action "Created Linux user $username"
    else
        echo "ERROR: User creation failed. Check sudo privileges and system policy."
        log_action "ERROR: failed to create Linux user $username"
        return 1
    fi
}

check_software() {
    echo "--------------- SOFTWARE AVAILABILITY ----------------"
    local tools=("bash" "ls" "grep" "awk" "tar" "df" "free" "ip" "ping" "curl" "gcc" "python3")
    printf "%-12s %s\n" "COMMAND" "STATUS"
    printf "%-12s %s\n" "------------" "----------------------"
    local tool
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf "%-12s %s\n" "$tool" "Available: $(command -v "$tool")"
        else
            printf "%-12s %s\n" "$tool" "Not installed / not in PATH"
        fi
    done
    echo
    echo "This check does not install software or change system packages."
    log_action "Checked software availability"
}

network_check() {
    echo "--------------- NETWORK STATUS ----------------"
    if command -v ip >/dev/null 2>&1; then
        echo "Network interfaces:"
        ip -brief address 2>/dev/null || ip address 2>/dev/null || true
    else
        echo "The 'ip' command is unavailable."
    fi
    echo
    if command -v ping >/dev/null 2>&1; then
        echo "Testing connectivity to 1.1.1.1 (one packet; may be blocked by the network)..."
        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            echo "Network test: reachable."
        else
            echo "Network test failed or ICMP is blocked. This does not always mean the internet is unavailable."
        fi
    else
        echo "The 'ping' command is unavailable; skipping connectivity test."
    fi
    log_action "Checked network status"
}

make_shared_note() {
    local filename
    read -r -p "Enter a shared filename (letters/numbers/._- only): " filename
    if [[ ! "$filename" =~ ^[a-zA-Z0-9._-]{1,60}$ ]]; then
        echo "ERROR: Invalid filename."
        log_action "ERROR: invalid shared filename"
        return 1
    fi
    if [[ "$filename" == "." || "$filename" == ".." ]]; then
        echo "ERROR: That filename is not allowed."
        return 1
    fi
    if [[ -e "$SHARED_DIR/$filename" ]]; then
        echo "ERROR: That file already exists; it was not overwritten."
        log_action "ERROR: shared file already exists $filename"
        return 1
    fi
    read -r -p "Enter a short note (one line): " note
    if printf '%s\n' "$note" > "$SHARED_DIR/$filename"; then
        chmod 664 "$SHARED_DIR/$filename"
        echo "SUCCESS: Shared note created at $SHARED_DIR/$filename"
        log_action "Created shared note $filename"
    else
        echo "ERROR: Could not write the shared note."
        log_action "ERROR: failed to create shared note $filename"
        return 1
    fi
}

backup_lab_data() {
    local archive
    archive="$BACKUP_DIR/lab_backup_$(date '+%Y%m%d_%H%M%S').tar.gz"
    if [[ ! -d "$STUDENT_DIR" && ! -d "$SHARED_DIR" ]]; then
        echo "ERROR: No lab folders are available to back up."
        log_action "ERROR: backup attempted without lab folders"
        return 1
    fi
    if tar -czf "$archive" -C "$BASE_DIR" students shared 2>/dev/null; then
        chmod 600 "$archive"
        echo "SUCCESS: Backup created:"
        echo "$archive"
        echo "Archive size: $(du -h "$archive" | awk '{print $1}')"
        log_action "Created backup $(basename "$archive")"
    else
        echo "ERROR: Backup failed. Check available disk space and folder permissions."
        rm -f "$archive" 2>/dev/null || true
        log_action "ERROR: backup failed"
        return 1
    fi
}

list_lab_data() {
    echo "--------------- LAB CONTENTS ----------------"
    echo "Student workspaces:"
    if [[ -d "$STUDENT_DIR" ]] && find "$STUDENT_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit | grep -q .; then
        find "$STUDENT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
    else
        echo "(none yet)"
    fi
    echo
    echo "Shared files:"
    if [[ -d "$SHARED_DIR" ]] && find "$SHARED_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit | grep -q .; then
        find "$SHARED_DIR" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort
    else
        echo "(none yet)"
    fi
    echo
    echo "Backup archives:"
    if [[ -d "$BACKUP_DIR" ]] && find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.tar.gz' -print -quit | grep -q .; then
        find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.tar.gz' -printf '%f (%s bytes)\n' 2>/dev/null | sort
    else
        echo "(none yet)"
    fi
    log_action "Listed lab contents"
}

show_logs() {
    echo "--------------- RECENT ACTIVITY LOG ----------------"
    if [[ -s "$LOG_FILE" ]]; then
        tail -n 20 "$LOG_FILE"
    else
        echo "No activity has been logged yet."
    fi
}

main_menu() {
    while true; do
        header
        cat <<'MENU'
1. Show system information
2. Create / verify lab folders and permissions
3. Create a student workspace folder
4. Create a Linux student account (admin required)
5. Check availability of useful lab software
6. Check network status
7. Create a shared note/file
8. Back up student and shared folders
9. List lab files and backups
10. View recent activity log
0. Exit
MENU
        echo
        read -r -p "Enter your choice [0-10]: " choice
        case "$choice" in
            1) show_system_info; pause ;;
            2) check_lab_folders; pause ;;
            3) create_student_folder; pause ;;
            4) create_lab_user; pause ;;
            5) check_software; pause ;;
            6) network_check; pause ;;
            7) make_shared_note; pause ;;
            8) backup_lab_data; pause ;;
            9) list_lab_data; pause ;;
            10) show_logs; pause ;;
            0) log_action "Exited project"; echo "Thank you for using $PROJECT_NAME."; exit 0 ;;
            *) echo "ERROR: Invalid choice. Please enter a number from 0 to 10."; log_action "ERROR: invalid menu choice"; pause ;;
        esac
    done
}

init_workspace
main_menu
