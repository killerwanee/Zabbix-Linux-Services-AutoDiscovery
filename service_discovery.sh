#!/bin/bash
export LC_ALL=C.UTF-8

SERVICE="$1"

if [ -n "$SERVICE" ]; then
    # Runtime numeric status for a single service
    INSTALL=$(systemctl is-enabled "$SERVICE" 2>/dev/null)
    RUNTIME=$(systemctl is-active "$SERVICE" 2>/dev/null)

    NUM=0
    case "$INSTALL" in
        enabled)
            [ "$RUNTIME" = "active" ] && NUM=1
            [ "$RUNTIME" != "active" ] && NUM=0
            ;;
        disabled)
            [ "$RUNTIME" = "active" ] && NUM=2
            [ "$RUNTIME" != "active" ] && NUM=3
            ;;
        static|masked|generated)
            NUM=4
            ;;
    esac
    echo "$NUM"
    exit 0
fi

# If no argument, do full discovery
TMPDIR=$(mktemp -d -t systemd_discovery.XXXXXXXXXX)
FILTER_FILE="/etc/zabbix/scripts/service_ignore.list"
FILTER_TMP="${TMPDIR}/ignore.list"
[ -f "$FILTER_FILE" ] && cp "$FILTER_FILE" "$FILTER_TMP" && sed -i 's/\r$//; /^$/d' "$FILTER_TMP" || touch "$FILTER_TMP"

SERVICES_TMP="${TMPDIR}/services"
systemctl list-unit-files --type=service --no-pager --no-legend \
    | awk '{print $1, $2}' \
    | grep '[a-z]' \
    | grep -Fvf "$FILTER_TMP" \
    | sort -u > "$SERVICES_TMP"

echo -e "{\n\t\"data\":["
PRINTED=false

while read -r LINE; do
    [ -z "$LINE" ] && continue
    SERVICE_NAME=$(echo "$LINE" | awk '{print $1}' | sed 's/\.service$//')
    INSTALL=$(echo "$LINE" | awk '{print $2}')

    RUNTIME=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null)
    NUM=0
    case "$INSTALL" in
        enabled)
            [ "$RUNTIME" = "active" ] && NUM=1
            [ "$RUNTIME" != "active" ] && NUM=0
            ;;
        disabled)
            [ "$RUNTIME" = "active" ] && NUM=2
            [ "$RUNTIME" != "active" ] && NUM=3
            ;;
        static|masked|generated)
            NUM=4
            ;;
    esac

    if $PRINTED; then echo ","; fi
    PRINTED=true
    echo -n -e "\t\t{ \"{#SERVICE}\":\"${SERVICE_NAME}\", \"{#STATE}\":${NUM} }"
done < "$SERVICES_TMP"

echo -e "\n\t]\n}"
rm -r "$TMPDIR"
