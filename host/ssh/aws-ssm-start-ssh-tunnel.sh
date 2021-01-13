#!/bin/bash
set -eu

SEARCH_TYPE=$(echo "${1}" | awk -F '---' '{print $2}' | cut -b 2-2)
SEARCH_VALUE=$(echo "${1}" | awk -F '---' '{print $2}' | cut -b 3-)
LOCAL_PORT=$(echo "${1}" | awk -F '---' '{print $3}')
DB_HOST=$(echo "${1}" | awk -F '---' '{print $4}')
DB_PORT=$(echo "${1}" | awk -F '---' '{print $5}')
SSH_PUBLIC_KEY_PATH="${2}"

STRING_TO_HASH="${SEARCH_TYPE}:${SEARCH_VALUE}:${LOCAL_PORT}:${DB_HOST}:${DB_PORT}"
case "$(uname -s)" in
    Linux*)     CONTAINER_NAME="ec2-tunnel-$(md5sum <<< "${STRING_TO_HASH}" | awk '{print $1}')";;
    Darwin*)    CONTAINER_NAME="ec2-tunnel-$(md5 "${STRING_TO_HASH}")";;
esac

if [ "$(docker ps -a --filter status=exited | grep -c "${CONTAINER_NAME}")" -eq 1 ]; then
    docker rm -f "${CONTAINER_NAME}" || true
fi

if [ "$(docker ps | grep -c "${CONTAINER_NAME}")" -eq 0 ]; then
    LOCAL_SSH_PORT=$((32769 + RANDOM % 65536))
    docker run \
        --detach \
        --name="${CONTAINER_NAME}" \
        --add-host "${DB_HOST}:127.0.0.1" \
        -v "${SSH_PUBLIC_KEY_PATH}:/root/.ssh/id_rsa.pub:ro" \
        -v "$(dirname "${SSH_AUTH_SOCK}")":"$(dirname "${SSH_AUTH_SOCK}")" \
        -e "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}" \
        -v ~/.aws:/root/.aws \
        -p "${LOCAL_SSH_PORT}:22" \
        aws-ssm-ssh-helper /usr/local/bin/ssh-tunnel.sh "${SEARCH_TYPE}" "${SEARCH_VALUE}" "${LOCAL_PORT}" "${DB_HOST}" "${DB_PORT}"

    COUNTER=0
    while [ "$(docker container logs "${CONTAINER_NAME}" | grep -c "TUNNEL TO EC2 ESTABLISHED")" -lt 1 ] && [ "${COUNTER}" -lt 60 ]
    do
        sleep 1
        COUNTER=$((COUNTER+1))
    done
else
    LOCAL_SSH_PORT=$(docker port "${CONTAINER_NAME}" 22 | awk -F ':' '{print $2}')
fi

exec ssh -o "StrictHostKeyChecking=no" -W localhost:22 root@localhost -p "${LOCAL_SSH_PORT}"
