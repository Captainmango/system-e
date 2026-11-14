# Agent Context

## Project Overview
Ansible playbooks for bootstrapping new machines with a minimal, opinionated environment (ZSH, Starship, tmux, Docker, Neovim, fonts, base tools). Debian/Ubuntu targets use `local.yml`/`remote.yml`; macOS targets use `local-mac.yml`/`remote-mac.yml`.

# IMPORTANT
- Never run the test-container.sh script. Ask the user to run this and provide the output. It takes too long to run in a chat session.
- Never run the test-macos.sh script for the same reason (it drives a macOS VM and is even slower). Ask the user to run it.
- Ignore macos folder completely. It contains the container image used for basic testing and should not ever be considered read.

## Key Files
| File | Purpose |
|------|---------|
| `local.yml` | Playbook for localhost execution (used on new machines) |
| `remote.yml` | Playbook for remote hosts over SSH |
| `tasks/main.yml` | Orchestrates all setup steps |
| `tasks/steps/*.yml` | Individual task modules (base deps, terminal, fonts, Docker, Neovim, etc.) |
| `local-mac.yml` | Playbook for localhost execution on macOS |
| `remote-mac.yml` | Playbook for remote macOS hosts over SSH |
| `tasks/macos.yml` | Orchestrates all macOS setup steps |
| `tasks/steps/macos/*.yml` | macOS task modules — direct installs where possible, Homebrew only when detected |
| `requirements.yml` | Ansible collections needed (`community.general` provides the `homebrew` module) |
| `bin/install-local.sh` | Installs Ansible from PPA and runs `local.yml` |
| `bin/install-local-mac.sh` | Ensures CLT/Ansible/collections and runs `local-mac.yml` |
| `bin/post-install-mac.sh` | macOS post-install (default shell, yadm fallback) |
| `bin/test-container.sh` | Docker-based test harness for `remote.yml` |
| `bin/test-macos.sh` | macOS VM test harness for `remote-mac.yml` |
| `bin/validate-macos.sh` | Checks SSH connectivity to the macOS VM before testing |
| `Dockerfile.test` | Ubuntu SSH container used by the test harness |
| `ansible.cfg` | Minimal Ansible config (`host_key_checking = False`) |

## Developer Commands
- **Local bootstrap**: `./bin/install-local.sh` (Debian) / `./bin/install-local-mac.sh` (macOS)
- **Remote test in Docker**: `./bin/test-container.sh`
  - Builds an Ubuntu SSH container, generates a temp SSH key, and runs `remote.yml` against it.
  - Auto-cleans the container and temp files on exit/error via `trap`.
- **macOS VM test**: `./bin/test-macos.sh` (after `./bin/validate-macos.sh`)
  - Runs `remote-mac.yml` against the macOS VM from `docker-compose.yml`, then validates each step over SSH.
  - Sets `minimal_install=true` automatically on Intel guests (skips heavy GUI apps); override with `MINIMAL_INSTALL=true|false`.

## CI
- `.github/workflows/ci.yml` runs `./bin/install-local.sh` on every push to `main`, weekly (Mondays at 05:30 UTC), and on manual dispatch.
- CI does **not** run `bin/test-container.sh`.

## Conventions & Constraints
- **Target OS**: Debian/Ubuntu (APT-based) and macOS (`*-mac.yml` playbooks + `tasks/steps/macos/`).
- **Philosophy**: Prefer working builds over completeness, simplicity over complexity, stability over speed.
- **Ansible style**: Use `apt` module with `become: true` for package management. Use `include_tasks` for modularity.
- **macOS/Homebrew**: Avoid Homebrew wherever a direct install exists (vendor URLs, GitHub releases). Homebrew-backed tasks must be gated on the `homebrew_installed` fact set by `tasks/steps/macos/homebrew.yml`, so the playbook runs clean on machines without brew (like the test VM). The `homebrew` module comes from the `community.general` collection — installed via `ansible-galaxy collection install -r requirements.yml` (the bin scripts do this). macOS tasks also avoid `become` where possible (user-local `~/.local/bin`, admin-writable `/Applications`); it is only used for CLT install, Remote Login and `chsh`, all guarded by checks.
- **Environment variable**: `USER` must be set. It is used by `remote.yml`, `Dockerfile.test`, `bin/test-container.sh`, `tasks/steps/install_docker.yml` (adding user to `docker` group), and `tasks/steps/setup_terminal.yml` (changing default shell to zsh). macOS tasks use the `ansible_user_id` fact instead so they work for both local and remote runs.
- **Architecture mapping**: Both Debian playbooks define `arch_mapping` (`x86_64` → `amd64`, `aarch64` → `arm64`) for the Docker APT repository. Both macOS playbooks define `arch_mapping` (`x86_64` → `amd64`, `arm64` → `arm64`) for the Docker Desktop dmg URL. Note macOS reports `arm64`, not `aarch64`.
- **Config bootstrap**: `copy_config.yml` force-clones `https://github.com/Captainmango/config-files.git` via `yadm`.
- **Step Validation**: New steps must have a validation function in bin/test-container.sh (Debian) or bin/test-macos.sh (macOS) to validate the outcome is successful.
- **Minimal mode**: `minimal_install` (playbook var, default `false`) skips the heavy macOS GUI apps (WezTerm, Docker Desktop, VSCode, Obsidian, Chrome) for smoke tests.
