# Local Cluster Setup

## Proxmox

### Sources

[How to deploy VMs in Proxmox with Terraform](https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/)

### Installation

TODO

## Preparing cloud-init templates

### Sources

[How to create a Proxmox Ubuntu cloud-init image](https://austinsnerdythings.com/2021/08/30/how-to-create-a-proxmox-ubuntu-cloud-init-image/)

[Using Cloud-Init with Proxmox](https://www.davidbonsall.com/using-cloud-init-with-proxmox/)

[Techno Tim - Perfect Proxmox Template with Cloud Image and Cloud Init](https://docs.technotim.live/posts/cloud-init-cloud-image/)

### Installation

Note that we could script the following steps and have them executed regularly to keep the templates up to date.

On the proxmox server hosting the templates, you need to install prerequisites first:

```sh
# install the required tools
apt update -y && apt install libguestfs-tools -y
```

Now you can prepare the images:

```sh
mkdir ~/dl && cd ~/dl
```

Prepare Ubuntu 20.04 LTS:

```sh
# get the latest image overriding the existing one
wget -O focal-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img

# add `qemu-guest-agent` into the image
virt-customize -a focal-server-cloudimg-amd64.img --install qemu-guest-agent

# prepare the cloud template
qm create 9000 --name "ubuntu-2004-cloudinit-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 focal-server-cloudimg-amd64.img ceph-data
qm set 9000 --scsihw virtio-scsi-pci --scsi0 ceph-data:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 ceph-data:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
rm focal-server-cloudimg-amd64.img
```

Prepare Ubuntu 22.04 LTS:

```sh
# get the latest image overriding the existing one
wget -O jammy-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# add `qemu-guest-agent` into the image
virt-customize -a jammy-server-cloudimg-amd64.img --install qemu-guest-agent

# prepare the cloud template
qm create 9001 --name "ubuntu-2204-cloudinit-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9001 jammy-server-cloudimg-amd64.img ceph-data
qm set 9001 --scsihw virtio-scsi-pci --scsi0 ceph-data:vm-9001-disk-0
qm set 9001 --boot c --bootdisk scsi0
qm set 9001 --ide2 ceph-data:cloudinit
qm set 9001 --serial0 socket --vga serial0
qm set 9001 --agent enabled=1
qm template 9001
rm jammy-server-cloudimg-amd64.img
```

Prepare Debian 10:

```sh
# get the latest image overriding the existing one
wget -O debian-10-genericcloud-amd64.qcow2 https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2

# add `qemu-guest-agent` into the image
virt-customize -a debian-10-genericcloud-amd64.qcow2 --install qemu-guest-agent

# prepare the cloud template
qm create 9003 --name "debian-10-cloudinit-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9003 debian-10-genericcloud-amd64.qcow2 ceph-data -format qcow2
qm set 9003 --scsihw virtio-scsi-pci --scsi0 ceph-data:vm-9003-disk-0
qm set 9003 --boot c --bootdisk scsi0
qm set 9003 --ide2 ceph-data:cloudinit
qm set 9003 --serial0 socket --vga serial0
qm set 9003 --agent enabled=1
qm template 9003
rm debian-10-genericcloud-amd64.qcow2
```

Prepare Debian 11:

```sh
# get the latest image overriding the existing one
wget -O debian-11-genericcloud-amd64.qcow2 https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2

# add `qemu-guest-agent` into the image
virt-customize -a debian-11-genericcloud-amd64.qcow2 --install qemu-guest-agent

# prepare the cloud template
qm create 9002 --name "debian-11-cloudinit-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9002 debian-11-genericcloud-amd64.qcow2 ceph-data -format qcow2
qm set 9002 --scsihw virtio-scsi-pci --scsi0 ceph-data:vm-9002-disk-0
qm set 9002 --boot c --bootdisk scsi0
qm set 9002 --ide2 ceph-data:cloudinit
qm set 9002 --serial0 socket --vga serial0
qm set 9002 --agent enabled=1
qm template 9002
rm debian-11-genericcloud-amd64.qcow2
```

### Testing

Next, we test that creating VMs based on this template works fine:

```sh
qm clone 9002 999 --name test-clone-cloud-init --full --target prox-h3
# connect to the proxmox target host if not identical to the current one
qm resize 999 scsi0 +10G
qm set 999 --ciuser testuser --sshkey ~/.ssh/id_rsa.pub
qm set 999 --ipconfig0 ip=dhcp
qm start 999

# test connecting
ssh testuser@ip
exit

# clean-up
qm stop 999 && qm destroy 999
```

### Troubleshooting

If you need to reset your machine-id. Log into the vm, then execute:


```sh
sudo rm -f /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo shutdown -h now
```

Do not boot it up. A new id will be generated the next time it boots. If it does not you can run:

```sh
sudo systemd-machine-id-setup
```


## Preparing Cloud-Init enabled base image with Packer

> This is an alternative approach. However, I did not manage to get it to work for Ubuntu 20.04, 22.04 nor Debian 11.

### Sources

[Packer: Proxmox Builder (from an ISO)](https://www.packer.io/plugins/builders/proxmox/iso)

[Ubuntu Server 22.04 image with Packer and Subiquity for Proxmox](https://www.aerialls.eu/posts/ubuntu-server-2204-image-packer-subiquity-for-proxmox/#proxmox)

[Debian Proxmox Packer Template](https://github.com/romantomjak/packer-proxmox-template)

[bento images](https://github.com/chef/bento/tree/main/packer_templates/ubuntu)

[The Digital Live - Github Repository](https://github.com/xcad2k/boilerplates/tree/main/packer/proxmox)

[Terraform: Provision Infrastructure with Packer](https://learn.hashicorp.com/tutorials/terraform/packer)


### Installation

First, create an API user for packer on the proxmox server:

In the proxmox UI, navigate to Datacenter -> Permissions -> API Tokens and click on `Add`:

User: `root@pam`
Token ID: `packer`
Comment: `Token for Packer`
Priviledge Separation: `unchecked`

Save the generated token in 1Password at `ENV_PROXMOX_SERVER_1`.

TODO: create a less priviledged user instead assigning only the roles required to create the template. I did not find any documentation on it so far.

To check: based on [this documentation](https://www.aerialls.eu/posts/ubuntu-server-2204-image-packer-subiquity-for-proxmox/#proxmox), you can create a dedicated user with the correct priviledges like this:

```sh
$ pveum useradd packer@pve
$ pveum passwd packer@pve
Enter new password: ****************
Retype new password: ****************
$ pveum roleadd Packer -privs "VM.Config.Disk VM.Config.CPU VM.Config.Memory Datastore.AllocateSpace Sys.Modify VM.Config.Options VM.Allocate VM.Audit VM.Console VM.Config.CDROM VM.Config.Network VM.PowerMgmt VM.Config.HWType VM.Monitor"
$ pveum aclmod / -user packer@pve -role Packer
```

### Installing Packer

On the `dev` VM, install packer:

```sh
cd ~/dl
# note: get the latest release for your platform from https://www.packer.io/downloads
curl -OL https://releases.hashicorp.com/packer/1.8.0/packer_1.8.0_linux_arm64.zip
unzip packer_1.8.0_linux_arm64.zip
sudo mv packer /usr/local/bin
rm -f packer_1.8.0_linux_arm64.zip

# install auto completion
packer -autocomplete-install
```

### Building the template

```sh
cd packer/ubuntu-server-jammy/
packer init .
packer validate .
packer fmt .
packer build ./ubuntu-server-jammy.pkr.hcl
```


## Provisioning with Terraform

### Installing Terraform

On the `dev` VM, install terraform:

```sh
cd ~/dl
# note: get the latest release for your platform from https://www.terraform.io/downloads
curl -OL https://releases.hashicorp.com/terraform/1.1.9/terraform_1.1.9_linux_arm64.zip
unzip terraform_1.1.9_linux_arm64.zip
sudo mv terraform /usr/local/bin
rm -f terraform_1.1.9_linux_arm64.zip

# install auto completion
terraform -install-autocomplete
```

### Create Proxmox User for Terraform

```sh
pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
pveum user token add terraform-prov@pve terraform --privsep 0

# modify the role if needed, e.g. for migrations
# pveum role modify TerraformProv -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"
```

Save the user, password, token id and token secret in 1Password at `Proxmox Terraform User`.

### Create the VMs

```sh
cd terraform/cluster
terraform init
terraform plan
terraform apply
```

This creates 5 VMs: 3 server VMs intended to run nomad, consul and vault server and 2 clients intended to run nomand and consul clients.