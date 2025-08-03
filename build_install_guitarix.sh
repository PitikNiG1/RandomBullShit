#!/bin/bash

set -e

echo "--------------------------------------------------------"
echo "  Guitarix Build and Install Script"
echo "--------------------------------------------------------"
echo ""

# --- VARIABLES ---
# The directory where the Guitarix repository will be cloned.
# This will be created in your home directory.
BUILD_DIR="$HOME/guitarix_build"

# The dependencies required to build Guitarix.
# This list is based on the guide you provided.
# Note: libjack-dev is chosen over libjack-jackd2-dev for simplicity.
DEPENDENCIES="gperf intltool libavahi-gobject-dev libbluetooth-dev libboost-dev libboost-iostreams-dev libboost-system-dev libboost-thread-dev libeigen3-dev libgtk-3-dev libgtkmm-3.0-dev libjack-dev liblilv-dev liblrdf0-dev libsndfile1-dev libfftw3-dev lv2-dev python3 python-is-python3 sassc"

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

# --- STEP 3: CLONE THE GUITARIX REPOSITORY ---
echo "--> Step 3: Cloning the Guitarix repository from GitHub."
git clone https://github.com/brummer10/guitarix.git
cd guitarix
echo "--> Repository cloned successfully."
echo ""

# --- STEP 4: UPDATE GIT SUBMODULES ---
echo "--> Step 4: Initializing and updating Git submodules."
git submodule update --init --recursive
echo "--> Submodules updated."
echo ""

# --- STEP 5: CONFIGURE THE BUILD ---
echo "--> Step 5: Configuring the build with 'waf'."
cd trunk
./waf configure --prefix=/usr --includeresampler --includeconvolver --optimization
echo "--> Configuration complete."
echo ""

# --- STEP 6: BUILD THE CODE ---
echo "--> Step 6: Building the Guitarix code. This may take a while."
./waf build
echo "--> Build complete."
echo ""

# --- STEP 7: INSTALL THE PLUGINS AND APPLICATION ---
echo "--> Step 7: Installing Guitarix. This requires your sudo password."
sudo ./waf install
echo "--> Installation complete."
echo ""

echo "--------------------------------------------------------"
echo "  Script Finished!"
echo "--------------------------------------------------------"
echo "The Guitarix LV2 plugins should now be installed."
echo ""
echo "To use them in Reaper, remember to:"
echo "1. Launch Reaper."
echo "2. Go to Options -> Preferences -> Plugins -> VST."
echo "3. Click 'Clear cache/re-scan'."
echo ""
echo "You can now safely remove the build directory with the following command:"
echo "rm -rf $BUILD_DIR"