#!/usr/bin/env bash
#
# patch-libinput-debounce-safe.sh
# - Detects package manager and installs deps
# - Backs up current libinput runtime files
# - Removes existing libinput packages
# - Clones libinput, patches debounce timers to zero
# - Builds and installs libinput into /usr (replaces system libinput)
# - Prints final message and waits 5s for user; then reloads udev and restarts Plasma
# - On error, attempts to restore backed-up libinput files
#
# WARNING: This script will remove and replace system libinput. Use at your own risk.
# Recommended: inspect the script and run in a test environment first.

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
WORKDIR="/tmp/libinput-build-$$"
BACKUP_DIR="/tmp/libinput-backup-$$"
REPO="https://gitlab.freedesktop.org/libinput/libinput.git"
WAIT_BEFORE_INSTALL=5
WAIT_AFTER_INSTALL=5

# Colors
BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"

log()  { echo -e "${BOLD}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*"; }

# --- Cleanup & restore on error ---
restore_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        warn "Attempting to restore original libinput files from $BACKUP_DIR ..."
        sudo cp -a "$BACKUP_DIR/"* / 2>/dev/null || true
        sudo ldconfig || true
        warn "Restoration attempted (check output). You may need to reboot or re-login."
    else
        warn "No backup directory found; cannot automatically restore."
    fi
}

on_error() {
    err "An error occurred. Running cleanup and attempting restore..."
    restore_backup
    exit 1
}
trap on_error ERR

# --- Detect package manager & install deps ---
detect_pkgmgr() {
    if command -v apt >/dev/null 2>&1; then
        PKGMGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKGMGR="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PKGMGR="pacman"
    else
        err "Unsupported distro: no apt/dnf/pacman found. Install dependencies manually."
        exit 1
    fi
    echo "$PKGMGR"
}

install_deps() {
    PKG=$(detect_pkgmgr)
    log "Using package manager: $PKG"
    case "$PKG" in
        apt)
            log "Installing build deps (sudo will be used)..."
            sudo apt update
            sudo apt install -y git build-essential meson ninja-build pkg-config libevdev-dev libwacom-dev libglib2.0-dev libudev-dev || true
            ;;
        dnf)
            log "Installing build deps..."
            sudo dnf install -y git meson ninja-build gcc make libevdev-devel libwacom-devel glib2-devel systemd-devel pkgconfig || true
            ;;
        pacman)
            log "Installing build deps..."
            sudo pacman -Sy --noconfirm git meson ninja gcc make libevdev libwacom glib2 systemd pkgconf || true
            ;;
    esac
}

# --- Backup existing libinput files (so we can restore if needed) ---
backup_existing_libinput() {
    log "Backing up existing libinput files to $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"

    # Common places to check
    for p in /usr/lib /usr/lib64 /usr/local/lib /lib /lib64 /usr/bin /usr/local/bin; do
        if [ -d "$p" ]; then
            # copy libinput shared objects and binaries
            sudo bash -c "shopt -s nullglob; for f in $p/libinput* $p/*libinput*; do cp -a \"\$f\" \"$BACKUP_DIR/\" 2>/dev/null || true; done"
        fi
    done

    # also back up configuration and udev rules
    sudo mkdir -p "$BACKUP_DIR/etc_libinput_backup"
    sudo cp -a /etc/libinput* "$BACKUP_DIR/etc_libinput_backup/" 2>/dev/null || true
    sudo cp -a /usr/lib/udev /tmp/udev-backup-$$ 2>/dev/null || true

    log "Backup done (check $BACKUP_DIR to verify)."
}

# --- Remove existing libinput packages (best-effort) ---
remove_libinput_packages() {
    PKG=$(detect_pkgmgr)
    log "Attempting to remove libinput packages via package manager ($PKG). This is best-effort and may fail gracefully."
    case "$PKG" in
        apt)
            sudo apt remove -y libinput-dev libinput10 libinput-bin || true
            ;;
        dnf)
            sudo dnf remove -y libinput || true
            ;;
        pacman)
            sudo pacman -Rns --noconfirm libinput || true
            ;;
    esac

    # Also remove leftover library files from standard locations (we backed them up)
    log "Removing leftover libinput files from common paths (if any)..."
    sudo find /usr/lib /usr/lib64 /usr/local/lib /lib /lib64 -maxdepth 1 -type f -name "libinput*" -exec rm -f {} \; 2>/dev/null || true
    sudo rm -f /usr/bin/libinput /usr/local/bin/libinput 2>/dev/null || true

    log "Removal attempt finished."
}

# --- Clone, patch, build, install ---
build_and_install() {
    log "Preparing workdir $WORKDIR ..."
    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    log "Cloning libinput..."
    git clone "$REPO" libinput || { err "git clone failed"; exit 1; }
    cd libinput

    log "Applying debounce patch (set timers to 0)..."
    # ensure the file exists
    FILE="src/libinput-plugin-button-debounce.c"
    if [ ! -f "$FILE" ]; then
        err "$FILE not found in repo (libinput changed structure?). Aborting."
        exit 1
    fi
    # replace only ms2us(25) and ms2us(12) -> ms2us(0)
    sed -i.bak 's/ms2us(25)/ms2us(0)/g; s/ms2us(12)/ms2us(0)/g' "$FILE"

    log "Configuring meson build (install prefix = /usr)..."
    rm -rf builddir
    meson setup builddir --prefix=/usr

    log "Compiling (this may take a minute)..."
    ninja -C builddir

    log "Installing patched libinput to /usr (requires sudo)..."
    sudo ninja -C builddir install
}

# --- Finalization: ldconfig, pause message then reload and restart ---
finalize_and_restart() {
    log "Updating dynamic linker cache (ldconfig)..."
    sudo ldconfig || warn "ldconfig failed (proceeding)."

    echo -e "\n${GREEN}✅ All done!${RESET}"
    echo -e "Run ${BOLD}libinput --version${RESET} to verify you're using the patched version."
    echo -e "${YELLOW}(Waiting ${WAIT_AFTER_INSTALL}s before reloading system to let you read this...)${RESET}"
    sleep "$WAIT_AFTER_INSTALL"

    log "Reloading udev rules..."
    sudo udevadm control --reload-rules && sudo udevadm trigger

    log "Restarting Plasma shell (user)..."
    systemctl --user restart plasma-plasmashell || warn "Could not restart Plasma automatically — you may need to log out and back in."
}

# ---- safe-run main ----
main() {
    echo -e "${BOLD}${GREEN}=== Libinput Debounce Remover (SAFE) ===${RESET}"
    echo -e "${YELLOW}This will remove system libinput and install a patched build with debounce disabled.${RESET}"
    echo -e "${YELLOW}Make sure you have a way to access your system if input behaves unexpectedly (ssh/tty).${RESET}"
    read -rp "Type 'YES' to proceed: " confirm
    if [ "$confirm" != "YES" ]; then
        log "Aborting by user request."
        exit 0
    fi

    install_deps

    backup_existing_libinput

    remove_libinput_packages

    log "Waiting ${WAIT_BEFORE_INSTALL}s before building/installation..."
    sleep "$WAIT_BEFORE_INSTALL"

    build_and_install

    finalize_and_restart

    log "Done. Build dir: $WORKDIR/libinput (you can remove it)"
    log "If you see input problems, run the restore command or reboot to recover."
}

main
