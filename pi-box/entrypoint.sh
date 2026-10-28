#!/usr/bin/env bash
set -euo pipefail

: "${FRPC_ADDR:?FRPC_ADDR must be set}"
: "${FRPC_TOKEN:?FRPC_TOKEN must be set}"
: "${FRP_PORT:?FRP_PORT must be set}"

CONFIG=/etc/frp/frpc.toml

# Replace placeholders with environment variables.
sed -i \
    -e "s|FRPC_ADDR|${FRPC_ADDR//\\/\\\\}|g" \
    -e "s|FRPC_TOKEN|${FRPC_TOKEN//\\/\\\\}|g" \
    -e "s|FRP_PORT|${FRP_PORT//\\/\\\\}|g" \
    "$CONFIG"

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

