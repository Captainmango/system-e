#!/usr/bin/env bash
#
# macOS equivalent of bin/debian/install-local.sh.
# HomeBrew is OPTIONAL: the playbook detects it (tasks/steps/macos/homebrew.yml)
# and only runs Homebrew-backed installs when it is present. Everything else is
# installed directly.

set -euo pipefail

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${base_dir}"

# git/curl/make/python3 come from the Xcode Command Line Tools.
# Installing them pops a GUI prompt, so do it here rather than in the playbook.
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Xcode Command Line Tools (accept the GUI prompt)..."
    xcode-select --install
    echo "Re-run this script once the installation finishes."
    exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew install ansible
    else
        echo "Homebrew not found — installing ansible-core with pip3..."
        python3 -m pip install --user ansible-core
        PATH="$(python3 -m site --user-base)/bin:${PATH}"
        export PATH
    fi
fi

# The Homebrew Ansible module (community.general.homebrew) lives in the
# community.general collection — make sure it is installed.
ansible-galaxy collection install -r requirements.yml

ansible-playbook playbooks/macos/local.yml --ask-become-pass
./bin/macos/post-install.sh
