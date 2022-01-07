# home-cluster-v2
Cluster running apps and services for my smarthome

## Current Status

This repository is currently under heavy development as it tracks my various attemps for setting up the services. In a first step, all installation will be done manually and this document serves as a notebook to record the steps taken and the resources consulted.

I am using [Ubuntu Multipass](https://multipass.run/) for a local development environment. This ensures that we a clean, reproducable base line. Vagrant is not an option since I am using an M1 based Mac and there is no good virtualization support that plays nicely with Vagrant.

For an initial testing and for everyone else to reproduce, I am using Hetzner to build up a virtual cluster before erasing my current set of servers running at home.


### Progress

- [X] Provision hardware
- [X] Provide storage
- [ ] Install nomad, consul and vault
- [ ] Test storage in nomad
- [ ] Setup ingress with test load
- 

## Test environment

We will be using a set of VMs on [Hetzner](https://www.hetzner.com).

### References

[Tutorial: ](https://community.hetzner.com/tutorials/k3s-glusterfs-loadbalancer)

### Development environment provisioning

Download and install multipass from https://multipass.run/.

Set up a VM called `dev` with 2GB RAM, 2 CPUs and 4GB disk space:

```sh
multipass launch -n dev -m 2G -c 2 -d 4G
multipass start dev
multipass shell dev
```

Prepare the local environment:

```sh
sudo apt update
sudo apt upgrade
sudo apt install -y direnv neovim

# create a ssh key without passphrase for convenience
ssh-keygen

# add to the bottom of ~/.bashrc
eval "$(direnv hook bash)"

# reload the shell
source ~/.bashrc

# get the sources
mkdir ~/src && cd ~/src
git clone https://github.com/davosian/home-cluster-v2.git
cd home-cluster-v2

# prepare the environment
cp .envrc.example .envrc
direnv allow
```

### Hardware provisionig

Connect into the multipass VM if not done so already in the previous section. All other steps in this section will be performed inside this VM.

```sh
multipass shell dev
```

Install the [Hetzner CLI](https://github.com/hetznercloud/cli):

```sh
# install hcloud manually since the one from apt is outdated and 
# does not work with the following instructions
mkdir ~/dl && cd ~/dl
# note: get the latest release for your platform from https://github.com/hetznercloud/cli/releases
curl -OL https://github.com/hetznercloud/cli/releases/download/v1.29.0/hcloud-linux-arm64.tar.gz
tar -xvf hcloud-linux-arm64.tar.gz
sudo mv hcloud /usr/local/bin
rm -f CHANGES.md LICENSE README.md hcloud hcloud-linux-arm64.tar.gz

# add to the bottom of ~/.bashrc
source <(hcloud completion bash)

# prepare the hcloud cli
# first follow the steps from https://github.com/hetznercloud/cli, then continue here

# add the hetzner api key and context to .envrc
# also add your public ssh key (in double quotes, without `user@server` at the end)
export HCLOUD_TOKEN=YOUR_TOKEN
export HCLOUD_CONTEXT=home-cluster
export SSH_PUBLIC_KEY=YOUR_KEY

direnv allow

# connect to hetzner
hcloud context create home-cluster

# make sure the connection is working
hcloud server-type list
hcloud server list
```

Provision the cloud infrastructure:

```sh
# Create private network
hcloud network create --name network-nomad --ip-range 10.0.0.0/16
hcloud network add-subnet network-nomad --network-zone eu-central --type server --ip-range 10.0.0.0/16

# Create placement group
hcloud placement-group create --name group-spread --type spread

# Prepare a ssh key to use for connecting to the servers
hcloud ssh-key create --name home-cluster --public-key "$SSH_PUBLIC_KEY"

# Create VMs
hcloud server create --datacenter fsn1-dc14 --type cx11 --name server-1 --image debian-11 --ssh-key home-cluster --network network-nomad --placement-group group-spread
hcloud server create --datacenter fsn1-dc14 --type cx11 --name server-2 --image debian-11 --ssh-key home-cluster --network network-nomad --placement-group group-spread
hcloud server create --datacenter fsn1-dc14 --type cx11 --name server-3 --image debian-11 --ssh-key home-cluster --network network-nomad --placement-group group-spread
# hcloud server create --datacenter fsn1-dc14 --type cx11 --name client-1 --image debian-11 --ssh-key home-cluster --network network-nomad --placement-group group-spread
# hcloud server create --datacenter fsn1-dc14 --type cx11 --name client-2 --image debian-11 --ssh-key home-cluster --network network-nomad --placement-group group-spread

# Create firewall
hcloud firewall create --name firewall-nomad

# Allow incoming SSH and ICMP
hcloud firewall add-rule firewall-nomad --description "Allow SSH In" --direction in --port 22 --protocol tcp --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule firewall-nomad --description "Allow ICMP In" --direction in --protocol icmp --source-ips 0.0.0.0/0 --source-ips ::/0

# Allow outgoing ICMP, DNS, HTTP, HTTPS and NTP
hcloud firewall add-rule firewall-nomad --description "Allow ICMP Out" --direction out --protocol icmp --destination-ips 0.0.0.0/0 --destination-ips ::/0
hcloud firewall add-rule firewall-nomad --description "Allow DNS TCP Out" --direction out --port 53 --protocol tcp --destination-ips 0.0.0.0/0 --destination-ips ::/0
hcloud firewall add-rule firewall-nomad --description "Allow DNS UDP Out" --direction out --port 53 --protocol udp --destination-ips 0.0.0.0/0 --destination-ips ::/0
hcloud firewall add-rule firewall-nomad --description "Allow HTTP Out" --direction out --port 80 --protocol tcp --destination-ips 0.0.0.0/0 --destination-ips ::/0
hcloud firewall add-rule firewall-nomad --description "Allow HTTPS Out" --direction out --port 443 --protocol tcp --destination-ips 0.0.0.0/0 --destination-ips ::/0
hcloud firewall add-rule firewall-nomad --description "Allow NTP UDP Out" --direction out --port 123 --protocol udp --destination-ips 0.0.0.0/0 --destination-ips ::/0

# Apply firewall rules to all servers
hcloud firewall apply-to-resource firewall-nomad --type server --server server-1
hcloud firewall apply-to-resource firewall-nomad --type server --server server-2
hcloud firewall apply-to-resource firewall-nomad --type server --server server-3
# hcloud firewall apply-to-resource firewall-nomad --type server --server client-1
# hcloud firewall apply-to-resource firewall-nomad --type server --server client-2

# Check the connections and accept the keys when prompted
hcloud server ssh server-1
hcloud server ssh server-2
hcloud server ssh server-3
# hcloud server ssh client-1
# hcloud server ssh client-2
```

### Storage

Decided to give GlusterFS a go since it is easy to set up, light weight and integrates into Nomad through CSI.

```sh
# connect to the node
hcloud server ssh server-x # replace x with 1 to 3

# download and install glusterfs
apt-get update && apt-get install -y gnupg2
wget -O - https://download.gluster.org/pub/gluster/glusterfs/9/rsa.pub | apt-key add -
DEBID=$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')
DEBVER=$(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+')
DEBARCH=$(dpkg --print-architecture)
echo deb https://download.gluster.org/pub/gluster/glusterfs/LATEST/Debian/${DEBID}/${DEBARCH}/apt ${DEBVER} main > /etc/apt/sources.list.d/gluster.list
apt update && apt install -y glusterfs-server
systemctl enable glusterd && systemctl start glusterd

# check that the service is running
systemctl status glusterd

# create the storage bricks
mkdir -p /data/glusterfs/nomad/brick1
mkdir -p /mnt/gluster-nomad

# done
exit
```

Repeat the above steps for all servers (not the clients since they will not carry glusterfs).

Let's make server-1 the master node and add the other nodes as peers:

```sh
hcloud server ssh server-1
gluster peer probe 10.0.0.3
gluster peer probe 10.0.0.4
gluster peer status
```

Next create the volume. Also only run this on the master node.

```sh
hcloud server ssh server-1
gluster volume create nomadvol replica 3 \
    10.0.0.2:/data/glusterfs/nomad/brick1/brick \
    10.0.0.3:/data/glusterfs/nomad/brick1/brick \
    10.0.0.4:/data/glusterfs/nomad/brick1/brick \
    force
gluster volume start nomadvol
gluster volume info
```

On all three nodes, mount the newly created GlusterFS volume:

```sh
hcloud server ssh server-x # replace x with 1 to 3
echo "127.0.0.1:/nomadvol /mnt/gluster-nomad glusterfs defaults,_netdev 0 0" >> /etc/fstab
mount /mnt/gluster-nomad
```

Test the volume by creating a file and making sure it is accessible on all three hosts:

```sh
hcloud server ssh server-3
mkdir /mnt/gluster-nomad/storagetest1
echo "Hello World!" > /mnt/gluster-nomad/storagetest1/index.html
```

Check the existence on all three servers:

```sh
hcloud server ssh server-x # replace x with 1 to 3
less /mnt/gluster-nomad/storagetest1/index.html
```

