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
  sshkeys         = "74132294"
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

# Run Ansible to configure the development machine
resource "null_resource" "ansible_provisioner" {
  triggers = {
    instance_id = utho_cloud_instance.development_instance.id
    dns_record_id = utho_dns_record.development_instance_dns_record.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook ../ansible/playbooks/setup-dev-machine.yml \
        -e "github_token=${var.github_token}" \
        -e "git_user_name='${var.git_user_name}'" \
        -e "git_user_email='${var.git_user_email}'" \
        -e "ansible_host=devmachine.utho.saurabhharwande.com"
    EOT

    working_dir = path.module
  }

  depends_on = [
    utho_cloud_instance.development_instance,
    utho_dns_record.development_instance_dns_record
  ]
}

# Retrieve the SSH public key from the remote machine
data "external" "ssh_public_key" {
  program = ["sh", "-c", "ssh -o StrictHostKeyChecking=no root@devmachine.utho.saurabhharwande.com 'cat /root/.ssh/id_ed25519.pub' | jq -Rs '{key: .}'"]

  depends_on = [null_resource.ansible_provisioner]
}

# Upload SSH key to GitHub
resource "github_user_ssh_key" "dev_machine_key" {
  title = "development-machine-${var.instance_name}"
  key   = data.external.ssh_public_key.result.key

  depends_on = [data.external.ssh_public_key]
}