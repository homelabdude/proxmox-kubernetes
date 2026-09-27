#!/bin/sh

usage() {
    echo "Usage: $0 --vmid <VMID> [--storage <STORAGE>] [--release <RELEASE>] [--help]"
    echo "Options:"
    echo "  --vmid       Specify a unique VM ID (required)."
    echo "  --storage    Specify the storage pool to use (optional, default: local-lvm)."
    echo "  --release    Ubuntu release: noble (24.04) or resolute (26.04) (optional, default: noble)."
    echo "  --help       Display help."
    exit 1
}

# Default values
STORAGE="local-lvm"
RELEASE="noble"

# Parse command-line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --vmid) VMID="$2"; shift ;;
        --storage) STORAGE="$2"; shift ;;
        --release) RELEASE="$2"; shift ;;
        --help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Check for required VMID argument
if [ -z "$VMID" ]; then
    echo "Error: VMID is required."
    usage
fi

# Validate the Ubuntu release
case "$RELEASE" in
    noble) VERSION="2404" ;;
    resolute) VERSION="2604" ;;
    *) echo "Error: Unsupported release: $RELEASE"; usage ;;
esac

IMAGE="$RELEASE-server-cloudimg-amd64.img"
TEMPLATE_NAME="ubuntu-$VERSION-template"

# Fetch a cloud-init image of Ubuntu
wget -q -O "$IMAGE" "https://cloud-images.ubuntu.com/$RELEASE/current/$IMAGE"

# If you have multiple nodes and run a Proxmox cluster, try and run this on the node with the maximum storage.
# If you are not on a Proxmox subscription, disable any enterprise repos:
# The enterprise repos can be disabled by navigating to the node name ('pve') and going into the 'Repositories' section.

# Update and install necessary tools
apt update -y
apt install -y libguestfs-tools
virt-customize -a "$IMAGE" --install qemu-guest-agent

# Create a base VM with the right configuration
echo "Creating VM with ID: $VMID, storage: $STORAGE and release: $RELEASE"
qm create "$VMID" --name "$TEMPLATE_NAME" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk "$VMID" "$IMAGE" "$STORAGE"
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-$VMID-disk-0"
qm set "$VMID" --boot c --bootdisk scsi0
qm set "$VMID" --ide2 "$STORAGE:cloudinit"
qm set "$VMID" --serial0 socket --vga serial0
qm set "$VMID" --agent enabled=1

# Convert the VM into a template
qm template "$VMID"

echo "Template created successfully with VMID: $VMID on storage: $STORAGE"
