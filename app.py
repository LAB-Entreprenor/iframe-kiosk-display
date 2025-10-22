from flask import Flask, render_template, request, redirect, url_for, jsonify
import json
import os
import time
import subprocess
import concurrent.futures

app = Flask(__name__)
CONFIG_FILE = "config.json"

_last_modified = 0  # used for change detection


# ==========================================================
# --- CONFIG HANDLING ---
# ==========================================================
def load_config():
    """Load or initialize config.json"""
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "w") as f:
            json.dump({
                "urls": [],
                "layout": "auto",
                "generator_url": "",
                "dashboard_enabled": True  # 👈 new flag
            }, f)

    with open(CONFIG_FILE, "r") as f:
        data = json.load(f)

    # --- Backward compatibility ---
    if isinstance(data, list):
        data = {"urls": data, "layout": "auto", "generator_url": "", "dashboard_enabled": True}
    if "generator_url" not in data:
        data["generator_url"] = ""
    if "layout" not in data:
        data["layout"] = "auto"
    if "urls" not in data:
        data["urls"] = []
    if "dashboard_enabled" not in data:
        data["dashboard_enabled"] = True  # 👈 add default if missing

    return data


def save_config(data):
    """Save the configuration to config.json"""
    with open(CONFIG_FILE, "w") as f:
        json.dump(data, f, indent=4)


def get_config():
    """Return config if modified, otherwise None"""
    global _last_modified
    try:
        modified = os.path.getmtime(CONFIG_FILE)
        if modified != _last_modified:
            _last_modified = modified
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
    except Exception:
        pass
    return None


# ==========================================================
# --- ROUTES ---
# ==========================================================
@app.route("/")
def index():
    config = get_config() or load_config()
    urls = config.get("urls", [])
    layout = config.get("layout", "auto")
    return render_template("index.html", urls=urls, layout=layout, time=time)


@app.route("/manage", methods=["GET", "POST"])
def manage():
    config = load_config()

    # --- Disable access if dashboard is locked ---
    if not config.get("dashboard_enabled", True):
        return "Dashboard is disabled. Edit config.json to re-enable.", 403

    urls = config["urls"]
    layout = config.get("layout", "auto")
    generator_url = config.get("generator_url", "")
    message = None

    if request.method == "POST":
        # Add new display URL
        if "add" in request.form:
            new_url = request.form.get("url", "").strip()
            if new_url and new_url not in urls:
                urls.append(new_url)

        # Remove display URL
        elif "remove" in request.form:
            to_remove = request.form.get("remove")
            urls = [u for u in urls if u != to_remove]

        # Update layout
        elif "layout" in request.form:
            layout = request.form.get("layout")

        # Update or clear generator URL
        elif "set_generator" in request.form:
            generator_url = request.form.get("generator_url", "").strip()

        # Disable dashboard (self-lock)
        elif "disable_dashboard" in request.form:
            config["dashboard_enabled"] = False
            save_config(config)
            return "Dashboard disabled. Edit config.json to re-enable.", 200

        # Save all changes
        config["urls"] = urls
        config["layout"] = layout
        config["generator_url"] = generator_url
        save_config(config)

        return redirect(url_for("manage"))

    return render_template(
        "manage.html",
        urls=urls,
        layout=layout,
        generator_url=generator_url,
        message=message,
        config=config
    )



# ==========================================================
# --- SERVICE CONTROL: STOP DISPLAY SESSION ---
# ==========================================================
@app.route("/stop-session", methods=["POST"])
def stop_session():
    """Stop the Chromium kiosk display session"""
    try:
        subprocess.run(
            ["sudo", "systemctl", "stop", "display-kiosk-session.service"],
            check=True
        )
        message = "✅ Kiosk display session stopped."
    except subprocess.CalledProcessError:
        message = "⚠️ Failed to stop display session. Check permissions."

    config = load_config()
    urls = config.get("urls", [])
    layout = config.get("layout", "auto")
    generator_url = config.get("generator_url", "")

    return render_template(
        "manage.html",
        urls=urls,
        layout=layout,
        generator_url=generator_url,
        message=message
    )


@app.route("/reboot", methods=["POST"])
def reboot_system():
    """Reboot the Raspberry Pi or host system"""
    try:
        subprocess.run(["sudo", "reboot"], check=True)
        message = "🔄 System is rebooting..."
    except subprocess.CalledProcessError:
        message = "⚠️ Failed to reboot system. Check permissions."

    config = load_config()
    urls = config.get("urls", [])
    layout = config.get("layout", "auto")
    generator_url = config.get("generator_url", "")

    return render_template(
        "manage.html",
        urls=urls,
        layout=layout,
        generator_url=generator_url,
        message=message
    )



# ==========================================================
# --- AUTO REFRESH ENDPOINT ---
# ==========================================================
@app.route("/last-updated")
def last_updated():
    """Return timestamp for config.json modification"""
    try:
        return str(os.path.getmtime(CONFIG_FILE))
    except Exception:
        return "0"


# ==========================================================
# --- NETWORK STATUS (PARALLEL PING) ---
# ==========================================================
@app.route("/network-status")
def network_status():
    """
    Fast parallel ping check for LAN + Internet connectivity.
    Cross-platform: works on Windows and Linux (Raspberry Pi).
    """
    targets = ["192.168.1.1", "1.1.1.1"]  # local router + internet DNS

    def ping_target(target):
        try:
            cmd = (
                ["ping", "-n", "1", "-w", "300", target]
                if os.name == "nt"
                else ["ping", "-c", "1", "-W", "0.3", target]
            )
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except subprocess.CalledProcessError:
            return False

    # Run pings concurrently
    with concurrent.futures.ThreadPoolExecutor() as executor:
        results = list(executor.map(ping_target, targets))

    online = any(results)
    return jsonify({"online": online})


# ==========================================================
# --- MAIN ENTRY POINT ---
# ==========================================================
if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
