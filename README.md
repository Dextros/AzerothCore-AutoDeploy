# 🛠️ Automated AzerothCore + Playerbots Installer for Debian 13

An all-in-one automated script to deploy a pristine **AzerothCore (WoW 3.3.5a) server with integrated Playerbots** on a fresh Debian 13 environment. This project is tailored for home labs, private networks, with a simple install procedure to get up and running with the basics quickly.

🎬 **[Watch the Complete Video Walkthrough on YouTube](YOUR_YOUTUBE_LINK_HERE)**

---

## 🛑 Critical Security Warning

> [!WARNING]
> **LAN USE ONLY:** This setup framework runs operations under the **`root`** account and configures SSH for direct root access. This is a deliberate security trade-off for installation simplicity. **Do not expose this server to the internet.** Keep it strictly inside your private local network. An updated version supporting non-root service users is currently under development.

---

## 📦 Required Resources

Before starting, download the necessary files to your local machine:

### 1. Server Environment
* **Operating System:** [Debian 13 AMD64 Netinst ISO](https://mirror.cogentco.com/debian-cd/current/amd64/iso-cd/) *(Note: Avoid the `edu` and `mac` variants).*
* **Virtualisation Software:** You can run this on any hypervisor. Popular choices include **unRaid (VMs)**,  VirtualBox, or VMware Workstation.

### 2. Client & Addons
* **Game Client:** [WotLK 3.3.5a Clean Client via ChromieCraft](https://chromiecraft.com/en/downloads/)
* **Addons:** [ChromieCraft 3.3.5a Addons Listing](https://felbite.com/chromiecraft-addons/)
* **Bot Control Addon:** [Unbot Addon (English Branch)](https://github.com/noisiver/unbot-addon/tree/english) *(Essential for commanding your playerbots in-game).*

---

## 📑 Step-by-Step Installation Guide

### Step 1: Base OS Installation
1. Boot your virtual machine using the downloaded Debian 13 ISO.
2. Follow the standard text installation prompts. 
3. **Important:** When selecting software components, **do not install a desktop environment**. Ensure that **SSH Server** and **Standard System Utilities** are checked.
4. Finish installation, remove the installation media, and reboot.

### Step 2: Initial Login & Enable SSH Root Access
Log directly into your server through your hypervisor console, then elevate to the root user and unlock remote SSH terminal connections:

```bash
# Elevate to root account
su root

# Enable root login over SSH and restart the service
sed -ie '0,/#PermitRootLogin prohibit-password/s/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && service sshd restart
```

### Step 3: Configure a Static IP Address
To ensure you don't lose track of your server across reboots, assign it a permanent static IP address. 

1. Run this helper command to automatically generate the correct network block configuration matching your current network settings:
   ```bash
   IFACE=$(ip -o -4 addr show | grep -v ' lo ' | awk '{print $2}' | head -n1); echo -e "auto $IFACE\niface $IFACE inet static\n address $(ip -o -4 addr show | grep -v ' lo ' | awk '{print $4}' | head -n1)\n gateway $(ip route | awk '/default/ {print $3}')\n dns-nameservers $(grep -v -E '^#|^$' /etc/resolv.conf | awk '/nameserver/ {print $2}' | paste -sd ' ' -)"
   ```
2. Open your network configurations file:
   ```bash
   nano /etc/network/interfaces
   ```
3. Use the output generated in the previous step to format your file so it looks like this (adjusting variables to match your network adapter name and IP schema):
   ```text
   auto enp3s0
   iface enp3s0 inet static
       address 192.168.1.21/24
       gateway 192.168.1.1
       dns-nameservers 192.168.1.2
   ```
4. Save and exit (`Ctrl + O`, then `Ctrl + X`), then restart your networking service:
   ```bash
   systemctl restart networking
   ```

### Step 4: Run the Automated Deployment Script
Type `exit` to clear the hypervisor console. Open your favorite desktop terminal emulator (like PuTTY, Windows Terminal) and log back in remotely using your new static IP address.

```bash
# Log back in as root via your desktop terminal
ssh root@your_new_static_ip

# Install curl to grab the script from github
apt update && apt install curl -y

# Navigate to home directory
cd ~

# Download and execute the installer script
curl -O https://raw.githubusercontent.com/Dextros/AzerothCore-AutoDeploy/refs/heads/main/setup_acore.sh && chmod +x setup_acore.sh && ./setup_acore.sh
```
# Follow the on screen instructions to complete the remainder of the set up.
---

## ⌨️ Server Management Shortcuts
Once the installer completes its tasks, it will inject several helper aliases directly into your terminal interface. You can manage your entire server utilising these when logged in as the root user:

| Command | Action |
| :--- | :--- |
| `start` | Launches both Auth and World server background processes in tmux sessions. |
| `stop` | Instantly and safely kills all background running game server instances. |
| `wow` | Hooks your active terminal directly into the live **World Server console**. *(Disconnect using `Ctrl+B`, then `D`)* |
| `auth` | Hooks your active terminal directly into the live **Auth Server console**. *(Disconnect using `Ctrl+B`, then `D`)* |
| `upgrade-ac` | Fully automates a safe update sequence: stops services, runs a backup, pulls updates, updates db schema, and rebuilds. |
| `wow-status` | Verifies that the server applications are running and listening on network ports `8085` and `3724`. |
| `clear-logs` | Safely clears down and truncates all server text logs to recover valuable storage space. |
| `update` | Grabs the absolute latest updates for the primary AzerothCore repository code from GitHub. |
| `compile` | Triggers a full, top-to-bottom clean compilation of your core files (ideal for first-time setup). |
| `build` | Triggers a quick incremental compilation that builds only new modifications or script edits. |
| `version` | Displays the exact build release version signature hash currently tracking on your installation. |
| `backup` | Instantly exports a secure tarball archive of your system configuration files and an SQL data dump. |
| `audit-configs` | Compares your active production server configuration files against the default core layout templates. |
| `clean` | Clears down local operational caches to resolve occasional complex compiler hiccups. |
| `db-init` | Re-runs the baseline database design framework installation settings tools. |
| `maps-get` | Triggers the build framework's utility client to download or check core game asset maps files. |
| `mods` | Launches the interactive shell menu to toggle or deploy custom community modular options. |
| `updatemods` | Loops through your active extensions directory and runs an automated git pull update across all modules. |
| `world` | Opens the main operational settings configuration map directly into nano text editor. |
| `pb` | Reaches straight inside the playerbot modular configurations parameters inside nano text editor. |
| `conf` | Displays the built-in server settings dashboard deployment script engine tools. |
| `ac-test` | Runs the software unit test suites to ensure proper baseline framework stability. |

---
To use these, log into the game client on an account with GM permissions, hit Enter to open chat, and type them exactly as shown.

### 🌟 Essential Game Master (GM) Commands

| Command Syntax          | What it does                                                  | Example / Tip                                            |
|-------------------------|---------------------------------------------------------------|----------------------------------------------------------|
| `.tele $location`       | Instantly teleports your character to major hubs or zones.    | `.tele stormwind` or `.tele orgrimmar`                   |
| `.tele group $location` | Instantly teleports your group to major hubs or zones.        | `.tele group stormwind` or `.tele group orgrimmar`       |
| `.gps`                  | Displays your exact grid coordinates and Zone ID.             | Great for finding coordinates to use with other scripts. |
| `.additem #id`          | Spawns a specific item directly into your bags.               | `.additem 49623` *(Spawns Shadowmourne)*                 |
| `.modify money #amount` | Adds copper to your character (`10000` = 1 Gold).             | `.modify money 5000000` *(Adds 500 Gold)*                |
| `.modify speed #value`  | Changes your running/flying speed (Default speed is `1`).     | `.modify speed 5` *(Makes you run 5x faster)*            |
| `.revive`               | Restores full health/mana and resurrects you if you are dead. | Target a dead player or bot to resurrect them instead.   |
| `.lookup item $name`    | Searches the database for an item's numerical ID code.        | `.lookup item Sulfuras`                                  |
| `.lookup quest $name`   | Searches for a quest ID to help skip broken/stuck quests.     | `.lookup quest The Lich King`                            |
### 🗺️ World, Npc, & Instance Management

- .npc add #creatureid
  - What it does: Spawns a permanent monster, vendor, or custom NPC exactly where your character is standing.
  - Tip: Use .lookup creature $name to find the ID code first. To delete a misplaced NPC, target them and type .npc delete.
- .instance unbind all
  - What it does: Wipes all raid and heroic dungeon save locks from your target character.
  - Tip: Essential if you are testing dungeon scripts or boss mechanics and don't want to wait a week for the standard instance lock reset.

 Full list of PlayerBot Commands here - https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Commands 
