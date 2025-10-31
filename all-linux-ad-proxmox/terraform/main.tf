locals {


cpu { cores = var.ad.dc2.cores }
memory { dedicated = var.ad.dc2.memory_mb }


agent { enabled = true }


disk {
interface = "scsi0"
size = var.ad.dc2.disk_gb
datastore_id = var.vm_storage
}


network_device {
bridge = var.bridge
vlan_id = var.vlan
}


initialization {
datastore_id = var.vm_storage
user_account { keys = [var.ssh_pubkey] }
ip_config {
ipv4 {
address = "${var.ad.dc2.ip}/24"
gateway = var.dhcp.router
}
}
}
}


# ===== DHCP server (LXC)
resource "proxmox_virtual_environment_container" "dhcp1" {
count = var.dhcp.enabled ? 1 : 0
node_name = var.pm_node
vm_id = null
description= "ISC-DHCP"


initialization {
hostname = var.dhcp.srv1.name
user_account { keys = [var.ssh_pubkey] }
ip_config {
ipv4 { address = "${var.dhcp.srv1.ip}/24"; gateway = var.dhcp.router }
}
}


operating_system {
template_file_id = var.template_lxc_debian
type = "debian"
}


memory { dedicated = var.dhcp.srv1.memory_mb }
cpu { cores = var.dhcp.srv1.cores }
disk { datastore_id = var.lxc_storage size = var.dhcp.srv1.disk_gb }
network_interface { name = "eth0"; bridge = var.bridge; vlan_id = var.vlan }
features { nesting = true }
}


output "provisioned_ips" {
value = {
dc1 = var.ad.dc1.ip
dc2 = var.ad.dc2.ip
dhcp = var.dhcp.enabled ? var.dhcp.srv1.ip : null
}
}