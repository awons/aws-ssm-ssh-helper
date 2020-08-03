#!/bin/bash
set -eu

EC2_INSTANCE_ID="${1}"
SSH_USER="${2}"
SSH_PORT="${3}"
SSH_PUBLIC_KEY_PATH="${4}"

docker run \
    --rm \
    -i \
    -v "${SSH_PUBLIC_KEY_PATH}:/root/.ssh/id_rsa.pub:ro" \
    -v "$(dirname "${SSH_AUTH_SOCK}")":"$(dirname "${SSH_AUTH_SOCK}")" \
    -v ~/.aws:/root/.aws \
    -e "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}" \
    aws-ssm-ssh-helper /usr/local/bin/ssh-session.sh "${EC2_INSTANCE_ID}" "${SSH_USER}" "${SSH_PORT}"
