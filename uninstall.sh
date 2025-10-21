#!/usr/bin/env bash
# ----------------------------------------------------------
# Raspberry Pi / Linux Kiosk Display Uninstaller
# ----------------------------------------------------------
# Removes all kiosk display files, services, and shortcuts.
# ----------------------------------------------------------

set -euo pipefail

APP_NAME="display-kiosk"
PROJECT_DIR="/opt/${APP_NAME}"
SYSTEMD_DIR="/etc/systemd/system"
DESKTOP_DIR="/usr/local/share/applications"
SERVICE_FILE_APP="$SYSTEMD_DIR/${APP_NAME}.service"
SERVICE_FILE_SESSION="$SYSTEMD_DIR/${APP_NAME}-session.service"
DESKTOP_FILE="$DESKTOP_DIR/KioskDisplayManager.desktop"
ICON_FILE="/usr/share/pixmaps/kiosk-icon.png"
LOGFILE="/tmp/${APP_NAME}-uninstall.log"

echo "----------------------------------------------------------"
echo " 🧹  Uninstalling Flask Kiosk Display"
echo "----------------------------------------------------------"
echo "Logging to: $LOGFILE"
echo

read -p "⚠️  Are you sure you want to remove all kiosk files and services? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Uninstall cancelled."
  exit 0
fi

# --- 1. Stop and disable services ---
echo "[1/4] Stopping services..." | tee "$LOGFILE"

for svc in "$APP_NAME.service" "$APP_NAME-session.service"; do
  if systemctl list-units --full -all | grep -Fq "$svc"; then
    echo "Disabling and stopping $svc..." | tee -a "$LOGFILE"
    systemctl disable --now "$svc" >>"$LOGFILE" 2>&1 || true
    rm -f "$SYSTEMD_DIR/$svc"
  else
    echo "Service $svc not found, skipping..." | tee -a "$LOGFILE"
  fi
done

systemctl daemon-reload

# --- 2. Remove application files ---
echo "[2/4] Removing application directory..." | tee -a "$LOGFILE"
if [ -d "$PROJECT_DIR" ]; then
  rm -rf "$PROJECT_DIR"
  echo "Removed: $PROJECT_DIR" | tee -a "$LOGFILE"
else
  echo "App directory not found: $PROJECT_DIR" | tee -a "$LOGFILE"
fi

# --- 3. Remove desktop shortcut and icon ---
echo "[3/4] Removing desktop shortcut and icon..." | tee -a "$LOGFILE"

if [ -f "$DESKTOP_FILE" ]; then
  rm -f "$DESKTOP_FILE"
  echo "Removed: $DESKTOP_FILE" | tee -a "$LOGFILE"
else
  echo "No desktop entry found." | tee -a "$LOGFILE"
fi

if [ -f "$ICON_FILE" ]; then
  rm -f "$ICON_FILE"
  echo "Removed: $ICON_FILE" | tee -a "$LOGFILE"
fi

update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

# --- 4. Cleanup logs ---
echo "[4/4] Cleaning up logs..." | tee -a "$LOGFILE"
rm -f /tmp/display-kiosk*.log /tmp/display-kiosk*.error.log 2>/dev/null || true

echo
echo "----------------------------------------------------------"
echo " ✅ Uninstallation complete!"
echo "----------------------------------------------------------"
echo "Removed application:   $PROJECT_DIR"
echo "Removed services:      $SERVICE_FILE_APP"
echo "                       $SERVICE_FILE_SESSION"
echo "Removed desktop entry: $DESKTOP_FILE"
echo "Removed icon:          $ICON_FILE"
echo "----------------------------------------------------------"
echo "You may need to reboot to finalize service cleanup."
echo
read -p "Press [Enter] to reboot now or Ctrl+C to cancel..."
reboot
