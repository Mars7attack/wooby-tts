#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import signal
import time

HOME_DIR = os.path.expanduser("~")
WOOBY_DIR = os.path.join(HOME_DIR, "repo/wooby-tts")
SHARE_DIR = os.path.expanduser("~/.local/share/wooby-tts")
CONFIG_FILE = os.path.join(SHARE_DIR, "config.json")
PID_FILE = os.path.join(SHARE_DIR, "daemon.pid")
DAEMON_BIN = os.path.join(WOOBY_DIR, "bin/wooby-hotkey")
VOICE_FLOW_SH = os.path.join(WOOBY_DIR, "bin/voice-flow.sh")

os.makedirs(SHARE_DIR, exist_ok=True)

# Table de correspondance simplifiée (Carbon KeyCodes)
KEY_MAP = {
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34,
    "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12,
    "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
    "space": 49, "enter": 36, "tab": 48,
}

MOD_MAP = {
    "cmd": 1048576,
    "shift": 131072,
    "alt": 524288,
    "option": 524288,
    "ctrl": 262144,
    "control": 262144,
}

def parse_hotkey(hotkey_str):
    """Traduit '<cmd>+<shift>+d' en (modifiers, keycode)"""
    parts = hotkey_str.lower().replace("<", "").replace(">", "").split("+")
    modifiers = 0
    keycode = 40 # Par défaut 'k'
    
    for p in parts:
        if p in MOD_MAP:
            modifiers |= MOD_MAP[p]
        elif p in KEY_MAP:
            keycode = KEY_MAP[p]
    
    return modifiers, keycode

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except:
            pass
    return {"hotkey": "<ctrl>+<shift>+k"}

def save_config(config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=4)

def is_running():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            return pid
        except (ValueError, ProcessLookupError, FileNotFoundError):
            pass
    return None

def start():
    pid = is_running()
    if pid:
        print(f"✅ Wooby Daemon is already running (PID: {pid})")
        return

    config = load_config()
    hotkey_str = config.get("hotkey", "<ctrl>+<shift>+k")
    mods, key = parse_hotkey(hotkey_str)

    print(f"🚀 Starting Wooby Native Daemon ({hotkey_str})...")
    
    DAEMON_LOG = os.path.join(SHARE_DIR, "wooby-daemon.log")
    log_file = open(DAEMON_LOG, "a")

    # Lancer le binaire Swift
    proc = subprocess.Popen(
        [DAEMON_BIN, str(mods), str(key), VOICE_FLOW_SH],
        stdout=log_file,
        stderr=log_file,
        start_new_session=True
    )
    
    with open(PID_FILE, "w") as f:
        f.write(str(proc.pid))
    
    time.sleep(0.5)
    if proc.poll() is not None:
        print("❌ Daemon failed to start. Verify Accessibility permissions for Terminal.")
    else:
        print(f"✅ Daemon started (PID: {proc.pid})")
        print(f"   Logs redirected to: {DAEMON_LOG}")

def stop():
    pid = is_running()
    if not pid:
        print("⚠️ Wooby Daemon is not running.")
        # Toujours nettoyer le fichier PID si présent sans processus
        if os.path.exists(PID_FILE): os.remove(PID_FILE)
        return

    print(f"🛑 Stopping Wooby Daemon (PID: {pid})...")
    try:
        os.kill(pid, signal.SIGTERM)
        time.sleep(0.5)
        if is_running():
            os.kill(pid, signal.SIGKILL)
        print("✅ Daemon stopped.")
    except ProcessLookupError:
        print("⚠️ Already stopped.")
    
    if os.path.exists(PID_FILE):
        os.remove(PID_FILE)
    
    # Nettoyer aussi le verrou d'enregistrement s'il reste
    if os.path.exists("/tmp/wooby-recording.pid"):
        os.remove("/tmp/wooby-recording.pid")

def status():
    pid = is_running()
    config = load_config()
    print(f"--- Wooby TTS Status ---")
    print(f"Driver:  ✨ NATIVE SWIFT (Global)")
    print(f"Status:  {'🟢 RUNNING' if pid else '🔴 STOPPED'}")
    if pid:
        print(f"PID:     {pid}")
    
    is_rec = os.path.exists("/tmp/wooby-recording.pid")
    print(f"Recording: {'🔴 YES (Active)' if is_rec else '⚪ NO (Idle)'}")
    print(f"Hotkey:  {config.get('hotkey')}")
    print(f"Logs:    ~/repo/wooby-tts/bin/voice-flow.sh (via loop)")

def set_hotkey(hotkey):
    config = load_config()
    config["hotkey"] = hotkey
    save_config(config)
    print(f"✅ Hotkey updated to: {hotkey}")
    if is_running():
        print("🔄 Restarting daemon to apply changes...")
        stop()
        start()

def usage():
    print("Usage: wooby [start|stop|restart|status|set <hotkey>]")
    print("\nExamples:")
    print("  wooby start")
    print("  wooby set '<cmd>+<shift>+d'")
    print("  wooby set '<ctrl>+<alt>+j'")
    print("\nNote: Use single quotes for the hotkey string.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "start":
        start()
    elif cmd == "stop":
        stop()
    elif cmd == "restart":
        stop()
        start()
    elif cmd == "status":
        status()
    elif cmd == "set" and len(sys.argv) > 2:
        set_hotkey(sys.argv[2])
    else:
        usage()
