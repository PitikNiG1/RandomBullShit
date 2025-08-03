#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--------------------------------------------------------"
echo "  Guitarix Build and Install Script"
echo "--------------------------------------------------------"
echo ""

# --- VARIABLES ---
# The directory where the build and downloads will happen.
# This will be created in your home directory.
BUILD_DIR="$HOME/audio_software_build"

# URL for the Reaper Linux build
REAPER_URL="https://www.reaper.fm/files/7.x/reaper742_linux_x86_64.tar.xz"

# The dependencies required to build Guitarix and download Reaper.
# This list is based on your provided list and ensures C++ compilers and other tools are available.
# Note: 'icpc' is a proprietary compiler and cannot be installed via apt.
DEPENDENCIES="build-essential clang gperf intltool libavahi-gobject-dev libbluetooth-dev libboost-dev libboost-iostreams-dev libboost-system-dev libboost-thread-dev libeigen3-dev libgtk-3-dev libgtkmm-3.0-dev libjack-dev liblilv-dev liblrdf0-dev libsndfile1-dev libfftw3-dev lv2-dev python3 python-is-python3 sassc wget fonts-roboto faust jackd2"

# --- STEP 1: INSTALL BUILD DEPENDENCIES ---
echo "--> Step 1: Installing build dependencies. This may take a few minutes."
echo "    The following packages will be installed: $DEPENDENCIES"
sudo apt update
sudo apt install -y $DEPENDENCIES
echo "--> Dependencies installed successfully."
echo ""

# --- STEP 2: PREPARE THE BUILD DIRECTORY ---
echo "--> Step 2: Preparing the build directory."
if [ -d "$BUILD_DIR" ]; then
    echo "    Existing build directory found. Removing old directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
echo "--> Directory $BUILD_DIR is ready."
echo ""

# --- STEP 3: DOWNLOAD AND INSTALL REAPER ---
echo "--> Step 3: Downloading and installing Reaper."
echo "    Downloading Reaper from $REAPER_URL"
wget "$REAPER_URL"
echo "--> Download complete. Extracting..."
tar -xvf reaper742_linux_x86_64.tar.xz
cd reaper_linux_x86_64
echo "--> Running Reaper installer script with automated options..."
# The following command runs the installer non-interactively with specific options.
# --install /opt: Installs to the /opt directory.
# --integrate-desktop: Creates desktop shortcuts and file associations.
# --usr-local-bin-symlink: Creates a symlink to /usr/local/bin for easy command-line access.
sudo ./install-reaper.sh --install /opt --integrate-desktop --usr-local-bin-symlink
echo "--> Reaper installation complete."
echo ""

# --- STEP 4: CLONE THE GUITARIX REPOSITORY ---
echo "--> Step 4: Cloning the Guitarix repository from GitHub."
cd "$BUILD_DIR"
git clone https://github.com/brummer10/guitarix.git
cd guitarix
echo "--> Repository cloned successfully."
echo ""

# --- STEP 5: UPDATE GIT SUBMODULES ---
echo "--> Step 5: Initializing and updating Git submodules."
git submodule update --init --recursive
echo "--> Submodules updated."
echo ""

# --- STEP 6: CONFIGURE THE GUITARIX BUILD ---
echo "--> Step 6: Configuring the Guitarix build with 'waf'."
cd trunk
# The '--optimization' flag enables compiler optimizations, including support for
# modern CPU instruction sets like x86-64-v3, to improve performance.
echo "--> Configuring the build for optimization and modern CPU instruction sets."
./waf configure --prefix=/usr --includeresampler --includeconvolver --optimization
echo "--> Configuration complete."
echo ""

# --- STEP 7: BUILD THE GUITARIX CODE ---
echo "--> Step 7: Building the Guitarix code. This may take a while."
./waf build
echo "--> Build complete."
echo ""

# --- STEP 8: INSTALL THE GUITARIX PLUGINS AND APPLICATION ---
echo "--> Step 8: Installing Guitarix. This requires your sudo password."
sudo ./waf install
echo "--> Guitarix installation complete."
echo ""

echo "--------------------------------------------------------"
echo "  Script Finished!"
echo "--------------------------------------------------------"
echo "Both Guitarix LV2 plugins and the Reaper DAW are now installed."
echo ""
echo "To use them, remember to:"
echo "1. Launch Reaper."
echo "2. Go to Options -> Preferences -> Plugins -> VST."
echo "3. Click 'Clear cache/re-scan'."
echo ""
echo "You can now safely remove the build directory with the following command:"
echo "rm -rf $BUILD_DIR"
