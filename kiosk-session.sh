#!/usr/bin/env bash
# ----------------------------------------------------------
# Chromium Kiosk Session Launcher
# ----------------------------------------------------------
# Prepares display, disables power-saving,
# hides cursor, and launches Chromium in kiosk mode.
# ----------------------------------------------------------

set -euo pipefail

LOGFILE="/tmp/display-kiosk-session.log"
URLS=("http://127.0.0.1:5000/")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting kiosk session..." >> "$LOGFILE"

# --- Prevent screen blanking & hide cursor ---
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.1 -root &

sleep 1  # ensure display is ready

# --- Launch Chromium in kiosk mode ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Chromium with URLs: ${URLS[*]}" >> "$LOGFILE"

chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-notifications \
  --disable-save-password-bubble \
  --disable-session-crashed-bubble \
  --no-first-run \
  --disable-translate \
  --disable-features=TranslateUI,SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure \
  --disable-sync \
  --disable-background-networking \
  --disable-component-update \
  --disable-client-side-phishing-detection \
  --password-store=basic \
  --start-maximized \
  --enable-features=OverlayScrollbar \
  "${URLS[@]}" &

CHROME_PID=$!
echo "Chromium PID: $CHROME_PID" >> "$LOGFILE"

wait $CHROME_PID
