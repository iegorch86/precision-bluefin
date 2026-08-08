#!/usr/bin/bash

set -euo pipefail

IMAGE_REPO="${1:?Usage: install-image-trust.sh ghcr.io/owner/image}"

POLICY="/etc/containers/policy.json"
KEY="/usr/lib/pki/containers/iegorch86.pub"

echo "Installing container-signature trust for ${IMAGE_REPO}"

if [[ ! -f /ctx/cosign.pub ]]; then
    echo "ERROR: /ctx/cosign.pub is missing."
    exit 1
fi

if [[ ! -f "${POLICY}" ]]; then
    echo "ERROR: ${POLICY} is missing."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to safely update ${POLICY}."
    exit 1
fi

# Install our public Cosign key in the same general location
# used by Universal Blue for container verification keys.
install -Dm0644 \
    /ctx/cosign.pub \
    "${KEY}"

tmp_policy="$(mktemp)"

jq \
    --arg repo "${IMAGE_REPO}" \
    --arg key "${KEY}" \
    '
    .transports |= (. // {}) |
    .transports.docker |= (. // {}) |
    .transports.docker[$repo] = [
        {
            "type": "sigstoreSigned",
            "keyPath": $key,
            "signedIdentity": {
                "type": "matchRepository"
            }
        }
    ]
    ' \
    "${POLICY}" > "${tmp_policy}"

# Make sure we did not generate broken JSON.
jq empty "${tmp_policy}"

install -m0644 "${tmp_policy}" "${POLICY}"
rm -f "${tmp_policy}"

echo "Container-signature trust installed for ${IMAGE_REPO}"
