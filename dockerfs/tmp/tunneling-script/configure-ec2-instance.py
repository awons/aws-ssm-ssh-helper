#!/usr/local/bin/python

from click_option_group import optgroup, RequiredMutuallyExclusiveOptionGroup
import boto3
import click
import logging
import os
import random
import sys
import subprocess

SSH_PUBLIC_KEY_PATH = '/root/.ssh/id_rsa.pub'


@click.command()
@optgroup.group('Targeting instance', cls=RequiredMutuallyExclusiveOptionGroup,
                help='Put SSH key on found EC2 instance')
@optgroup.option('-i', '--instance-id', default=None, help='ID of an instance to connect through in format i-* or mi-*.')
@optgroup.option('-c', '--cluster', default=None, help='Name of an ECS cluster. Will pick a random instance form that cluster.')
@click.option('tags', '-t', '--tag', type=(str, str), default=None, multiple=True, help='Pick one instance having this tag and value: -t tag_name tag_value. Can be used in combination with --cluster. You can use multiple --tag options.')
def run(instance_id, cluster, tags):
    if cluster is not None:
        instance_id = lookup_instance_id(cluster, tags)

    add_ssh_key_to_instance(instance_id)
    
    print(instance_id)


def lookup_instance_id(cluster, tags):
    logging.info(f'Looking up an instance in cluster "{cluster}"')
    ecs = boto3.client('ecs')
    try:
        container_instance_arns = ecs.list_container_instances(cluster=cluster)
    except ecs.exceptions.ClusterNotFoundException as e:
        click.ClickException.exit_code = -1
        raise click.ClickException(str(e))

    container_instances = ecs.describe_container_instances(
        cluster=cluster, containerInstances=container_instance_arns['containerInstanceArns'])
    ec2_instance_ids = []
    for container_instance in container_instances['containerInstances']:
        ec2_instance_ids.append(container_instance['ec2InstanceId'])

    filtered_instance_ids = filter_instances_by_tags(ec2_instance_ids, tags)
    if not filtered_instance_ids:
        click.ClickException.exit_code = -1
        raise click.ClickException("Couldn't find maching instances")

    return random_instance_id(filtered_instance_ids)


def filter_instances_by_tags(instances, tags):
    ec2 = boto3.client('ec2')
    filtered_instances = []

    describe_kwargs = dict(InstanceIds=instances)
    if not all(tags):
        tag_filter = []
        for tag in tags:
            tag_filter.append({'Name': 'tag', 'Values': tag})
        describe_kwargs['Filters'] = tag_filter

    result = ec2.describe_instances(**describe_kwargs)
    for reservations in result['Reservations']:
        for filtered_instance in reservations['Instances']:
            filtered_instances.append(filtered_instance['InstanceId'])

    return filtered_instances


def random_instance_id(instance_ids):
    return random.choice(instance_ids)


def add_ssh_key_to_instance(instance_id):
    logging.info(f'Adding a public SSH key to instance {instance_id}')

    with open(SSH_PUBLIC_KEY_PATH) as ssh_key:
        ssh_key_data = ssh_key.read()

    commands = r'''mkdir -p /home/ssm-user/.ssh || true
cd /home/ssm-user/.ssh || exit 1
authorized_key='{pub_ssh_key} ssm-session'
echo "${{authorized_key}}" >> authorized_keys
sleep 60
grep -v -F "${{authorized_key}}" authorized_keys > .authorized_keys
mv .authorized_keys authorized_keys'''.format(pub_ssh_key=ssh_key_data)

    ssm = boto3.client('ssm')
    ssm.send_command(DocumentName='AWS-RunShellScript', InstanceIds=[instance_id],
                     Comment='Add an SSH public key to authorized_keys for 60 seconds', Parameters={'commands': [commands]})

if __name__ == '__main__':
    logging.basicConfig(
        handlers=[logging.StreamHandler(sys.stdout)], level=logging.INFO)
    # pylint: disable=no-value-for-parameter
    run()
