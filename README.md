# System E

Ansible stuff that gets a new machine set up for me. This is supposed to be my bare minimum set up (ZSH Powerline10k etc). Should not be setting up loads of language stuff.

> Prefer working build over completeness

> Prefer Simplicity over Complexity

> Prefer stability over speed

## Usage
1. Clone the repo
2. Run the install local bin script `./bin/install-local.sh`
3. Go off and do something else (If TZInfo isn't installed, the script will ask for this.)

## Todo list
- [x] Set up Ansible playbooks in tasks folder
- [x] Set up test bed with Docker
- [x] Create task for installing the font (MesloLGS)
- [x] Create task for installing basic deps
- [x] Create task for porting configurations
- [x] Create task for installing languages using Mise
- [x] Add Docker and sudo group for Docker
- ~[x] Add Portainer~ We need the docker daemon to be started and booting systemD in docker isn't worth it so we cannot test this
- [ ] Set up scheduled testing using Github Actions (run weekly or monthly)


### basic deps
- ~git~
- ~docker (with usergroup to not need sudo)~
- ~c-utils (build-essentials)~
- ~curl~
- git cli
- git-town
- ~portainer~
- ~tmux~
- ~ohmyzsh~
- ~powerline10k~


### Language deps
- Go
- Ruby
- Python
- Scala/ Java

