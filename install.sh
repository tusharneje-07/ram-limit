#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UUID="ram-alert@local"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/ram-alert"
DATA_DIR="$HOME/.local/share/ram-alert"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
UNIT_DIR="$HOME/.config/systemd/user"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required."
    exit 2
fi

AUDIO_PATH="${1:-}"
if [[ -z "$AUDIO_PATH" ]]; then
    for candidate in \
        "$BASE_DIR/alert.mp3" \
        "$BASE_DIR/../alert.mp3" \
        "$HOME/Music/alert.mp3" \
        "$HOME/Downloads/alert.mp3" \
        "$HOME/.local/share/sounds/alert.mp3"; do
        if [[ -f "$candidate" && -r "$candidate" ]]; then
            AUDIO_PATH="$candidate"
            break
        fi
    done
fi

if [[ -z "$AUDIO_PATH" ]]; then
    printf 'Enter the full path to your alert.mp3: '
    IFS= read -r AUDIO_PATH
fi
if [[ -z "$AUDIO_PATH" || ! -f "$AUDIO_PATH" || ! -r "$AUDIO_PATH" ]]; then
    echo "Error: a readable alert audio file is required."
    echo "Usage: $0 /absolute/path/to/alert.mp3"
    exit 2
fi
AUDIO_PATH="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).expanduser().resolve())' "$AUDIO_PATH")"

if ! command -v mpv >/dev/null 2>&1 && ! command -v ffplay >/dev/null 2>&1 \
   && ! command -v gst-play-1.0 >/dev/null 2>&1 \
   && ! command -v mpg123 >/dev/null 2>&1 && ! command -v cvlc >/dev/null 2>&1 \
   && ! command -v vlc >/dev/null 2>&1 && ! command -v mplayer >/dev/null 2>&1; then
    printf 'No supported audio player was found. Install Fedora GStreamer MP3 tools now? [y/N] '
    IFS= read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        sudo dnf install -y gstreamer1-plugins-base-tools gstreamer1-plugins-good
    else
        echo "Cannot install without an MP3 player. Install playback support and rerun this script:"
        echo "  sudo dnf install gstreamer1-plugins-base-tools gstreamer1-plugins-good"
        exit 2
    fi
fi

if ! command -v mpv >/dev/null 2>&1 && ! command -v ffplay >/dev/null 2>&1 \
   && ! command -v gst-play-1.0 >/dev/null 2>&1 && ! command -v mpg123 >/dev/null 2>&1 \
   && ! command -v cvlc >/dev/null 2>&1 && ! command -v vlc >/dev/null 2>&1 \
   && ! command -v mplayer >/dev/null 2>&1; then
    echo "Error: no supported MP3 player is available after installation."
    echo "Install one with: sudo dnf install gstreamer1-plugins-base-tools gstreamer1-plugins-good"
    exit 2
fi

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR" "$EXT_DIR" "$UNIT_DIR"
install -m 0755 "$BASE_DIR/bin/ram-alert" "$BIN_DIR/ram-alert"

# Copy the alert sound into the home directory so the monitor still works if
# the source project lives on an external drive that is later unmounted.
INSTALLED_AUDIO="$DATA_DIR/alert.mp3"
install -m 0644 "$AUDIO_PATH" "$INSTALLED_AUDIO"
printf '%s\n' "$INSTALLED_AUDIO" > "$CONFIG_DIR/audio-path"
chmod 0600 "$CONFIG_DIR/audio-path"

# Prefer GNOME's extension installer because it refreshes extension metadata.
if command -v gnome-extensions >/dev/null 2>&1 \
   && [[ -f "$BASE_DIR/extension/ram-alert@local.zip" ]]; then
    if gnome-extensions install --force "$BASE_DIR/extension/ram-alert@local.zip"; then
        echo "Installed GNOME Shell extension package."
    else
        echo "WARNING: GNOME extension installer failed; copying extension files directly."
        cp -f "$BASE_DIR/extension/metadata.json" "$EXT_DIR/metadata.json"
        cp -f "$BASE_DIR/extension/extension.js" "$EXT_DIR/extension.js"
        cp -f "$BASE_DIR/extension/stylesheet.css" "$EXT_DIR/stylesheet.css"
    fi
else
    cp -f "$BASE_DIR/extension/metadata.json" "$EXT_DIR/metadata.json"
    cp -f "$BASE_DIR/extension/extension.js" "$EXT_DIR/extension.js"
    cp -f "$BASE_DIR/extension/stylesheet.css" "$EXT_DIR/stylesheet.css"
fi

install -m 0644 "$BASE_DIR/systemd/ram-alert.service" "$UNIT_DIR/ram-alert.service"

# Ensure the user-local bin is available in common interactive shells.
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]] && ! grep -Fq '# ram-alert: add user-local bin' "$rc"; then
        cat >> "$rc" <<'RC'

# ram-alert: add user-local bin
export PATH="$HOME/.local/bin:$PATH"
RC
    fi
done

FISH_RC="$HOME/.config/fish/config.fish"
if [[ -f "$FISH_RC" ]] && ! grep -Fq '# ram-alert: add user-local bin' "$FISH_RC"; then
    cat >> "$FISH_RC" <<'FISHRC'

# ram-alert: add user-local bin
fish_add_path "$HOME/.local/bin"
FISHRC
fi

# Keep the existing enabled-extension list intact, and schedule this extension
# for the next GNOME login. Newly installed extensions are discovered by the
# running Shell at session startup, so log out/in after the first installation.
EXTENSION_SCHEDULED=0
if command -v gsettings >/dev/null 2>&1 \
   && gsettings list-keys org.gnome.shell 2>/dev/null | grep -qx 'enabled-extensions'; then
    CURRENT_EXTENSIONS="$(gsettings get org.gnome.shell enabled-extensions)"
    UPDATED_EXTENSIONS="$(python3 - "$CURRENT_EXTENSIONS" "$UUID" <<'PYEXT'
import ast
import sys
try:
    values = ast.literal_eval(sys.argv[1])
    if not isinstance(values, list) or not all(isinstance(x, str) for x in values):
        values = []
except (ValueError, SyntaxError):
    values = []
if sys.argv[2] not in values:
    values.append(sys.argv[2])
print(repr(values))
PYEXT
)"
    if gsettings set org.gnome.shell enabled-extensions "$UPDATED_EXTENSIONS"; then
        EXTENSION_SCHEDULED=1
        echo "Scheduled $UUID to load at the next GNOME login."
    fi
fi

if [[ "$EXTENSION_SCHEDULED" -eq 0 ]]; then
    echo "WARNING: Could not update GNOME's enabled-extensions setting automatically."
    echo "After logging out and back in, run: gnome-extensions enable $UUID"
else
    echo "Log out of GNOME and log back in once to load the newly installed extension."
fi

systemctl --user daemon-reload
systemctl --user enable --now ram-alert.service

printf '\nInstalled ram-alert.\n'
printf 'Audio: %s\n' "$INSTALLED_AUDIO"
printf 'Command: %s/ram-alert --help\n' "$BIN_DIR"
printf '\nTest immediately with: %s/ram-alert --test 0\n' "$BIN_DIR"
printf 'Check status with: %s/ram-alert --status\n' "$BIN_DIR"
printf 'Service logs: journalctl --user -u ram-alert.service -f\n'
printf '\nLog out and back in before running the top-bar flash test.\n'
