# Set up SSH connections and tunneling through an EC2 instance using A Docker container

## Prerequisites

* Docker
* Make
* Your public RSA key under `~/.ssh/id_rsa.pub`
* A running SSH agent
* AWS CLI configuration under `~/.aws` with correct region to use

## Installation
```bash
make build && make install
```

## Use cases

### SSH / SCP
Put those lines into your `~/.ssh/config`:

```
Host i-* im-*
	IdentityFile ~/.ssh/id_rsa
	ProxyCommand ~/.ssh/aws-ssm-start-ssh-session.sh %h %r %p ~/.ssh/id_rsa.pub
	StrictHostKeyChecking no
	PreferredAuthentications publickey
```

Now you can `ssh` into your instance by simply using its ID like this:

```bash
ssh ec2-user@i-XXXXXXXXXXXXXXXXX
```

Same is for using `scp`:

```bash
scp ec2-user@i-XXXXXXXXXXXXXXXXX:/path/to/my/file.txt .
```

### Tunneling through an EC2 instance

Say you need to tunnel into your RDS that is only accesible from a specific instance or a any instance in a ECS cluster.

This solution will only work if you can use OpenSSH config directly in your IDE (like all JetBrains products). First, add this entry to your `~/.ssh/config`:

```
Host ec2-tunnel---*
        ProxyCommand /home/alex/Projects/aws-ssm-ssh-helper/host/ssh/aws-ssm-start-ssh-tunnel.sh %h ~/.ssh/id_rsa.pub
        StrictHostKeyChecking no
        PreferredAuthentications publickey
        IdentityFile ~/.ssh/id_rsa
        UserKnownHostsFile /dev/null
```

The following is a description for PhpStorm but the settings will be similar in any other IDE that is capable of using the OpenSSH config.

Uder the general DB configuration put the follwoing values:

* Host - your RDS host name
* Port - pick anything you want. This will be used for tunneling from within the Docker container. To avoid confusion you can just put the same port that the actual RDS database is available under.
* Username and password - your RDS credentials.

Uder `SSH/SSL` choose `Use SSH tunnel`. Put in the following configuration:

* Host in form:
  * for connecting to an EC2 instance: `ec2-tunnel---tii-XXXXXXXXXXXXXXXXX---LOCAL_PORT---RDS_DB_HOST---RDS_DB_PORT` where `i-XXXXXXXXXXXXXXXXX` is your instance ID
  * for connecting to any instance in an ECS cluster: `ec2-tunnel---tcXXXXXXXXXXXXXXXXX---LOCAL_PORT---RDS_DB_HOST---RDS_DB_PORT` where `XXXXXXXXXXXXXXXXX` is your cluster name
  
  The `LOCAL_PORT` must be the same value as you specified under the general configuration. `RDS_DB_HOST` and `RDS_DB_PORT` are self-explanatory - the actual DB hostname and port.
* Port: anything - it won't be used
* Username: `root`
* Local port: leave at dynamic
* Authentication type: `OpenSSH config and authentication agent`

Now you can save the settings and test your connection.

Please notice that this will spin up a docker container with an SSH server and open tunnel within that contaner. The whole procedure can take really long time during connecting (at my machine even 20 seconds). Subsequent calles will already go through an open connection.
