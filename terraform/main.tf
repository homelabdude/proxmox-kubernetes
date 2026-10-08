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
  # Start the VM when the Proxmox node boots
  start_at_node_boot = true
  balloon            = 0
  scsihw             = "virtio-scsi-single"
  boot               = "order=scsi0"
  # The provider has no default for this, so leaving it unset shows as a diff against the running VM
  power_state = "running"

  # Proxmox starts VMs in ascending order and shuts them down in reverse. The control plane is
  # order 1: up first, and down last, so the API server is still there while the agents drain
  # their pods (kubelet graceful node shutdown, 60s). shutdown_timeout leaves room for that plus
  # the OS shutdown before Proxmox stops the VM hard.
  startup_shutdown {
    order            = 1
    startup_delay    = 30
    shutdown_timeout = 180
  }

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

  # Keep the disks in the order Proxmox reports them (ide2 before scsi0) to avoid a perpetual diff
  disk {
    slot    = "ide2"
    type    = "cloudinit"
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
    format = "raw"
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
  # Start the VM when the Proxmox node boots
  start_at_node_boot = true
  balloon            = 0
  scsihw             = "virtio-scsi-single"
  boot               = "order=scsi0"
  power_state = "running"

  # After the control plane on the way up, before it on the way down (see kube-server)
  startup_shutdown {
    order            = 2
    shutdown_timeout = 180
  }

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

  # Keep the disks in the order Proxmox reports them (ide2 before scsi0) to avoid a perpetual diff
  disk {
    slot    = "ide2"
    type    = "cloudinit"
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
    format = "raw"
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

resource "proxmox_vm_qemu" "test-vm" {
  count       = var.build_test_VM ? 1 : 0
  name        = "test-vm-01"
  target_node = var.target_node_test_vm
  vmid        = 701
  qemu_os     = "l26"
  clone       = var.vm_template_name
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  bios        = "ovmf"
  machine     = var.machine
  memory      = var.test_vm_memory
  start_at_node_boot = true
  balloon            = 0
  scsihw             = "virtio-scsi-single"
  boot               = "order=scsi0"
  power_state = "running"

  # Not part of the cluster, so up after it and down before it
  startup_shutdown {
    order            = 3
    shutdown_timeout = 60
  }

  cpu {
    cores = var.test_vm_cores
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

  # Keep the disks in the order Proxmox reports them (ide2 before scsi0) to avoid a perpetual diff.
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage
  }

  disk {
    slot       = "scsi0"
    size       = var.test_vm_disk_size
    type       = "disk"
    storage    = var.storage
    iothread   = true
    discard    = true
    emulatessd = true
    format = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    queues = var.test_vm_cores
  }

  lifecycle {
    ignore_changes = [
      network,
    ]

    precondition {
      condition     = var.target_node_test_vm != null && var.ip_net_test_vm != null
      error_message = "build_test_VM needs target_node_test_vm and ip_net_test_vm to be set."
    }
  }

  ipconfig0 = "ip=${var.ip_net_test_vm},gw=${var.gateway}"
  sshkeys   = var.ssh_key
}
