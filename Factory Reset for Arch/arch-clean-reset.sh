#!/usr/bin/env bash
#
# arch-clean-reset.sh
#
# One-shot "strip my Arch install back to a usable TTY" script.
# Removes everything you installed on top of the base system (desktop
# environments, apps, AUR packages), cleans up orphaned dependencies and
# cache, and quarantines leftover config/cache folders those apps left
# behind — all in a single run. Nothing is permanently deleted; quarantined
# configs are moved into the backup folder so you can review and clear them
# yourself afterward.
#
# Usage:
#   ./arch-clean-reset.sh
#
# THIS IS DESTRUCTIVE to installed packages. Read it before running it on
# a system you care about. You'll be asked to confirm once before anything
# actually changes.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user, not root — it calls sudo when needed."
  exit 1
fi

BACKUP_DIR="$HOME/arch-reset-backup-$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# 1. AUTO-DETECT WHAT NEEDS TO BE KEPT
# ---------------------------------------------------------------------------

echo "=== Detecting your system so nothing essential gets removed ==="

KEEP_PKGS=(
  base base-devel
  linux linux-lts linux-zen linux-hardened linux-firmware linux-headers
  amd-ucode intel-ucode
  systemd systemd-sysvcompat systemd-libs
  pacman pacman-contrib archlinux-keyring pacman-mirrorlist
  glibc filesystem coreutils util-linux util-linux-libs
  sudo shadow
  networkmanager iwd wpa_supplicant dhcpcd
  mkinitcpio mkinitcpio-busybox
  btrfs-progs e2fsprogs dosfstools xfsprogs f2fs-tools
)

if [[ -d /boot/loader/entries ]] || bootctl is-installed &>/dev/null; then
  KEEP_PKGS+=(systemd-boot efibootmgr)
  echo "Detected bootloader: systemd-boot"
elif [[ -f /etc/default/grub ]]; then
  KEEP_PKGS+=(grub efibootmgr)
  echo "Detected bootloader: grub"
elif pacman -Qq refind &>/dev/null; then
  KEEP_PKGS+=(refind)
  echo "Detected bootloader: rEFInd"
else
  echo "!! Could not detect your bootloader automatically — check the keep list below carefully."
fi

CURRENT_SHELL_PKG=$(basename "${SHELL:-/bin/bash}")
KEEP_PKGS+=("$CURRENT_SHELL_PKG")
echo "Detected shell: $CURRENT_SHELL_PKG"

for ed in vim nano neovim; do
  pacman -Qq "$ed" &>/dev/null && KEEP_PKGS+=("$ed")
done

for helper in yay yay-bin paru paru-bin; do
  if pacman -Qq "$helper" &>/dev/null; then
    KEEP_PKGS+=("$helper")
    echo "Detected AUR helper: $helper"
  fi
done

if systemctl is-enabled sshd &>/dev/null; then
  KEEP_PKGS+=(openssh)
  echo "sshd is enabled — keeping openssh"
fi

pacman -Qq git &>/dev/null && KEEP_PKGS+=(git)

mapfile -t KEEP_PKGS < <(printf '%s\n' "${KEEP_PKGS[@]}" | sort -u)

echo
echo "Packages that will always be kept:"
printf '  %s\n' "${KEEP_PKGS[@]}"
echo

# ---------------------------------------------------------------------------
# 2. CONFIRM (single prompt, does everything after this)
# ---------------------------------------------------------------------------

echo "=============================================================="
echo " ARCH CLEAN RESET"
echo "=============================================================="
echo "This will, in one go:"
echo "  1. Remove every explicitly-installed package not listed above"
echo "  2. Remove orphaned dependencies and clean the package cache"
echo "  3. Reinstall the 'base' group to guarantee a complete minimal system"
echo "  4. Move leftover config/cache folders for removed apps into a backup"
echo "     folder (quarantined, not deleted)"
echo
read -rp "Type EXACTLY 'reset my system' to continue: " confirm
if [[ "$confirm" != "reset my system" ]]; then
  echo "Confirmation text didn't match. Aborting, nothing was changed."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# 3. BACKUP
# ---------------------------------------------------------------------------

echo "=== Backing up current state to $BACKUP_DIR ==="
pacman -Qqe > "$BACKUP_DIR/explicit-packages.txt"
pacman -Qq  > "$BACKUP_DIR/all-packages.txt"
pacman -Qm  > "$BACKUP_DIR/foreign-aur-packages.txt" 2>/dev/null || true
sudo cp -r /etc/pacman.conf /etc/pacman.d "$BACKUP_DIR/" 2>/dev/null || true
systemctl list-unit-files --state=enabled > "$BACKUP_DIR/enabled-services.txt" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. COMPUTE + REMOVE PACKAGES
# ---------------------------------------------------------------------------

mapfile -t EXPLICIT_PKGS < "$BACKUP_DIR/explicit-packages.txt"
TO_REMOVE=()
for pkg in "${EXPLICIT_PKGS[@]}"; do
  keep=false
  for k in "${KEEP_PKGS[@]}"; do
    [[ "$pkg" == "$k" ]] && { keep=true; break; }
  done
  $keep || TO_REMOVE+=("$pkg")
done

echo
if [[ ${#TO_REMOVE[@]} -eq 0 ]]; then
  echo "Nothing to remove — explicit packages already match the keep list."
else
  echo "Removing ${#TO_REMOVE[@]} packages:"
  printf '  %s\n' "${TO_REMOVE[@]}"
  sudo pacman -Rns --noconfirm "${TO_REMOVE[@]}" || \
    echo "Some packages failed to remove (likely required by something kept). Review above."
fi

# ---------------------------------------------------------------------------
# 5. ORPHANS + CACHE
# ---------------------------------------------------------------------------

echo "=== Cleaning orphaned dependencies ==="
while true; do
  orphans=$(pacman -Qtdq || true)
  [[ -z "$orphans" ]] && break
  echo "$orphans" | sudo pacman -Rns --noconfirm -
done

echo "=== Cleaning pacman cache ==="
sudo pacman -Scc --noconfirm

echo "=== Reinstalling base group to guarantee a complete minimal system ==="
sudo pacman -S --needed --noconfirm base

# ---------------------------------------------------------------------------
# 6. QUARANTINE LEFTOVER CONFIGS (moved, never deleted outright)
# ---------------------------------------------------------------------------

if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
  QUARANTINE="$BACKUP_DIR/quarantined-configs"
  mkdir -p "$QUARANTINE"
  echo "=== Moving matching leftover config/cache dirs into $QUARANTINE ==="
  for pkg in "${TO_REMOVE[@]}"; do
    name="${pkg%% *}"
    for base in "$HOME/.config" "$HOME/.local/share" "$HOME/.cache"; do
      if [[ -e "$base/$name" ]]; then
        mkdir -p "$QUARANTINE$base"
        mv "$base/$name" "$QUARANTINE$base/" && echo "  moved $base/$name"
      fi
    done
  done
  echo "Nothing was permanently deleted — review $QUARANTINE and remove it yourself once you're sure."
fi

echo
echo "=============================================================="
echo " DONE"
echo "=============================================================="
echo "Backup + quarantined configs: $BACKUP_DIR"
echo "Reboot to confirm everything still comes up cleanly: sudo reboot"
