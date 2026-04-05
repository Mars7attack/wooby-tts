# 🛠️ Architecture Technique : Wooby-TTS

Ce document détaille le fonctionnement interne du projet pour faciliter la maintenance future.

## 🏗️ Structure des Fichiers
-   `bin/wooby` : Point d'entrée CLI (lien vers `wooby-cli.py`).
-   `bin/wooby-hotkey` : Binaire natif (moteur de raccourcis).
-   `bin/voice-flow.sh` : Pipeline Orchestrator (Bash).
-   `models/parakeet-tdt/` : Modèles ONNX (Sherpa).
-   `~/.local/share/wooby-tts/` : Fichiers de log et configuration.

## 🔄 Flux d'exécution (Mode Toggle)

### Phase 1 : Écoute (Swift)
Le binaire `wooby-hotkey` utilise un `CGEventTap` (.cgSessionEventTap). C'est le niveau le plus bas possible sur macOS.
-   Il intercepte les touches au niveau du Window Server avant qu'elles n'atteignent les applications.
-   Il vérifie la présence de `/tmp/wooby-recording.pid` pour décider de l'action (`--start` ou `--stop`).
-   Il utilise un verrou `isProcessing` pour éviter les collisions si l'utilisateur appuie trop vite.

### Phase 2 : Enregistrement (Bash + Sox)
L'action `--start` lance `sox` :
-   `sox -d -r 16000 -c 1 -b 16 /tmp/wooby-speech.wav`.
-   Le PID de `sox` est enregistré dans `/tmp/wooby-recording.pid`.

### Phase 3 : Transcription (Sherpa-ONNX)
L'action `--stop` tue le PID de `sox` et lance le script Python inline :
-   Le modèle **Parakeet TDT** est chargé via `from_transducer`.
-   `model_type=""` est forcé pour bypasser les warnings de métadonnées.
-   Le texte est nettoyé (regex pour virer les tokens NeMo).

### Phase 4 : Injection (AppleScript)
-   `pbcopy` met le texte dans le presse-papier.
-   `osascript` simule `Cmd + V`.
-   Le clipboard original est restauré après 300ms.

## 🛡️ Robustesse & Gestion d'état
-   **PIDs Orphelins** : Au démarrage, `wooby` nettoie les fichiers PID si le processus n'existe plus.
-   **Audio Corrompu** : Si `sox` n'a rien enregistré (ex: absence de son), la transcription est annulée avant de lancer Python.
-   **Buffering** : Le driver Swift force le `fflush(stdout)` pour des logs en temps réel.
