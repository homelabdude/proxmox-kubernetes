variable "server_url" {
  description = "URL of your proxmox API, e.g. https://<proxmox-host>:8006/api2/json"
  type        = string
}

variable "token_id" {
  description = "Token ID of the generated API token"
  type        = string
}

variable "token_secret" {
  description = "Token secret of the generated API token"
  type        = string
  sensitive   = true
}

variable "vm_template_name" {
  description = "The name of the VM template to use (ubuntu-2404-template for noble, ubuntu-2604-template for resolute)"
  type        = string
  default     = "ubuntu-2404-template"
}

variable "storage" {
  description = "Proxmox storage pool for the VM disks. Should match the --storage used for the template (e.g. local-lvm or local-zfs)"
  type        = string
  default     = "local-lvm"
}

variable "machine" {
  description = "QEMU machine type of the VMs (q35 or pc for i440fx)"
  type        = string
  default     = "q35"
}


variable "gateway" {
  description = "Gateway"
  type        = string
}

variable "ssh_key" {
  description = "The ssh public key to add into the VMs for easy access on startup"
  type        = string
  default     = ""
}

# Main node vars
variable "target_node_main" {
  description = "The target proxmox node to create the main k8s node on"
  type        = string
}

variable "ip_net_main" {
  description = "Main VM's static IP with subnet prefix, e.g. 192.168.0.100/24"
  type        = string
}

variable "server_cores" {
  description = "CPU cores of the main k8s node"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "Memory (MB) of the main k8s node"
  type        = number
  default     = 8192
}

variable "server_disk_size" {
  description = "Size of the root disk of the main k8s node"
  type        = string
  default     = "64G"
}

# Agent vars
variable "target_node_agent" {
  description = "The target proxmox node to create the agent k8s nodes on"
  type        = string
}

variable "ip_net_agent" {
  description = "First agent VM's static IP with subnet prefix, e.g. 192.168.0.200/24. Subsequent agents get the next IPs"
  type        = string
}

variable "agent_count" {
  description = "Number of agent k8s nodes"
  type        = number
  default     = 2
}

variable "agent_cores" {
  description = "CPU cores of each agent k8s node"
  type        = number
  default     = 2
}

variable "agent_memory" {
  description = "Memory (MB) of each agent k8s node"
  type        = number
  default     = 12288
}

variable "agent_disk_size" {
  description = "Size of the root disk of each agent k8s node"
  type        = string
  default     = "128G"
}

# Test VM vars
variable "build_test_VM" {
  description = "Also create a standalone test VM outside the k8s cluster, e.g. to run a SPIRE server/agent"
  type        = bool
  default     = false
}

variable "target_node_test_vm" {
  description = "The target proxmox node to create the test VM on"
  type        = string
  default     = null
}

variable "ip_net_test_vm" {
  description = "Test VM's static IP with subnet prefix, e.g. 192.168.0.220/24"
  type        = string
  default     = null
}

variable "test_vm_cores" {
  description = "CPU cores of the test VM"
  type        = number
  default     = 2
}

variable "test_vm_memory" {
  description = "Memory (MB) of the test VM"
  type        = number
  default     = 4096
}

variable "test_vm_disk_size" {
  description = "Size of the root disk of the test VM"
  type        = string
  default     = "32G"
}
