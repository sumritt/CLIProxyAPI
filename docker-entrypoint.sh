#!/bin/sh
set -eu

DATA_DIR="/CPA-DATA"
SPACES_ENDPOINT="https://${DO_SPACES_REGION}.digitaloceanspaces.com"
SPACES_PATH="s3://${DO_SPACES_BUCKET}/cliproxyapi"

export AWS_ACCESS_KEY_ID="${DO_SPACES_KEY}"
export AWS_SECRET_ACCESS_KEY="${DO_SPACES_SECRET}"
export AWS_DEFAULT_REGION="${DO_SPACES_REGION}"

mkdir -p "${DATA_DIR}"

echo "Restoring CLIProxyAPI state..."

aws s3 sync \
    "${SPACES_PATH}/" \
    "${DATA_DIR}/" \
    --endpoint-url "${SPACES_ENDPOINT}" \
    --only-show-errors

echo "State restored."

echo "Starting background backup..."

(
    while true; do
        sleep 30

        aws s3 sync \
            "${DATA_DIR}/" \
            "${SPACES_PATH}/" \
            --endpoint-url "${SPACES_ENDPOINT}" \
            --only-show-errors || true
    done
) &

exec /CLIProxyAPI/CLIProxyAPI \
    --config "${DATA_DIR}/config.yaml"