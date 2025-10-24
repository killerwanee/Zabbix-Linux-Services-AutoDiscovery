#!/bin/bash
# Zabbix Linux Services AutoDiscovery - Robust Deployment Script (Debian)
# Version: 1.1 (2025-10)
# Author: Marwane with GPT-5 assistance

set -euo pipefail

# --- COLORS (terminal only) ---
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# --- CONFIG ---
TARGET_DIR="/etc/zabbix/scripts"
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"
REPO_URL="https://github.com/killerwanee/Zabbix-Linux-Services-AutoDiscovery.git"
TMP_DIR="/tmp/zabbix_service_discovery_repo"
PARAM_LINE1="UserParameter=service.discovery,/etc/zabbix/scripts/service_discovery.sh"
PARAM_LINE2="UserParameter=service.status[*],/etc/zabbix/scripts/service_discovery.sh \$1"
LOG_DIR="/var/log/zabbix"
LOG_FILE="$LOG_DIR/deploy_service_discovery.log"

mkdir -p "$LOG_DIR"

# --- LOG FUNCTION ---
log() {
    echo -e "$1"
    echo -e "$1" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' >> "$LOG_FILE"
}

log "============================================"
log "Deployment run: $(date)"
log "============================================\n"

# --- CHECK ROOT PRIVILEGES ---
if [ "$EUID" -ne 0 ]; then
    log "${RED}ERROR:${NC} This script must be run as root."
    exit 1
fi

# --- CHECK GIT ---
if ! command -v git >/dev/null 2>&1; then
    log "${YELLOW}git is not installed.${NC}"
    read -rp "Install git now? (y/N): " INSTALL_GIT
    if [[ "$INSTALL_GIT" =~ ^[Yy]$ ]]; then
        log "Installing git..."
        apt update && apt install -y git || { log "${RED}ERROR:${NC} git installation failed."; exit 1; }
        log "${GREEN}git installed successfully.${NC}"
    else
        log "${RED}Cannot continue without git. Aborting.${NC}"
        exit 1
    fi
fi

# --- PRECHECKS ---
log "===== ZABBIX SERVICE DISCOVERY DEPLOYMENT PRECHECK ====="
log "Target directory: $TARGET_DIR"
log "Config file:      $CONF_FILE"
log ""

NEED_ACTION=false

# Directory
if [ -d "$TARGET_DIR" ]; then
    log "${GREEN}Target directory exists:${NC} $TARGET_DIR"
else
    log "${YELLOW}Target directory missing:${NC} $TARGET_DIR (will be created)"
    NEED_ACTION=true
fi

# Config file
if [ -f "$CONF_FILE" ]; then
    log "${GREEN}Zabbix config file exists:${NC} $CONF_FILE"
else
    log "${RED}ERROR: Zabbix config file missing:${NC} $CONF_FILE"
    exit 1
fi

# --- TIMEOUT CHECK & OPTIONAL UPDATE ---
TIMEOUT_LINE=$(grep -iE '^\s*#?\s*timeout\s*=' "$CONF_FILE" || true)

if [ -n "$TIMEOUT_LINE" ]; then
    if [[ "$TIMEOUT_LINE" =~ ^# ]]; then
        log "${YELLOW}Timeout setting is currently commented:${NC} $TIMEOUT_LINE"
    else
        log "${YELLOW}Timeout setting is currently set to:${NC} $TIMEOUT_LINE"
    fi
else
    log "${YELLOW}No timeout setting found in $CONF_FILE.${NC}"
fi

read -rp "Do you want to set Timeout=10 in zabbix_agentd.conf? (y/N): " SET_TIMEOUT
if [[ "$SET_TIMEOUT" =~ ^[Yy]$ ]]; then
    if [ -n "$TIMEOUT_LINE" ]; then
        # Replace the detected line in place
        sed -i "s|^\s*#\?\s*timeout\s*=.*|Timeout=10|I" "$CONF_FILE"
        log "${GREEN}Timeout updated to 10, replacing existing line.${NC}"
    else
        # No line found, add new
        echo "Timeout=10" >> "$CONF_FILE"
        log "${GREEN}Timeout=10 added as new line.${NC}"
    fi
else
    log "Timeout not changed."
fi

# Check files
SCRIPT_PATH="$TARGET_DIR/service_discovery.sh"
IGNORE_PATH="$TARGET_DIR/service_ignore.list"

for FILE in "$SCRIPT_PATH" "$IGNORE_PATH"; do
    if [ -f "$FILE" ]; then
        log "${GREEN}$FILE:${NC} already present (no action)"
    else
        log "${YELLOW}$FILE:${NC} missing (will be created)"
        NEED_ACTION=true
    fi
done

# Check UserParameter lines
for PARAM in "$PARAM_LINE1" "$PARAM_LINE2"; do
    if grep -Fxq "$PARAM" "$CONF_FILE"; then
        log "${GREEN}$PARAM:${NC} already present (no action)"
    else
        log "${YELLOW}$PARAM:${NC} missing (will be added)"
        NEED_ACTION=true
    fi
done

# Nothing to do?
if ! $NEED_ACTION; then
    log "\n${GREEN}All files and parameters already present. Nothing to do.${NC}"
    log "Agent restart skipped."
    log "===== DEPLOYMENT SKIPPED ====="
    exit 0
fi

log ""
log "Planned actions summary:"
log " - ${YELLOW}Create missing files in $TARGET_DIR${NC}"
log " - ${YELLOW}Add missing UserParameter lines to $CONF_FILE${NC}"
log " - ${YELLOW}Restart Zabbix agent (mandatory)${NC}"
log ""
read -rp "Proceed with these actions? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }

# --- BACKUP CONFIG ---
BACKUP_FILE="${CONF_FILE}.bak_$(date +%F_%H-%M-%S)"
cp "$CONF_FILE" "$BACKUP_FILE"
log "${GREEN}Backup created:${NC} $BACKUP_FILE"

# --- CREATE DIRECTORY ---
mkdir -p "$TARGET_DIR"

# --- CLONE REPO ---
log "Cloning repository..."
rm -rf "$TMP_DIR"
if ! git clone --depth=1 "$REPO_URL" "$TMP_DIR"; then
    log "${RED}ERROR:${NC} Repository clone failed. Check URL/network/git."
    exit 1
fi

# --- COPY FILES (if missing) ---
for FILE in "$SCRIPT_PATH" "$IGNORE_PATH"; do
    BASE=$(basename "$FILE")
    if [ ! -f "$FILE" ]; then
        if ! cp "$TMP_DIR/$BASE" "$FILE"; then
            log "${RED}ERROR:${NC} Failed to copy $BASE"
            exit 1
        fi
        chmod +x "$FILE"
        log "${YELLOW}Created:${NC} $BASE → $TARGET_DIR"
    else
        log "${GREEN}Skipped:${NC} $BASE (already exists)"
    fi
done

# --- CLEAN TMP ---
rm -rf "$TMP_DIR"

# --- ADD USERPARAMETER LINES ---
for PARAM in "$PARAM_LINE1" "$PARAM_LINE2"; do
    if ! grep -Fxq "$PARAM" "$CONF_FILE"; then
        if grep -q "^# UserParameter=" "$CONF_FILE"; then
            LINE_NUM=$(grep -n "^# UserParameter=" "$CONF_FILE" | head -n1 | cut -d: -f1)
            sed -i "$((LINE_NUM+1))i $PARAM" "$CONF_FILE"
        else
            TOTAL_LINES=$(wc -l < "$CONF_FILE")
            if [ "$TOTAL_LINES" -ge 31 ]; then
                sed -i "31i $PARAM" "$CONF_FILE"
            else
                echo "$PARAM" >> "$CONF_FILE"
            fi
        fi
        log "${YELLOW}Added UserParameter line:${NC} $PARAM"
    fi
done

# --- VALIDATE CONFIG ---
log "Validating Zabbix agent configuration..."
if ! zabbix_agentd -t "service.discovery" >/dev/null 2>&1; then
    log "${RED}ERROR:${NC} Configuration test failed. Restoring backup."
    cp "$BACKUP_FILE" "$CONF_FILE"
    exit 1
else
    log "${GREEN}Configuration validated successfully.${NC}"
fi

# --- INTERACTIVE, MANDATORY RESTART ---
if systemctl status zabbix-agent >/dev/null 2>&1; then
    echo "Restart is mandatory for the deployment to work."
    while true; do
        read -rp "Do you want to restart the Zabbix agent now? (y/N): " RESTART_CONFIRM
        RESTART_CONFIRM=${RESTART_CONFIRM:-y}  # default yes if empty
        if [[ "$RESTART_CONFIRM" =~ ^([Yy])$ ]]; then
            if systemctl restart zabbix-agent; then
                log "${GREEN}Zabbix agent restarted.${NC}"
                break
            else
                log "${RED}ERROR:${NC} Failed to restart zabbix-agent."
                exit 1
            fi
        else
            echo "Restart is mandatory. Please confirm."
        fi
    done
else
    log "${RED}ERROR:${NC} zabbix-agent service not found. Cannot restart."
    exit 1
fi

# --- POST-DEPLOYMENT VERIFICATION ---
log ""
log "===== POST-DEPLOYMENT VERIFICATION ====="
for FILE in "$SCRIPT_PATH" "$IGNORE_PATH"; do
    [ -f "$FILE" ] && log "${GREEN}[OK]${NC} $FILE exists" || log "${RED}[MISSING]${NC} $FILE"
done

for PARAM in "$PARAM_LINE1" "$PARAM_LINE2"; do
    grep -Fxq "$PARAM" "$CONF_FILE" && log "${GREEN}[OK]${NC} UserParameter line present: $PARAM" || log "${RED}[MISSING]${NC} UserParameter line: $PARAM"
done

log "===== DEPLOYMENT COMPLETE ====="
