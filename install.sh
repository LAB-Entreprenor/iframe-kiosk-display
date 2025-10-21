#!/usr/bin/env bash
# ----------------------------------------------------------
# Raspberry Pi / Linux Kiosk Display Installer (Root Only)
# ----------------------------------------------------------
# Installs Flask-based kiosk display environment system-wide.
# Creates systemd services, autostart, and desktop entry.
# ----------------------------------------------------------

set -euo pipefail

# --- Require root ---
if [ "$EUID" -ne 0 ]; then
  echo "Warning: This installer must be run as root (use: sudo ./install-kiosk.sh)"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(logname 2>/dev/null || whoami)"
USER_HOME="$(eval echo "~$USER_NAME")"
SYSTEM_BIN="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
DESKTOP_DIR="/usr/local/share/applications"
APP_NAME="display-kiosk"
LOGFILE="/tmp/kiosk-install.log"
SERVICE_FILE_APP="$SYSTEMD_DIR/${APP_NAME}.service"
SERVICE_FILE_SESSION="$SYSTEMD_DIR/${APP_NAME}-session.service"

echo "Installing Flask Kiosk Display for user '$USER_NAME'..." | tee "$LOGFILE"

# --- 1. Dependencies ---
echo "[1/5] Installing dependencies..." | tee -a "$LOGFILE"
apt update -y >>"$LOGFILE" 2>&1
apt install -y \
  python3 python3-flask git \
  chromium unclutter xdotool x11-xserver-utils jq \
  xserver-xorg xdg-utils >>"$LOGFILE" 2>&1

# --- 2. Create systemd service files ---
echo "[2/5] Creating systemd services..." | tee -a "$LOGFILE"

cat <<EOF > "$SERVICE_FILE_APP"
[Unit]
Description=Flask Kiosk Display App
After=network.target

[Service]
#User=$USER_NAME
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 $PROJECT_DIR/app.py
Restart=always
RestartSec=5
StandardOutput=file:/tmp/display-kiosk.log
StandardError=file:/tmp/display-kiosk-error.log

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > "$SERVICE_FILE_SESSION"
[Unit]
Description=Chromium Kiosk Session
After=graphical.target network.target $APP_NAME.service
Requires=$APP_NAME.service

[Service]
#User=$USER_NAME
#Group=$USER_NAME
Environment=DISPLAY=:0
Environment=XAUTHORITY=$USER_HOME/.Xauthority
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u $USER_NAME)
ExecStart=/usr/bin/chromium --noerrdialogs --disable-infobars --kiosk http://127.0.0.1:5000/
Restart=always
RestartSec=3

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable --now "$APP_NAME.service" "$APP_NAME-session.service"

# --- 3. Desktop entry for manager ---
echo "[3/5] Creating desktop entry..." | tee -a "$LOGFILE"
mkdir -p "$DESKTOP_DIR"

# Install icon if available
ICON_SRC="$PROJECT_DIR/assets/kiosk-icon.png"
ICON_DST="/usr/share/pixmaps/kiosk-icon.png"

if [ -f "$ICON_SRC" ]; then
  echo "Installing custom icon..." | tee -a "$LOGFILE"
  install -Dm644 "$ICON_SRC" "$ICON_DST"
else
  echo "No custom icon found, using system default 'display' icon." | tee -a "$LOGFILE"
  ICON_DST="display"
fi

DESKTOP_FILE="$DESKTOP_DIR/KioskDisplayManager.desktop"

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Kiosk Display Manager
Exec=/usr/bin/chromium http://127.0.0.1:5000/manage
Icon=$ICON_DST
Terminal=false
Categories=Network;Utility;
Comment=Flask-based kiosk display management dashboard
EOF

chmod 644 "$DESKTOP_FILE"
update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

# --- 4. Configuration file ---
CONFIG_FILE="$PROJECT_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating default configuration file..." | tee -a "$LOGFILE"
  cat <<EOF > "$CONFIG_FILE"
{
  "urls": [
    "https://avgangsvisning.skyss.no/?stops=NSR:StopPlace:30938%7CNSR:Quay:53264&type=TERMINAL&colors=dark"
  ],
  "layout": "auto",
  "generator_url": "https://avgangsvisning.skyss.no"
}
EOF
else
  echo "Keeping existing configuration file: $CONFIG_FILE" | tee -a "$LOGFILE"
fi

# --- 5. Ownership + summary ---
echo "[5/5] Finalizing setup..." | tee -a "$LOGFILE"
chown "$USER_NAME:$USER_NAME" "$CONFIG_FILE" || true

echo "----------------------------------------------------------"
echo " Kiosk Display Installation Complete!"
echo "----------------------------------------------------------"
echo " Installed for user:  $USER_NAME"
echo " Flask app dir:       $PROJECT_DIR"
echo " Config file:         $CONFIG_FILE"
echo " Service files:       $SERVICE_FILE_APP"
echo "                      $SERVICE_FILE_SESSION"
echo " Desktop shortcut:    $DESKTOP_FILE"
echo " Web Manager:         http://localhost:5000/manage"
echo " Install log:         $LOGFILE"
echo "----------------------------------------------------------"
echo " To restart services manually:"
echo "   sudo systemctl restart ${APP_NAME}.service ${APP_NAME}-session.service"
echo
echo "✅ Setup complete! The kiosk will auto-start after reboot."
echo
read -p "Press [Enter] to reboot now or Ctrl+C to cancel..."
reboot
