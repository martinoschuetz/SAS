[TOC]

# Machine Preparation

On AWS, choose a CentOS based VM, r5.4xlarge, 150 GB Disk

Tags:

```
# resourceowner: gerhje
# id:            cc=38755:::dept=ade:::div=eapsl:::proj=:::cust=
# stoptime:      30 20 * * 5 Europe/Berlin
```

Use the subnet ending with "...e9e".

Make sure to add the private IP to Windows local `hosts` file:

```shell
# Viya4 SMP single node cluster
10.249.5.19  dach-viya4-k8s
```

Add virtual NIC IP address to Linux `/etc/hosts`

```shell
# sudo vi /etc/hosts
192.168.100.199  dach-viya4-k8s
```



## Launch instance using Powershell

```powershell
C:\Tools\getawskey\getawskey.exe  -duration 43200
aws ec2 run-instances `
    --image-id ami-0766c896190544be7 `
    --count 1 --instance-type m4.large `
    --key-name AWS_FEDERATED_ACCOUNT_GERHJE_KEY `
    --security-group-ids sg-71ba5516 `
    --subnet-id subnet-b5ab3e9e `
    --profile 738386057074-eapsl `
    --placement AvailabilityZone=us-east-1a `
    --tag-specifications 'ResourceType=instance,Tags=[{Key=id,Value=cc=38755:::dept=ade:::div=eapsl:::proj=:::cust=}]'
```

### Powershell script

```powershell
# Set-PSDebug -Trace 1

# -----------------------------------------------------------------------------
# C:\Tools\getawskey\getawskey.exe  -duration 43200

# -----------------------------------------------------------------------------
New-Variable -Name "AWS_VIYA4AMI" -Value "ami-0c18489a5534eea52"    # v2
New-Variable -Name "AWS_INSTANCE" -Value "m4.large"
New-Variable -Name "AWS_PROFILE"  -Value "738386057074-eapsl"
New-Variable -Name "AWS_SUBNET"   -Value "subnet-b5ab3e9e"
New-Variable -Name "AWS_SECGRP"   -Value "sg-71ba5516"
New-Variable -Name "AWS_TAG_ID"   -Value "cc=38755:::dept=ade:::div=eapsl:::proj=:::cust="

# -----------------------------------------------------------------------------
$RESPONSE=$(aws ec2 run-instances `
    --image-id $AWS_VIYA4AMI `
    --count 1 --instance-type $AWS_INSTANCE `
    --key-name AWS_FEDERATED_ACCOUNT_GERHJE_KEY `
    --security-group-ids $AWS_SECGRP `
    --subnet-id $AWS_SUBNET `
    --profile $AWS_PROFILE `
    --placement AvailabilityZone=us-east-1a `
    --tag-specifications 'ResourceType=instance,Tags=[{Key=id,Value=$AWS_TAG_ID}]' | ConvertFrom-Json).Instances

Write-Output ""
Write-Output "---------------------------------------------------------"
Write-Output "AWS instance started. Update IP address to: " ($RESPONSE.PrivateIpAddress)
Write-Output ""
```



## SSH Keys

```shell
cat <<EOF > ~/.ssh/id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEpgIBAAKCAQEA07ZR6ht7hU6KceDmJROOS3rGikgX4Ge0VCnbjG5jtw2ud1dg
bjCBv/y+0fp0R+p/q8MYkl8cdzES6pUxrhAOMF6n7fE9qMFS2Wf17BYBf5xJNq/o
Jo7Yw63ZkiMcFfJhpCEnJwLV7E65zmlK4c3+W45UOt9HzKqI6EsHp54Zn9Sr4Y8F
FNBOzUps3m2uwGZVWwv66J8ouQ3rsiF0JJa54tOvFztkrIvrq00cFtUelsFTVmSz
Qup8pKM/HxXi1z6F+2pwyM238wiuCNDvaO5YKg4f176y+dh8QgLLWI/2O0rhLbOD
IiMhoR2o85TuuX1WOXc7wD21J0FxFiHmUvHqZQIDAQABAoIBAQC8ukyveyxTm75C
4g+HgbVZh+sxHi9atlfEp0O2Hjn51tJuRJAL6mXf9blNigzahyqkvVhMM0k236JT
SAhveJSNffQJYwJqS1xFvi019jADyBhkDc/Pf4uwdGv9oBrLXbS5EWzLk/WLoGp2
nNpKDM3wZCKmEKD6zBMbsLb0LzX8iYQjOfeGRmmbKPoK++xfg9MaxevngF4dc9hJ
zRRshE7BC0rYgCih+gZTsuDk6JX+a2M6et0oNIki+Nn6buqIxfvYFACktnbVftBz
7ABd5N9IRPMlAA2z9YJFMyuD2WWMNJCVACXWdguRuzcHSvOF5TZdwm+Vgp4lbcKa
2Tx5u1aJAoGBAPAguftNkVY20MS8CDbiQd0aV5ezghwP4RGOn2j+9OmGg2QI9kve
sA7kD3gauXeWZ/AanCaOAJEpCef25htwAZShs0+YzGufW1+w4IdS8A/J3sO+3viR
1I2/1YXjYiRIHvXklJXzHxiHAUYhkVO3fVtv0bGopWJvKAaS6nnAW4rLAoGBAOG0
w5GQW8K+p6BjJwLkBamFNPni6pkKX/s7gY+AAFx4fTeOoRO2Ng7vUjuiiQeXgGNf
1B6Vp5Al/niGI8Au6SPxl9J1f1CshHMGkKSeOvDUMw+HIpWSaM+fJwl//VLijgtN
QQ7TRs6WQXifXjhHlxfTpIRVppeVxZTJXOI2wsmPAoGBAOfX8Tl9zxFao38PvS6g
jc8Ym/HQU5MckcYN2kPZxkWipkFzlbnzLDF0aKshwmiAQ6JDTvi6qjl9Uh8w90MO
hbgn16TGdriCiAqAEIkXvsi/s+Fy7H067+pciaBXxm4ZZCsto3iT4DYiQ0yfJF2c
D+C0udW6atP7Vr3iI5mh68C5AoGBAMRyQbmjTMp+iIVnZ1/zuR3ny8knAIs9ZXbU
Pxr4DNhvIoVFhdsTP4/WKtuuxtetvFhB4uzP0qz69LZQAjPWYKMhNsQ98hb0YL+A
2kn9Uk2kU+DS/H30lXcIDcEN/h2zBHC/x70wlLNgQhHLnAUeAlsBoXJw3fOXrwWm
EUru4LDvAoGBALfIEUvdEj0sjxsHFdcGEQFWf/4dLzn+cwA0LsaGMDaSmkSReRo3
IW68FjL5pfzDm33e6Ho2K0dNBniens5zbWAky/zt33wlbUf/rz6wQg5DmDaBELDS
nzcaT9qmYEGVSjNhbnZiAGiUPI8GzFlenKfi/GnRFQVkhHwDKNT+saDa
-----END RSA PRIVATE KEY-----
EOF

cat <<EOF > ~/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTtlHqG3uFTopx4OYlE45LesaKSBfgZ7RUKduMbmO3Da53V2BuMIG//L7R+nRH6n+rwxiSXxx3MRLqlTGuEA4wXqft8T2owVLZZ/XsFgF/nEk2r+gmjtjDrdmSIxwV8mGkIScnAtXsTrnOaUrhzf5bjlQ630fMqojoSwennhmf1KvhjwUU0E7NSmzeba7AZlVbC/ronyi5DeuyIXQklrni068XO2Ssi+urTRwW1R6WwVNWZLNC6nykoz8fFeLXPoX7anDIzbfzCK4I0O9o7lgqDh/XvrL52HxCAstYj/Y7SuEts4MiIyGhHajzlO65fVY5dzvAPbUnQXEWIeZS8epl ROOT_AWS_VIYATOGO_KEY
EOF

cat <<EOF > ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTtlHqG3uFTopx4OYlE45LesaKSBfgZ7RUKduMbmO3Da53V2BuMIG//L7R+nRH6n+rwxiSXxx3MRLqlTGuEA4wXqft8T2owVLZZ/XsFgF/nEk2r+gmjtjDrdmSIxwV8mGkIScnAtXsTrnOaUrhzf5bjlQ630fMqojoSwennhmf1KvhjwUU0E7NSmzeba7AZlVbC/ronyi5DeuyIXQklrni068XO2Ssi+urTRwW1R6WwVNWZLNC6nykoz8fFeLXPoX7anDIzbfzCK4I0O9o7lgqDh/XvrL52HxCAstYj/Y7SuEts4MiIyGhHajzlO65fVY5dzvAPbUnQXEWIeZS8epl ROOT_AWS_VIYATOGO_KEY
EOF

chmod 600 ~/.ssh/authorized_keys ~/.ssh/id_rsa
```



## System Update

```shell
sudo hostnamectl --static set-hostname dach-viya4-k8s
sudo hostnamectl --transient set-hostname dach-viya4-k8s

vi /etc/cloud/cloud.cfg
# preserve_hostname: true

timedatectl set-timezone UTC

sudo yum install epel-release -y
sudo yum install -y mlocate vim ufw wget git socat htop jq nfs-utils conntrack zip unzip htop tmux mailx at
sudo updatedb
sudo systemctl enable --now atd.service

sudo yum update -y
```



### Disable SELinux

```shell
# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```



## Add Docker (19.03)

```shell
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install -y \
  containerd.io-1.2.13 \
  docker-ce-19.03.11 \
  docker-ce-cli-19.03.11

sudo groupadd -f docker
sudo usermod -aG docker centos

sudo systemctl enable docker
sudo systemctl start docker

sudo su -
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": [ "native.cgroupdriver=systemd" ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [ "overlay2.override_kernel_check=true" ]
}
EOF

sudo systemctl restart docker
```



## Set up virtual NIC to ensure stable IP address

```shell
modprobe dummy

ip link set name eth10 dev dummy0
ip addr add 192.168.100.199/24 brd + dev eth10

ifconfig eth10 up

# check
ifconfig eth10

mkdir -p /opt/vnic

cat <<EOF > /opt/vnic/sas-vnic.service
[Unit]
Description=Setup a virtual NIC and assign a static IP address
Before=kubelet.service docker.service
After=network.target network-online.target

[Service]
Type=oneshot
ExecStart=/opt/vnic/mk_vnic.sh

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /opt/vnic/mk_vnic.sh
#!/bin/sh
# define virtual NIC and start it
modprobe dummy

ip link set name eth10 dev dummy0
ip addr add 192.168.100.199/24 brd + dev eth10

ifconfig eth10 up
EOF

chmod a+x /opt/vnic/mk_vnic.sh
systemctl enable /opt/vnic/sas-vnic.service
```



## Set up NFS server

```shell
sudo mkdir /nfsshare
sudo chown nfsnobody: /nfsshare

sudo yum install -y nfs-utils
sudo systemctl enable nfs-server.service
sudo systemctl start nfs-server.service

sudo vi /etc/exports
cat /etc/exports
/nfsshare        *(rw,async,no_subtree_check,no_root_squash,nofail,nodiratime)
sudo exportfs -ra

sudo showmount -e dach-viya4-k8s
```

```shell
# static network shares for user data
cd /nfsshare
sudo mkdir sasdata
sudo chown centos:centos sasdata
sudo mkdir casdata
sudo chown centos:centos casdata
sudo mkdir pythondata
sudo chown centos:centos pythondata
chmod 777 sasdata/ casdata/ pythondata/
```

Use from Windows Explorer:

```
\\dach-viya4-k8s\nfsshare\sasdata
```



## Set up local PostgreSQL database

Add repository, install database, init db, start & enable service. Make sure that Postgres starts _after_ the virtual NIC service has started.

```shell
rpm -Uvh https://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum -y install postgresql11-server postgresql11 postgresql11-contrib

/usr/pgsql-11/bin/postgresql-11-setup initdb
systemctl start postgresql-11 && systemctl enable postgresql-11

# make sure that the postgres service starts AFTER the virtual network service
cat /usr/lib/systemd/system/postgresql-11.service
# add:
# After=network.target sas-vnic.service

systemctl daemon-reload

# check systemd start order (view in browser): systemd-analyze plot > systemd.svg
```

Change the Linux password of `postgres` (database superuser)

```shell
cat << EOF | passwd postgres
lnxsas
lnxsas
EOF
```

Change the internal password of `postgres` as well and add a second database user (used by Viya)

```shell
# run the following commands as the "postgres" user
su - postgres

# change the DB password
psql -d template1 -c "ALTER USER postgres WITH PASSWORD 'lnxsas';"

# enter interactive mode
psql postgres

# set up a new user account named "pgadmin"
CREATE ROLE pgadmin WITH LOGIN SUPERUSER CREATEDB CREATEROLE INHERIT REPLICATION PASSWORD 'lnxsas';

# check
\du+

# exit
\q
```

Modify the PostGres configuration. Make sure that the database process listens on dummy network interface and increase the max connections:

```shell
vi /var/lib/pgsql/11/data/postgresql.conf
# add these lines to "postgresql.conf"
listen_addresses = '192.168.100.199'
max_connections = 1024
```

Allow inbound traffic from local IP address and from pod CIDR

```shell
vi /var/lib/pgsql/11/data/pg_hba.conf
# add lines
host    all             all             192.168.100.199/32      password
host    all             all             10.244.0.0/16           password
```

Restart the database process.

```shell
systemctl restart postgresql-11
```

Test local access

```shell
PGPASSWORD=lnxsas psql --user pgadmin -h 192.168.100.199 -d postgres -c 'SELECT datname FROM pg_database;'
```

Btw: to delete the database generated by Viya if you want to re-do the deployment:

```shell
PGPASSWORD=lnxsas psql --user postgres -h 192.168.100.199 -d postgres -c 'DROP DATABASE "SharedServices";'

# or interactively
su - postgres
psql postgres
\l
DROP DATABASE "SharedServices";
\l
\q
```



## Set up Samba Server

NFS shares often do not map properly from Windows. Set up a Samba server to expose the same shares through the SMB protocol.

```shell
sudo yum install samba samba-client -y
sudo systemctl start smb.service
sudo systemctl start nmb.service
sudo systemctl enable smb.service
sudo systemctl enable nmb.service
```

```shell
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.org
cat <<EOF > /etc/samba/smb.conf
[smbshare]
path = /nfsshare
    browseable = yes
    read only = no
    force create mode = 0777
    force directory mode = 2777
	force user = centos
	force group = centos
EOF
sudo systemctl restart smb.service
sudo systemctl restart nmb.service
```

Add a samba user (Windows policy prohibits anonymous access)

```shell
smbpasswd -a viyademo01
# Password: lnxsas
smbpasswd -e viyademo01
```

Use this command from DOS

```powershell
net use Z: \\dach-viya4-k8s\smbshare lnxsas /user:localhost\viyademo01
```

