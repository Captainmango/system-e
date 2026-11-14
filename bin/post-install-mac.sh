#!/usr/bin/env bash
#
# macOS equivalent of bin/post-install.sh.
# The docker group and systemd bits don't apply on macOS (Docker Desktop runs
# its own VM), so this only covers the shell and dotfiles.

set -euo pipefail

echo "Running macOS post-install steps..."

# Change default shell to zsh (macOS ships zsh at /bin/zsh)
current_shell="$(dscl . -read "/Users/${USER}" UserShell | awk '{print $2}')"
if [[ "${current_shell}" != "/bin/zsh" ]]; then
    echo "Changing default shell to zsh..."
    sudo dscl . -create "/Users/${USER}" UserShell /bin/zsh
else
    echo "Default shell is already zsh."
fi

# Docker Desktop: launch it once from /Applications to finish setup
if [[ -d "/Applications/Docker.app" ]]; then
    echo "Remember to launch Docker Desktop once to complete its setup."
fi

YADM="$(command -v yadm || echo "${HOME}/.local/bin/yadm")"
if "${YADM}" status &>/dev/null; then
  echo "yadm repo already exists — dotfiles are cloned."
else
  echo "No yadm repo found — cloning dotfiles..."
  "${YADM}" clone -f https://github.com/Captainmango/config-files.git
  "${YADM}" reset HEAD --hard
  echo "Done! Dotfiles cloned successfully."
fi

echo ""
echo "Post-install complete. You may need to log out and back in for all changes to take effect."
