#!/usr/bin/env bash

set -euo pipefail

identifier="$(< /dev/urandom tr -dc 'a-z0-9' | fold -w 5 | head -n 1)" ||:
img_name="system-e-test"
NAME="${img_name}-${identifier}"
base_dir="$(dirname "$(readlink -f "$0")")"
DBG_LVL="${1:-}"
DBG=""

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
    TEMP_DIR=$(mktemp --directory "/tmp/${NAME}".XXXXXXXX)

    export TEMP_DIR
}

function create_temporary_ssh_id() {
    ssh-keygen -b 2048 -t rsa -C "${USER}@email.com" -f "${TEMP_DIR}/id_rsa" -N ""

    chmod 600 "${TEMP_DIR}/id_rsa"
    chmod 644 "${TEMP_DIR}/id_rsa.pub"
}

function start_container() {
    docker build --tag "${img_name}" \
        --build-arg USER \
        --file "${base_dir}/../Dockerfile.test" \
        "${TEMP_DIR}"

    docker run -d -P --name "${NAME}" "${img_name}"

    CONTAINER_ADDR=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${NAME}")

    export CONTAINER_ADDR
}

function setup_test_inventory() {
    TEMP_INVENTORY_FILE="${TEMP_DIR}/hosts"

    echo $CONTAINER_ADDR

    cat > "${TEMP_INVENTORY_FILE}" << EOL
[target_group]
${CONTAINER_ADDR}:22
[target_group:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
EOL
    export TEMP_INVENTORY_FILE
}

function run_ansible_playbook() {
    ANSIBLE_CONFIG="${base_dir}/ansible.cfg"
    if [[ -n "${DBG}" ]]; then
        ansible-playbook -i "${TEMP_INVENTORY_FILE}" "${DBG}" "${base_dir}/../remote.yml"
    else
        ansible-playbook -i "${TEMP_INVENTORY_FILE}" "${base_dir}/../remote.yml"
    fi
}

function validate_dotfiles() {
    local user="$1"
    local failed=0

    echo "Validating dotfiles..."
    if ! docker exec "${NAME}" test -f "/home/${user}/.zshrc"; then
        echo "FAIL: .zshrc not found"
        failed=1
    fi

    if ! docker exec "${NAME}" test -f "/home/${user}/.zsh_aliases"; then
        echo "FAIL: .zsh_aliases not found"
        failed=1
    fi

    if ! docker exec "${NAME}" test -d "/home/${user}/.local/share/yadm/repo.git"; then
        echo "FAIL: yadm repo not found"
        failed=1
    fi

    return $failed
}

function validate_docker_group() {
    local user="$1"

    echo "Validating Docker group..."
    if ! docker exec "${NAME}" sh -c "groups ${user} | grep -qw docker"; then
        echo "FAIL: ${user} is not in the docker group"
        return 1
    fi
}

function validate_fonts() {
    echo "Validating fonts..."
    if ! docker exec "${NAME}" sh -c 'ls "/usr/share/fonts/truetype/MesloLGSDZ Nerd Font" | grep -qi meslo'; then
        echo "FAIL: Meslo font not found in /usr/share/fonts/truetype/MesloLGSDZ Nerd Font"
        return 1
    fi
}

function validate_default_shell() {
    local user="$1"

    echo "Validating default shell..."
    local default_shell
    default_shell=$(docker exec "${NAME}" getent passwd "${user}" | cut -d: -f7)
    if [[ "${default_shell}" != "/usr/bin/zsh" ]]; then
        echo "FAIL: Default shell is ${default_shell}, expected /usr/bin/zsh"
        return 1
    fi
}

function validate_alacritty() {
    echo "Validating Alacritty..."
    if ! docker exec "${NAME}" sh -c "command -v alacritty > /dev/null 2>&1"; then
        echo "FAIL: alacritty not found"
        return 1
    fi
}

function validate_mise() {
    echo "Validating Mise..."
    if ! docker exec "${NAME}" sh -c "command -v mise > /dev/null 2>&1"; then
        echo "FAIL: mise not found"
        return 1
    fi

    if ! docker exec "${NAME}" sh -c "mise --version > /dev/null 2>&1"; then
        echo "FAIL: mise is not working"
        return 1
    fi
}

function validate_neovim() {
    echo "Validating Neovim..."
    if ! docker exec "${NAME}" sh -c "command -v nvim > /dev/null 2>&1"; then
        echo "FAIL: nvim not found"
        return 1
    fi

    if ! docker exec "${NAME}" sh -c "nvim --version > /dev/null 2>&1"; then
        echo "FAIL: nvim is not working"
        return 1
    fi
}

function validate_editor_envvar() {
    local user="$1"

    echo "Validating EDITOR envvar..."
    local editor_val
    editor_val=$(docker exec "${NAME}" zsh -l -c 'echo "$EDITOR"')
    if [[ "${editor_val}" != "nvim" ]]; then
        echo "FAIL: EDITOR is '${editor_val}', expected 'nvim'"
        return 1
    fi
}

function validate_container() {
    echo "Restarting container ${NAME}..."
    docker restart "${NAME}"
    sleep 2

    local user="${USER}"
    local failed=0

    validate_dotfiles "${user}" || failed=1
    validate_docker_group "${user}" || failed=1
    validate_fonts || failed=1
    validate_default_shell "${user}" || failed=1
    validate_alacritty || failed=1
    validate_mise || failed=1
    validate_neovim || failed=1
    validate_editor_envvar "${user}" || failed=1

    if [[ "${failed}" -eq 1 ]]; then
        echo "Validation FAILED"
        return 1
    fi

    echo "Validation PASSED"
}

function cleanup() {
    container_id=$(docker inspect --format="{{.Id}}" "${NAME}" ||:)

    if [[ -n "${container_id}" ]]; then
        echo "Cleaning up container ${NAME}"
        docker rm --force "${container_id}"
    fi

    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        echo "Cleaning up tempdir ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}

setup_tempdir
trap cleanup EXIT
trap cleanup ERR
create_temporary_ssh_id
start_container
setup_test_inventory
run_ansible_playbook
validate_container
