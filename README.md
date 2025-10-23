# Linux Services Discovery for Zabbix

Forked from: [Zabbix Community Template – Linux Services](https://github.com/zabbix/community-templates/tree/main/Operating_Systems/template_linux_services/6.0)

This repository contains a Zabbix template, scripts, and configuration for automated discovery and monitoring of Linux services.

Tested on Debian 11 & 12 servers, with zabbix 6.4.15 and zabbix-agent 6.4.15 only.

It's my first time creating something on github and also, I used ChatGPT for doing this. I think it could be better in many ways but do the trick for my needs for now.

## Contents

- `service_discovery.sh` – Script to discover systemd services and report their status numerically.
- `service_ignore.list` – List of services to exclude from discovery.
- `Linux_Discovery.yaml` – Zabbix template for service discovery.
- Instructions to configure Zabbix agent.

## Requirements

- Zabbix agent installed on the monitored host.
- Systemd-based Linux distribution.

## Installation

1. **Place scripts on the monitored host:**

```bash
sudo mkdir -p /etc/zabbix/scripts
sudo cp service_discovery.sh /etc/zabbix/scripts/
sudo cp service_ignore.list /etc/zabbix/scripts/
sudo chmod +x /etc/zabbix/scripts/service_discovery.sh

```
Update Zabbix agent configuration (/etc/zabbix/zabbix_agentd.conf):

Add these lines
```bash
UserParameter=service.discovery,/etc/zabbix/scripts/service_discovery.sh
UserParameter=service.status[*],/etc/zabbix/scripts/service_discovery.sh $1
```
Restart Zabbix agent:
```bash
sudo systemctl restart zabbix-agent
```
Import the template (Linux_Discovery.yaml) into your Zabbix frontend.

How it Works
service_discovery.sh:

Without arguments: performs full discovery of systemd services, excluding those listed in service_ignore.list. - discovery key -

With a service name argument - Item prototype key - : returns a numeric status:

1: enabled and running

0: enabled but stopped

2: disabled but running

3: disabled and stopped

4: static/masked/generated

Zabbix template:

Uses the discovery script to create items for each service.

Creates triggers if a service is not running but should be (because enabled).

Customization
Modify service_ignore.list to exclude additional services (I ignored services I consider useless to monitor and "aliases".
You can modify/add trigers based on other numeric status as you like

## Author

**Marwane** (forked from Frater)

---

## Macros used

There are no macros linked in this template.

---

## Template links

There are no template links in this template.

---

## Discovery rules

| Name                     | Description                                                                                  | Type        | Key and additional info | Update interval |
|--------------------------|----------------------------------------------------------------------------------------------|------------|------------------------|----------------|
| Linux service discovery  | Automatically discovers all systemd services on the host, excluding those in service_ignore.list. Creates items for each discovered service. | Zabbix agent | service.discovery      | 1h             |

---

## Items collected

| Name                     | Description                                                                                  | Type        | Key and additional info        | Update interval |
|--------------------------|----------------------------------------------------------------------------------------------|------------|-------------------------------|----------------|
| Service status {#SERVICE} | Reports numeric status of each discovered service: 0=enabled/stopped, 1=enabled/running, 2=disabled/running, 3=disabled/stopped, 4=static/masked/generated | Zabbix agent | service.status[{#SERVICE}]    | 2m             |

---

## Triggers

| Name                         | Description                                                                                  | Expression                                  | Recovery expression | Priority |
|-------------------------------|----------------------------------------------------------------------------------------------|--------------------------------------------|------------------|----------|
| Service {#SERVICE} is not running | Fires when a monitored service is enabled but not running (numeric value 0). | `last(/Linux_Services/service.status[{#SERVICE}])=0` | -                | High     |

Notes
UTF-8 is enforced in scripts to handle non-ASCII service names.

Tested on systemd-based Linux distributions.
