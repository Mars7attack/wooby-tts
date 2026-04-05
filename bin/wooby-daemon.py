#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import signal
import threading
import time
from pynput import keyboard

# Chemins absolus
HOME_DIR = os.path.expanduser("~")
WOOBY_DIR = os.path.join(HOME_DIR, "repo/wooby-tts")
CONFIG_FILE = os.path.expanduser("~/.local/share/wooby-tts/config.json")
LOG_FILE = os.path.expanduser("~/.local/share/wooby-tts/wooby-daemon.log")
VOICE_FLOW_SH = os.path.join(WOOBY_DIR, "bin/voice-flow.sh")

# Verrou pour éviter les exécutions concurrentes
trigger_lock = threading.Lock()

def log(msg):
    # Rotation basique : si > 1MB, on vide
    if os.path.exists(LOG_FILE) and os.path.getsize(LOG_FILE) > 1024 * 1024:
        with open(LOG_FILE, "w") as f:
            f.write("--- Log Rotated ---\n")
    
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(LOG_FILE, "a") as f:
        f.write(f"[{timestamp}] {msg}\n")

def trigger_voice_flow():
    if not trigger_lock.acquire(blocking=False):
        log("Hotkey pressed but a transcription is already in progress. Ignoring.")
        return

    log("Hotkey pressed! Triggering voice-flow.sh...")
    try:
        # On lance voice-flow.sh et on attend la fin pour libérer le verrou
        # On utilise subprocess.run au lieu de Popen pour que le thread attende
        def run_script():
            try:
                subprocess.run([VOICE_FLOW_SH], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            finally:
                trigger_lock.release()
                log("voice-flow.sh finished. Lock released.")

        threading.Thread(target=run_script).start()
    except Exception as e:
        log(f"Error triggering voice-flow.sh: {e}")
        trigger_lock.release()

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except:
            pass
    return {"hotkey": "<ctrl>+<shift>+k"}

def main():
    config = load_config()
    hotkey_str = config.get("hotkey", "<ctrl>+<shift>+k")
    
    log(f"Starting Wooby Daemon with hotkey: {hotkey_str}")
    
    # pynput utilise des angles < > pour les modificateurs
    # ex: <ctrl>+<shift>+k
    
    try:
        with keyboard.GlobalHotKeys({
            hotkey_str: trigger_voice_flow
        }) as h:
            h.join()
    except Exception as e:
        log(f"Fatal error in daemon: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Ignorer SIGHUP pour rester en vie si le terminal ferme
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    main()
