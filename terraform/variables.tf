variable "server_url" {
  description = "FQDN or IP of your proxmox installation"
  type        = string
}

variable "token_id" {
  description = "Token ID of the generated API token"
  type        = string
}

variable "token_secret" {
  description = "Token secret of the generated API token"
  type        = string
}

variable "vm_template_name" {
  description = "The name of the VM template to use (ubuntu-2404-template for noble, ubuntu-2604-template for resolute)"
  type        = string
  default     = "ubuntu-2404-template"
}

variable "file_system" {
  description = "File system of the proxmox host node"
  type        = string
  default     = "ext4"
}

variable "gateway" {
  description = "Gateway"
  type        = string
}

variable "ssh_key" {
  description = "The ssh key to add into the VM for easy acces on startup"
  type        = string
  default     = ""
}

# Main node vars
variable "target_node_main" {
  description = "The target proxmox node to create the main k8s node on"
  type        = string
}

variable "ip_net_main" {
  description = "Main VM's static ip and subnet of the network"
  type        = string
}


# Agent vars
variable "target_node_agent" {
  description = "The target proxmox node to create the main k8s node on"
  type        = string
}

variable "ip_net_agent" {
  description = "Main VM's static ip and subnet of the network"
  type        = string
}



