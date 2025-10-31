terraform {
required_version = ">= 1.5.0"
required_providers {
proxmox = {
source = "bpg/proxmox"
version = ">= 0.65.0"
}
}
}


provider "proxmox" {
endpoint = var.pm_api_url
api_token = var.pm_api_token
insecure = var.pm_insecure
}