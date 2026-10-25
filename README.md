# ram-alert

RAM threshold monitoring for Fedora Linux with GNOME Shell 48.

## Overview

`ram-alert` monitors Linux memory usage using `MemTotal - MemAvailable`. When
usage reaches the configured threshold, it plays an MP3 alert and asks a GNOME
Shell extension to flash the top bar for about 10 seconds. The default
threshold is 14.5 GiB, and the background monitor runs as a user systemd
service.

The project is intended for Fedora Linux desktops running GNOME Shell 48. It
uses Python 3 for the monitor, Bash for installation, D-Bus for communication
with GNOME Shell, and a small GNOME Shell extension for the visual alert.

## Features

- Monitors memory usage every two seconds.
- Uses a 0.5 GiB hysteresis before rearming an alert.
- Accepts binary and decimal memory units such as `GiB`, `GB`, `MiB`, and `MB`.
- Plays an installed MP3 with the first available supported player.
- Flashes the GNOME top bar through a D-Bus extension.
- Provides one-shot tests, status output, and configurable alert audio.
- Installs and enables a per-user systemd service.

## Quick Start

### Prerequisites

- Fedora Linux with GNOME Shell 48.
- Python 3.
- A readable MP3 alert file.
- One supported audio player: `mpv`, `ffplay`, `gst-play-1.0`, `mpg123`,
  `cvlc`, `vlc`, or `mplayer`.

The installer can offer to install Fedora's GStreamer MP3 tools when no
supported player is found.

### Installation

Clone the repository, enter it, and run the installer:

```bash
git clone https://github.com/tusharneje-07/ram-limit.git
cd ram-limit
chmod +x install.sh
./install.sh
```

The installer copies the audio file to `~/.local/share/ram-alert/`, installs
the CLI to `~/.local/bin/`, installs the GNOME extension and user service, and
enables the service. Log out of GNOME and log back in once after the first
installation so the running Shell loads the extension.

To provide an audio file explicitly:

```bash
./install.sh /absolute/path/to/alert.mp3
```

## Usage

Run a status check after installation:

```bash
ram-alert --status
```

Trigger an immediate audio and top-bar test:

```bash
ram-alert --test 0
```

Other useful commands:

```bash
ram-alert --help
ram-alert --threshold 14.5GiB
ram-alert --test 14.5GiB
ram-alert --set-audio ~/Music/alert.mp3
```

A bare numeric threshold is interpreted as GiB using base 1024. The `--test`
mode alerts once the threshold is reached and then exits. The continuous
monitor alerts when crossing the threshold and rearms after usage falls at
least 0.5 GiB below it.

The service can be managed with:

```bash
systemctl --user status ram-alert.service
systemctl --user restart ram-alert.service
systemctl --user stop ram-alert.service
systemctl --user start ram-alert.service
journalctl --user -u ram-alert.service -f
```

## Project Structure

```text
.
├── bin/ram-alert                    Python CLI and memory monitor
├── extension/                       GNOME Shell extension source and package
│   ├── extension.js                 D-Bus service and top-bar flash behavior
│   ├── metadata.json                GNOME Shell 48 metadata
│   ├── ram-alert@local.zip          Extension archive used by the installer
│   └── stylesheet.css               Flashing top-bar styles
├── systemd/ram-alert.service        User service definition
├── alert.mp3                        Bundled default alert sound
├── install.sh                       Installation and setup script
└── README.md                        Project documentation
```

## Development and Testing

Run the available local checks from the project root:

```bash
bash -n install.sh
python3 -m py_compile bin/ram-alert
unzip -t extension/ram-alert@local.zip
```

You can inspect the CLI without starting a long-running monitor:

```bash
python3 bin/ram-alert --help
python3 bin/ram-alert --status
```

## Documentation

- [Installation script](install.sh)
- [RAM monitor CLI](bin/ram-alert)
- [GNOME Shell extension](extension/extension.js)
- [User service](systemd/ram-alert.service)

## Contributing

Contributions are welcome when they preserve the project's purpose as a
lightweight Fedora/GNOME RAM alert. Keep changes focused, avoid committing
personal data or generated caches, update the README when behavior changes,
and run the documented verification commands before opening a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
