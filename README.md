# Proxmox Kubernetes

![Proxmox Kubernetes Terraform CI status](https://github.com/ash0ne/proxmox-kubernetes/actions/workflows/ci.yml/badge.svg)

- A complete package built using shell, Terrafrom and Ansible to automate the creation of a complete Kubernetes cluster in a proxmox installation.
- Most values default to the default installation settings of proxmox, the comments in the files should help you change any if you need to.
- Has been tested with proxmox 7.x and 8.x.
- The terrafrom assumes a 2 node setup but if you have more nodes, you can easily update the terraform and ansible to suit your needs.

## Steps:

### Create a VM template
- SSH into your each of your proxmox nodes as root and run the below command to create a VM template in each proxmox node.
- Make sure to replace `<vm-id>` with a valid and recognizable number like 8888 or 9999
- Run  `wget -O template.sh https://raw.githubusercontent.com/ash0ne/proxmox-kubernetes/main/prepare-vm-template.sh && . template.sh --vmid <vm-id>`
- If you use zfs, please run `wget -O template.sh https://raw.githubusercontent.com/ash0ne/proxmox-kubernetes/main/prepare-vm-template.sh && . template.sh --vmid <vm-id> --storage local-zfs`
- The template uses Ubuntu 24.04 (noble) by default. To use Ubuntu 26.04 (resolute) instead, add `--release resolute`

### Create an API key and add permissions
- Click on Datacenter -> Permissions -> API Tokens
- Click on 'Add' and create a token for one of your admin users. Ideally this must be an admin user in the pve realm but any admin user works just fine.
- Lastly, do not forget to add the permission for the API token by going to Permissions -> Add. This needs to be done even if the user acssociated with the token already has permissions.
  
 ![Screenshot 2023-07-13 071644](https://github.com/ash0ne/proxmox-kubernetes/assets/136186619/3b3def4e-e759-4185-8e2b-7d5846d11f97)

### Update values in terraform.tfvars
- Update everything to the right values in `terraform.tfvars`
- A sample tfvars file is added at `./terrafrom/terraform.tfvars`
- From the `./terraform` directory, run `terraform plan` and `terraform apply`

### Check the connectivity to hosts before running ansible
- Run `ansible -i ./ansible/inventory/hosts all -m ping -u ubuntu --key-file <private_ssh_key>`. This SSH key should be the private key matching the ssh public key added in `terraform.tfvars`

### Run the ansible playbooks in order
- Apply the common playbook first by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/common/tasks/main.yaml`
- Apply the main-node playbook to initialise k8s master node by running `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/main-node/tasks/main.yaml`
- At this point, ssh into the master node by running `ssh ubuntu@<main-nod-ip> -i <private_ssh_key>` and install the cluster network by running `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/calico.yaml`
- You should now have your core `kube-system` pods running and should see the below output if you run `kubectl get pod -A`

 ![kube-system](https://github.com/ash0ne/proxmox-kubernetes/assets/136186619/dfcb5737-827b-4379-988a-c828a425d6e6)

- Join the agent nodes by running  `ansible-playbook -i ./ansible/inventory/hosts --key-file <private_ssh_key> ./ansible/roles/join-nodes/tasks/main.yaml --extra-vars "main_node_ip=<ip_of_the_main_node>"`
