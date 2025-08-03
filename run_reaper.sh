#!/bin/bash
# This script installs an @reboot cron job to automatically start the
# JACK audio server and REAPER at system boot.
# You only need to run this script once to set up the cron job.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the paths for the script. The script will be placed in the user's home directory.
SCRIPT_NAME="reaper-jack-startup.sh"
SCRIPT_PATH="$HOME/$SCRIPT_NAME"

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

# Function to find the card number of the USB audio device.
find_usb_device_card_number() {
    aplay -l | grep -oP 'card \K[0-9]+: Device \[USB Composite Device], device 0: USB Audio' | awk '{print $1}'
}

# --- Main Script Logic to be run by the cron job ---
run_service() {
    # Check for crucial audio permissions.
    # The user must be a member of the 'audio' group for low-latency performance.
    if ! groups | grep -q "audio"; then
        echo "WARNING: User not in the 'audio' group. Please add with 'sudo usermod -aG audio <username>' and reboot."
        echo ""
    fi

    # Check if JACK daemon is installed.
    if ! check_jack_installed; then
        echo "JACK daemon not found. Please install JACK to use Reaper."
        exit 1
    fi

    # Check for and stop any running JACK servers to prevent conflicts.
    if pidof jackd &> /dev/null; then
        echo "Existing JACK server found. Stopping it..."
        killall jackd
        sleep 1 # Give the system a moment to clean up.
    fi

    echo "Starting JACK server..."

    # Find the correct card number for your USB audio device.
    CARD_NUM=$(find_usb_device_card_number)

    if [ -n "$CARD_NUM" ]; then
        echo "USB Composite Device found on card $CARD_NUM. Using this device."
    else
        CARD_NUM=0
        echo "USB Composite Device not found. Defaulting to card 0 (built-in audio)."
    fi

    # The `jackd` command starts the server.
    # The cron job runs without a graphical display, so we use 'nohup' and '&'
    # to ensure it continues to run after the cron job's process finishes.
    nohup jackd -d alsa -d hw:$CARD_NUM -r 48000 -p 256 -n 2 &> "$HOME/jack-startup.log" &
    
    # Add a short delay to give the JACK server time to initialize.
    sleep 2

    echo "JACK server started. Check jack-startup.log for output."

    # Then, check if Reaper is installed.
    if check_reaper_installed; then
        echo "Reaper found. Launching Reaper..."
        reaper &
    else
        echo "Reaper not found. Please ensure it is installed."
        exit 1
    fi
}

# --- Installation Logic (to be run manually once) ---
echo "Installing the REAPER and JACK startup script as a cron job..."

# Create the script file with the necessary content.
# Using 'cat << EOF >' to write the whole script into a single file.
cat << EOF > "$SCRIPT_PATH"
#!/bin/bash
# This script is the backend for the cron job.
run_service() {
    if ! groups | grep -q "audio"; then
        echo "WARNING: User not in the 'audio' group. Please add with 'sudo usermod -aG audio <username>' and reboot."
        echo ""
    fi
    if ! command -v jackd &> /dev/null; then
        echo "JACK daemon not found. Please install JACK to use Reaper."
        exit 1
    fi
    if pidof jackd &> /dev/null; then
        killall jackd
        sleep 1
    fi
    echo "Starting JACK server..."
    CARD_NUM=\$(aplay -l | grep -oP 'card \K[0-9]+: Device \[USB Composite Device], device 0: USB Audio' | awk '{print \$1}')
    if [ -n "\$CARD_NUM" ]; then
        echo "USB Composite Device found on card \$CARD_NUM. Using this device."
    else
        CARD_NUM=0
        echo "USB Composite Device not found. Defaulting to card 0 (built-in audio)."
    fi
    nohup jackd -d alsa -d hw:\$CARD_NUM -r 48000 -p 256 -n 2 &> "$HOME/jack-startup.log" &
    sleep 2
    echo "JACK server started. Check jack-startup.log for output."
    if command -v reaper &> /dev/null; then
        echo "Reaper found. Launching Reaper..."
        reaper &
    else
        echo "Reaper not found. Please ensure it is installed."
        exit 1
    fi
}
run_service
EOF

# Make the script executable.
chmod +x "$SCRIPT_PATH"
echo "Script copied to $SCRIPT_PATH and made executable."

# Add the cron job entry.
# We first list all existing cron jobs, remove our old one if it exists,
# then add the new one, and pipe it all back to crontab.
(crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" ; echo "@reboot bash $SCRIPT_PATH") | crontab -

echo "--------------------------------------------------------"
echo "Installation Complete!"
echo "The REAPER and JACK startup script has been added as a cron job."
echo "It will automatically run when the system reboots."
echo ""
echo "To check your cron jobs, run: crontab -l"
echo "To remove the cron job, run: crontab -e and delete the corresponding line."
