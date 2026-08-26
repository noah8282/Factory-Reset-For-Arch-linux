#!/usr/bin/env bash
#
# install.sh — installs arch-clean-reset as a system-wide command.
# Fetched and run via the one-liner in README.md.

set -euo pipefail

REPO_RAW_URL="https://raw.githubusercontent.com/noah8282/Factory-Reset-For-Arch-linux/main/arch-clean-reset.sh"
INSTALL_PATH="/usr/local/bin/arch-clean-reset"

if [[ $EUID -eq 0 ]]; then
  echo "Run this installer as your normal user, not root — it uses sudo only where needed."
  exit 1
fi

if ! command -v pacman &>/dev/null; then
  echo "This doesn't look like an Arch-based system (pacman not found). Aborting."
  exit 1
fi

echo "Downloading arch-clean-reset..."
curl -fsSL "$REPO_RAW_URL" -o /tmp/arch-clean-reset.sh

echo "Installing to $INSTALL_PATH (requires sudo)..."
sudo install -Dm755 /tmp/arch-clean-reset.sh "$INSTALL_PATH"
rm -f /tmp/arch-clean-reset.sh

echo
echo "🎗️ Installed. Run it from anywhere with:"
echo "    arch-clean-reset"
