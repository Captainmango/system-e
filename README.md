# System E

Ansible stuff that gets a new machine set up for me. This is supposed to be my bare minimum set up (ZSH Powerline10k etc). Should not be setting up loads of language stuff.

> Prefer working build over completeness

> Prefer Simplicity over Complexity

> Prefer stability over speed

## Usage
1. Clone the repo
2. Update the package repository (this was made for Debian distros so use APT)
3. Run the install local bin script `./bin/install-local.sh`
4. Go off and do something else (If TZInfo isn't installed, the script will ask for this.)
5. Check everything has run as expected (Probably hasn't lol)
6. Install Git Town https://www.git-town.com/install

## Todo list
- [x] Set up Ansible playbooks in tasks folder
- [x] Set up test bed with Docker
- [x] Create task for installing the font (MesloLGS)
- [x] Create task for installing basic deps
- [x] Create task for porting configurations
- [x] Create task for installing languages using Mise
- [x] Add Docker and sudo group for Docker
- [x] ~Add Portainer~ We need the docker daemon to be started and booting systemD in docker isn't worth it so we cannot test this
- [x] Set up scheduled testing using Github Actions (run weekly or monthly)
- [ ] Set up Git and associated tools (github CLI and Git-town)
- [ ] Set up Neovim (get the tarball from latest and unzip into opt, then Symlink)


### basic deps
- ~git~
- ~docker (with usergroup to not need sudo)~
- ~c-utils (build-essentials)~
- ~curl~
- ~git cli~
- git-town
- ~portainer~
- ~tmux~
- ~ohmyzsh~
- ~powerline10k~


### Post Run Checklist
- [ ] Create an SSH key for Git and anything else as well while you're at it and add it to the ssh server
- [ ] Copy config using yadm `sudo yadm pull -f [config repo thing here]`
- [ ] Check path is set up
- [ ] Make sure SystemD daemon is reloaded
- [ ] Install languages we need

