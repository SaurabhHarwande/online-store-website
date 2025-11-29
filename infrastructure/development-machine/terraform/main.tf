terraform {
  required_providers {
    utho = {
      source  = "uthoplatforms/utho"
      version = "~> 0.6.4"
    }
  }
}

provider "utho" {
  token = var.utho_api_key
  # You can also use environment variable: UTHO_TOKEN
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