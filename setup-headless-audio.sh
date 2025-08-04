#!/bin/bash
# === SETUP HEADLESS AUTOSTART FOR ANTI-X ===
# Tested for antiX 23.2 base/runit edition

# 1. Disable SLiM Login Manager (GUI Login Screen)
sudo sv down slim
sudo rm -f /etc/runit/runsvdir/default/slim

# 2. Enable auto-login on TTY1
AUTOLOGIN_SERVICE="/etc/sv/agetty-tty1/conf"
sudo mkdir -p "$AUTOLOGIN_SERVICE"
echo 'exec /sbin/agetty --autologin vboxuser --noclear tty1 linux' | sudo tee "$AUTOLOGIN_SERVICE/run"
sudo chmod +x "$AUTOLOGIN_SERVICE/run"
sudo ln -sf /etc/sv/agetty-tty1 /etc/runit/runsvdir/default/

# 3. Configure .bash_profile to auto-run X and REAPER + JACK
PROFILE_SCRIPT="/home/vboxuser/.bash_profile"

cat << 'EOF' | sudo tee "$PROFILE_SCRIPT"
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
EOF

# 4. Configure .xinitrc to start JACK and REAPER
XINITRC="/home/vboxuser/.xinitrc"

cat << 'EOF' | sudo tee "$XINITRC"
#!/bin/bash

# Start JACK
jackd -d alsa &

# Wait for JACK to initialize
sleep 2

# Start REAPER
reaper

# If REAPER exits, fallback to icewm
exec icewm-session
EOF

sudo chmod +x "$XINITRC"
sudo chown vboxuser:vboxuser "$PROFILE_SCRIPT" "$XINITRC"

echo "✅ Setup complete. Reboot to test auto-login with JACK + REAPER launch."
