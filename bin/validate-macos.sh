#!/usr/bin/env bash

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
    ssh -i "${TEMP_DIR}/id_rsa" -p "${MAC_PORT}" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "${SSH_USER}@${MAC_HOST}" 'echo "Passwordless SSH OK"'

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

function run_ansible_ping() {
    export ANSIBLE_CONFIG="${base_dir}/../ansible.cfg"

    echo "Running ansible ping against mac..."
    # shellcheck disable=SC2086
    ansible -i "${TEMP_INVENTORY_FILE}" mac -m ping ${DBG}
}

function validate_macos() {
    echo "Validating macOS guest..."

    local failed=0

    # shellcheck disable=SC2086
    if ! ansible -i "${TEMP_INVENTORY_FILE}" mac -m command -a "sw_vers -productVersion" ${DBG}; then
        echo "FAIL: sw_vers did not run on the guest"
        failed=1
    fi

    # shellcheck disable=SC2086
    if ! ansible -i "${TEMP_INVENTORY_FILE}" mac -m command -a "python3 --version" ${DBG}; then
        echo "FAIL: python3 not usable on the guest"
        failed=1
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
    if ssh -i "${TEMP_DIR}/id_rsa" -p "${MAC_PORT}" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "${SSH_USER}@${MAC_HOST}" \
        "touch ~/.ssh/authorized_keys; grep -vF '${KEY_COMMENT}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp || true; mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"; then
        KEY_INSTALLED=0
        echo "Temporary SSH key removed, macos storage reverted."
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
run_ansible_ping
validate_macos
