terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.9.10"
    }
  }
}

# https://registry.terraform.io/providers/Telmate/proxmox/latest/docs
provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  pm_api_token_id = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret

  # leave tls_insecure set to true for default self signed certificates
  pm_tls_insecure = true

  # debugging
  # pm_log_enable = true
  # pm_log_file   = "terraform-plugin-proxmox.log"
  # pm_debug      = true
  # pm_log_levels = {
  #   _default    = "debug"
  #   # enable for detailed sub module debugging
  #   # _capturelog = ""
  # }
}

resource "proxmox_vm_qemu" "nomad_server" {
  # count = 0 # set to 0 to destroy the VMs
  count = length(var.nomad_server)

  name = var.nomad_server[count.index]
	target_node = element(var.proxmox_hosts, count.index)
  clone = var.template_name

  agent = 1
  os_type = "cloud-init"
  cores = 1
  memory = 2048
  scsihw = "virtio-scsi-single"
  bootdisk = "scsi0"

  disk {
    slot = 0
    size = "20G"
    type = "scsi"
    storage = "ceph-data"
    iothread = 1
    cache = "writeback"
  }
  
  # if you want two NICs, just duplicate the whole network section
  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  # required
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  
  # cloud-init settings
  ciuser = var.ssh_username
  ipconfig0 = "ip=dhcp"
  
  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}

resource "proxmox_vm_qemu" "nomad_client" {
  # count = 0 # set to 0 to destroy the VMs
  count = length(var.nomad_clients)

  name = var.nomad_clients[count.index]
  target_node = element(var.proxmox_hosts, count.index+1) # skip the first node as it is older hardware
  clone = var.template_name

  agent = 1
  os_type = "cloud-init"
  cores = 1
  memory = 2048
  scsihw = "virtio-scsi-single"
  bootdisk = "scsi0"

  disk {
    slot = 0
    size = "20G"
    type = "scsi"
    storage = "ceph-data"
    iothread = 1
    cache = "writeback"
  }
  
  # if you want two NICs, just duplicate the whole network section
  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  # required
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  
  # cloud-init settings
  ciuser = var.ssh_username
  ipconfig0 = "ip=dhcp"
  
  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}