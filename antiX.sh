#!/bin/bash
# This script automates the setup of antiX Linux for a headless (no desktop environment)
# audio workstation, installing REAPER and Guitarix, and optimizing for low-latency.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--------------------------------------------------------"
echo "  AntiX Headless Audio Workstation Setup Script"
echo "--------------------------------------------------------"
echo ""

# --- VARIABLES ---
USER_NAME=$(whoami) # Automatically detect the current user
BUILD_DIR="$HOME/audio_software_build"
REAPER_URL="https://www.reaper.fm/files/7.x/reaper742_linux_x86_64.tar.xz"

# Dependencies for building Guitarix and general audio tools, split to handle jackd2 issue
JACK_DEPENDENCIES="jackd2 libjack-jackd2-0"
CORE_DEPENDENCIES="git build-essential clang gperf intltool libavahi-gobject-dev libbluetooth-dev libboost-dev libboost-iostreams-dev libboost-system-dev libboost-thread-dev libeigen3-dev libgtk-3-dev libgtkmm-3.0-dev libjack-dev liblilv-dev liblrdf0-dev libsndfile1-dev libfftw3-dev lv2-dev python3 python-is-python3 sassc wget fonts-roboto faust alsa-utils nano dkms linux-headers-$(uname -r)"

# Packages to purge for debloating antiX's default desktop environment
DEBLOAT_PACKAGES="desktop-defaults* rox-filer spacefm* icewm* slim* yad* lightdm* openbox*" # Expanded list for antiX/Debian variants

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

# First, install the JACK dependencies separately to resolve the dependency issue
echo "--> Step 1.1: Installing JACK daemon and libraries..."
echo "    The following packages will be installed: $JACK_DEPENDENCIES"
sudo apt install -y $JACK_DEPENDENCIES
echo "--> JACK components installed successfully."
echo ""

# Now install the rest of the dependencies
echo "--> Step 1.2: Installing remaining essential dependencies."
echo "    The following packages will be installed: $CORE_DEPENDENCIES"
sudo apt install -y $CORE_DEPENDENCIES
echo "--> Remaining dependencies installed successfully."
echo ""

# ====== 2. Install Real-time Kernel (if available and not already installed) ======
echo "--> Step 2: Checking for and installing a real-time (RT) kernel..."
# antiX often has a low-latency kernel by default, but a specific RT kernel might be available.
# This command attempts to install a common RT kernel package for Debian-based systems.
RT_KERNEL_PACKAGE="linux-image-rt-amd64"
if ! dpkg -l | grep -q "$RT_KERNEL_PACKAGE"; then
    echo "    Installing $RT_KERNEL_PACKAGE..."
    sudo apt install -y "$RT_KERNEL_PACKAGE" || echo "    Warning: $RT_KERNEL_PACKAGE not found or failed to install. Continuing with current kernel."
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

# ====== 4. Debloat and Configure Headless Graphical Auto-start ======
echo "--> Step 4: Configuring headless graphical auto-start and debloating."

# Disable default login manager (e.g., SLiM or LightDM for antiX)
echo "    Attempting to disable common login managers..."
sudo ln -sf /etc/sv/slim /etc/runit/runsvdir/default.disabled || true # For antiX/runit SLiM
sudo rm -f /etc/runit/runsvdir/default/slim || true # Remove direct link if it exists

# For systemd-based login managers (e.g. LightDM in some Debian flavors antiX might pull)
if command -v systemctl &> /dev/null; then
    sudo systemctl stop lightdm.service || true
    sudo systemctl disable lightdm.service || true
fi
echo "    Login managers disabled."

# Enable Auto-login on TTY1 for the current user (using runit's agetty)
echo "    Enabling auto-login for tty1 for user '$USER_NAME'..."
sudo mkdir -p /etc/sv/agetty-tty1/conf
echo "exec /sbin/agetty --autologin $USER_NAME --noclear tty1 linux" | sudo tee /etc/sv/agetty-tty1/conf/run > /dev/null
sudo chmod +x /etc/sv/agetty-tty1/conf/run
sudo ln -sf /etc/sv/agetty-tty1 /etc/runit/runsvdir/default/
echo "    Auto-login configured."

# Create .xinitrc for Auto Start of JACK and REAPER
echo "    Setting up .xinitrc to launch JACK and REAPER at login..."
cat <<EOF > "$HOME/.xinitrc"
#!/bin/bash

# Ensure XDG_RUNTIME_DIR is set for graphical applications run from a tty
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Start JACK (nohup and & to run in background after .xinitrc finishes)
nohup jackd -d alsa &> "$HOME/jack-startup.log" &

# Wait for JACK to start
sleep 2

# Start REAPER
nohup reaper &> "$HOME/reaper-startup.log" &

# Optional: Fallback to shell if REAPER exits or for troubleshooting
# exec bash
EOF
chmod +x "$HOME/.xinitrc"
echo "    .xinitrc created."

# Auto-start X on login (if not already running)
echo "    Adding startx to .bash_profile..."
if ! grep -q 'exec startx' "$HOME/.bash_profile"; then
    echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$HOME/.bash_profile"
    echo "    startx added to .bash_profile."
else
    echo "    startx already present in .bash_profile."
fi
echo ""

# Remove Unneeded GUI Apps for deeper debloating
echo "    Removing unneeded GUI-related packages for debloating..."
sudo apt purge -y $DEBLOAT_PACKAGES || true # Use || true to prevent script from failing if package isn't found
sudo apt autoremove -y
sudo apt clean
echo "    GUI packages removed."
echo ""

# ====== 5. Install REAPER DAW ======
echo "--> Step 5: Downloading and installing REAPER."
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

# ====== 6. Build and Install Guitarix ======
echo "--> Step 6: Building and installing Guitarix."
cd "$BUILD_DIR"
if [ -d "guitarix" ]; then
    echo "    Existing Guitarix source found. Pulling latest changes..."
    cd guitarix
    git pull --recurse-submodules
else
    echo "    Cloning the Guitarix repository from GitHub..."
    git clone https://github.com/brummer10/guitarix.git
    cd guitarix
fi
echo "--> Repository ready."
echo "    Initializing and updating Git submodules..."
git submodule update --init --recursive
echo "--> Submodules updated."
echo "    Configuring the Guitarix build with 'waf' for optimization..."
cd trunk
./waf configure --prefix=/usr --includeresampler --includeconvolver --optimization
echo "--> Configuration complete. Building Guitarix code. This may take a while..."
./waf build
echo "--> Build complete. Installing Guitarix. This requires your sudo password."
sudo ./waf install
echo "--> Guitarix installation complete."
echo ""

# --- FINAL STEPS ---
echo "--------------------------------------------------------"
echo "✅ AntiX Headless Audio Setup Complete!"
echo "--------------------------------------------------------"
echo "Please REBOOT your system NOW for all changes (especially group memberships and kernel) to take effect."
echo ""
echo "After reboot, the system should automatically log in, start JACK, and launch REAPER."
echo ""
echo "Troubleshooting & Verification:"
echo "1. Jack startup log: tail -f ~/jack-startup.log"
echo "2. Reaper startup log: tail -f ~/reaper-startup.log"
echo "3. Check audio group: groups $USER_NAME"
echo "4. Check real-time limits: cat /etc/security/limits.conf"
echo "5. You can safely remove the build directory with: rm -rf $BUILD_DIR"
echo ""
