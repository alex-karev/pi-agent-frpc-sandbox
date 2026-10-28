# pi-agent-frpc-sandbox

Docker sandbox for a [pi coding agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent), exposed over SSH through an [frp](https://github.com/fatedier/frp) tunnel.

## What this does

One container that gives you:

- The pi coding agent, installed globally via npm
- A hardened SSH server (key-only auth, no root login, only user `dev`)
- tmux + tmuxinator, preconfigured with vi keybindings
- `frpc` that forwards the container's SSH port to a public `frps` server

Use it when you want a disposable dev box you can reach from anywhere, without opening ports on the host. The container is the box; `frps` is the doorbell.

## How it works

`docker-compose.yml` builds `pi-box` from `pi-box/Dockerfile`:

- Base image: `node:24-bookworm-slim`
- Installs bash, git, ripgrep, sudo, curl, vim, python3, openssh-server, tmux, tmuxinator
- Installs `frpc` v0.71.1 (linux/amd64)
- Installs `@earendil-works/pi-coding-agent` globally
- Creates user `dev` with your host UID/GID (default 1000) and passwordless sudo
- Copies in bash aliases, tmux config, and an `frpc.toml` template

On startup, `entrypoint.sh`:

1. Substitutes `FRPC_ADDR`, `FRP_TOKEN`, and `FRP_PORT` into the frp config
2. Starts sshd in the background
3. Starts `frpc` in the background
4. Kills the whole container if either process exits

`frpc` connects to your `frps` server and exposes the container's SSH port (22) as a TCP proxy on the public server's `FRP_PORT`.

## Prerequisites

- Docker with Docker Compose
- A running `frps` server with a token set
- An SSH keypair you want to use for the box

If you don't have an `frps` server, you need one. This project only ships the client side.

## Quick start

```bash
cp example.env .env
```

Edit `.env`:

```bash
HOST_UID=1000        # your host uid, or match the build arg
FRPC_ADDR=123.456.78.90   # your frps server address
FRPC_TOKEN=very-secure-token
FRPC_PORT=3141       # public port the container's SSH will be reachable on
```

Put your public key in place:

```bash
mkdir -p authorized_keys  # or store your key file here
# the compose file mounts ./authorized_keys:/home/dev/.ssh/authorized_keys:ro
# so make sure it contains a valid public key
```

The compose file mounts `./authorized_keys` as a file (read-only) at `/home/dev/.ssh/authorized_keys`. Either place your public key at that path, or adjust the mount in `docker-compose.yml`.

Build and start:

```bash
docker compose up -d --build
```

Connect from anywhere the `frps` server is reachable:

```bash
ssh -p 3141 dev@123.456.78.90
```

## Configuration

### Environment variables

| Variable      | Required | Default             | Description                                    |
|---------------|----------|---------------------|------------------------------------------------|
| `HOST_UID`    | no       | `1000`              | UID of the `dev` user (build arg and `.env`)   |
| `HOST_GID`    | no       | `1000`              | GID of the `dev` user                          |
| `FRPC_ADDR`   | yes      | -                   | Address of your `frps` server                  |
| `FRPC_TOKEN`  | yes      | -                   | Authentication token for the frp server        |
| `FRP_PORT`    | yes      | -                   | Public port for the SSH proxy on the frp server |

Note: `entrypoint.sh` fails fast if `FRPC_ADDR`, `FRPC_TOKEN`, or `FRP_PORT` are unset. The error messages are there for a reason, don't skip them.

### Mounts

| Host path            | Container path                    | Purpose                                    |
|----------------------|-----------------------------------|--------------------------------------------|
| `./workspace`        | `/home/dev/workspace`             | Your working files inside the container    |
| `./agent`            | `/home/dev/.pi/agent`             | pi agent config, shared with the host      |
| `./tmuxinator`       | `/home/dev/.config/tmuxinator`    | tmuxinator project layouts                 |
| `./authorized_keys`  | `/home/dev/.ssh/authorized_keys`  | SSH public keys (read-only)                |

### frpc config

The template lives at `pi-box/frpc.toml`. It's a single TCP proxy named `pi-box-ssh` that forwards the container's local port 22 to `remotePort = FRP_PORT` on the frp server. Tweak it if you want more proxies, different types (UDP, HTTP, etc.), or a custom proxy name.

## Project layout

```
.
├── docker-compose.yml
├── example.env
├── pi-box/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── bashrc
│   ├── tmux.conf
│   └── frpc.toml
```

## Security notes

- SSH allows key authentication only, no passwords
- Root login is disabled, only `dev` can log in
- `dev` has passwordless sudo, because it's your sandbox, but keep the key safe
- The SSH port is exposed on the public internet via frp. Do not reuse weak keys, do not push the private key anywhere near this repo

## Caveats

- The Dockerfile assumes `linux/amd64`. Change the frpc download URL if you're on ARM.
- The npm install runs at build time. Pin the version in `package.json` if you care about reproducibility.
- The container restarts unless stopped, but the SSH port assignment is fixed by `container_name: pi-box`.
