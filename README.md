# 🎙️ Wooby-TTS (Parakeet Edition)

Wooby-TTS est un système de dictée vocale 100% hors-ligne pour macOS, optimisé pour les puces Apple Silicon. Il utilise le moteur `sherpa-onnx` et le modèle NVIDIA Parakeet TDT pour une transcription instantanée et précise.

---

## ✨ Points forts
-   **100% Offline** : Aucune donnée ne quitte ton Mac.
-   **Driver Natif** : Utilise un binaire Swift (`CGEventTap`) pour une priorité maximale sur les raccourcis.
-   **Mode Toggle** : Appuie une fois pour démarrer, une fois pour arrêter. Pas de limite de temps.
-   **Injection Directe** : Le texte est inséré automatiquement au curseur là où tu tapes.

---

## 🚀 Installation & Setup

### 1. Dépendances système
```bash
brew install sox
pip install sherpa-onnx
```

### 2. Télécharger le modèle AI
Lance le script de téléchargement automatique :
```bash
~/repo/wooby-tts/bin/download-parakeet-model.sh
```

### 3. Préparer le driver
Le driver est pré-compilé, mais si tu as besoin de le refaire :
```bash
cd ~/repo/wooby-tts/bin
swiftc -o wooby-hotkey wooby-hotkey.swift -framework Cocoa
chmod +x wooby-cli.py wooby-daemon.py wooby-hotkey
ln -sf wooby-cli.py wooby
```

---

## 🎮 Utilisation du CLI

Tout se gère via la commande `wooby` :

### Lancement
```bash
~/repo/wooby-tts/bin/wooby start
```
*Le raccourci par défaut est `Ctrl + Shift + K`.*

### Commandes utiles
| Commande | Action |
|---|---|
| `wooby status` | Voir si le démon tourne et si l'enregistrement est actif |
| `wooby restart` | Relancer le démon (en cas de plantage ou de changement de raccourci) |
| `wooby stop` | Arrêter totalement le service |
| `wooby set '<cmd>+<shift>+d'` | Changer le raccourci global |

---

## ⚙️ Mode Start/Stop (Toggle)
1.  **Hotkey Pressed** : 🎵 "Tink" — L'enregistrement commence.
2.  **Parle.**
3.  **Hotkey Pressed Again** : 🎵 "Morse" — L'enregistrement finit, le texte est injecté.

---

## 🛠️ Dépannage & Permissions

### Permissions macOS (Primordial)
Pour que ça fonctionne, tu **dois** autoriser ton **Terminal/iTerm** dans :
`Réglages Système > Confidentialité et sécurité > Accessibilité`.

### Logs
Pour voir ce qui se passe sous le capot :
```bash
~/repo/wooby-tts/bin/show-logs.sh
```
Ou surveille le log du démon :
`tail -f ~/.local/share/wooby-tts/wooby-daemon.log`
