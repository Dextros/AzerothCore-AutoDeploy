#!/bin/bash
# ==============================================================================
# Script Name: install_azerothcore.sh
# Author:      Dextros - DK Inspirations in Tech
# Description: AzerothCore WotLK Automated Installer
# Target OS:   Debian 13 (Minimal Install)
# Host OS:     unRaid host
# ==============================================================================

# --- Colours ---
readonly PURPLE='\033[0;35m'
readonly B_PURPLE='\033[1;35m'
readonly GREY='\033[1;30m'
readonly BLUE='\033[1;36m'
readonly B_BLUE='\033[1;34m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# --- Global Variables ---
INSTALL_DIR="$HOME/azerothcore-wotlk"
LOG_FILE="/var/log/acore-install.log"
SETUP_SUMMARY="$HOME/wotlk_setup_summary.txt"

# --- Error Handling Function ---
die() {
    echo -e "\n${RED}[!] ERROR: $1${NC}"
    echo "Check $LOG_FILE for details." >&2
    exit 1
}

# --- Logging Setup ---
# Ensure log directory/file is writable before redirecting
touch "$LOG_FILE" 2>/dev/null || echo -e "${YELLOW}[!] Log file /var/log/acore-install.log not writable. Running without system log file capture.${NC}"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Header ---
echo -e "${B_PURPLE}██████╗ ██╗  ██╗██╗${GREY} - ${B_BLUE}████████╗███████╗ ██████╗██╗  ██╗${NC}"
echo -e "${B_PURPLE}██╔══██╗██║ ██╔╝██║${GREY} - ${B_BLUE}╚══██╔══╝██╔════╝██╔════╝██║  ██║${NC}"
echo -e "${B_PURPLE}██║  ██║█████╔╝ ██║${GREY} - ${B_BLUE}   ██║   █████╗  ██║     ███████║${NC}"
echo -e "${B_PURPLE}██║  ██║██╔═██╗ ██║${GREY} - ${B_BLUE}   ██║   ██╔══╝  ██║     ██╔══██║${NC}"
echo -e "${B_PURPLE}██████╔╝██║  ██╗██║${GREY} - ${B_BLUE}   ██║   ███████╗╚██████╗██║  ██║${NC}"
echo -e "${B_PURPLE}╚═════╝ ╚═╝  ╚═╝╚═╝${GREY} - ${B_BLUE}   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝${NC}"

echo -e "\n${BLUE}AzerothCore Automated Installer${NC}"
echo -e "${GREY}Prepared by Dextros | DK Inspirations in Tech${NC}"
echo "--------------------------------------------------------------------------------------"

# --- 1. Pre-flight Checks ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" || ( "$VERSION_ID" != "12" && "$VERSION_ID" != "13" ) ]]; then
        die "Unsupported OS: $NAME $VERSION_ID. This script requires Debian 12 or 13."
    fi
    echo -e "${GREEN}[+] Detected $NAME $VERSION_ID.${NC}"
else
    die "Could not determine Operating System."
fi

# --- 2. Network Configuration Check ---
echo -e "\n${BLUE}[*] Checking network configuration...${NC}"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
[[ -z "$INTERFACE" ]] && INTERFACE=$(ip -4 route show | grep default | awk '{print $5}' | head -n1)

IS_DHCP=false
if grep -q "dhcp" /etc/network/interfaces 2>/dev/null || [ -d "/etc/netplan" ] || command -v nmcli &>/dev/null; then
    IS_DHCP=true
fi

if [ "$IS_DHCP" = true ]; then
    echo -e "${YELLOW}[!] WARNING: DHCP detected. Your IP may change, breaking client connections.${NC}"
    echo -e "${YELLOW}[!] You can use this as a template to edit your interfaces "nano /etc/network/interfaces".${NC}"
        echo "auto $INTERFACE"
        echo "iface $INTERFACE inet static"
        echo "    address 192.168.1.21/24"
        echo "    gateway 192.168.1.1"
        echo "    dns-nameservers 192.168.1.1"
    read -p "[?] Do you want to proceed with a dynamic IP anyway? (y/n): " CONTINUE_DHCP
    [[ "$CONTINUE_DHCP" != "y" ]] && die "Installation aborted by user."
fi

# --- 3. User Input Section ---
echo -e "\n${BLUE}[*] Configuring Server Identity...${NC}"
DETECTED_IP=$(hostname -I | awk '{print $1}')

read -p "[?] What do you want your Realm Name to be? [Default: Azeroth]: " REALM_NAME
REALM_NAME=${REALM_NAME:-Azeroth}

read -p "[?] Server IP [Default: $DETECTED_IP]: " SERVER_IP
SERVER_IP=${SERVER_IP:-$DETECTED_IP}

read -p "[?] First Account Username [Default: DKI]: " ACCT_USER
ACCT_USER=${ACCT_USER:-DKI}

read -s -p "[?] First Account Password [Default: DKI]: " ACCT_PASS
echo ""
ACCT_PASS=${ACCT_PASS:-DKI}

# Save Summary
{
    echo "--- Install Run: $(date) ---"
    echo "Realm: $REALM_NAME | IP: $SERVER_IP | User: $ACCT_USER"
} > "$SETUP_SUMMARY"

# --- 4. Expansion & Bot Configurator ---
echo -e "\n${BLUE}[*] Warcraft Expansion & Playerbot Configuration...${NC}"

# 1. Determine the core expansion era boundaries
echo -e "\n${BLUE}[*] Which expansion do you want the server to start on...${NC}"
echo "1) Vanilla [60] | 2) TBC [70] | 3) WotLK [80] (Default)"
read -p "Selection [3]: " ERA_CHOICE
case ${ERA_CHOICE:-3} in
    1) ERA="vanilla"; EXP_MAX_LVL=60; EXPANSION=0; DK_DISABLE=1; TALENT_LIMIT=1 ;;
    2) ERA="tbc";     EXP_MAX_LVL=70; EXPANSION=1; DK_DISABLE=1; TALENT_LIMIT=1 ;;
    *) ERA="wotlk";   EXP_MAX_LVL=80; EXPANSION=2; DK_DISABLE=0; TALENT_LIMIT=0 ;;
esac

# 2. Determine the starting progression ecosystem
read -p "[?] Do you want a Fresh Server experience (Bots start at Lvl 1)? (y/n) [n]: " NEW_SERVER
NEW_SERVER=${NEW_SERVER:-n}

if [[ "$NEW_SERVER" == "y" ]]; then
    BOT_MIN_LVL=1
    BOT_MAX_LVL=1
    RANDOM_LVLS=0
else
    BOT_MIN_LVL=10
    BOT_MAX_LVL=$EXP_MAX_LVL
    RANDOM_LVLS=1
fi

read -p "[?] Bot Login Behavior (1: Logs on when players do, 2: Bots are always online) [2]: " LOGIN_CHOICE
ONLY_WITH_PLAYER=$([[ "${LOGIN_CHOICE:-2}" == "1" ]] && echo 1 || echo 0)

# --- 5. System Dependencies ---
apt update && apt install sudo vim btop git curl unzip tmux build-essential cmake -y || die "Failed to install system packages."

# --- 6. Repository & Compilation ---
echo -e "\n${BLUE}[*] Cloning AzerothCore (Playerbot Branch)...${NC}"
cd "$HOME" || die "Could not access home directory."

if [ -d "azerothcore-wotlk" ]; then
    echo "[+] Existing repository found. Pulling latest changes..."
    cd "$INSTALL_DIR" && git pull || die "Failed to update repository."
else
    git clone https://github.com/mod-playerbots/azerothcore-wotlk.git --branch=Playerbot || die "Git clone failed."
    cd "$INSTALL_DIR"
fi

mkdir -p modules
if [ ! -d "modules/mod-playerbots" ]; then
    git clone https://github.com/mod-playerbots/mod-playerbots.git --branch=master ./modules/mod-playerbots || die "Failed to clone playerbot module."
fi

DIST_CONF="$HOME/azerothcore-wotlk/conf/dist/config.sh"
if [ -f "$DIST_CONF" ]; then
    echo -e "${BLUE}[*] Patching OS distribution target to Debian...${NC}"
    sed -i 's/# OSDISTRO="ubuntu"/OSDISTRO="debian"/' "$DIST_CONF" || die "Failed to patch OS distribution configuration template."
else
    die "Critical Error: Configuration template file not found at $DIST_CONF"
fi

echo -e "\n${BLUE}[*] Installing Dependencies...${NC}"
./acore.sh install-deps || die "acore.sh failed to install dependencies."

WORLD_BIN="$INSTALL_DIR/env/dist/bin/worldserver"
if [ -f "$WORLD_BIN" ]; then
    read -p "[?] Existing build detected. Do you want to Recompile? (y/n) [n]: " RECOMPILE
    [[ "$RECOMPILE" != "y" ]] && SKIP_BUILD=true || SKIP_BUILD=false
else
    SKIP_BUILD=false
fi

if [ "$SKIP_BUILD" != true ]; then
    echo -e "${BLUE}[*] Starting Compilation... This will take time.${NC}"
    ./acore.sh compiler all || die "Compilation failed."
fi

# --- 7. Database Setup ---
echo -e "\n${BLUE}[*] Configuring MySQL...${NC}"
MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
if [ -n "$MYSQL_CONF" ]; then
    sudo sed -i 's/^bind-address.*/bind-address            = 0.0.0.0/' "$MYSQL_CONF"
    if ! grep -q "disable_log_bin" "$MYSQL_CONF"; then
        echo "disable_log_bin" | sudo tee -a "$MYSQL_CONF"
    fi
fi
sudo systemctl restart mysql || die "Failed to restart SQL Service."

# Drop and Recreate Users
sudo mysql -e "DROP USER IF EXISTS 'acore'@'localhost';"
sudo mysql -e "DROP USER IF EXISTS 'acore'@'%';"
sudo mysql -e "CREATE USER 'acore'@'localhost' IDENTIFIED BY 'acore';"
sudo mysql -e "CREATE USER 'acore'@'%' IDENTIFIED BY 'acore';"

# Create Databases
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`acore_world\` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`acore_characters\` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`acore_auth\` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`acore_playerbots\` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"

# Global Permissions - for connectivity by other mods or database reader tools
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'localhost' WITH GRANT OPTION;"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'%' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"

# --- 8. Configuration Injection ---
echo -e "\n${BLUE}[*] Loading map data, default configuration files and injecting configurations...${NC}"
./acore.sh client-data
cp env/dist/etc/authserver.conf.dist env/dist/etc/authserver.conf
cp env/dist/etc/worldserver.conf.dist env/dist/etc/worldserver.conf
cp env/dist/etc/modules/playerbots.conf.dist env/dist/etc/modules/playerbots.conf

WORLD_CONF="$INSTALL_DIR/env/dist/etc/worldserver.conf"
PB_CONF="$INSTALL_DIR/env/dist/etc/modules/playerbots.conf"

# Injecting expansion and bot configuration
sed -i "s/^Expansion *=.*/Expansion = $EXPANSION/" "$WORLD_CONF"
sed -i "s/^MaxPlayerLevel *=.*/MaxPlayerLevel = $EXP_MAX_LVL/" "$WORLD_CONF" # Tracks 60, 70, or 80

sed -i "s/^AiPlayerbot.MinRandomBots *=.*/AiPlayerbot.MinRandomBots = $MIN_BOTS/" "$PB_CONF"
sed -i "s/^AiPlayerbot.MaxRandomBots *=.*/AiPlayerbot.MaxRandomBots = $MAX_BOTS/" "$PB_CONF"
sed -i "s/^AiPlayerbot.RandomBotMinLevel *=.*/AiPlayerbot.RandomBotMinLevel = $BOT_MIN_LVL/" "$PB_CONF"
sed -i "s/^AiPlayerbot.RandomBotMaxLevel *=.*/AiPlayerbot.RandomBotMaxLevel = $BOT_MAX_LVL/" "$PB_CONF"
sed -i "s/^AiPlayerbot.DisableDeathKnightLogin *=.*/AiPlayerbot.DisableDeathKnightLogin = $DK_DISABLE/" "$PB_CONF"
sed -i "s/^AiPlayerbot.LimitTalentsExpansion *=.*/AiPlayerbot.LimitTalentsExpansion = $TALENT_LIMIT/" "$PB_CONF"
sed -i "s/^AiPlayerbot.DisableRandomLevels *=.*/AiPlayerbot.DisableRandomLevels = $RANDOM_LVLS/" "$PB_CONF"
sed -i "s/^AiPlayerbot.RandombotStartingLevel *=.*/AiPlayerbot.RandombotStartingLevel = $START_LVL/" "$PB_CONF"
sed -i "s/^AiPlayerbot.DisabledWithoutRealPlayer *=.*/AiPlayerbot.DisabledWithoutRealPlayer = $ONLY_WITH_PLAYER/" "$PB_CONF"

# --- 9. Automation & Aliases ---
echo -e "\n${BLUE}[*] Setting up automation and aliases...${NC}"

# Startup Script
cat <<EOF > "$HOME/start_acore.sh"
#!/bin/bash
cd "$INSTALL_DIR/env/dist/bin"
authserver="./authserver"
worldserver="./worldserver"
tmux new-session -d -s auth-session "\$authserver"
tmux new-session -d -s world-session "\$worldserver"
echo "Servers started in separate tmux panels."
EOF
chmod +x "$HOME/start_acore.sh"

# Bashrc Aliases
if ! grep -q "wow=" "$HOME/.bashrc"; then
cat << 'EOF' >> "$HOME/.bashrc"
export INSTALL_DIR="$HOME/azerothcore-wotlk"

# --- Core Control ---
alias wow='tmux attach -t world-session'
alias auth='tmux attach -t auth-session'
alias start='bash "$HOME/start_acore.sh"'

alias stop='tmux kill-session -t auth-session 2>/dev/null; tmux kill-session -t world-session 2>/dev/null; echo "[+] Server processes stopped."'
alias wow-status='pgrep -fl "authserver|worldserver"; ss -tulnp | grep -E "8085|3724"'
alias clear-logs='truncate -s 0 "$INSTALL_DIR"/env/dist/bin/*.log 2>/dev/null; echo "[+] All WoW logs truncated."'

# --- Compilation & Updates ---
alias compile='cd "$INSTALL_DIR" && ./acore.sh compiler all'
alias build='cd "$INSTALL_DIR" && ./acore.sh compiler build'
alias update='cd "$INSTALL_DIR" && ./acore.sh pull'
alias version='cd "$INSTALL_DIR" && ./acore.sh version'

# --- Maintenance ---
alias backup='mkdir -p "$HOME/backups"; \
echo "[*] Backing up Databases..."; \
mysqldump -u root --all-databases > "$HOME/backups/wow_db_\$(date +%F).sql"; \
echo "[*] Backing up Configs..."; \
tar -czvf "$HOME/backups/wow_conf_\$(date +%F).tar.gz" \
"$INSTALL_DIR"/env/dist/etc/*.conf \
"$INSTALL_DIR"/env/dist/etc/modules/*.conf 2>/dev/null; \
echo "[+] Backup complete in \$HOME/backups/"'

alias upgrade-ac='stop; \
backup; \
update; \
updatemods; \
db-init && build; \
audit-configs; \
start'

alias audit-configs='echo "--- World Config Changes ---"; \
diff --color -u "$INSTALL_DIR/env/dist/etc/worldserver.conf.dist" "$INSTALL_DIR/env/dist/etc/worldserver.conf" | grep -E "^\+|^-"; \
echo "--- Playerbot Config Changes ---"; \
diff --color -u "$INSTALL_DIR/env/dist/etc/modules/playerbots.conf.dist" "$INSTALL_DIR/env/dist/etc/modules/playerbots.conf" | grep -E "^\+|^-"'

alias clean='cd "$INSTALL_DIR" && ./acore.sh reset'
alias db-init='cd "$INSTALL_DIR" && ./acore.sh setup-db'
alias deps-install='cd "$INSTALL_DIR" && ./acore.sh install-deps'

# --- Modules & Data ---
alias mods='cd "$INSTALL_DIR" && ./acore.sh module'
alias maps-get='cd "$INSTALL_DIR" && ./acore.sh client-data'
alias updatemods='cd "$INSTALL_DIR/modules" && find . -mindepth 1 -maxdepth 1 -type d -exec git -C {} pull \;'

# --- Configuration & Tools ---
alias pb='nano "$INSTALL_DIR/env/dist/etc/modules/playerbots.conf"'
alias world='nano "$INSTALL_DIR/env/dist/etc/worldserver.conf"'
alias conf='cd "$INSTALL_DIR" && ./acore.sh config'
alias ac-test='cd "$INSTALL_DIR" && ./acore.sh test'
EOF
fi
# Set up automated log rotation to prevent hard drive from filling up. This will keep one weeks worth of logs
sudo mkdir -p /etc/logrotate.d
sudo cat <<EOF > /etc/logrotate.d/azerothcore
$INSTALL_DIR/env/dist/bin/*.log {
    weekly
    rotate 1
    copytruncate
    compress
    missingok
    notifempty
}
EOF

# --- 10. Final Initialization ---
echo -e "\n${BLUE}[*] Initializing Worldserver for the first time...${NC}"
bash "$HOME/start_acore.sh"

LOG_FILE_AC="$INSTALL_DIR/env/dist/bin/Server.log"
TIMEOUT=1200
ELAPSED=0

echo -e "${GREY}(Waiting for 'World Initialized' signal...)${NC}"
while ! grep -q "World Initialized" "$LOG_FILE_AC" 2>/dev/null; do
    if [ $ELAPSED -gt $TIMEOUT ]; then
        die "Timeout reached during world initialization."
    fi
    printf "\r${BLUE}.${NC}" ; sleep 5
    ELAPSED=$((ELAPSED + 5))
done

echo -e "\n${GREEN}[+] Worldserver initialized for the first time!${NC}"
echo -e "\n${GREEN}[+] Creating the new GM/User account!${NC}"

sleep 3
tmux send-keys -t world-session "account create $ACCT_USER $ACCT_PASS" C-m
tmux send-keys -t world-session "account set gmlevel $ACCT_USER 3 -1" C-m
sleep 3

echo "[*] Shuting down the WoW Server to update Realm Name and IP..."
tmux kill-session -t auth-session 2>/dev/null; tmux kill-session -t world-session 2>/dev/null
sleep 3

CLEAN_REALM=$(echo "$REALM_NAME" | tr -cd '[:alnum:] _-')
sudo mysql -e "USE acore_auth; UPDATE realmlist SET name = '$CLEAN_REALM', address = '$SERVER_IP' WHERE id = 1;"

echo -e "${GREEN}[+] All systems configured. Your server is starting again and will be ready to log into shortly.${NC}"
bash "$HOME/start_acore.sh"

echo "--------------------------------------------------------------------------------------"
echo -e "${GREEN}SUCCESS! Installation complete.${NC}"
echo "--------------------------------------------------------------------------------------"
echo "Summary saved to: $SETUP_SUMMARY"
echo "To enable aliases immediately, please run: source ~/.bashrc"
echo "Commands available: start, stop, wow, auth, wow-status, backup, upgrade-ac, audit-configs, clean, db-init, deps-install, mods, maps-get, updatemods, compile, build, update, version, pb, world, conf, ac-test"
echo "REMINDER: Update your client's realmlist.wtf to: $SERVER_IP"
echo "--------------------------------------------------------------------------------------"
