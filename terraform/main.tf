terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

# Init provider
provider "proxmox" {
  pm_api_url          = var.server_url
  pm_api_token_id     = var.token_id
  pm_api_token_secret = var.token_secret
  # Proxmox ships with a self-signed certificate by default
  pm_tls_insecure = true
}

locals {
  # Agent IPs are allocated sequentially from the given agent IP, within its subnet
  agent_ip          = split("/", var.ip_net_agent)[0]
  agent_prefix      = split("/", var.ip_net_agent)[1]
  agent_ip_int      = sum([for i, octet in split(".", local.agent_ip) : tonumber(octet) * pow(256, 3 - i)])
  agent_network_int = sum([for i, octet in split(".", cidrhost(var.ip_net_agent, 0)) : tonumber(octet) * pow(256, 3 - i)])
  agent_host_offset = local.agent_ip_int - local.agent_network_int
}

# Create VM for main k8s node
resource "proxmox_vm_qemu" "kube-server" {
  name        = "kube-server-01"
  target_node = var.target_node_main
  vmid        = 501
  qemu_os     = "l26"
  clone       = var.vm_template_name
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  bios        = "ovmf"
  machine     = var.machine
  memory      = var.server_memory
  balloon     = 0
  scsihw      = "virtio-scsi-single"
  boot        = "order=scsi0"

  cpu {
    cores = var.server_cores
    type  = "host"
    # Double the default CPU weight so etcd and the API server win under host CPU contention
    units = 200
  }

  serial {
    id   = 0
    type = "socket"
  }

  efidisk {
    efitype           = "4m"
    pre_enrolled_keys = true
    storage           = var.storage
  }

  tpm_state {
    version = "v2.0"
    storage = var.storage
  }

  disk {
    slot       = "scsi0"
    size       = var.server_disk_size
    type       = "disk"
    storage    = var.storage
    iothread   = true
    discard    = true
    emulatessd = true
  }

  disk {
    slot    = "ide2"
    size    = "4M"
    type    = "cloudinit"
    storage = var.storage
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    queues = var.server_cores
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0 = "ip=${var.ip_net_main},gw=${var.gateway}"
  sshkeys   = var.ssh_key
}

# Create VMs for agent k8s nodes
resource "proxmox_vm_qemu" "kube-agent" {
  count       = var.agent_count
  name        = format("kube-agent-%02d", count.index + 1)
  target_node = var.target_node_agent
  vmid        = 601 + count.index
  qemu_os     = "l26"
  clone       = var.vm_template_name
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  bios        = "ovmf"
  machine     = var.machine
  memory      = var.agent_memory
  balloon     = 0
  scsihw      = "virtio-scsi-single"
  boot        = "order=scsi0"

  cpu {
    cores = var.agent_cores
    type  = "host"
  }

  serial {
    id   = 0
    type = "socket"
  }

  efidisk {
    efitype           = "4m"
    pre_enrolled_keys = true
    storage           = var.storage
  }

  tpm_state {
    version = "v2.0"
    storage = var.storage
  }

  disk {
    slot       = "scsi0"
    size       = var.agent_disk_size
    type       = "disk"
    storage    = var.storage
    iothread   = true
    discard    = true
    emulatessd = true
  }

  disk {
    slot    = "ide2"
    size    = "4M"
    type    = "cloudinit"
    storage = var.storage
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    queues = var.agent_cores
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0 = "ip=${cidrhost(var.ip_net_agent, local.agent_host_offset + count.index)}/${local.agent_prefix},gw=${var.gateway}"
  sshkeys   = var.ssh_key
}
