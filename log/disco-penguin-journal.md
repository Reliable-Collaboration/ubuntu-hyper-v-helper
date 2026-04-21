# Installation notes for disco-penguin

Test VM for the first real end-to-end run of the guest scripts. The VM itself was created by hand from a slightly-imperfect earlier pass at the docs; we're now running the guest scripts in order and recording what actually happens.

## Pre-bootstrap

Installed by hand before invoking any repo scripts:

```bash
sudo apt update && apt-get full-upgrade

# These commands will prevent the desktop from automatically locking when it's idle.
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

sudo apt install -y git
git clone https://github.com/Reliable-Collaboration/ubuntu-hyper-v-helper.git


sudo apt install curl -y
curl -fsSL https://claude.ai/install.sh | bash
```

