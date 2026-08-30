# Stay Awake

A GNOME tray app that stops your monitor going dark and your machine sleeping on idle. Click the coffee cup in the top bar to toggle it.

I got tired of long AI agent runs dying because Ubuntu decided the computer was idle, so I made this.

![Stay Awake icon](data/icons/stay-awake-on.svg)

## GNOME only

This only works on GNOME. I built and use it on Ubuntu. Other GNOME desktops (Pop!_OS, Fedora Workstation, Debian GNOME, Zorin) should be fine if the AppIndicator tray is available.

It does not work on KDE Plasma, XFCE, Cinnamon, MATE, or compositors like Sway and Hyprland. Those use different idle and power settings, and the top-bar icon needs GNOME's tray. `./install.sh` checks for GNOME and exits if it cannot find it.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/jatinkrmalik/stay-awake/main/install.sh | bash
```

That clones the repo into `~/.local/src/stay-awake` and installs into `~/.local`. No sudo. Needs `git`. Extra flags go through `bash -s`:

```bash
curl -fsSL https://raw.githubusercontent.com/jatinkrmalik/stay-awake/main/install.sh | bash -s -- --no-desktop
```

If you already have a checkout:

```bash
git clone https://github.com/jatinkrmalik/stay-awake.git
cd stay-awake
./install.sh
```

You get:

- a coffee cup in the top bar
- `stay-awake` on your PATH (if `~/.local/bin` is already there)
- a desktop shortcut
- autostart on login

If the icon does not appear, you are probably missing the tray libraries:

```bash
# Ubuntu / Debian / Pop!_OS
sudo apt install python3-gi gir1.2-appindicator3-0.1 gnome-shell-extension-appindicator libnotify-bin

# Fedora
sudo dnf install python3-gobject libappindicator-gtk3 libnotify
```

Then run `./install.sh` again.

```bash
./install.sh --no-desktop     # skip the Desktop shortcut
./install.sh --no-start       # install but do not launch the icon yet
```

## Usage

Click the cup and check `Keep awake`. Middle-click the cup to toggle without opening the menu. Scroll up for on, down for off.

A gold cup means it is on. A grey cup with a slash means it is off.

```bash
stay-awake          # toggle
stay-awake on
stay-awake off
stay-awake status
stay-awake indicator
```

`Quit` on the menu only hides the icon. It does not re-enable sleep. Uncheck `Keep awake`, or run `stay-awake off`, when you want timeouts back.

## How it works

While it is on, Stay Awake:

- sets GNOME `idle-delay` to 0 so the screen does not blank
- sets idle suspend on AC and battery to `nothing`
- turns off screensaver idle activation and auto-lock
- holds a `systemd-inhibit` block on `idle:sleep`

Your previous values are stored in `~/.local/share/stay-awake/saved-gsettings` and restored when you turn it off. Closing the lid still suspends; that setting is not touched.

## Uninstall

```bash
stay-awake-uninstall
```

From a git checkout, `./uninstall.sh` does the same thing. The curl installer leaves a copy at `~/.local/src/stay-awake/uninstall.sh`.

This turns Stay Awake off first so your old timeouts come back, then deletes the installed files.

```bash
stay-awake-uninstall --keep-state   # leave the saved settings dir in place
```

## License

MIT. See [LICENSE](LICENSE).
