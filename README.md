# Factory-Reset-For-Arch-linux

A general-purpose, reusable script to strip an Arch Linux install back down
to a clean, usable state — as if it were freshly installed — without
actually reinstalling the OS.

## Why this exists

Over time, an Arch install accumulates a lot of stuff: desktop environments
you tried and abandoned, AUR packages, dotfiles, leftover config and cache
folders from apps you no longer use, orphaned dependencies nothing needs
anymore. Uninstalling a desktop environment or a big app with plain
`pacman -R` almost never cleans up everything it left behind.

`arch-clean-reset` automates the process of tearing all of that back out,
so you're left with a minimal, working system — networking, your shell,
your bootloader, and a TTY login — without having to identify and remove
every package and config folder by hand.

It is **not** tied to any specific setup. It auto-detects your bootloader,
shell, AUR helper, and a few other essentials on the machine it's run on,
so it works the same way whether you're running Hyprland, GNOME, KDE, or
nothing at all.

## What it actually does, in order

1. **Detects what must be kept.** It scans your system for:
   - Your bootloader (systemd-boot, GRUB, or rEFInd)
   - Your current login shell
   - Any installed editor (vim/nano/neovim)
   - Any AUR helper (yay, paru, or their `-bin` variants)
   - Whether `sshd` is enabled (keeps `openssh` if so)
   - `git`, if installed

   Combined with core essentials (`base`, `base-devel`, kernel, firmware,
   systemd, pacman, networking, filesystem tools), this becomes the "keep
   list" — printed to the screen before anything happens.

2. **Asks for confirmation.** You must type `reset my system` exactly to
   proceed. Nothing is touched before this.

3. **Backs everything up first**, into a timestamped folder in your home
   directory (`~/arch-reset-backup-<date>/`):
   - Your full explicit package list
   - Your full package list (explicit + dependencies)
   - Your AUR/foreign package list
   - A copy of `/etc/pacman.conf` and `/etc/pacman.d`
   - A list of your currently enabled systemd services

4. **Removes every explicitly-installed package not on the keep list** —
   this is what clears out desktop environments, apps, and anything else
   you installed on top of the base system.

5. **Removes orphaned dependencies**, repeatedly, until none are left —
   this is what catches the libraries and support packages a DE or app
   pulled in that plain package removal usually leaves behind.

6. **Cleans the pacman package cache.**

7. **Reinstalls the `base` group** with `--needed`, to guarantee the
   system is complete and bootable even if something essential was pulled
   in only as a dependency and got removed as an orphan.

8. **Quarantines leftover config and cache folders.** For every package it
   removed, it checks `~/.config`, `~/.local/share`, and `~/.cache` for a
   matching folder and **moves** (never deletes) it into the backup
   directory, under `quarantined-configs/`. You review and delete that
   folder yourself once you're confident you don't need anything in it.

At the end, you're left with a clean TTY login: networking, your shell,
your bootloader, sudo, and nothing graphical.

## Safety notes

- **This is destructive to installed packages.** Read the script before
  running it on a machine you care about.
- Nothing is permanently deleted by the script itself — package removal
  goes through pacman (recoverable by reinstalling), and configs are moved,
  not deleted.
- The keep-list is printed and requires manual confirmation before any
  changes happen. Look it over — if your bootloader isn't detected
  correctly, or you need something else preserved, stop and edit the
  `KEEP_PKGS` array at the top of the script before running it.
- A reboot after running is recommended, to confirm the system still comes
  up cleanly.

## Installation

Install it as a system-wide command with:

```bash
curl -fsSL https://raw.githubusercontent.com/noah8282/Factory-Reset-For-Arch-linux/main/install.sh | bash
```

This downloads `arch-clean-reset.sh` and installs it to
`/usr/local/bin/arch-clean-reset`, so it's available as a plain command
from anywhere.

## Usage

```bash
arch-clean-reset
```

That's it — one command, one confirmation prompt, does everything listed
above in a single run.

## Manual install (without the one-liner)

If you'd rather not pipe a script into bash, clone the repo and run it
directly:

```bash
git clone https://github.com/noah8282/Factory-Reset-For-Arch-linux.git
cd Factory-Reset-For-Arch-linux
chmod +x arch-clean-reset.sh
./arch-clean-reset.sh
```

## Uninstalling arch-clean-reset itself

```bash
sudo rm /usr/local/bin/arch-clean-reset
```

## License

MIT — do whatever you want with it, no warranty. See `LICENSE`.
