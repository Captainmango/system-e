# Agent Context

## Project Overview
Ansible playbooks for bootstrapping new Debian/Ubuntu machines with a minimal, opinionated environment (ZSH, Powerline10k, tmux, Docker, Neovim, fonts, base tools).

# IMPORTANT
Never run the test-container.sh script. Ask the user to run this and provide the output. It takes too long to run in a chat session.

## Key Files
| File | Purpose |
|------|---------|
| `local.yml` | Playbook for localhost execution (used on new machines) |
| `remote.yml` | Playbook for remote hosts over SSH |
| `tasks/main.yml` | Orchestrates all setup steps |
| `tasks/steps/*.yml` | Individual task modules (base deps, terminal, fonts, Docker, Neovim, etc.) |
| `bin/install-local.sh` | Installs Ansible from PPA and runs `local.yml` |
| `bin/test-container.sh` | Docker-based test harness for `remote.yml` |
| `Dockerfile.test` | Ubuntu SSH container used by the test harness |
| `ansible.cfg` | Minimal Ansible config (`host_key_checking = False`) |

## Developer Commands
- **Local bootstrap**: `./bin/install-local.sh`
- **Remote test in Docker**: `./bin/test-container.sh`
  - Builds an Ubuntu SSH container, generates a temp SSH key, and runs `remote.yml` against it.
  - Auto-cleans the container and temp files on exit/error via `trap`.

## CI
- `.github/workflows/ci.yml` runs `./bin/install-local.sh` on every push to `main`, weekly (Mondays at 05:30 UTC), and on manual dispatch.
- CI does **not** run `bin/test-container.sh`.

## Conventions & Constraints
- **Target OS**: Debian/Ubuntu only (APT-based).
- **Philosophy**: Prefer working builds over completeness, simplicity over complexity, stability over speed.
- **Ansible style**: Use `apt` module with `become: true` for package management. Use `include_tasks` for modularity.
- **Environment variable**: `USER` must be set. It is used by `remote.yml`, `Dockerfile.test`, `bin/test-container.sh`, and `tasks/steps/install_docker.yml` (adding user to `docker` group).
- **Architecture mapping**: Both playbooks define `arch_mapping` (`x86_64` → `amd64`, `aarch64` → `arm64`) for the Docker APT repository.
- **Config bootstrap**: `copy_config.yml` force-clones `https://github.com/Captainmango/config-files.git` via `yadm`.
