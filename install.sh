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
  echo "This installer must be run as root (use: sudo ./install-kiosk.sh)"
  exit 1
fi

APP_NAME="display-kiosk"
PROJECT_DIR="/opt/${APP_NAME}"
USER_NAME="$(logname 2>/dev/null || whoami)"
USER_HOME="$(eval echo "~$USER_NAME")"
SYSTEMD_DIR="/etc/systemd/system"
DESKTOP_DIR="/usr/share/applications"
LOGFILE="/tmp/${APP_NAME}-install.log"
SERVICE_FILE_APP="$SYSTEMD_DIR/${APP_NAME}.service"
SERVICE_FILE_SESSION="$SYSTEMD_DIR/${APP_NAME}-session.service"

echo "----------------------------------------------------------"
echo " Installing Flask Kiosk Display for user: $USER_NAME"
echo "----------------------------------------------------------"
echo "Logging to: $LOGFILE"
echo

# --- 1. Dependencies ---
echo "[1/5] Installing dependencies..." | tee "$LOGFILE"
apt update -y >>"$LOGFILE" 2>&1
apt install -y \
  python3 python3-flask git gunicorn python3-pip \
  chromium unclutter xdotool x11-xserver-utils jq \
  xserver-xorg xdg-utils >>"$LOGFILE" 2>&1



# --- 2. Copy application files ---
echo "[2/5] Deploying application to $PROJECT_DIR..." | tee -a "$LOGFILE"
mkdir -p "$PROJECT_DIR"

# Copy main files
install -m 644 app.py "$PROJECT_DIR/app.py"
install -m 755 kiosk-session.sh "$PROJECT_DIR/kiosk-session.sh"

# Copy template and asset folders if they exist
[ -d "templates" ] && cp -r templates "$PROJECT_DIR/"
[ -d "assets" ] && cp -r assets "$PROJECT_DIR/"

# --- 3. Create systemd service files ---
echo "[3/5] Creating systemd services..." | tee -a "$LOGFILE"

# --- Flask App Service ---
cat <<EOF > "$SERVICE_FILE_APP"
[Unit]
Description=Flask Kiosk Display App
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=5
StandardOutput=append:/var/log/${APP_NAME}.log
StandardError=append:/var/log/${APP_NAME}-error.log

[Install]
WantedBy=multi-user.target
EOF

# --- Kiosk Chromium Session Service ---
cat <<EOF > "$SERVICE_FILE_SESSION"
[Unit]
Description=Chromium Kiosk Session
After=graphical.target network-online.target ${APP_NAME}.service
Wants=network-online.target
Requires=${APP_NAME}.service

[Service]
User=$USER_NAME
Group=$USER_NAME
Environment=DISPLAY=:0
Environment=XAUTHORITY=$USER_HOME/.Xauthority
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u $USER_NAME)
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash /opt/${APP_NAME}/kiosk-session.sh
Restart=always
RestartSec=3

[Install]
WantedBy=graphical.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable --now "$APP_NAME.service" "$APP_NAME-session.service"

# --- 4. Desktop entry for manager ---
echo "[4/5] Creating desktop entry..." | tee -a "$LOGFILE"

ICON_SRC="$PROJECT_DIR/assets/kiosk-icon.png"
ICON_DST="/usr/share/pixmaps/kiosk-icon.png"
if [ -f "$ICON_SRC" ]; then
  echo "Installing custom icon..." | tee -a "$LOGFILE"
  install -Dm644 "$ICON_SRC" "$ICON_DST"
else
  ICON_DST="display"
fi

DESKTOP_FILE="$DESKTOP_DIR/KioskDisplayManager.desktop"

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Kiosk Display Manager
Exec=/usr/bin/chromium --app=http://127.0.0.1:5000/manage
Icon=$ICON_DST
Terminal=false
Categories=Network;Utility;
Comment=Flask-based kiosk display management dashboard
EOF

chmod 644 "$DESKTOP_FILE"
update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

# --- 5. Configuration file ---
CONFIG_FILE="$PROJECT_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating default configuration file..." | tee -a "$LOGFILE"
  cat <<EOF > "$CONFIG_FILE"
{
  "urls": [
    "https://avgangsvisning.skyss.no/view/#/?stops=NSR:StopPlace:58536%7CNSR:Quay:51856,NSR:StopPlace:58536%7CNSR:Quay:99918,NSR:StopPlace:58536%7CNSR:Quay:105980,NSR:StopPlace:58536%7CNSR:Quay:107744,NSR:StopPlace:58536%7CNSR:Quay:99927,NSR:StopPlace:58536%7CNSR:Quay:107747&viewFreq=10000&type=TERMINAL&colors=dark"
  ],
  "layout": "auto",
  "generator_url": "https://avgangsvisning.skyss.no",
  "dashboard_enabled": true
}
EOF
else
  echo "Keeping existing configuration file: $CONFIG_FILE" | tee -a "$LOGFILE"
fi

# --- Permissions ---
chown -R "$USER_NAME:$USER_NAME" "$PROJECT_DIR"

# Create persistent logs
touch /var/log/${APP_NAME}.log /var/log/${APP_NAME}-error.log
chown "$USER_NAME":"$USER_NAME" /var/log/${APP_NAME}*.log

echo
echo "----------------------------------------------------------"
echo " ✅ Installation Complete!"
echo "----------------------------------------------------------"
echo " Installed for user:  $USER_NAME"
echo " Application dir:     $PROJECT_DIR"
echo " Config file:         $CONFIG_FILE"
echo " Services:            $SERVICE_FILE_APP"
echo "                      $SERVICE_FILE_SESSION"
echo " Desktop shortcut:    $DESKTOP_FILE"
echo " Web Manager:         http://localhost:5000/manage"
echo " Logs:                /var/log/${APP_NAME}.log"
echo "----------------------------------------------------------"
echo " To restart services manually:"
echo "   sudo systemctl restart ${APP_NAME}.service ${APP_NAME}-session.service"
echo
read -p "Press [Enter] to reboot now or Ctrl+C to cancel..."
reboot
