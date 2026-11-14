# System E

Ansible stuff that gets a new machine set up for me. This is supposed to be my bare minimum set up (ZSH Starship etc). Should not be setting up loads of language stuff.

> Prefer working build over completeness

> Prefer Simplicity over Complexity

> Prefer stability over speed

## Usage

This works for Debian Distros or MacOS (Apple Silicon only). Use the relevant instructions.

### Debian
1. Clone the repo
2. Update the package repository
3. Run the install local bin script `./bin/debian/install-local.sh`
4. Go off and do something else (If TZInfo isn't installed, the script will ask for this.)
5. Check everything has run as expected
6. Install Git Town https://www.git-town.com/install

### MacOS
1. Clone the repo
2. Install HomeBrew (optional — the playbook detects it and only runs Homebrew-backed installs when it is present; everything else installs directly)
3. Run the install local bin script `./bin/macos/install-local.sh`
4. Go off and do something else
5. Check everything has run as expected
6. Install Git Town https://www.git-town.com/install

## Testing

### Debian
Simply run `./bin/debian/test-container.sh` with ansible installed. It won't ask for the become password as it's not needed in the container.

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
2. Run `./bin/macos/validate-vm.sh` to check that we can establish connection
3. run `./bin/macos/test-vm.sh` to run the test

> The docker container will utilise the processor available on the box. This will mean that for x86 cpus, the Mac will be an Intel version rather than Apple Silicon. In this case, the test will do a minimal install as a smoke test and not the full shebang. :( (`bin/macos/test-vm.sh` sets `minimal_install=true` automatically on Intel guests — override with `MINIMAL_INSTALL=true|false`.)


### Post Run Checklist
- [ ] Create an SSH key for Git and anything else as well while you're at it and add it to the ssh client
- [ ] Copy config using yadm `sudo yadm pull -f [config repo thing here]`
- [ ] Check path is set up
- [ ] Make sure SystemD daemon is reloaded for Docker
- [ ] Make sure Mise is set up right so we can install languages (use `mise doctor`)

