# Linux Services Discovery for Zabbix

Forked from: [Zabbix Community Template – Linux Services](https://github.com/zabbix/community-templates/tree/main/Operating_Systems/template_linux_services/6.0)

This repository contains a Zabbix template, scripts, and configuration for automated discovery and monitoring of Linux services.

## Contents

- `service_discovery.sh` – Script to discover systemd services and report their status numerically.
- `service_ignore.list` – List of services to exclude from discovery.
- `Linux_Discovery.yaml` – Zabbix template for service discovery.
- Instructions to configure Zabbix agent.

## Requirements

- Zabbix agent installed on the monitored host.
- Systemd-based Linux distribution.
- Scripts installed under `/etc/zabbix/scripts/`.

## Installation

1. **Place scripts on the monitored host:**

```bash
sudo mkdir -p /etc/zabbix/scripts
sudo cp service_discovery.sh /etc/zabbix/scripts/
sudo cp service_ignore.list /etc/zabbix/scripts/
sudo chmod +x /etc/zabbix/scripts/service_discovery.sh
Update Zabbix agent configuration (/etc/zabbix/zabbix_agentd.conf):

conf
Copier le code
UserParameter=service.discovery,/etc/zabbix/scripts/service_discovery.sh
UserParameter=service.status[*],/etc/zabbix/scripts/service_discovery.sh $1
Restart Zabbix agent:

bash
Copier le code
sudo systemctl restart zabbix-agent
Import the template (Linux_Discovery.yaml) into your Zabbix frontend.

How it Works
service_discovery.sh:

Without arguments: performs full discovery of systemd services, excluding those listed in service_ignore.list.

With a service name argument: returns a numeric status:

1: enabled and running

0: enabled but stopped

2: disabled but running

3: disabled and stopped

4: static/masked/generated

Zabbix template:

Uses the discovery script to create items for each service.

Creates triggers if a service is not running.

Customization
Modify service_ignore.list to exclude additional services.

Adjust discovery delay or item polling intervals in the template YAML.

Notes
UTF-8 is enforced in scripts to handle non-ASCII service names.

Tested on systemd-based Linux distributions.
