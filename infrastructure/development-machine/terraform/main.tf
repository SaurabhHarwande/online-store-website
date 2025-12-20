terraform {
  required_providers {
    utho = {
      source  = "uthoplatforms/utho"
      version = "~> 0.6.4"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "utho" {
  token = var.utho_api_key
  # You can also use environment variable: UTHO_TOKEN
}

provider "github" {
  token = var.github_token
}

# Create cloud instance
resource "utho_cloud_instance" "development_instance" {
  dcslug          = var.instance_dcslug
  image           = var.instance_image
  name            = var.instance_name
  root_password   = var.instance_password
  enable_publicip = true
  billingcycle    = "hourly"
  planid          = var.instance_planid
  sshkeys         = var.utho_ssh_key
  enablebackup    = false

  lifecycle {
    ignore_changes = [
      root_password,  # Ignore password changes after creation
      vpc_id,         # Ignore VPC changes (if not explicitly set)
    ]
  }
}

# Create a DNS record for connecting to the server
resource "utho_dns_record" "development_instance_dns_record" {
  domain    = "utho.saurabhharwande.com"
  hostname  = "devmachine"
  porttype  = "TCP"
  ttl       = "3600"
  type      = "A"
  value     = utho_cloud_instance.development_instance.ip
  priority  = ""
  port      = ""
  weight    = ""

  depends_on = [utho_cloud_instance.development_instance]
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
