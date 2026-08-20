#!/bin/sh

set -eu

AUTH_DIR="/root/.cli-proxy-api"
CONFIG_FILE="/CLIProxyAPI/config.yaml"

SPACES_ENDPOINT="https://${DO_SPACES_REGION}.digitaloceanspaces.com"
SPACES_PATH="s3://${DO_SPACES_BUCKET}/cliproxyapi"

export AWS_ACCESS_KEY_ID="${DO_SPACES_KEY}"
export AWS_SECRET_ACCESS_KEY="${DO_SPACES_SECRET}"
export AWS_DEFAULT_REGION="${DO_SPACES_REGION}"

echo "======================================"
echo " CLIProxyAPI Startup"
echo "======================================"

mkdir -p "${AUTH_DIR}"

echo "[1/3] Restoring data from DigitalOcean Spaces..."

aws s3 sync \
    "${SPACES_PATH}/auth/" \
    "${AUTH_DIR}/" \
    --endpoint-url "${SPACES_ENDPOINT}" \
    --only-show-errors || true

aws s3 cp \
    "${SPACES_PATH}/config.yaml" \
    "${CONFIG_FILE}" \
    --endpoint-url "${SPACES_ENDPOINT}" \
    --only-show-errors || true

echo "[2/3] Starting background backup..."

(
    while true
    do
        sleep 30

        aws s3 sync \
            "${AUTH_DIR}/" \
            "${SPACES_PATH}/auth/" \
            --endpoint-url "${SPACES_ENDPOINT}" \
            --only-show-errors || true

        aws s3 cp \
            "${CONFIG_FILE}" \
            "${SPACES_PATH}/config.yaml" \
            --endpoint-url "${SPACES_ENDPOINT}" \
            --only-show-errors || true
    done
) &

echo "[3/3] Starting CLIProxyAPI..."

exec /CLIProxyAPI/CLIProxyAPI