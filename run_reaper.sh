#!/bin/bash
# This script is designed to run Reaper at system startup.
# It first checks if the JACK audio server is running, and if not, it starts it.
# Then, it launches Reaper, which can then connect to the JACK server.

# Function to check if Reaper is installed and available via the symlink.
check_reaper_installed() {
    if command -v reaper &> /dev/null; then
        return 0  # Reaper is found.
    else
        return 1  # Reaper not found.
    fi
}

# Function to check if JACK is installed.
check_jack_installed() {
    if command -v jackd &> /dev/null; then
        return 0 # jackd is found.
    else
        return 1 # jackd not found.
    fi
}

# --- Main Script Logic ---
# First, check if JACK daemon is installed.
if check_jack_installed; then
    echo "JACK daemon found. Proceeding with checks..."
else
    echo "JACK daemon not found. Please install JACK to use Reaper."
    echo "You may need to run 'sudo apt install jackd2' to fix this."
    exit 1
fi

# Check if a JACK server is already running to avoid starting a new one.
# 'pidof' checks for the process ID of a running program.
if ! pidof jackd &> /dev/null; then
    echo "JACK server is not running. Starting the server..."
    # The `jackd` command starts the server.
    # The options used here are:
    # -d alsa: Use the ALSA audio driver.
    # -d hw:CARD_NUM: Specifies the audio device. '0' is usually the built-in sound card,
    #                  while external USB interfaces might be 1, 2, etc.
    # -r 48000: Sets the sample rate to 48kHz.
    # -p 256: Sets the buffer size to 256 frames.
    # -n 2: Sets the number of periods/buffers to 2.
    # We use 'nohup' and '&' to run it in the background and detach from the terminal.
    nohup jackd -d alsa -d hw:0 -r 48000 -p 256 -n 2 &> jack-startup.log &
    echo "JACK server started. Check jack-startup.log for output."
else
    echo "JACK server is already running."
fi

# Then, check if Reaper is installed.
if check_reaper_installed; then
    echo "Reaper found. Launching Reaper..."
    # Launch Reaper. The '&' sends it to the background so the script can finish.
    reaper &
else
    echo "Reaper not found. Please ensure it is installed and the symlink exists."
    echo "To install Reaper, run the 'Build Guitarix and Install Reaper Script' from the Canvas."
    exit 1
fi
