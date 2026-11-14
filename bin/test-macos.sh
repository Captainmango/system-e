#!/usr/bin/env bash
#
# macOS equivalent of bin/test-container.sh.
#
# Runs remote-mac.yml against the macOS VM from docker-compose.yml and
# validates each step over SSH. Start the VM and install macOS first (see
# README → Testing → MacOS); bin/validate-macos.sh checks connectivity.
#
# Per the README, an Intel (x86_64) VM only gets a minimal smoke-test install
# (no heavy GUI apps). Override with MINIMAL_INSTALL=true|false.
#
# Like test-container.sh, do not expect this to be quick — it downloads and
# installs a full machine's worth of software inside a VM.

set -euo pipefail

identifier="$(< /dev/urandom tr -dc 'a-z0-9' | fold -w 5 | head -n 1)" ||:
NAME="macos"
base_dir="$(dirname "$(readlink -f "$0")")"
DBG_LVL="${1:-}"
DBG=""

MAC_HOST="127.0.0.1"
MAC_PORT="2222"
SSH_USER="${USER}"
KEY_COMMENT="system-e-macos-test-${identifier}"
KEY_INSTALLED=0

case "${DBG_LVL}" in
    "DEBUG")
        DBG="-vvv"
        ;;
    "INFO")
        DBG="-v"
        ;;
    *)
        DBG=""
        ;;
esac

function setup_tempdir() {
    TEMP_DIR=$(mktemp --directory "/tmp/${NAME}-test".XXXXXXXX)

    export TEMP_DIR
}

function create_temporary_ssh_id() {
    ssh-keygen -b 2048 -t rsa -C "${KEY_COMMENT}" -f "${TEMP_DIR}/id_rsa" -N ""

    chmod 600 "${TEMP_DIR}/id_rsa"
    chmod 644 "${TEMP_DIR}/id_rsa.pub"
}

function ensure_container() {
    if ! docker ps --format '{{.Names}}' | grep -qx "${NAME}"; then
        echo "Container ${NAME} is not running, starting it..."
        docker compose --file "${base_dir}/../docker-compose.yml" up -d "${NAME}"
    fi
}

function wait_for_ssh() {
    echo "Waiting for SSH on ${MAC_HOST}:${MAC_PORT}..."

    local tries=0
    until nc -z "${MAC_HOST}" "${MAC_PORT}"; do
        tries=$((tries + 1))
        if [[ "${tries}" -gt 150 ]]; then
            echo "ERROR: SSH did not come up on ${MAC_HOST}:${MAC_PORT}"
            return 1
        fi
        sleep 2
    done
}

function install_temporary_ssh_id() {
    if ! command -v sshpass > /dev/null 2>&1; then
        echo "ERROR: sshpass is required (sudo apt install sshpass)"
        return 1
    fi

    if [[ -z "${MAC_PASSWORD:-}" ]]; then
        read -rsp "Password for ${SSH_USER}@${MAC_HOST}:${MAC_PORT}: " MAC_PASSWORD
        echo
    fi
    export SSHPASS="${MAC_PASSWORD}"

    local pub
    pub="$(cat "${TEMP_DIR}/id_rsa.pub")"

    echo "Installing temporary SSH key on the macOS guest..."
    sshpass -e ssh -p "${MAC_PORT}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "${SSH_USER}@${MAC_HOST}" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && { grep -qF '${KEY_COMMENT}' ~/.ssh/authorized_keys || echo '${pub}' >> ~/.ssh/authorized_keys; }"

    unset SSHPASS
    unset MAC_PASSWORD

    echo "Verifying passwordless SSH..."
    ssh_run 'echo "Passwordless SSH OK"'

    KEY_INSTALLED=1
}

function setup_test_inventory() {
    TEMP_INVENTORY_FILE="${TEMP_DIR}/hosts"

    cat > "${TEMP_INVENTORY_FILE}" << EOL
[mac]
testmac ansible_host=${MAC_HOST} ansible_port=${MAC_PORT} ansible_user=${SSH_USER} ansible_python_interpreter=/usr/bin/python3
[mac:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
EOL
    export TEMP_INVENTORY_FILE
}

function ssh_run() {
    ssh -i "${TEMP_DIR}/id_rsa" -p "${MAC_PORT}" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "${SSH_USER}@${MAC_HOST}" "$@"
}

function detect_arch_and_mode() {
    MAC_ARCH="$(ssh_run uname -m)"

    MINIMAL="${MINIMAL_INSTALL:-auto}"
    if [[ "${MINIMAL}" == "auto" ]]; then
        # README: the Intel test VM only gets a minimal smoke-test install.
        if [[ "${MAC_ARCH}" == "x86_64" ]]; then
            MINIMAL="true"
        else
            MINIMAL="false"
        fi
    fi

    export MAC_ARCH MINIMAL
    echo "Guest arch: ${MAC_ARCH} — minimal_install: ${MINIMAL}"
}

function run_ansible_playbook() {
    export ANSIBLE_CONFIG="${base_dir}/../ansible.cfg"

    # The Homebrew module (community.general.homebrew) comes from the
    # community.general collection.
    ansible-galaxy collection install -r "${base_dir}/../requirements.yml"

    echo "Running remote-mac.yml against the macOS guest..."
    # The macOS tasks avoid sudo: become is only needed if the Command Line
    # Tools are missing, Remote Login is off, or the shell isn't zsh yet —
    # none of which apply to an already-reachable VM.
    # shellcheck disable=SC2086
    ansible-playbook -i "${TEMP_INVENTORY_FILE}" \
        -e "minimal_install=${MINIMAL}" \
        ${DBG} \
        "${base_dir}/../remote-mac.yml"
}

function validate_dotfiles() {
    echo "Validating dotfiles..."
    local failed=0

    if ! ssh_run 'test -f ~/.zshrc'; then
        echo "FAIL: .zshrc not found"
        failed=1
    fi

    if ! ssh_run 'test -f ~/.zsh_aliases'; then
        echo "FAIL: .zsh_aliases not found"
        failed=1
    fi

    if ! ssh_run 'test -d ~/.local/share/yadm/repo.git'; then
        echo "FAIL: yadm repo not found"
        failed=1
    fi

    return $failed
}

function validate_default_shell() {
    echo "Validating default shell..."
    local default_shell
    default_shell="$(ssh_run "dscl . -read /Users/\$(whoami) UserShell" | awk '{print $2}')"

    if [[ "${default_shell}" != "/bin/zsh" ]]; then
        echo "FAIL: Default shell is ${default_shell}, expected /bin/zsh"
        return 1
    fi
}

function validate_yadm() {
    echo "Validating yadm..."
    if ! ssh_run '~/.local/bin/yadm --version > /dev/null 2>&1'; then
        echo "FAIL: yadm is not working"
        return 1
    fi
}

function validate_starship() {
    echo "Validating Starship..."
    if ! ssh_run '~/.local/bin/starship --version > /dev/null 2>&1'; then
        echo "FAIL: starship is not working"
        return 1
    fi
}

function validate_gh() {
    echo "Validating GitHub CLI..."
    if ! ssh_run '~/.local/bin/gh --version > /dev/null 2>&1'; then
        echo "FAIL: gh is not working"
        return 1
    fi
}

function validate_fonts() {
    echo "Validating fonts..."
    if ! ssh_run 'ls ~/Library/Fonts | grep -qi meslo'; then
        echo "FAIL: Meslo font not found in ~/Library/Fonts"
        return 1
    fi
}

function validate_mise() {
    echo "Validating Mise..."
    if ! ssh_run '~/.local/bin/mise --version > /dev/null 2>&1'; then
        echo "FAIL: mise is not working"
        return 1
    fi
}

function validate_neovim() {
    echo "Validating Neovim..."
    if ! ssh_run '~/.local/bin/nvim --version > /dev/null 2>&1'; then
        echo "FAIL: nvim is not working"
        return 1
    fi
}

function validate_git_town() {
    echo "Validating Git Town..."
    if ! ssh_run '~/.local/bin/git-town --version > /dev/null 2>&1'; then
        echo "FAIL: git-town is not working"
        return 1
    fi
}

function validate_homebrew_gating() {
    echo "Validating Homebrew gating..."
    if ssh_run 'test -x /opt/homebrew/bin/brew || test -x /usr/local/bin/brew'; then
        echo "Homebrew present on guest — brew-backed formulae should be installed."
        if ! ssh_run 'test -x /opt/homebrew/bin/tmux || test -x /usr/local/bin/tmux'; then
            echo "FAIL: Homebrew is installed but tmux was not"
            return 1
        fi
    else
        echo "Homebrew absent on guest — brew-backed steps were expected to skip (playbook succeeded, so gating works)."
    fi
}

function validate_wezterm() {
    echo "Validating WezTerm..."
    if ! ssh_run 'test -d /Applications/WezTerm.app'; then
        echo "FAIL: WezTerm.app not found in /Applications"
        return 1
    fi
}

function validate_docker() {
    echo "Validating Docker Desktop..."
    if ! ssh_run 'test -d /Applications/Docker.app'; then
        echo "FAIL: Docker.app not found in /Applications"
        return 1
    fi
}

function validate_vscode() {
    echo "Validating VSCode..."
    if ! ssh_run 'test -d "/Applications/Visual Studio Code.app"'; then
        echo "FAIL: Visual Studio Code.app not found in /Applications"
        return 1
    fi
}

function validate_obsidian() {
    echo "Validating Obsidian..."
    if ! ssh_run 'test -d /Applications/Obsidian.app'; then
        echo "FAIL: Obsidian.app not found in /Applications"
        return 1
    fi
}

function validate_chrome() {
    echo "Validating Chrome..."
    if ! ssh_run 'test -d "/Applications/Google Chrome.app"'; then
        echo "FAIL: Google Chrome.app not found in /Applications"
        return 1
    fi
}

function validate_guest() {
    local failed=0

    validate_dotfiles || failed=1
    validate_default_shell || failed=1
    validate_yadm || failed=1
    validate_starship || failed=1
    validate_gh || failed=1
    validate_fonts || failed=1
    validate_mise || failed=1
    validate_neovim || failed=1
    validate_git_town || failed=1
    validate_homebrew_gating || failed=1

    if [[ "${MINIMAL}" != "true" ]]; then
        validate_wezterm || failed=1
        validate_docker || failed=1
        validate_vscode || failed=1
        validate_obsidian || failed=1
        validate_chrome || failed=1
    else
        echo "Minimal install — skipping GUI app validation (WezTerm, Docker, VSCode, Obsidian, Chrome)."
    fi

    if [[ "${failed}" -eq 1 ]]; then
        echo "Validation FAILED"
        return 1
    fi

    echo "Validation PASSED"
}

function remove_temporary_ssh_id() {
    if [[ "${KEY_INSTALLED}" -ne 1 ]]; then
        return 0
    fi

    echo "Removing temporary SSH key from the macOS guest..."
    if ssh_run "touch ~/.ssh/authorized_keys; grep -vF '${KEY_COMMENT}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp || true; mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"; then
        KEY_INSTALLED=0
        echo "Temporary SSH key removed."
    else
        echo "WARN: could not remove the temporary key. Remove it manually with:"
        echo "WARN:   ssh -p ${MAC_PORT} ${SSH_USER}@${MAC_HOST} \"sed -i '' '/${KEY_COMMENT}/d' ~/.ssh/authorized_keys\""
        return 1
    fi
}

function cleanup() {
    remove_temporary_ssh_id ||:

    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        echo "Cleaning up tempdir ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}

setup_tempdir
trap cleanup EXIT
trap cleanup ERR
ensure_container
wait_for_ssh
create_temporary_ssh_id
install_temporary_ssh_id
setup_test_inventory
detect_arch_and_mode
run_ansible_playbook
validate_guest
