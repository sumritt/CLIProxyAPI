#!/bin/sh

set -eu

DATA_DIR="/CPA-DATA"
CONFIG_FILE="${DATA_DIR}/config.yaml"

SPACES_ENDPOINT="https://${DO_SPACES_REGION}.digitaloceanspaces.com"
SPACES_PREFIX="s3://${DO_SPACES_BUCKET}/cliproxyapi"

export AWS_ACCESS_KEY_ID="${DO_SPACES_KEY}"
export AWS_SECRET_ACCESS_KEY="${DO_SPACES_SECRET}"
export AWS_DEFAULT_REGION="${DO_SPACES_REGION}"

echo "========================================"
echo " CLIProxyAPI Persistent Storage"
echo "========================================"

mkdir -p "${DATA_DIR}/auth"
mkdir -p "${DATA_DIR}/plugins"

# --------------------------------------------------
# Check whether persistent state already exists
# --------------------------------------------------

echo "[1/5] Checking DigitalOcean Spaces..."

if aws s3api head-object \
    --bucket "${DO_SPACES_BUCKET}" \
    --key "cliproxyapi/.initialized" \
    --endpoint-url "${SPACES_ENDPOINT}" \
    >/dev/null 2>&1
then

    echo "Persistent state found."
    echo "Restoring from DigitalOcean Spaces..."

    aws s3 sync \
        "${SPACES_PREFIX}/" \
        "${DATA_DIR}/" \
        --endpoint-url "${SPACES_ENDPOINT}" \
        --delete \
        --only-show-errors

else

    echo "No persistent state found."
    echo "Creating initial state..."

    # Copy default config only on first initialization
    if [ ! -f "${CONFIG_FILE}" ]; then
        cp /CLIProxyAPI/config.example.yaml "${CONFIG_FILE}"
    fi

    # Create marker
    touch "${DATA_DIR}/.initialized"

    echo "Uploading initial state..."

    aws s3 sync \
        "${DATA_DIR}/" \
        "${SPACES_PREFIX}/" \
        --endpoint-url "${SPACES_ENDPOINT}" \
        --delete \
        --only-show-errors
fi


# --------------------------------------------------
# Ensure required directories exist
# --------------------------------------------------

echo "[2/5] Preparing directories..."

mkdir -p "${DATA_DIR}/auth"
mkdir -p "${DATA_DIR}/plugins"


# --------------------------------------------------
# Show persistent state
# --------------------------------------------------

echo "[3/5] Persistent state:"

echo "Config:"
ls -lh "${CONFIG_FILE}" 2>/dev/null || true

echo "Auth:"
find "${DATA_DIR}/auth" -maxdepth 2 -type f 2>/dev/null | head -50 || true

echo "Plugins:"
find "${DATA_DIR}/plugins" -maxdepth 2 -type f 2>/dev/null | head -50 || true


# --------------------------------------------------
# Background sync
# --------------------------------------------------

echo "[4/5] Starting background persistence..."

(
    while true
    do
        sleep 30

        echo "[SYNC] Uploading CPA state to Spaces..."

        aws s3 sync \
            "${DATA_DIR}/" \
            "${SPACES_PREFIX}/" \
            --endpoint-url "${SPACES_ENDPOINT}" \
            --delete \
            --only-show-errors || \
            echo "[SYNC] WARNING: backup failed"
    done
) &

SYNC_PID=$!


# --------------------------------------------------
# Graceful shutdown
# --------------------------------------------------

cleanup() {

    echo ""
    echo "========================================"
    echo " CLIProxyAPI shutting down"
    echo " Final backup to Spaces..."
    echo "========================================"

    kill "${SYNC_PID}" 2>/dev/null || true

    aws s3 sync \
        "${DATA_DIR}/" \
        "${SPACES_PREFIX}/" \
        --endpoint-url "${SPACES_ENDPOINT}" \
        --delete \
        --only-show-errors || \
        echo "[SYNC] WARNING: final backup failed"

    echo "Final backup completed."
}

trap cleanup TERM INT


# --------------------------------------------------
# Start CPA
# --------------------------------------------------

echo "[5/5] Starting CLIProxyAPI..."

exec /CLIProxyAPI/CLIProxyAPI \
    --config /CPA-DATA/config.yaml