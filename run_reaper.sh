#!/bin/bash
# This script is designed to run Reaper at system startup using a cron job.
# It first checks if the 'reaper' executable is available in the system's PATH.

# Function to check if Reaper is installed and available via the symlink.
check_reaper_installed() {
    # The 'command -v' command checks if a command exists.
    # The previous installation script created a symlink to /usr/local/bin/reaper.
    if command -v reaper &> /dev/null; then
        return 0  # Reaper is found.
    else
        return 1  # Reaper not found.
    fi
}

# --- Main Script Logic ---
if check_reaper_installed; then
    echo "Reaper found. Launching Reaper..."
    # Launch Reaper. The '&' sends it to the background so the script can finish.
    reaper &
else
    echo "Reaper not found. Please ensure it is installed and the symlink exists."
    echo "To install Reaper, run the 'Build Guitarix and Install Reaper Script' from the Canvas."
    exit 1
fi