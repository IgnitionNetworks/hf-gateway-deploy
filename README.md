# Ignition Networks HF Gateway — Docker Deployment

**Browser-based control and audio for Codan Envoy HF radio networks.**

The HF Web Gateway connects your Codan Envoy HF radios to IP networks and browser clients, giving operators full radio control from any device on the network — without dedicated hardware or specialist software.

Each of the features is licensable:
* Number of Radios to connect
* Web Audio and PTT
* RTP Streaming
* SIP Integration
* Multi Radio IVR system

> [!IMPORTANT]
> x86_64 required — will not work on ARM

Bootstrap package for running the Codan HF Radio Gateway using pre-built Docker images. No source code or build tools required.

---

## What It Does

### Web-Based Radio Control

A responsive web interface lets operators monitor and control all connected radios from any browser. Each radio shows live status, current channel, PTT state, and active call information. No plugins or client software required.

### Browser Audio Streaming

Transmit and receive audio directly in the browser. Operators can listen to radio traffic and key PTT without a physical radio present. Multiple clients can monitor simultaneously.

### VoIP / Telephone Integration

Connects HF radios to standard SIP telephone infrastructure. Incoming and outgoing calls are bridged between the radio and your phone system, enabling telephone users to communicate over HF with no additional hardware.

### Automated Call Handling

- **Auto-answer** incoming calls and bridge them directly to radio
- **IVR (Interactive Voice Response)** — play audio menus to callers and route calls based on DTMF input
- **VOX (Voice Operated Switch)** — automatic PTT triggered by audio level, no manual keying required
- **DTMF PTT** — telephone keypad controls push-to-talk on the radio

### Multi-Radio Management

Manage multiple radios from a single interface. Each radio operates independently with its own channel list, call routing, and audio configuration. Operators can switch channels, monitor status, and control PTT across all radios simultaneously.

### RTP Audio Routing

Stream radio audio to and from any RTP-capable device or system on the network — recorders, dispatch consoles, intercom systems, and broadcast equipment.

### Message History

Incoming call records and messages are logged and accessible through the web interface.

---

## System Requirements

- Linux host (x86_64)
- [Docker Engine](https://docs.docker.com/engine/install/) ≥ 24
- [Docker Compose](https://docs.docker.com/compose/install/) v2 (bundled with Docker Desktop or installed via the plugin)
- Codan Envoy HF radio reachable over IP
- A valid Ignition Networks HF Gateway licence

---

## Installation

### 1. Clone this repo

```bash
git clone https://github.com/ignitionnetworks/hf-gateway-deploy
cd hf-gateway-deploy
```

### 2. Configure

Copy the starter config and fill in your radio details:

```bash
cp config/starter_config.jsonc config/config.jsonc
```
This step is simply required for new installations and is here so upgrades dont overwrite existing config.

### 3. Set your environment

```bash
cp .env.example .env
```

Edit `.env` if you want a different port (default: 8000) or to pin to a specific version.

### 4. Start

```bash
docker compose up -d
```

Pull and start. The gateway container uses `network_mode: host` for direct RTP/SIP access; the backend container exposes the web UI on the configured port.

### 5. Access the web UI

Open `http://<your-host-ip>:8000` in a browser.

Default credentials: **admin / changeme**

**Change the password immediately** after first login via Settings → Change Password.

---

## Operations

### View logs

```bash
docker compose logs -f
# or check the ./logs/ directory on the host
```

### Stop

```bash
docker compose down
```

### Upgrade to a new release

```bash
docker compose pull
docker compose up -d
```

Data in `./data/` (users, sessions, message history) is preserved across upgrades.

### Reset admin password

If you are locked out:

```bash
docker compose exec backend reset_admin_password.sh
```

---

## Directory Layout

```
hf-gateway-deploy/
├── docker-compose.yml      — service definitions (pull from GHCR)
├── .env.example            — version + port settings
├── config/
│   └── starter_config.jsonc  — radio/system config template
├── data/                   — SQLite databases (auto-created, do not commit)
└── logs/                   — runtime logs (auto-created)
```

---

## Licensing

The HF Web Gateway is licensed software. Each installation requires a licence tied to the specific machine or container it runs on.

To obtain a licence:

1. Install the software and note your unique key (shown on the web UI licence page, or via `GET /api/license`)
2. Email [contact@ignition.net.nz](mailto:contact@ignition.net.nz) with your unique key and intended use
3. Enter the registration code you receive into the configuration file

For licensing enquiries, volume pricing, or support contracts, contact us at **[contact@ignition.net.nz](mailto:contact@ignition.net.nz)**.

---

## Troubleshooting

**Web UI not loading**
- Check `docker compose ps` — both containers should be `Up`
- Check `docker compose logs backend` for startup errors
- Verify `./config/config.jsonc` exists and is valid JSON (minus comments)

**Gateway not connecting to radio**
- Confirm radio IP is reachable from the host: `ping <radio-ip>`
- The gateway uses `network_mode: host` — check that RTP ports (default 50010–50020) are not blocked by a firewall
- Check `docker compose logs rtp-gateway` for SDK errors

**IPC socket not found (backend can't reach gateway)**
- Both containers share `/tmp` via the `ipc` Docker volume
- Check the socket exists: `docker compose exec backend ls /tmp/codan_rtp_gateway.sock`
- If missing, the gateway may not have started — check its logs

**Licence errors**
- Ensure `license.registration_code` in `config.jsonc` matches your licence

---

## Image Registry

Images are published to the GitHub Container Registry (GHCR):

- `ghcr.io/ignitionnetworks/codan-hf-gateway`
- `ghcr.io/ignitionnetworks/codan-hf-backend`

Tags follow semantic versioning (`v1.2.3`) plus `latest`.

---

*HF Web Gateway is developed and maintained by Ignition Networks.*
