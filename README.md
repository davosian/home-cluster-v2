# home-cluster-v2
Cluster running apps and services for my smarthome

## Current Status

This repository is currently under heavy development as it tracks my various attemps for setting up the services. In a first step, all installation will be done manually and this document serves as a notebook to record the steps taken and the resources consulted.

> **Disclaimer:** I am new to Nomad, Consul and Vault, so do not take this setup as best practice. It might contain serious security holes! Should you find issues with this setup, please open an [issue](https://github.com/davosian/home-cluster-v2/issues) or [propose a fix (PR)](https://github.com/davosian/home-cluster-v2/pulls).

I am using [Ubuntu Multipass](https://multipass.run/) for a local development environment. This ensures that we a clean, reproducable base line. Vagrant is not an option since I am using an M1 based Mac and there is no good virtualization support that plays nicely with Vagrant.

For an initial testing and for everyone else to reproduce, I am using [Hetzner](https://www.hetzner.com) to build up a virtual cluster before erasing my current set of servers running at home.

### Progress

- [X] Provision hardware
- [X] Provide storage
- [X] Install nomad, consul and vault
- [X] VPN access to the cluster
- [X] Initial configuration for Vault
- [ ] Ingress setup
- [ ] Test storage in nomad
- [ ] Setup ingress with test load
- 


## References

- [Tutorial: ](https://community.hetzner.com/tutorials/k3s-glusterfs-loadbalancer)


## Test environment

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
sudo apt install -y unzip direnv neovim

# create a ssh key without passphrase for convenience
ssh-keygen

# configure direnv
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

# reload the shell
source ~/.bashrc

# prepare the hcloud cli
# first follow the steps from https://github.com/hetznercloud/cli, then continue here

# add the hetzner api key and context to .envrc
# also add your public ssh key (in double quotes, without `user@server` at the end)
export HCLOUD_TOKEN=YOUR_TOKEN
export HCLOUD_CONTEXT=home-cluster
export SSH_PUBLIC_KEY=YOUR_KEY
export SSH_USER=root

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
hcloud server create --datacenter fsn1-dc14 --type cx11 --name server-1 --image debian-10 --ssh-key home-cluster --network network-nomad --placement-group group-spread
hcloud server create --datacenter fsn1-dc14 --type cx11 --name server-2 --image debian-10 --ssh-key home-cluster --network network-nomad --placement-group group-spread
hcloud server create --datacenter fsn1-dc14 --type cx11 --name server-3 --image debian-10 --ssh-key home-cluster --network network-nomad --placement-group group-spread
hcloud server create --datacenter fsn1-dc14 --type cx11 --name client-1 --image debian-10 --ssh-key home-cluster --network network-nomad --placement-group group-spread
hcloud server create --datacenter fsn1-dc14 --type cx11 --name client-2 --image debian-10 --ssh-key home-cluster --network network-nomad --placement-group group-spread

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
hcloud firewall apply-to-resource firewall-nomad --type server --server client-1
hcloud firewall apply-to-resource firewall-nomad --type server --server client-2

# Check the connections and accept the keys when prompted
# Update debian to the latest patches
hcloud server ssh server-1
apt update && apt upgrade -y

hcloud server ssh server-2
apt update && apt upgrade -y

hcloud server ssh server-3
apt update && apt upgrade -y

hcloud server ssh client-1
apt update && apt upgrade -y

hcloud server ssh client-2
apt update && apt upgrade -y

# add the server IPs to .envrc
export SERVER_1_IP= # get it with `hcloud server ip server-1`
export SERVER_2_IP= # get it with `hcloud server ip server-2`
export SERVER_3_IP= # get it with `hcloud server ip server-3`
export CLIENT_1_IP= # get it with `hcloud server ip client-1`
export CLIENT_2_IP= # get it with `hcloud server ip client-2`
export SERVER_1_IP_INTERNAL= # get it from the private network created, e.g. 10.0.0.2 from `hcloud server describe server-1 | grep IP`
export SERVER_2_IP_INTERNAL= # get it from the private network created, e.g. 10.0.0.3 from `hcloud server describe server-2 | grep IP`
export SERVER_3_IP_INTERNAL= # get it from the private network created, e.g. 10.0.0.4 from `hcloud server describe server-3 | grep IP`
export CLIENT_1_IP_INTERNAL= # get it from the private network created, e.g. 10.0.0.5 from `hcloud server describe client-1 | grep IP`
export CLIENT_2_IP_INTERNAL= # get it from the private network created, e.g. 10.0.0.6 from `hcloud server describe client-2 | grep IP`

direnv allow
```

### Storage

Decided to give GlusterFS a go since it is easy to set up, light weight and integrates into Nomad through CSI.

```sh
# connect to the server node
hcloud server ssh server-x # replace x with 1 to 3

# download and install glusterfs
apt-get update && apt-get install -y gnupg2
wget -O - https://download.gluster.org/pub/gluster/glusterfs/10/rsa.pub | apt-key add -
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
gluster peer probe 10.0.0.3 # $SERVER_2_IP_INTERNAL
gluster peer probe 10.0.0.4 # $SERVER_3_IP_INTERNAL
gluster peer status
```

Next create the volume. Also only run this on the master node.

```sh
hcloud server ssh server-1
gluster volume create nomadvol replica 3 \
    10.0.0.2:/data/glusterfs/nomad/brick1/brick \ # $SERVER_1_IP_INTERNAL
    10.0.0.3:/data/glusterfs/nomad/brick1/brick \ # $SERVER_2_IP_INTERNAL
    10.0.0.4:/data/glusterfs/nomad/brick1/brick \ # $SERVER_3_IP_INTERNAL
    force
gluster volume start nomadvol
gluster volume info
```

On all server nodes, mount the newly created GlusterFS volume:

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

Check the existence on all server nodes:

```sh
hcloud server ssh server-x # replace x with 1 to 3
less /mnt/gluster-nomad/storagetest1/index.html
```

Set up the clients:

```sh
# connect to the client node
hcloud server ssh client-x # replace x with 1 to 2

# download and install glusterfs
apt-get update && apt-get install -y gnupg2
wget -O - https://download.gluster.org/pub/gluster/glusterfs/10/rsa.pub | apt-key add -
DEBID=$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')
DEBVER=$(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+')
DEBARCH=$(dpkg --print-architecture)
echo deb https://download.gluster.org/pub/gluster/glusterfs/LATEST/Debian/${DEBID}/${DEBARCH}/apt ${DEBVER} main > /etc/apt/sources.list.d/gluster.list
apt update && apt install -y glusterfs-client

# check the installation
glusterfs --version

# mount the storage pool
mkdir -p /mnt/gluster-nomad
export SERVER_1_IP_INTERNAL=GLUSTERFS_IP # set to the correct IP of one of the GlusterFS servers, e.g. 10.0.0.2
echo "$SERVER_1_IP_INTERNAL:/nomadvol /mnt/gluster-nomad glusterfs defaults,_netdev 0 0" >> /etc/fstab
mount /mnt/gluster-nomad

# check if the data is available 
less /mnt/gluster-nomad/storagetest1/index.html

# done
exit
```

Repeat the above steps for all clients.

### Nomad, Consul and Vault installation

The installation is meant to be highly available so that if one of the servers goes down, the system should still function properly.

Install [hashi-up](https://github.com/jsiebens/hashi-up):

```sh
# connect to the dev server
multipass start dev
multipass shell dev

# install hashi-up
curl -sLS https://get.hashi-up.dev | sudo sh
hashi-up version
```

#### Install Consul

```sh
# server
hashi-up consul install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL
  
hashi-up consul install \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL
  
hashi-up consul install \
  --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL

# clients
hashi-up consul install \
  --ssh-target-addr $CLIENT_1_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL

hashi-up consul install \
  --ssh-target-addr $CLIENT_2_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL

# Check that all services are up and consul is running:
hcloud server ssh server-1
consul members
exit
```

The installation sets up the following configuration:

- `consul` binary put into `/usr/local/bin`
- configuration put into `/etc/consul.d/consul.hcl`
- certificates and other resources are put into `/etc/consul.d` and `/opt/consul`

#### Install Vault

```sh
hashi-up vault install \
    --ssh-target-addr $SERVER_1_IP \
    --ssh-target-user $SSH_USER \
    --ssh-target-key ~/.ssh/id_rsa \
    --storage consul \
    --api-addr http://$SERVER_1_IP_INTERNAL:8200

hashi-up vault install \
    --ssh-target-addr $SERVER_2_IP \
    --ssh-target-user $SSH_USER \
    --ssh-target-key ~/.ssh/id_rsa \
    --storage consul \
    --api-addr http://$SERVER_2_IP_INTERNAL:8200

hashi-up vault install \
    --ssh-target-addr $SERVER_3_IP \
    --ssh-target-user $SSH_USER \
    --ssh-target-key ~/.ssh/id_rsa \
    --storage consul \
    --api-addr http://$SERVER_3_IP_INTERNAL:8200

# Check that all services are up and consul is running for each server:
hcloud server ssh server-x # replace x with 1 to 3
systemctl status vault
exit
```

The installation sets up the following configuration:

- `vault` binary put into `/usr/local/bin`
- configuration put into `/etc/vault.d/vault.hcl`
- certificates and other resources are put into `/etc/vault.d` and `/opt/vault`

 #### Install Nomad

```sh
# server
hashi-up nomad install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --server \
  --bootstrap-expect 3
   
hashi-up nomad install \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --server \
  --bootstrap-expect 3

hashi-up nomad install \
  --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --server \
  --bootstrap-expect 3

# clients
hashi-up nomad install \
  --ssh-target-addr $CLIENT_1_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --client
  
hashi-up nomad install \
  --ssh-target-addr $CLIENT_2_IP \
  --ssh-target-user $SSH_USER \
  --ssh-target-key ~/.ssh/id_rsa \
  --client

# check the cluster
hcloud server ssh server-1
nomad server members
nomad node status
exit
```

The installation sets up the following configuration:

- `nomad` binary put into `/usr/local/bin`
- configuration put into `/etc/nomad.d/nomad.hcl`
- certificates and other resources are put into `/etc/nomad.d` and `/opt/nomad`

Install docker for nomad to use on all clients:

```sh
# connect to the client node
hcloud server ssh client-x # replace x with 1 to 2

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install docker-ce docker-ce-cli containerd.io

# test
docker run hello-world
```

### VPN

I will be setting up Zerotier since I have been using it in the past successfully.

Create an account and a new network under https://my.zerotier.com. Take note of the network ID.

[Download and install ZeroTier](https://www.zerotier.com/download/) on your host (not inside the multipass VM since we want our browser to access the services). Join the network from the host using the Zerotier UI or the CLI.

Open the firewall for Zerotier:

```sh
# Allow incoming ZeroTier
hcloud firewall add-rule firewall-nomad --description "Allow ZeroTier In" --direction in --port 9993 --protocol udp --source-ips 0.0.0.0/0 --source-ips ::/0

# Allow outgoing ZeroTier
hcloud firewall add-rule firewall-nomad --description "Allow ZeroTier Out" --direction out --port 9993 --protocol udp --destination-ips 0.0.0.0/0 --destination-ips ::/0
```

Install the ZeroTier client on all nodes:

```sh
hcloud server ssh any-x # replace any with `client` or `server` and x with 1 to 3
curl -s https://install.zerotier.com | sudo bash
zerotier-cli join NETWORK_ID
```

Install the ZeroTier client on the dev VM:

```sh
multipass start dev
multipass shell dev
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join NETWORK_ID
```

Approve all joining requests on https://my.zerotier.com/ and give the nodes names that help you identify them. All clients should be online now with IPs assigned.

Test the access: take note of an IP for one of the server nodes. On your local machine try to access the web UIs:

- Nomad: http://SERVER_IP_ZEROTIER:4646/
- Consul: http://SERVER_IP_ZEROTIER:8500/
- Vault: http://SERVER_IP_ZEROTIER:8200/

Note that Consul is not yet happy with the Vault server since that one is still lacking the initial configuration.

Add the ZeroTier IPs to our environment variables so that we can interact with the cluster from externally:

```sh
# add the ZeroTier server IPs to .envrc
export ZT_SERVER_1_IP=ZEROTIER_IP # get it at https://my.zerotier.com`
export ZT_SERVER_2_IP=ZEROTIER_IP # get it at https://my.zerotier.com`
export ZT_SERVER_3_IP=ZEROTIER_IP # get it at https://my.zerotier.com`
export ZT_CLIENT_1_IP=ZEROTIER_IP # get it at https://my.zerotier.com`
export ZT_CLIENT_2_IP=ZEROTIER_IP # get it at https://my.zerotier.com`
```

### Vault configuration

Each node of the vault cluster has to be unsealed first before it can be used.

On your host, connect to the ZeroTier network, then using your browser connect to the Vault UI for `server-1` at http://SERVER_IP_ZEROTIER:8200/.

Enter `5` for the `Key shares` and `3` for the `Key threshold`, then click on `Initialize`.

On the next page, click on `Download keys` and store them in a password manager. Click on `Continue to Unseal`.

The next few steps have to be repeated for each Vault node.

Copy one of the `keys` (not `keys_base64`) and enter it in the `Master Key Portion` field. Click `Unseal` to proceed. Repeat until you have entered 3 keys.

In order to unseal the vaults on each server, repeat the login steps for `server-2` and `server-3`.

Optionally, after unsealing, you can enter the `root_token` from the password file and click on `Sign In` to get access to the web UI.

When you are done, you should see that the Vault server status switched to green in the Consul web ui over at http://SERVER_IP_ZEROTIER:8500/.

On the command line, you can now also check the vault status:

```sh
hcloud server ssh server-1
export VAULT_ADDR='http://127.0.0.1:8200'
vault status
```

### Install the CLIs on the dev VM

In order to interact easier with Nomad and the other services, we install the CLIs on our multipass VM. Since the Ubuntu packages are outdated, we install the binaries directly:

```sh
multipass start dev
multipass shell dev
cd ~/dl

curl -OL https://releases.hashicorp.com/nomad/1.2.3/nomad_1.2.3_linux_arm64.zip
unzip nomad_1.2.3_linux_arm64.zip
sudo mv nomad /usr/local/bin
rm nomad_1.2.3_linux_arm64.zip
nomad -v

curl -OL https://releases.hashicorp.com/vault/1.9.2/vault_1.9.2_linux_arm64.zip
unzip vault_1.9.2_linux_arm64.zip
sudo mv vault /usr/local/bin
rm vault_1.9.2_linux_arm64.zip
vault -v

curl -OL https://releases.hashicorp.com/consul/1.11.1/consul_1.11.1_linux_arm64.zip
unzip consul_1.11.1_linux_arm64.zip
sudo mv consul /usr/local/bin
rm consul_1.11.1_linux_arm64.zip
consul -v
```

Check the connection (make sure the dev VM is connected to ZeroTier):

```sh
cd ~/src/home-cluster-v2/

# make sure VAULT_ADDR is set in `.envrc` so it connects remotely
vault status

# make sure CONSUL_HTTP_ADDR is set in `.envrc` so it connects remotely
consul members

# make sure NOMAD_ADDR is set in `.envrc` so it connects remotely
nomad server members
```

### Ingress setup

> **This section is still work in progress**

Install and configure Traefik

```sh
# install a sample web app
nomad run nomad/jobs/demo-webapp.nomad

# install traefik as load balancer. Verify that the job gets deployed succesfully.
nomad run nomad/jobs/traefik.nomad

# check that you can reach the traefik dashboard through curl or a local browser
# use a ZT client ip to connect. If it is not working, try the other client IP
curl -L http://$ZT_CLIENT_1_IP:8081

# check that you can reach the load balanced app
# again, experiment with all client ips
# execute 6 times to see how the servers and/or ports change
curl http://$ZT_CLIENT_1_IP:8080/myapp

# check that load balancing is working
hcloud server ssh server-1
curl http://traefik.service.consul:8080/myapp
```

Prepare a load balancer to direct traffic to the servers.

```sh
# create the loadbalancer
hcloud load-balancer create --type lb11 --location fsn1 --name lb-nomad
hcloud load-balancer attach-to-network --network network-nomad --ip 10.0.0.254 lb-nomad

# direct traffic to the server
hcloud load-balancer add-target lb-nomad --server server-1 --use-private-ip
hcloud load-balancer add-target lb-nomad --server server-2 --use-private-ip
hcloud load-balancer add-target lb-nomad --server server-3 --use-private-ip

# manage certificates
hcloud certificate create --domain <example.com> --type managed --name cert-t1
hcloud certificate list

# proxy and health check
hcloud load-balancer add-service lb-nomad --protocol https --http-redirect-http --proxy-protocol --http-certificates <certificate_id> # use the id from the step before
hcloud load-balancer update-service lb-nomad --listen-port 443 --health-check-http-domain <example.com>
```