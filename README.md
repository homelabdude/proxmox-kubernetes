# Proxmox Kubernetes

![Proxmox Kubernetes Terraform CI status](https://github.com/ash0ne/proxmox-kubernetes/actions/workflows/ci.yml/badge.svg)

- A complete package built using shell, Terrafrom and Ansible to automate the creation of a complete Kubernetes cluster in a proxmox installation.
- Most values default to the default installation settings of proxmox, the comments in the files should help you change any if you need to.
- Has been tested with proxmox 7.x and 8.x.
- The terraform creates 1 main node and 2 agent nodes by default. Set `agent_count` in `terraform.tfvars` for more agents and update the ansible inventory to match.

## Steps:

### Create a VM template
- SSH into your each of your proxmox nodes as root and run the below command to create a VM template in each proxmox node.
- Make sure to replace `<vm-id>` with a valid and recognizable number like 8888 or 9999
- Run  `wget -O template.sh https://raw.githubusercontent.com/ash0ne/proxmox-kubernetes/main/prepare-vm-template.sh && . template.sh --vmid <vm-id>`
- If you use zfs, please run `wget -O template.sh https://raw.githubusercontent.com/ash0ne/proxmox-kubernetes/main/prepare-vm-template.sh && . template.sh --vmid <vm-id> --storage local-zfs` and set `storage = "local-zfs"` in `terraform.tfvars`
- The template uses Ubuntu 24.04 (noble) by default. To use Ubuntu 26.04 (resolute) instead, add `--release resolute` and set `vm_template_name = "ubuntu-2604-template"` in `terraform.tfvars`

### Create an API key and add permissions
- Click on Datacenter -> Permissions -> API Tokens
- Click on 'Add' and create a token for one of your admin users. Ideally this must be an admin user in the pve realm but any admin user works just fine.
- Lastly, do not forget to add the permission for the API token by going to Permissions -> Add. This needs to be done even if the user acssociated with the token already has permissions.
  
 ![Screenshot 2023-07-13 071644](https://github.com/ash0ne/proxmox-kubernetes/assets/136186619/3b3def4e-e759-4185-8e2b-7d5846d11f97)

### Update values in terraform.tfvars
- From the `./terraform` directory, copy the sample file by running `cp terraform.tfvars.example terraform.tfvars`
- Update everything to the right values in `terraform.tfvars`. This file is git-ignored so your token stays out of version control
- From the `./terraform` directory, run `terraform init`, `terraform plan` and `terraform apply`

### Update the ansible inventory
- From the `./ansible/inventory` directory, copy the sample file by running `cp hosts.example hosts`
- Update the IPs in `hosts` to match `ip_net_main` and `ip_net_agent` from `terraform.tfvars`. This file is git-ignored

### Check the connectivity to hosts before running ansible
- Run `ansible -i ./ansible/inventory/hosts all -m ping -u ubuntu --key-file <private_ssh_key>`. This SSH key should be the private key matching the ssh public key added in `terraform.tfvars`

### Run the ansible playbooks in order
- Apply the common playbook first by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/common/tasks/main.yaml`
  - This installs Kubernetes v1.36 by default. To pick another version, add `--extra-vars "k8s_version=v1.37"`
- Apply the main-node playbook to initialise k8s master node by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/main-node/tasks/main.yaml`
- At this point, ssh into the master node by running `ssh ubuntu@<main-nod-ip> -i <private_ssh_key>` and install the cluster network by running `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/calico.yaml`
- You should now have your core `kube-system` pods running and should see the below output if you run `kubectl get pod -A`

 ![kube-system](https://github.com/ash0ne/proxmox-kubernetes/assets/136186619/dfcb5737-827b-4379-988a-c828a425d6e6)

- Join the agent nodes by running  `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/join-nodes/tasks/main.yaml --extra-vars "main_node_ip=<ip_of_the_main_node>"`
- Install storage by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/storage/tasks/main.yaml`. This sets up two storage classes:
  - `longhorn` (default): volumes replicated across the agent nodes, with snapshots and backups. Use this for anything you want to keep
  - `local-path`: a plain directory on the node the pod runs on. Faster, but the data is lost with the node. Use it with `storageClassName: local-path`
- Set `metallb_ip_range`, `gateway_ip` and `gateway_domain` in the inventory, then install ingress by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/ingress/tasks/main.yaml`. This sets up:
  - MetalLB, which gives `LoadBalancer` services an IP from `metallb_ip_range` on your LAN
  - Envoy Gateway with a gateway named `eg` on `gateway_ip`, listening for plain HTTP on `*.<gateway_domain>`. Terminate TLS in a reverse proxy in front of it
  - The Longhorn UI is exposed at `longhorn.<gateway_domain>` if Longhorn is installed. It has no login, so keep it off the internet
  - Expose an app by creating an `HTTPRoute` with `parentRefs: [{name: eg, namespace: envoy-gateway-system}]` and a hostname under `gateway_domain`. Gateway API's `TCPRoute`, `UDPRoute` and `TLSRoute` are also installed for L4 traffic
- Install metrics-server for `kubectl top` by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/metrics-server/tasks/main.yaml`
