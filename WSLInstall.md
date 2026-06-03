# 🐧 AzerothCore + Playerbots: WSL2 (Windows Subsystem for Linux) Installation Guide

This guide walks you through deploying the automated AzerothCore server environment directly inside Windows using **WSL2 running Debian**. 

Using WSL2 allows you to run the server locally on your gaming machine without a dedicated Linux VM or secondary server hardware.

---

## 💻 Step 1: Prepare Windows & Hardware Virtualization

Before installing Linux components, hardware virtualization must be enabled at the motherboard layer.
### 1. Verify Virtualization Status
1. Open Windows Task Manager (`Ctrl + Shift + Esc`).
2. Navigate to the **Performance** tab and click on **CPU**.
3. Look at the bottom right metrics and verify that **Virtualization: Enabled** is visible.

### 2. Enable Virtualization in your BIOS/UEFI
If not enabled, reboot your PC, enter your BIOS setup menu, and locate the CPU virtualization flag based on your processor type:
* **Intel Based CPUs:** Enable **Intel Virtualization Technology**, **VT-x**, or **Virtualization**.
* **AMD Based CPUs:** Enable **SVM Mode** or **AMD-V**.

*Save settings and reboot into Windows and re-verify.*

---

## 🛠️ Step 2: Install WSL2 Framework

1. Right-click the Windows Start button and select **PowerShell (Admin)** or **Terminal (Admin)**.
2. Execute the primary installation command:
   ```powershell
   wsl --install
   ```
3. **Reboot your computer** when prompted by Windows to finalize system-level components.
4. After rebooting, double-check Task Manager (`Performance → CPU`) to ensure Virtualization remains **Enabled**.

---

## 🧠 Step 3: Optimize WSL2 Resource Limits (Prevent RAM Overallocation)

By default, WSL2 can consume up to 75% or more of your total host system memory, which can starve your Windows environment during intensive compiler tasks. We will constrain it to a stable 8GB pool - I have 32GB of Ram, so please choose your own number.

1. Open a fresh **PowerShell** window.
2. Copy, paste, and run the following command block to instantly generate a custom resource configuration file (`.wslconfig`) in your Windows user profile folder:

```powershell
@"
[wsl2]
memory=8GB
"@ | Set-Content "$env:USERPROFILE\.wslconfig"
```

---

## 🐚 Step 4: Install and Prepare Debian

1. Open your terminal or PowerShell and pull down the explicit Debian environment layer:
   ```powershell
   wsl --install -d Debian
   ```
2. A new console window will pop open. Follow the prompts to set up your primary Linux username and password.
3. Bring the package manager up to date and install any updates:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
4. Assign a dedicated root system password:
   ```bash
   sudo su
   ```
   ```bash
   passwd
   ```
   ### Enter and confirm a strong root password

---

## 🌐 Step 5: Run the Auto-Deploy Installer Script

> [!NOTE]
> **No Network Formatting Needed:** Because WSL2 shares a local loopback interface directly with your Windows host operating system, you **do not** need to edit `/etc/network/interfaces` or calculate complex static IP subnets. The environment binds natively to `127.0.0.1`.

1. Ensure `curl` is present inside the Linux image:
   ```bash
   sudo apt update && sudo apt install curl -y
   ```
2. Drop into the root home directory, pull your specialized automation framework repository, flip permissions, and initialize deployment:
   ```bash
   su root
   ```
   ```bash
   cd ~
   ```
   ```bash
   curl -O https://raw.githubusercontent.com/Dextros/AzerothCore-AutoDeploy/refs/heads/main/setup_acore.sh && chmod +x setup_acore.sh && ./setup_acore.sh
   ```

### 🚨 Critical Installer Prompt Value:
When the script pauses and asks you to enter your **Server Network IP or Local Address**, type the exact local loopback address:
```text
127.0.0.1
```
Continue on and answer the questions with the settings that you want. 
---

## 🎮 Step 6: Connecting Your WoW Client

Once compilation finishes and the script spins up your tmux sessions, your infrastructure is fully alive on your local machine.

1. Navigate to your local World of Warcraft 3.3.5a client directory on your Windows desktop.
2. Open the file `/Data/enUS/realmlist.wtf` (or your regional variant folder) using Notepad.
3. Completely replace the contents with the local loopback target:
   ```text
   set realmlist 127.0.0.1
   ```
4. Save the file and launch `Wow.exe`. You can now log straight into your server natively from your Windows host!
5. Remember if you close your terminal session the WoW server will shutdown!

---

## 🔴 Step 7: Troubleshooting

If you are unable to connect to your server from your Windows game client, the most common issue is that the authentication or world processes haven't finished starting up inside Linux, or the local network ports are blocked.

You can verify if the server is listening for connections by running network connectivity checks directly from your Windows environment.

### 1. Test Network Ports via PowerShell
Open a standard **Windows PowerShell** window (no need to be inside Linux) and run the following diagnostic commands:

```powershell
# Test connection to the Login/Authentication Service (Port 3724)
Test-NetConnection 127.0.0.1 -Port 3724

# Test connection to the Game/World Service (Port 8085)
Test-NetConnection 127.0.0.1 -Port 8085
```

### 2. Reading Your Diagnostic Results

#### 🟢 What Success Looks Like (`TcpTestSucceeded : True`)
If your server applications are fully running and bound to your local environment correctly, the final line in your PowerShell window will explicitly state:
```text
ComputerName           : 127.0.0.1
RemoteAddress          : 127.0.0.1
RemotePort             : 3724
InterfaceAlias         : Loopback Pseudo-Interface 1
SourceAddress          : 127.0.0.1
TcpTestSucceeded       : True
```
If **`TcpTestSucceeded : True`** shows up for both ports, your infrastructure is perfectly healthy. Double-check your `realmlist.wtf` formatting to ensure it is typed correctly.

#### 🔴 What Failure Looks Like (`TcpTestSucceeded : False`)
If the check returns **`Warning: TCP connect to (127.0.0.1 : 3724) failed`** and displays **`TcpTestSucceeded : False`**, it means Windows cannot find the active game engine processes. 

To resolve a connection failure, follow these steps:
1. Hop back into your Linux terminal window.
2. Run the status command to see if the applications are running in memory:
   ```bash
   wow-status
   ```
3. If they are missing, type `start` to boot up the processes manually. If the World Server was recently started or updated, it can take up to 2–3 minutes to fully compile and load maps into memory before port `8085` opens up to accept connections.
