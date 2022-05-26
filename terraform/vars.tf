variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
  description = "Format: user@pve!token_id"
}

variable "proxmox_api_token_secret" {
  type = string
  sensitive = true
}

variable "template_name" {
  type = string
  default = "debian-10-cloudinit-template"
  description = "Proxmox template to use. Currently: Debian 10, Debian 11, Ubuntu 20.04 or Ubuntu 22.04."
}

variable "proxmox_hosts" {
  type = list(string)
  description = "List of the proxmox hostnames."
}

variable "nomad_server" {
  type    = list(string)
  description = "List of nomad server hostnames."
}

variable "nomad_clients" {
  type    = list(string)
  description = "List of nomad client hostnames."
}

variable "ssh_username" {
  type = string
}

variable "ssh_key" {
  type = string
  sensitive = true
}