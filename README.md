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

Files will be installed at ``/opt/display-kiosk/``

### Display Mode

Shows multiple web pages (iframes) at once

Supports four layout modes:

Auto – Automatically fits frames in a grid-structrure

Horizontal – Frames side-by-side in a single row

This is the standard display site

Accessible through: ``http://localhost:5000/``


### Web-Based Dashboard

Add or remove display URLs directly from the browser

Change the layout instantly — no restart required

Optionally embed an external generator page (for example, https://avgangsvisning.skyss.no) directly in the dashboard

All settings are saved to config.json automatically

Accessible through: ``http://localhost:5000/manage`` or ``http://<machine>.local:5000/manage``

### Systemd powerd
The app is running as systemd services, ``display-kiosk.service`` and `display-kiosk-session.service`

Use `sudo systemctl status||restart||stop display-kiosk.service display-kiosk-session.service`
to check status, restart or stop the services using the terminal or SSH into the host machine

### Configuration
The app uses a simple JSON configfile to store URLs and settings.
These can be configures through the dashboard or by SSH remote to the host machine

The file itself is will be located at: 
```/opt/display-kiosk/config.json```

`
{    
"urls": ["https://example.com", ...],
"layout": "horizontal", 
"generator_url": "https://avgangsvisning.skyss.no",
"dashboard_enabled": true 
}
`

### Disclaimer

This app is developed to be used with raspberry pi (linux) and View departures Service, 
but there should be no problem using it to display any other web page suitable for an always on display.

_Skyss is owned by VESTLAND FYLKESKOMMUNE SKYSS which is not affiliated with this project._