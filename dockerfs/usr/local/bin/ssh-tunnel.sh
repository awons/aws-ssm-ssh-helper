#!/bin/bash
set -eu

SEARCH_TYPE="${1}"
SEARCH_VALUE="${2}"
LOCAL_PORT="${3}"
DB_HOST="${4}"
DB_PORT="${5}"

cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
/usr/sbin/sshd -e

OUTPUT=$(python3 /tmp/tunneling-script/configure-ec2-instance.py "-${SEARCH_TYPE}" "${SEARCH_VALUE}")
INSTANCE_ID=$(echo "${OUTPUT}" | tail -n1)

ssh -v -4 -f -N -M \
    -i /root/.ssh/id_rsa \
    -S temp-ssh.sock \
    -L "${LOCAL_PORT}:${DB_HOST}:${DB_PORT}" "ssm-user@${INSTANCE_ID}" \
    -o "UserKnownHostsFile=/dev/null" \
    -o "StrictHostKeyChecking=no" \
    -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p"

echo "TUNNEL TO EC2 ESTABLISHED"

while [ "$(netstat -tnpa | grep -c 'ESTABLISHED.*sshd')" -lt 1 ]
do
    echo '' >> /dev/null
done

while [ "$(netstat -tnpa | grep -c 'ESTABLISHED.*sshd')" -gt 0 ]
do
    sleep 2
done

exit 0
