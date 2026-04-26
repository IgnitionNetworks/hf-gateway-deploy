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

## Operations

### View logs

The container writes to three log files under `./logs/`:

| File | Contents |
|---|---|
| `./logs/gateway.log` | C++ RTP gateway — SDK connections, RTP, SIP, codec |
| `./logs/backend.log` | Python web backend — API, WebSocket, IPC, notifications |
| `./logs/supervisord.log` | Process supervisor — start/stop/restart events |

```bash
# Tail both processes together
docker compose logs -f

# Gateway process only (C++ RTP gateway)
tail -f ./logs/gateway.log

# Web backend only (API, auth, notifications)
tail -f ./logs/backend.log
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

Data in `./data/` (users, sessions, message history) and `./config/config.jsonc` are preserved across upgrades.

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
└── logs/                     — runtime logs (gateway, backend, supervisord — gitignored)
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
docker compose logs ignition-hf-gateway
# or check the log files directly:
cat ./logs/supervisord.log
cat ./logs/backend.log
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
grep -i "sip\|registration\|401\|403" ./logs/gateway.log | tail -30
```

Common causes:
- Wrong username, password, or registrar address in config
- SIP feature not licensed
- Network firewall blocking SIP ports (5060 UDP/TCP)

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
