variable "pm_api_url" { type = string }
variable "pm_api_token" { type = string }
variable "pm_insecure" { type = bool default = false }


variable "pm_node" { type = string }
variable "vm_storage" { type = string }
variable "lxc_storage" { type = string }
variable "bridge" { type = string default = "vmbr0" }
variable "vlan" { type = number default = null }


variable "template_vm_debian_id" { type = number } # cloud-init Debian VM template ID
variable "template_lxc_debian" { type = string } # LXC template (e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)


variable "ssh_pubkey" { type = string }


variable "ad" {
type = object({
domain = string # e.g. "example.local"
realm = string # e.g. "EXAMPLE.LOCAL"
netbios= string # e.g. "EXAMPLE"
site = string # e.g. "Default-First-Site-Name"


dc1 = object({ name = string, ip = string, cores = number, memory_mb = number, disk_gb = number })
dc2 = object({ name = string, ip = string, cores = number, memory_mb = number, disk_gb = number })
})
}


variable "dhcp" {
type = object({
enabled = bool
srv1 = object({ name = string, ip = string, cores = number, memory_mb = number, disk_gb = number })
srv2 = object({ name = string, ip = string, cores = number, memory_mb = number, disk_gb = number, enable_failover = bool })
subnet_cidr = string # e.g. "192.168.10.0/24"
router = string # e.g. "192.168.10.1"
range_start = string # e.g. "192.168.10.100"
range_end = string # e.g. "192.168.10.199"
dns_servers = list(string) # usually dc1/dc2 IPs
domain_name = string
ntp_servers = list(string)
})
}