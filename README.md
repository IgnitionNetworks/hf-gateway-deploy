# Ignition Networks HF Gateway — Docker Deployment

**Browser-based control and audio for Codan Envoy HF radio networks.**

The HF Web Gateway connects your Codan Envoy HF radios to IP networks and browser clients, giving operators full radio control from any device on the network — without dedicated hardware or specialist software.

Each of the following features is individually licensable:

- Number of radios to connect
- Web Audio (browser streaming and PTT)
- RTP streaming
- SIP / VoIP telephone integration
- IVR (Interactive Voice Response)
- Instant Connect Enterprise channel sync
- Virtual Radios (RX voting and split-site operation)

> [!IMPORTANT]
> x86_64 required — will not run on ARM (Raspberry Pi, Apple Silicon, etc.)

Bootstrap package for running the HF Web Gateway using a pre-built Docker image. No source code or build tools required.

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

Manage multiple radios from a single interface. Each radio operates independently with its own channel list, call routing, and audio configuration.

### Virtual Radios and RX Voting

Group physical radios into virtual radio groups for split-site operation and receive voting. The gateway selects the best-signal receiver automatically.

### RTP Audio Routing

Stream radio audio to and from any RTP-capable device or system — recorders, dispatch consoles, intercom systems, and broadcast equipment.

### Instant Connect Enterprise Integration

Automatically push radio channel names to an ICE system whenever the channel changes, keeping ICE channel labels in sync with radio state.

### Message History

Incoming call records and SELCAL/ALE messages are logged and accessible through the web interface.

---

## System Requirements

- Linux host (x86_64)
- [Docker Engine](https://docs.docker.com/engine/install/) ≥ 24
- [Docker Compose](https://docs.docker.com/compose/install/) v2 (bundled with Docker Desktop or installed via the plugin)
- Codan Envoy HF radio reachable over IP
- A valid Ignition Networks HF Gateway licence
- `openssl` on the host (for generating self-signed certificates; pre-installed on most Linux distributions)
- Ports 80 and 443 open in your firewall

If you have problems installing Docker on Ubuntu 24.04 - try these things

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o  /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```



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

Edit `config/config.jsonc` — at minimum set the radio `ip` address and set `enabled: true` once it is reachable. All other settings can be adjusted from the web UI after first boot.

### 3. Set your environment

```bash
cp .env.example .env
```

Edit `.env` if you want to pin to a specific image version.

### 4. Set up SSL

The default deployment uses nginx for HTTPS. Choose one of the options below before starting.

#### Option A — Self-signed certificate (quick start / internal networks)

Generates a certificate in seconds. Browsers will show a one-time security warning; accept it or add the certificate to your OS trust store.

```bash
bash certs/generate-self-signed.sh
```

#### Option B — Let's Encrypt (internet-facing / trusted certificate)

Requires a public domain name with a DNS A record pointing to this server, and port 80 reachable from the internet.

```bash
# Start nginx first (using a self-signed cert as a placeholder):
bash certs/generate-self-signed.sh
docker compose up -d nginx

# Then replace with the trusted certificate:
bash scripts/letsencrypt-setup.sh your.domain.com admin@example.com
```

The script obtains the certificate, links it into place, reloads nginx, and prints a `crontab` entry for automatic renewal.

#### Option C — Existing reverse proxy / SSL offload

If TLS is already handled upstream (hardware load balancer, existing nginx, cloud proxy), use the bare compose file instead. It exposes port 8000 directly without the bundled nginx:

```bash
docker compose -f docker-compose.template.yml up -d
```

Your upstream proxy must pass `Upgrade`/`Connection` headers for the `/ws` WebSocket path and set `X-Forwarded-Proto: https`.

### 5. Start

```bash
docker compose up -d
```

Pulls the gateway and nginx images and starts both containers. The RTP gateway and web backend run together inside the gateway container managed by supervisord. `network_mode: host` is used for direct RTP/SIP UDP access; nginx bridges to it via the host network.

### 6. Access the web UI

Open `https://<your-host-ip>` in a browser. (If using a self-signed certificate your browser will warn — accept the exception to proceed.)

Default credentials: **admin / changeme**

**Change the password immediately** after first login via the user menu → Change Password.

---

## Air-gap Installation

For hosts with no internet access, export the Docker images on a connected machine, transfer them, and load them on the target.

Two images are required:
| Image | Purpose |
|---|---|
| `ghcr.io/ignitionnetworks/ignition-hf-gateway:<version>` | Gateway + web backend |
| `nginx:alpine` | Reverse proxy / SSL termination |

### Step 1 — Export images (internet-connected machine)

```bash
# Replace v1.2.3 with the release you are deploying
VERSION=v1.2.3

docker pull ghcr.io/ignitionnetworks/ignition-hf-gateway:${VERSION}
docker pull nginx:alpine

docker save ghcr.io/ignitionnetworks/ignition-hf-gateway:${VERSION} \
    | gzip > ignition-hf-gateway-${VERSION}.tar.gz

docker save nginx:alpine | gzip > nginx-alpine.tar.gz
```

### Step 2 — Transfer to the target host

Copy both `.tar.gz` files and the contents of this repository to the airgapped host via USB drive, secure file transfer, or your organisation's approved media:

```
ignition-hf-gateway-v1.2.3.tar.gz
nginx-alpine.tar.gz
hf-gateway-deploy/          ← this repository
```

### Step 3 — Load images (target host)

```bash
docker load < ignition-hf-gateway-v1.2.3.tar.gz
docker load < nginx-alpine.tar.gz
```

Confirm both images are present:

```bash
docker images | grep -E "ignition-hf-gateway|nginx"
```

### Step 4 — Pin the version and start

Edit `.env` to pin to the exact version you loaded (this prevents Docker from attempting a pull at startup):

```bash
# .env
VERSION=v1.2.3
```

Then follow the standard installation steps (configure, generate certs, start):

```bash
bash certs/generate-self-signed.sh
docker compose up -d
```

### Upgrading on an air-gapped host

Repeat Steps 1–3 for the new release, then:

```bash
# Update the pinned version
sed -i 's/VERSION=.*/VERSION=v1.3.0/' .env

# Restart — uses the locally loaded image, no pull attempted
docker compose up -d
```

---

## Operations

### View logs

All log files are written under `./logs/` on the host:

| File | Contents | Rotation |
|---|---|---|
| `gateway.log` | C++ RTP gateway — radio SDK, RTP, codec, call events | 20 MB × 5 |
| `backend.log` | Python web backend — API, WebSocket, IPC, auth, notifications | 20 MB × 10 |
| `backend-stderr.log` | Uvicorn stderr — startup messages and unhandled exceptions | 5 MB × 2 |
| `supervisord.log` | Process supervisor — service start/stop/restart events | 10 MB × 3 |
| `entrypoint.log` | Container startup diagnostics — hostname resolution, SDK port checks | unbounded |
| `smtp.log` | Email notification activity (DEBUG level; also appears in `backend.log`) | 20 MB × 10 |
| `sip.log` | PJSIP trace — SIP registration, calls, errors *(only created if SIP is enabled)* | unbounded |

```bash
# Follow gateway and radio events
tail -f ./logs/gateway.log

# Follow backend API, auth, and notification activity
tail -f ./logs/backend.log

# Follow both together
tail -f ./logs/gateway.log ./logs/backend.log

# Check container startup and SDK port diagnostics
cat ./logs/entrypoint.log

# Supervisor process events (start/stop/crash)
tail -f ./logs/supervisord.log
```

### Stop

```bash
docker compose down
```

### Upgrade to a new release

> [!IMPORTANT]
> Read the release notes before upgrading. Some releases include a configuration migration step that must be completed before restarting services.

Data in `./data/` (users, sessions, message history), `./config/config.jsonc`, and `./certs/` are preserved across upgrades.

#### Online upgrade (internet-connected host)

```bash
# Pull the latest gateway image (nginx:alpine is pulled automatically if not cached)
docker compose pull

# Restart containers with the new image
docker compose up -d
```

To pin to a specific release rather than always running `latest`, set the version in `.env`:

```bash
# .env
VERSION=v1.3.0
```

Then pull and restart as above. To roll back, set `VERSION` to the previous tag and run `docker compose up -d` — Docker will use the locally cached image without re-pulling.

#### Air-gap upgrade (no internet on target host)

See the **Air-gap Installation** section below for how to transfer a new image to an isolated host.

### Reset admin password

If you are locked out of the admin account:

```bash
docker compose exec ignition-hf-gateway reset_admin_password.sh
```

---

## Directory Layout

```
hf-gateway-deploy/
├── docker-compose.yml        — default: gateway + nginx SSL termination
├── docker-compose.template.yml — bare: gateway only, for existing SSL infrastructure
├── .env.example              — version pin settings
├── nginx/
│   └── nginx.conf            — nginx: HTTP→HTTPS redirect, WebSocket upgrade, proxy config
├── certs/
│   ├── generate-self-signed.sh — generates certs/fullchain.pem + privkey.pem
│   ├── fullchain.pem         — TLS certificate (gitignored — generated locally)
│   └── privkey.pem           — TLS private key  (gitignored — generated locally)
├── scripts/
│   └── letsencrypt-setup.sh  — obtain a trusted cert via Let's Encrypt (certbot)
├── config/
│   ├── starter_config.jsonc  — copy this to config.jsonc to get started
│   └── config.jsonc          — your active config (gitignored)
├── prompts/                  — WAV audio files served to callers
│   ├── ringtone.wav          — ringback tone heard while HF call connects (replaceable)
│   └── deny_tone.wav         — tone played when a call is rejected or times out (replaceable)
├── data/                     — SQLite databases (auth, messages — gitignored)
└── logs/                     — runtime logs (gitignored; see Operations → View logs for file list)
```

The `prompts/` directory is mounted at `/prompts` inside the container. Replace either WAV file with your own 8 kHz mono PCM WAV to customise call audio. IVR flow prompt files uploaded via the web UI are also stored here.

Certificate files (`*.pem`, `*.key`, `*.crt`) are excluded from git by `certs/.gitignore` and must be generated locally on each host.

---

## Licensing

The HF Web Gateway is licensed software. Each installation requires a licence tied to the specific machine or container instance it runs on.

To obtain a licence:

1. Start the container and note your **unique key** — shown on the web UI Settings → License page, or via:
   ```bash
   curl http://localhost:8000/api/license | python3 -m json.tool
   ```
2. Email [contact@ignition.net.nz](mailto:contact@ignition.net.nz) with your unique key and the features you need
3. Paste the registration code you receive into `config/config.jsonc` under `license.registration_code`, then save — no restart required

For licensing enquiries, volume pricing, or support contracts, contact **[contact@ignition.net.nz](mailto:contact@ignition.net.nz)**.

---

## Troubleshooting

### Web UI not loading

```bash
docker compose ps
```
The `ignition-hf-gateway` container should show `Up`. If it has exited or is restarting:

```bash
# Supervisor process events — what started, crashed, or restarted
cat ./logs/supervisord.log

# Backend startup errors (uvicorn stderr — config parse failures, import errors)
cat ./logs/backend-stderr.log

# Container startup diagnostics — hostname resolution, SDK port conflicts
cat ./logs/entrypoint.log
```

Common causes:
- `./config/config.jsonc` is missing — copy from `starter_config.jsonc`
- `config.jsonc` has a JSON syntax error — run `python3 -m json.tool config/config.jsonc` to validate (note: strip `//` comments first, or use a JSONC-aware linter)

### Gateway not connecting to radio

```bash
tail -f ./logs/gateway.log
```

Look for SDK errors or connection refused messages. Common causes:
- Radio IP unreachable from the host — verify with `ping <radio-ip>`
- The container uses `network_mode: host` — confirm that UDP ports (default 50010+) are not blocked by a host firewall
- Radio SDK alias mismatch — the `sdk_alias` in config must match what the radio expects
- SDK ports 5000–5009 already in use on the host — check `./logs/entrypoint.log` for port conflict warnings

### Audio not working in browser

```bash
tail -f ./logs/backend.log
```

Look for WebSocket or web audio errors. Common causes:
- Web Audio feature not licensed — check Settings → License in the UI
- Browser microphone access requires HTTPS — ensure you are accessing the UI via `https://` (the default compose includes nginx for this; if using the bare template compose, add TLS upstream)
- `web_audio.enabled` is `false` for the radio in config

### SIP registration failing

```bash
# SIP-specific trace log (only exists when SIP is enabled in config)
tail -f ./logs/sip.log

# Gateway log also contains SIP connection events
grep -i "sip\|registration\|401\|403" ./logs/gateway.log | tail -30
```

Common causes:
- Wrong username, password, or registrar address in config
- SIP feature not licensed
- Network firewall blocking SIP ports (5060 UDP/TCP)

### Email notifications not sending

```bash
tail -f ./logs/smtp.log
```

The SMTP log is written at DEBUG level and captures every send attempt, authentication step, and error. All entries also appear in `backend.log`.

### Licence errors

```bash
curl http://localhost:8000/api/license | python3 -m json.tool
```

- `status: "Unregistered"` — no registration code entered
- `status: "Expired"` — licence has expired; contact [contact@ignition.net.nz](mailto:contact@ignition.net.nz)
- `is_valid: false` with no other error — unique key may not match (e.g. after moving to a new machine or recreating the container with a different instance ID)

The unique key is derived from the container's machine ID. To keep it stable across container recreations, set `IGNITION_INSTANCE_ID` in your `.env`:

```bash
# .env
IGNITION_INSTANCE_ID=my-stable-instance-id   # any unique string; does not change
```

And add it to `docker-compose.yml` under `environment`:
```yaml
environment:
  - IGNITION_INSTANCE_ID=${IGNITION_INSTANCE_ID}
```

---

## Image Registry

Images are published to the GitHub Container Registry (GHCR):

```
ghcr.io/ignitionnetworks/ignition-hf-gateway
```

Tags follow semantic versioning (`v1.2.3`) plus `latest`.

---

*HF Web Gateway is developed and maintained by [Ignition Networks](mailto:contact@ignition.net.nz).*
