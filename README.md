# System E

Ansible stuff that gets a new machine set up for me. This is supposed to be my bare minimum set up (ZSH Starship etc). Should not be setting up loads of language stuff.

> Prefer working build over completeness

> Prefer Simplicity over Complexity

> Prefer stability over speed

## Usage

This works for Debian Distros or MacOS. Use the relevant instructions.

### Debian
1. Clone the repo
2. Update the package repository
3. Run the install local bin script `./bin/install-local.sh`
4. Go off and do something else (If TZInfo isn't installed, the script will ask for this.)
5. Check everything has run as expected
6. Install Git Town https://www.git-town.com/install

### MacOS
1. Run `docker compose up -d` to start the Mac Docker VM
    a. Connect to port 8006 using your web browser.
    b. After the recovery image is downloaded, a black screen with a progress bar will appear while macOS downloads the remaining installation files.
    c. Once the download is complete, the macOS recovery menu will appear.
    d. Choose Disk Utility and then select the largest Apple Inc. VirtIO Block Media disk.
    e. Click the Erase button to format the disk to APFS, and give it any name you like.
    f. Close the current window and proceed the installation by clicking Reinstall macOS.
    g. When prompted where you want to install it, select the disk you created previously.
    h. After all files are copied, select your region, language, and keyboard settings.
    i. When the Migration Assistant wants to transfer data, select Not now (bottom left).
    j. On the Apple ID screen, select Set Up Later (bottom left) and then proceed using Skip.
    k. On the Create a Computer Account screen, fill in a username and password and Continue.



## Todo list
- [x] Set up Ansible playbooks in tasks folder
- [x] Set up test bed with Docker
- [x] Create task for installing the font (MesloLGS)
- [x] Create task for installing basic deps
- [x] Create task for porting configurations
- [x] Create task for installing languages using Mise
- [x] Add Docker and sudo group for Docker
- [x] Set up scheduled testing using Github Actions (run weekly or monthly)
- [x] Set up Git and associated tools (github CLI and Git-town)
- [x] Set up Neovim (get the tarball from latest and unzip into opt, then Symlink)
- [ ] SSH keys maybe?
- [x] Move to Starship over Powerline10k
- [ ] Optional tasks
    - [ ] Bitwarden
    - [x] Chrome
    - [x] Obsidian + vaults


### basic deps
- ~git~
- ~docker (with usergroup to not need sudo)~
- ~c-utils (build-essentials)~
- ~curl~
- ~git cli~
- ~git-town~
- ~portainer~
- ~tmux~
- ~ohmyzsh~
- ~powerline10k~
- ~Starship~


### Post Run Checklist
- [ ] Create an SSH key for Git and anything else as well while you're at it and add it to the ssh server
- [ ] Copy config using yadm `sudo yadm pull -f [config repo thing here]`
- [ ] Check path is set up
- [ ] Make sure SystemD daemon is reloaded
- [ ] Make sure Mise is set up right so we can install languages

