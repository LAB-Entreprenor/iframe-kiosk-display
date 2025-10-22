# IFrame Kiosk Display

### Overview

IFrame Kiosk Display is a simple, lightweight web application that displays one or more web pages in fullscreen using iframes.
It’s designed for kiosk displays, information screens, or public dashboards where multiple URLs need to be shown together or in a grid layout.

The app runs a small local Flask server and opens the display in a fullscreen Chromium browser window (kiosk mode).

### Quick install command

To quickly install; copy and paste this into the terminal:
```
git clone https://github.com/LAB-Entreprenor/iframe-kiosk-display.git 
cd ./iframe-kiosk-display 
chmod +x install.sh
sudo ./install.sh
```

### Display Mode

Shows multiple web pages (iframes) at once

Supports four layout modes:

Auto – Automatically fits as many frames as possible per row

2×2 – Fixed four-frame grid

Horizontal – Frames side-by-side in a single row

Fullscreen – Displays one page at a time

This is the standard display site

Accessible through: ``http://localhost:5000/``


### Web-Based Dashboard

Add or remove display URLs directly from the browser

Change the layout instantly — no restart required

Optionally embed an external generator page (for example, https://avgangsvisning.skyss.no) directly in the dashboard

All settings are saved to config.json automatically

Accessible through: ``http://localhost:5000/manage`` or ``http://<machine>.local:5000/manage``


### Disclaimer

This app is developed to be used with raspberry pi (linux) and View departures Service, 
but there should be no problem using it to display any other web page suitable for an always on display.

_Skyss is owned by VESTLAND FYLKESKOMMUNE SKYSS which is not affiliated with this project._