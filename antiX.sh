#!/bin/bash
# This script automates the installation of audio software (REAPER, Guitarix)
# and configures real-time audio permissions on antiX Linux.
# It does NOT handle debloating or auto-login configurations.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--------------------------------------------------------"
echo "  AntiX Audio Software Installer Script"
echo "--------------------------------------------------------"
echo ""

# --- VARIABLES ---
USER_NAME=$(whoami) # Automatically detect the current user
BUILD_DIR="$HOME/audio_software_build"
REAPER_URL="https://www.reaper.fm/files/7.x/reaper742_linux_x86_64.tar.xz"
INSTALL_LOG_FILE="$HOME/installation.log"
GUITARIX_BUILD_LOG="$HOME/guitarix_build.log"

# Dependencies for building Guitarix and general audio tools, split to handle jackd2 issue
JACK_DEPENDENCIES="jackd2 libjack-jackd2-0"
CORE_DEPENDENCIES="git build-essential clang gperf intltool libavahi-gobject-dev libbluetooth-dev libboost-dev libboost-iostreams-dev libboost-system-dev libboost-thread-dev libeigen3-dev libgtk-3-dev libgtkmm-3.0-dev libjack-dev liblilv-dev liblrdf0-dev libsndfile1-dev libfftw3-dev lv2-dev python3 python-is-python3 sassc wget fonts-roboto faust alsa-utils nano dkms linux-headers-$(uname -r)"

# --- FUNCTIONS ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "⛔ Error: This script must be run with sudo privileges. Please run: sudo ./$0"
        exit 1
    fi
}

# --- SCRIPT START ---
check_root

echo "--> Updating apt package lists..."
sudo apt update
echo ""

# ====== 1. Install Core Dependencies for Audio & Building ======
echo "--> Step 1: Installing essential audio and build dependencies."
echo "    Installation progress and errors will be logged to $INSTALL_LOG_FILE"
echo "" > "$INSTALL_LOG_FILE" # Clear old log file

# First, install the JACK dependencies separately to resolve the dependency issue
echo "--> Step 1.1: Installing JACK daemon and libraries..."
echo "    The following packages will be installed: $JACK_DEPENDENCIES"
sudo apt install -y $JACK_DEPENDENCIES >> "$INSTALL_LOG_FILE" 2>&1
echo "--> JACK components installed successfully."
echo ""

# Now install the rest of the dependencies
echo "--> Step 1.2: Installing remaining essential dependencies."
echo "    The following packages will be installed: $CORE_DEPENDENCIES"
sudo apt install -y $CORE_DEPENDENCIES >> "$INSTALL_LOG_FILE" 2>&1
echo "--> Remaining dependencies installed successfully."
echo ""
echo "    Installation log is available at $INSTALL_LOG_FILE. Please review it for any warnings or errors."
echo ""

# ====== 2. Install Real-time Kernel (if available and not already installed) ======
echo "--> Step 2: Checking for and installing a real-time (RT) kernel..."
# antiX often has a low-latency kernel by default, but a specific RT kernel might be available.
# This command attempts to install a common RT kernel package for Debian-based systems.
RT_KERNEL_PACKAGE="linux-image-rt-amd64"
if ! dpkg -l | grep -q "$RT_KERNEL_PACKAGE"; then
    echo "    Installing $RT_KERNEL_PACKAGE..."
    sudo apt install -y "$RT_KERNEL_PACKAGE" >> "$INSTALL_LOG_FILE" 2>&1 || echo "    Warning: $RT_KERNEL_PACKAGE not found or failed to install. Continuing with current kernel."
else
    echo "    $RT_KERNEL_PACKAGE is already installed."
fi
echo ""

# ====== 3. Configure Real-time Audio Permissions ======
echo "--> Step 3: Configuring real-time audio permissions for user '$USER_NAME'."
# Add user to the 'audio' group if not already a member
if ! groups "$USER_NAME" | grep -q "audio"; then
    echo "    Adding user '$USER_NAME' to the 'audio' group..."
    sudo usermod -aG audio "$USER_NAME"
    echo "    User '$USER_NAME' added to 'audio' group. (Requires reboot to take full effect)"
else
    echo "    User '$USER_NAME' is already a member of the 'audio' group."
fi

# Configure limits.conf for real-time priority and memory locking
echo "    Setting real-time priorities in /etc/security/limits.conf..."
if ! grep -q "@audio - rtprio 99" /etc/security/limits.conf; then
    sudo sh -c 'echo "@audio - rtprio 99" >> /etc/security/limits.conf'
fi
if ! grep -q "@audio - memlock unlimited" /etc/security/limits.conf; then
    sudo sh -c 'echo "@audio - memlock unlimited" >> /etc/security/limits.conf'
fi
echo "    Real-time limits configured."
echo ""

# !!! IMPORTANT: Steps related to debloating, disabling login managers,
# !!! enabling auto-login, and setting up .xinitrc for auto-start
# !!! have been removed as per your request.
# !!! You will handle these aspects manually.

# ====== 4. Install REAPER DAW ======
echo "--> Step 4: Downloading and installing REAPER."
echo "    Downloading REAPER from $REAPER_URL"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
wget -nc "$REAPER_URL" # -nc means "no clobber", won't re-download if file exists
echo "--> Download complete. Extracting..."
tar -xvf "$(basename "$REAPER_URL")"
cd reaper_linux_x86_64
echo "--> Running REAPER installer script with automated options..."
sudo ./install-reaper.sh --install /opt --integrate-desktop --usr-local-bin-symlink
echo "--> REAPER installation complete."
echo ""

# ====== 5. Build and Install Guitarix ======
echo "--> Step 5: Building and installing Guitarix."
echo "    Build progress and errors will be logged to $GUITARIX_BUILD_LOG"
echo "" > "$GUITARIX_BUILD_LOG" # Clear old log file

# Check for crucial build dependencies before starting
echo "    Checking for essential build tools (waf, gperf)..."
if ! command -v waf &> /dev/null || ! command -v gperf &> /dev/null; then
    echo "⛔ Error: Critical build dependencies for Guitarix are missing. This is unexpected." >> "$GUITARIX_BUILD_LOG"
    echo "    Please check $INSTALL_LOG_FILE for details on failed package installations."
    echo "    Exiting Guitarix build process."
    exit 1
fi
echo "    Essential build tools found."

cd "$BUILD_DIR"
if [ -d "guitarix" ]; then
    echo "    Existing Guitarix source found. Pulling latest changes..."
    cd guitarix
    git pull --recurse-submodules >> "$GUITARIX_BUILD_LOG" 2>&1
else
    echo "    Cloning the Guitarix repository from GitHub..."
    git clone https://github.com/brummer10/guitarix.git >> "$GUITARIX_BUILD_LOG" 2>&1
    cd guitarix
fi
echo "--> Repository ready."
echo "    Initializing and updating Git submodules..."
git submodule update --init --recursive >> "$GUITARIX_BUILD_LOG" 2>&1
echo "--> Submodules updated."
echo "    Configuring the Guitarix build with 'waf' for optimization..."
cd trunk
./waf configure --prefix=/usr --includeresampler --includeconvolver --optimization >> "$GUITARIX_BUILD_LOG" 2>&1
echo "--> Configuration complete. Building Guitarix code. This may take a while..."
./waf build >> "$GUITARIX_BUILD_LOG" 2>&1
echo "--> Build complete. Installing Guitarix. This requires your sudo password."
sudo ./waf install >> "$GUITARIX_BUILD_LOG" 2>&1
echo "--> Guitarix installation complete."
echo "    Guitarix build log is available at $GUITARIX_BUILD_LOG."
echo ""

# --- FINAL STEPS ---
echo "--------------------------------------------------------"
echo "✅ AntiX Audio Software Installation Complete!"
echo "--------------------------------------------------------"
echo "Please REBOOT your system NOW for all changes (especially group memberships and kernel) to take effect."
echo ""
echo "What to do next:"
echo "1. Reboot your system: sudo reboot"
echo "2. Review installation logs: tail -f $INSTALL_LOG_FILE"
echo "3. Review Guitarix build logs: tail -f $GUITARIX_BUILD_LOG"
echo "4. You can now proceed with your manual system stripping/debloating and auto-login configuration."
echo "5. Check audio group: groups $USER_NAME"
echo "6. Check real-time limits: cat /etc/security/limits.conf"
echo "7. You can safely remove the build directory with: rm -rf $BUILD_DIR"
echo ""
