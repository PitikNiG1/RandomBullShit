#!/bin/bash
# This script installs a systemd service to automatically start the
# JACK audio server and REAPER at boot.
# You only need to run this script once to set up the service.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the paths for the script and the systemd service file.
SCRIPT_NAME="reaper-jack-startup.sh"
SERVICE_NAME="reaper-jack-startup.service"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"

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

# --- Main Script Logic to be run by systemd ---
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
    nohup jackd -d alsa -d hw:$CARD_NUM -r 48000 -p 256 -n 2 &> jack-startup.log &
    
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
echo "Installing the REAPER and JACK startup service..."

# First, check if the script is being run to install the service.
if [[ "$1" != "run" ]]; then
    # Create the script file with the necessary content.
    echo "#!/bin/bash" > "$SCRIPT_NAME"
    echo "# This script is the backend for the systemd service." >> "$SCRIPT_NAME"
    echo "cd $HOME" >> "$SCRIPT_NAME"
    echo "source $0 run" >> "$SCRIPT_NAME"

    # Make the script executable and move it to a system-wide bin directory.
    chmod +x "$SCRIPT_NAME"
    sudo mv "$SCRIPT_NAME" "$SCRIPT_PATH"
    echo "Script copied to $SCRIPT_PATH"

    # Create the systemd service file.
    sudo sh -c "cat << EOF > '$SERVICE_FILE_PATH'
[Unit]
Description=REAPER and JACK Audio Server Startup
After=network.target sound.target

[Service]
Type=forking
User=%i
Environment=\"XDG_RUNTIME_DIR=/run/user/%U\"
ExecStart=$SCRIPT_PATH
TimeoutSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

    echo "Service file created at $SERVICE_FILE_PATH"

    # Reload systemd, enable and start the service.
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"

    echo "--------------------------------------------------------"
    echo "Installation Complete!"
    echo "The REAPER and JACK startup service is now active."
    echo "It will automatically start at every boot."
    echo ""
    echo "To check the service status, run: sudo systemctl status $SERVICE_NAME"
    echo "To disable the service, run: sudo systemctl disable $SERVICE_NAME"

else
    # This is the "run" part of the script, executed by the systemd service.
    run_service
fi
