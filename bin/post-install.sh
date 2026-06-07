#!/usr/bin/env bash

set -euo pipefail

echo "Running post-install steps..."

# Add user to docker group
if ! groups "${USER}" | grep -qw docker; then
    echo "Adding ${USER} to docker group..."
    sudo usermod -aG docker "${USER}"
else
    echo "${USER} is already in the docker group."
fi

# Change default shell to zsh
ZSH_PATH="$(command -v zsh)"
if [[ "$(getent passwd "${USER}" | cut -d: -f7)" != "${ZSH_PATH}" ]]; then
    echo "Changing default shell to zsh..."
    sudo chsh -s "${ZSH_PATH}" "${USER}"
else
    echo "Default shell is already zsh."
fi

if yadm status &>/dev/null; then
  echo "yadm repo already exists — dotfiles are cloned."
else
  echo "No yadm repo found — cloning dotfiles..."
  yadm clone -f https://github.com/Captainmango/config-files.git
  yadm reset HEAD --hard
  echo "Done! Dotfiles cloned successfully."
fi

echo ""
echo "Post-install complete. You may need to log out and back in (or reboot) for all changes to take effect."
