#!/bin/bash

set -e

# ====== 1. Update and Install Dependencies ======
echo "[*] Updating and installing audio-related dependencies..."
sudo apt update
sudo apt install -y \
    reaper jackd2 qjackctl \
    alsa-utils nano \
    build-essential dkms linux-headers-$(uname -r)

# ====== 2. Disable SLiM Login Manager ======
echo "[*] Disabling SLiM login manager..."
sudo ln -sf /etc/sv/slim /etc/runit/runsvdir/default.disabled || true
sudo rm -f /etc/runit/runsvdir/default/slim

# ====== 3. Enable Auto-login on TTY1 ======
echo "[*] Enabling auto-login for tty1..."
sudo mkdir -p /etc/sv/agetty-tty1/conf
echo 'exec /sbin/agetty --autologin vboxuser --noclear tty1 linux' | sudo tee /etc/sv/agetty-tty1/conf/run
sudo chmod +x /etc/sv/agetty-tty1/conf/run
sudo ln -sf /etc/sv/agetty-tty1 /etc/runit/runsvdir/default/

# ====== 4. Create .xinitrc for Auto Start ======
echo "[*] Setting up REAPER + JACK launch at login..."
cat <<EOF > ~/.xinitrc
#!/bin/bash

# Start JACK
jackd -d alsa &

# Wait for JACK to start
sleep 2

# Start REAPER
reaper

# Optional fallback to shell
exec bash
EOF
chmod +x ~/.xinitrc

# ====== 5. Auto-start X on login ======
echo "[*] Adding startx to .bash_profile..."
echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> ~/.bash_profile

# ====== 6. Remove Unneeded GUI Apps ======
echo "[*] Removing GUI-related packages..."
sudo apt purge -y desktop-defaults* rox-filer spacefm* icewm* slim* yad*
sudo apt autoremove -y
sudo apt clean

echo "✅ Setup complete. Reboot to test auto-login + JACK + REAPER."
