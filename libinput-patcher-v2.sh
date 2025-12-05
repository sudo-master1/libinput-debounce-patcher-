#!/usr/bin/env bash
#
# libinput-debounce-patcher.sh
# Patch libinput to remove debounce timers for gaming mice
#
# WARNING: This will replace system libinput with a custom build.
# Use in a test environment first. Have SSH/TTY access available.

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
readonly WORKDIR="/tmp/libinput-build-$(id -u)"
readonly BACKUP_DIR="/tmp/libinput-backup-$(id -u)"
readonly REPO="https://gitlab.freedesktop.org/libinput/libinput.git"
readonly BRANCH="1.30.x"  # Match your current version
readonly PATCH_FILE="/tmp/libinput-debounce.patch"

# Colors for output
readonly BOLD='\033[1m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly RED='\033[31m'
readonly BLUE='\033[34m'
readonly RESET='\033[0m'

# --- LOGGING FUNCTIONS ---
log()  { echo -e "${BOLD}[INFO]${RESET} $*"; }
info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }

# --- DEPENDENCY CHECK ---
check_deps() {
    local missing_deps=()
    
    # Check for basic commands
    for cmd in git meson ninja gcc pkg-config sudo; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        err "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    return 0
}

# --- DISTRO DETECTION ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release >/dev/null 2>&1; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        err "Cannot detect distribution"
        exit 1
    fi
}

# --- DEPENDENCY INSTALLATION ---
install_deps() {
    local distro
    distro=$(detect_distro)
    
    info "Detected distribution: $distro"
    
    case "$distro" in
        arch|manjaro|endeavouros)
            sudo pacman -Sy --needed --noconfirm \
                git base-devel meson ninja gcc \
                libevdev libwacom glib2 systemd pkgconf || {
                warn "Some dependencies may have failed to install"
            }
            ;;
        debian|ubuntu|pop|linuxmint)
            sudo apt update && sudo apt install -y \
                git build-essential meson ninja-build \
                pkg-config libevdev-dev libmtdev-dev \
                libwacom-dev libgtk-3-dev libglib2.0-dev \
                libudev-dev gobject-introspection || {
                warn "Some dependencies may have failed to install"
            }
            ;;
        fedora|rhel|centos)
            sudo dnf install -y \
                git meson ninja-build gcc make \
                libevdev-devel libwacom-devel \
                glib2-devel systemd-devel gtk3-devel || {
                warn "Some dependencies may have failed to install"
            }
            ;;
        *)
            err "Unsupported distribution: $distro"
            warn "Please install build dependencies manually:"
            warn "  git, meson, ninja, gcc, pkg-config"
            warn "  libevdev, libwacom, glib2, systemd"
            exit 1
            ;;
    esac
}

# --- BACKUP EXISTING FILES ---
backup_libinput() {
    info "Creating backup of current libinput files..."
    
    # Create backup directory
    sudo mkdir -p "$BACKUP_DIR"
    
    # Backup libraries
    local libdirs=("/usr/lib" "/usr/lib64" "/usr/local/lib" "/lib" "/lib64")
    for libdir in "${libdirs[@]}"; do
        if [ -d "$libdir" ]; then
            sudo find "$libdir" -maxdepth 1 -type f -name "*libinput*" \
                -exec cp -v {} "$BACKUP_DIR/" \; 2>/dev/null || true
        fi
    done
    
    # Backup binaries
    local bindirs=("/usr/bin" "/usr/local/bin" "/bin")
    for bindir in "${bindirs[@]}"; do
        if [ -d "$bindir" ]; then
            sudo find "$bindir" -maxdepth 1 -type f -name "libinput*" \
                -exec cp -v {} "$BACKUP_DIR/" \; 2>/dev/null || true
        fi
    done
    
    # Backup configs
    if [ -d /etc/libinput ]; then
        sudo cp -ra /etc/libinput "$BACKUP_DIR/etc_libinput" 2>/dev/null || true
    fi
    
    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
echo "Restoring original libinput files..."
sudo cp -a ./* / 2>/dev/null || true
sudo ldconfig 2>/dev/null || true
echo "Restore attempted. You may need to reboot."
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    
    info "Backup saved to: $BACKUP_DIR"
    info "To restore: sudo $BACKUP_DIR/restore.sh"
}

# --- CREATE PATCH FILE ---
create_patch() {
    cat > "$PATCH_FILE" << 'PATCH'
diff --git a/src/libinput-plugin-button-debounce.c b/src/libinput-plugin-button-debounce.c
index abc1234..def5678 100644
--- a/src/libinput-plugin-button-debounce.c
+++ b/src/libinput-plugin-button-debounce.c
@@ -XX,XX +XX,XX @@
 
-    ms2us(25), /* threshold for first click detection */
-    ms2us(12), /* threshold between clicks for multi-click */
+    ms2us(0), /* threshold for first click detection */
+    ms2us(0), /* threshold between clicks for multi-click */
 
-    ms2us(25), /* threshold for first click detection */
-    ms2us(12), /* threshold between clicks for multi-click */
+    ms2us(0), /* threshold for first click detection */
+    ms2us(0), /* threshold between clicks for multi-click */
PATCH
    
    info "Patch file created: $PATCH_FILE"
}

# --- BUILD AND INSTALL ---
build_libinput() {
    info "Preparing build directory..."
    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    
    info "Cloning libinput repository..."
    git clone --depth 1 --branch "$BRANCH" "$REPO" libinput || {
        err "Failed to clone repository"
        return 1
    }
    cd libinput
    
    info "Applying debounce patch..."
    if ! patch -p1 < "$PATCH_FILE"; then
        warn "Patch failed, trying manual modification..."
        
        # Manual patch as fallback
        local target_file="src/libinput-plugin-button-debounce.c"
        if [ ! -f "$target_file" ]; then
            err "Target file not found: $target_file"
            return 1
        fi
        
        # Replace debounce timers
        sed -i.bak \
            -e 's/ms2us(25)/ms2us(0)/g' \
            -e 's/ms2us(12)/ms2us(0)/g' \
            "$target_file"
            
        # Verify changes
        if grep -q "ms2us(0)" "$target_file"; then
            info "Manual patch successful"
        else
            err "Manual patch failed"
            return 1
        fi
    fi
    
    info "Configuring build..."
    meson setup build \
        --prefix=/usr \
        --buildtype=release \
        --optimization=3 \
        --libdir=lib \
        -Dtests=false \
        -Ddocumentation=false \
        -Ddebug-gui=false
    
    info "Building libinput (this may take a few minutes)..."
    ninja -C build
    
    info "Installing patched libinput..."
    sudo ninja -C build install
    
    success "Build and installation complete!"
}

# --- VERIFY INSTALLATION ---
verify_installation() {
    info "Verifying installation..."
    
    # Check if libinput binary works
    if command -v libinput >/dev/null 2>&1; then
        info "libinput version: $(libinput --version 2>/dev/null || echo "Unknown")"
    fi
    
    # Update linker cache
    sudo ldconfig
    
    # Check library
    if ldconfig -p | grep -q libinput; then
        success "libinput library registered successfully"
    else
        warn "libinput library not found in cache"
    fi
}

# --- CLEANUP ---
cleanup() {
    info "Cleaning up..."
    rm -rf "$WORKDIR" "$PATCH_FILE" 2>/dev/null || true
}

# --- RESTORE FUNCTION ---
restore_libinput() {
    err "Restoring original libinput..."
    
    if [ -d "$BACKUP_DIR" ]; then
        info "Found backup at: $BACKUP_DIR"
        if [ -f "$BACKUP_DIR/restore.sh" ]; then
            sudo "$BACKUP_DIR/restore.sh"
        else
            warn "No restore script found, attempting manual restore..."
            sudo cp -a "$BACKUP_DIR/"* / 2>/dev/null || true
            sudo ldconfig
        fi
    else
        warn "No backup found. You may need to reinstall libinput:"
        case $(detect_distro) in
            arch|manjaro) echo "  sudo pacman -S libinput libinput-tools" ;;
            debian|ubuntu) echo "  sudo apt install --reinstall libinput10 libinput-bin" ;;
            fedora) echo "  sudo dnf reinstall libinput" ;;
        esac
    fi
    
    info "Original libinput should be restored. Reboot recommended."
}

# --- MAIN EXECUTION ---
main() {
    clear
    echo -e "${BOLD}${GREEN}=== Libinput Debounce Patcher ===${RESET}"
    echo -e "${YELLOW}This script will build and install a modified libinput with zero debounce.${RESET}"
    echo -e "${YELLOW}Warning: This replaces system libinput. Use with caution!${RESET}"
    echo -e "${BLUE}Backup will be created at: $BACKUP_DIR${RESET}"
    echo
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        err "Do not run as root! Use sudo only where needed."
        exit 1
    fi
    
    # Confirmation
    read -rp "Do you want to continue? (yes/NO): " confirm
    if [[ ! "$confirm" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        info "Aborted by user."
        exit 0
    fi
    
    # Check dependencies
    if ! check_deps; then
        warn "Missing dependencies. Attempting to install..."
        install_deps
    fi
    
    # Create backup
    backup_libinput
    
    # Create patch
    create_patch
    
    # Build and install
    if build_libinput; then
        verify_installation
        
        echo
        success "=== Installation Complete ==="
        echo -e "${GREEN}Patched libinput has been installed successfully.${RESET}"
        echo
        info "To revert changes, run:"
        echo "  sudo $BACKUP_DIR/restore.sh"
        echo
        info "You may need to restart your desktop session or reboot."
        echo -e "${YELLOW}Keep the backup directory until you confirm everything works.${RESET}"
        
        # Cleanup
        cleanup
    else
        err "Build failed! Attempting to restore..."
        restore_libinput
        cleanup
        exit 1
    fi
}

# Handle interrupts
trap 'err "Interrupted! Attempting to restore..."; restore_libinput; cleanup; exit 1' INT TERM

# Run main function
main
