#!/bin/bash
# Deploy Zabbix service discovery scripts from GitHub repo (Debian)
# UTF-8 / AZERTY compatible
# Run as root

set -e
export LC_ALL=C.UTF-8

SCRIPTS_DIR="/etc/zabbix/scripts"
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"
GIT_REPO="https://github.com/killerwanee/Zabbix-Linux-Services-AutoDiscovery.git"

FILES=("service_discovery.sh" "service_ignore.list")

PARAM1='UserParameter=service.discovery,/etc/zabbix/scripts/service_discovery.sh'
PARAM2='UserParameter=service.status[*],/etc/zabbix/scripts/service_discovery.sh $1'

echo "===== ZABBIX SERVICE DISCOVERY DEPLOYMENT PRECHECK ====="
echo "Target directory: $SCRIPTS_DIR"
echo "Config file:      $CONF_FILE"
echo ""

NEED_UPDATE=false

# Check directory
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo " - Directory missing: $SCRIPTS_DIR (will be created)"
    NEED_UPDATE=true
else
    echo " - Directory exists: $SCRIPTS_DIR"
fi

# Check files
for FILE in "${FILES[@]}"; do
    if [ -f "$SCRIPTS_DIR/$FILE" ]; then
        echo " - $FILE: already present"
    else
        echo " - $FILE: missing (will be copied)"
        NEED_UPDATE=true
    fi
done

# Check UserParameter lines
for PARAM in "$PARAM1" "$PARAM2"; do
    if grep -Fxq "$PARAM" "$CONF_FILE"; then
        echo " - $PARAM: already present"
    else
        echo " - $PARAM: missing (will be added)"
        NEED_UPDATE=true
    fi
done

# Decide if anything needs to be done
if ! $NEED_UPDATE; then
    echo ""
    echo "Nothing to update. All files and parameters are already present."
    echo "Agent restart skipped."
    echo "===== DEPLOYMENT SKIPPED ====="
    exit 0
fi

echo " - Zabbix agent: will be restarted if changes applied"
echo ""
read -rp "Proceed with these actions? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

echo ""
echo "===== EXECUTION STARTED ====="

# Create directory if missing
mkdir -p "$SCRIPTS_DIR"

# Clone repo into temporary folder
TMP_DIR=$(mktemp -d -t zabbix_discovery.XXXXXXXX)
git clone --depth 1 "$GIT_REPO" "$TMP_DIR"

# Copy required files only
for FILE in "${FILES[@]}"; do
    SRC="$TMP_DIR/$FILE"
    DEST="$SCRIPTS_DIR/$FILE"
    if [ -f "$DEST" ]; then
        echo "Skipped $FILE (already exists)"
    else
        cp "$SRC" "$DEST"
        echo "Copied $FILE to $SCRIPTS_DIR"
    fi
done

# Clean up temporary folder
rm -rf "$TMP_DIR"

# Remove unwanted repo files if present
for REMOVE_FILE in "README.md" "Linux_Services_Discovery.yaml"; do
    TARGET="$SCRIPTS_DIR/$REMOVE_FILE"
    if [ -f "$TARGET" ]; then
        rm -f "$TARGET"
        echo "Removed $REMOVE_FILE"
    fi
done

# Make main script executable
if [ -f "$SCRIPTS_DIR/service_discovery.sh" ]; then
    chmod +x "$SCRIPTS_DIR/service_discovery.sh"
    echo "Set executable permissions on service_discovery.sh"
fi

# Add UserParameter lines safely
for PARAM in "$PARAM1" "$PARAM2"; do
    if ! grep -Fxq "$PARAM" "$CONF_FILE"; then
        if grep -q '^# UserParameter=' "$CONF_FILE"; then
            sed -i "/^# UserParameter=/a $PARAM" "$CONF_FILE"
        else
            TOTAL_LINES=$(wc -l < "$CONF_FILE")
            if [ "$TOTAL_LINES" -ge 31 ]; then
                sed -i "31i $PARAM" "$CONF_FILE"
            else
                echo "$PARAM" >> "$CONF_FILE"
            fi
        fi
        echo "Added $PARAM"
    fi
done

# Restart Zabbix agent only if updates were applied
AGENT_RESTARTED=false
if $NEED_UPDATE && systemctl list-units --type=service | grep -q zabbix-agent.service; then
    systemctl restart zabbix-agent
    echo "Zabbix agent restarted."
    AGENT_RESTARTED=true
fi

echo ""
echo "===== POST-DEPLOYMENT VERIFICATION ====="

# Verify files
for FILE in "${FILES[@]}"; do
    if [ -f "$SCRIPTS_DIR/$FILE" ]; then
        echo "[OK] $FILE exists"
    else
        echo "[MISSING] $FILE"
    fi
done

# Verify UserParameter lines
for PARAM in "$PARAM1" "$PARAM2"; do
    if grep -Fxq "$PARAM" "$CONF_FILE"; then
        echo "[OK] UserParameter line present: $PARAM"
    else
        echo "[MISSING] UserParameter line: $PARAM"
    fi
done

# Verify zabbix-agent status
if $AGENT_RESTARTED; then
    echo "[OK] Zabbix agent restarted"
else
    echo "[INFO] Zabbix agent not restarted (no changes applied or service missing)"
fi

echo "===== DEPLOYMENT COMPLETE ====="