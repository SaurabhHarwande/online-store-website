terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.digital_ocean.token
}

provider "github" {
  token = var.github_token
}

resource "digitalocean_droplet" "development-machine" {
  image = var.digital_ocean.droplet.image
  name = var.digital_ocean.droplet.name
  region = var.digital_ocean.droplet.region
  size = var.digital_ocean.droplet.size
  ssh_keys = var.digital_ocean.droplet.ssh_keys
}

resource "digitalocean_record" "developmentmachine-do-saurabhharwande-com" {
  type = "A"
  domain = "do.saurabhharwande.com"
  value = "${digitalocean_droplet.development-machine.ipv4_address}"
  name = "developmentmachine"
}

# # Null resource to run Ansible playbook after instance is ready
# resource "null_resource" "ansible_provisioner" {
#   # Trigger provisioning when instance changes or variables change
#   triggers = {
#     instance_id      = utho_cloud_instance.development_instance.id
#     instance_ip      = utho_cloud_instance.development_instance.ip
#     dns_hostname     = "${utho_dns_record.development_instance_dns_record.hostname}.${utho_dns_record.development_instance_dns_record.domain}"
#     github_token     = var.github_token
#     git_user_name    = var.git_user_name
#     git_user_email   = var.git_user_email
#   }

#   # Wait for SSH to become available
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Waiting for SSH to become available on ${utho_dns_record.development_instance_dns_record.hostname}.${utho_dns_record.development_instance_dns_record.domain}..."
#       timeout 300 bash -c 'until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${utho_dns_record.development_instance_dns_record.hostname}.${utho_dns_record.development_instance_dns_record.domain} echo "SSH is ready"; do sleep 5; done'
#     EOT
#   }

#   # Run Ansible playbook
#   provisioner "local-exec" {
#     command = <<-EOT
#       cd ../ansible && \
#       ansible-playbook playbooks/setup-dev-machine.yml \
#         -i inventory.yml \
#         -e "ansible_host=${utho_dns_record.development_instance_dns_record.hostname}.${utho_dns_record.development_instance_dns_record.domain}" \
#         -e "github_token=${var.github_token}" \
#         -e "git_user_name='${var.git_user_name}'" \
#         -e "git_user_email='${var.git_user_email}'"
#     EOT
#   }

#   depends_on = [
#     utho_cloud_instance.development_instance,
#     utho_dns_record.development_instance_dns_record
#   ]
# }
