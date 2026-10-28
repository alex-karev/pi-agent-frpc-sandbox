#!/usr/bin/env bash
set -euo pipefail

: "${FRP_ADDR:?FRP_ADDR must be set}"
: "${FRP_TOKEN:?FRP_TOKEN must be set}"
: "${FRP_PORT:?FRP_PORT must be set}"

CONFIG=/etc/frp/frpc.toml
TEMPLATE=/etc/frp/frpc.toml.template

sed \
    -e "s|FRP_ADDR|${FRP_ADDR}|g" \
    -e "s|FRP_TOKEN|${FRP_TOKEN}|g" \
    -e "s|FRP_PORT|${FRP_PORT}|g" \
    "$TEMPLATE" > "$CONFIG"

/usr/sbin/sshd -D &
SSHD_PID=$!

/usr/local/bin/frpc -c "$CONFIG" &
FRPC_PID=$!

cleanup() {
    kill "$SSHD_PID" "$FRPC_PID" 2>/dev/null || true
    wait 2>/dev/null || true
}
trap cleanup EXIT TERM INT

# If either service exits, terminate the container.
wait -n "$SSHD_PID" "$FRPC_PID"
exit 1

