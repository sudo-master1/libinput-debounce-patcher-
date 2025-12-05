#!/usr/bin/env bash
# libinput-debounce-patcher-complete.sh
# Complete automated patcher - scans for zip, extracts, patches, builds, installs

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
readonly WORK_DIR="$(pwd)"
readonly BACKUP_DIR="/tmp/libinput-backup-$(id -u)"
readonly BUILD_DIR="$WORK_DIR/build"

# Colors
readonly BOLD='\033[1m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly RED='\033[31m'
readonly BLUE='\033[34m'
readonly RESET='\033[0m'

# --- LOGGING ---
log()  { echo -e "${BOLD}[INFO]${RESET} $*"; }
info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }

# --- CHECK AND INSTALL DEPENDENCIES ---
install_dependencies() {
    info "Checking and installing dependencies..."
    
    local missing_pkgs=()
    
    # Check for unzip
    if ! command -v unzip >/dev/null 2>&1; then
        missing_pkgs+=("unzip")
    fi
    
    # Check for build tools
    for tool in meson ninja gcc pkg-config; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_pkgs+=("$tool")
        fi
    done
    
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        warn "Missing packages: ${missing_pkgs[*]}"
        info "Installing dependencies..."
        
        if command -v pacman >/dev/null 2>&1; then
            # Arch Linux
            sudo pacman -Sy --noconfirm "${missing_pkgs[@]}" base-devel
        elif command -v apt >/dev/null 2>&1; then
            # Debian/Ubuntu
            sudo apt update
            sudo apt install -y "${missing_pkgs[@]}" build-essential
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora
            sudo dnf install -y "${missing_pkgs[@]}" @development-tools
        else
            err "Unsupported package manager. Install manually:"
            err "  ${missing_pkgs[*]}"
            exit 1
        fi
    fi
    
    success "Dependencies OK"
}

# --- FIND AND EXTRACT ZIP ---
find_and_extract_zip() {
    info "Scanning for libinput zip file..."
    
    local zip_files=()
    
    # Look for libinput zip files
    while IFS= read -r file; do
        zip_files+=("$file")
    done < <(find "$WORK_DIR" -maxdepth 1 -name "*libinput*.zip" -type f 2>/dev/null)
    
    if [ ${#zip_files[@]} -eq 0 ]; then
        err "No libinput zip file found in current directory!"
        err "Please download libinput-1.30.0.zip and place it here."
        exit 1
    fi
    
    # Use the first zip file found
    local zip_file="${zip_files[0]}"
    info "Found zip file: $(basename "$zip_file")"
    
    # Check if already extracted
    if [ -d "libinput-1.30.0" ]; then
        warn "libinput-1.30.0 directory already exists. Using existing source."
        return 0
    fi
    
    info "Extracting $(basename "$zip_file")..."
    if ! unzip -q "$zip_file"; then
        err "Failed to extract zip file"
        exit 1
    fi
    
    if [ ! -d "libinput-1.30.0" ]; then
        err "Extraction didn't create expected directory 'libinput-1.30.0'"
        exit 1
    fi
    
    success "Extraction complete"
}

# --- BACKUP CURRENT LIBINPUT ---
backup_libinput() {
    info "Creating backup of current libinput..."
    
    sudo mkdir -p "$BACKUP_DIR"
    
    # Backup library files
    local lib_files=()
    while IFS= read -r file; do
        lib_files+=("$file")
    done < <(sudo find /usr/lib /usr/lib64 -maxdepth 1 -name "*libinput*" -type f 2>/dev/null)
    
    # Backup binary files
    local bin_files=()
    while IFS= read -r file; do
        bin_files+=("$file")
    done < <(sudo find /usr/bin /usr/local/bin -maxdepth 1 -name "libinput*" -type f 2>/dev/null)
    
    # Copy files
    for file in "${lib_files[@]}" "${bin_files[@]}"; do
        if [ -f "$file" ]; then
            sudo cp -v "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
echo "=== Restoring libinput ==="
echo "Copying backup files to system..."
sudo cp -a ./* / 2>/dev/null || true
sudo ldconfig 2>/dev/null || true
echo "✓ Restoration complete"
echo "You may need to reboot or restart desktop session."
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    
    info "Backup saved to: $BACKUP_DIR"
}

# --- PATCH LIBINPUT ---
patch_libinput() {
    info "Patching libinput source code..."
    
    cd "libinput-1.30.0" || {
        err "Cannot enter libinput source directory"
        exit 1
    }
    
    # Find the debounce file
    local target_file=""
    target_file=$(find . -type f -name "*.c" -exec grep -l "ms2us(25)" {} \; 2>/dev/null | head -1)
    
    if [ -z "$target_file" ]; then
        err "Could not find file with debounce settings"
        exit 1
    fi
    
    info "Found target file: $target_file"
    
    # Create backup of the file
    cp "$target_file" "${target_file}.bak"
    
    # Apply patch - remove all debounce delays
    info "Applying patch (setting all debounce to 0ms)..."
    sed -i \
        -e 's/ms2us(25)/ms2us(0)/g' \
        -e 's/ms2us(12)/ms2us(0)/g' \
        -e 's/ms2us(10)/ms2us(0)/g' \
        -e 's/ms2us(8)/ms2us(0)/g' \
        -e 's/ms2us(5)/ms2us(0)/g' \
        -e 's/ms2us(20)/ms2us(0)/g' \
        -e 's/ms2us(15)/ms2us(0)/g' \
        "$target_file"
    
    # Verify patch
    if grep -q "ms2us(0)" "$target_file"; then
        info "Patch successful. Changes made:"
        grep -n "ms2us" "$target_file" | head -10
        success "✓ Source code patched"
    else
        err "Patch failed - no changes detected"
        exit 1
    fi
    
    cd ..
}

# --- BUILD LIBINPUT ---
build_libinput() {
    info "Building patched libinput..."
    
    cd "libinput-1.30.0" || exit 1
    
    # Clean previous build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || exit 1
    
    # Configure
    info "Configuring build..."
    meson .. \
        --prefix=/usr \
        --buildtype=release \
        --optimization=3 \
        --libdir=lib \
        -Dtests=false \
        -Ddocumentation=false \
        -Ddebug-gui=false \
        -Dlibwacom=false
    
    # Build
    info "Building (this may take a few minutes)..."
    ninja
    
    success "✓ Build complete"
}

# --- INSTALL LIBINPUT ---
install_libinput() {
    info "Installing patched libinput..."
    
    cd "libinput-1.30.0/$BUILD_DIR" || exit 1
    
    # Install
    sudo ninja install
    
    # Update library cache
    sudo ldconfig
    
    success "✓ Installation complete"
}

# --- VERIFY INSTALLATION ---
verify_installation() {
    info "Verifying installation..."
    
    # Check libinput binary
    if command -v libinput >/dev/null 2>&1; then
        local version
        version=$(libinput --version 2>/dev/null || echo "unknown")
        success "✓ libinput version: $version"
    else
        warn "libinput binary not found in PATH"
    fi
    
    # Check if patched version is running
    if strings "$(command -v libinput 2>/dev/null || echo /usr/bin/libinput)" 2>/dev/null | grep -q "ms2us(0)"; then
        success "✓ Patched version confirmed"
    else
        warn "Could not verify patch in binary"
    fi
}

# --- CLEANUP ---
cleanup() {
    info "Cleaning up..."
    # Keep source directory for future use
    rm -rf "$BUILD_DIR" 2>/dev/null || true
}

# --- RESTORE FUNCTION ---
restore_libinput() {
    err "=== RESTORING ORIGINAL LIBINPUT ==="
    
    if [ -d "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/restore.sh" ]; then
        info "Found backup, restoring..."
        sudo "$BACKUP_DIR/restore.sh"
    else
        warn "No backup found. Reinstalling from package manager..."
        if command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm libinput libinput-tools
        elif command -v apt >/dev/null 2>&1; then
            sudo apt install --reinstall -y libinput10 libinput-bin
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf reinstall -y libinput
        else
            err "Cannot auto-reinstall. Please install libinput manually."
        fi
        sudo ldconfig
    fi
    
    info "Original libinput restored. Reboot recommended."
}

# --- MAIN ---
main() {
    clear
    echo -e "${BOLD}${GREEN}=== Libinput Debounce Patcher (Complete) ===${RESET}"
    echo -e "${YELLOW}This will patch, build, and install libinput with zero debounce${RESET}"
    echo -e "${YELLOW}Warning: Replaces system libinput. Have backup/SSH access ready${RESET}"
    echo
    
    # Check for root
    if [ "$EUID" -eq 0 ]; then
        err "Do not run as root! Run as normal user."
        exit 1
    fi
    
    # Confirmation
    read -rp "Continue? (yes/NO): " confirm
    if [[ ! "$confirm" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        info "Aborted"
        exit 0
    fi
    
    # Set trap for error recovery
    trap 'err "Script failed! Restoring..."; restore_libinput; exit 1' ERR
    
    # Execute steps
    install_dependencies
    find_and_extract_zip
    backup_libinput
    patch_libinput
    build_libinput
    install_libinput
    verify_installation
    cleanup
    
    echo
    success "=== COMPLETE ==="
    echo -e "${GREEN}Patched libinput successfully installed!${RESET}"
    echo
    info "To restore original libinput:"
    echo "  sudo $BACKUP_DIR/restore.sh"
    echo
    info "You should restart your desktop session or reboot."
    echo -e "${YELLOW}Note: This patches SOFTWARE debounce only.${RESET}"
    echo -e "${YELLOW}Hardware debounce in mouse firmware is not affected.${RESET}"
    
    read -rp "Restart now? (y/N): " restart
    if [[ "$restart" =~ ^[Yy]$ ]]; then
        info "Restarting..."
        sudo systemctl reboot
    fi
}

# Run main
main "$@"
