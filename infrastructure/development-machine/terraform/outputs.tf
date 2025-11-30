# Outputs
output "instance_id" {
  description = "The ID of the cloud instance"
  value       = utho_cloud_instance.development_instance.id
}

output "instance_ip" {
  description = "The public IP address of the instance"
  value       = utho_cloud_instance.development_instance.ip
}

output "instance_status" {
  description = "The status of the instance"
  value       = utho_cloud_instance.development_instance.status
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "ssh root@${utho_cloud_instance.development_instance.ip}"
}

output "dns_hostname" {
  description = "The DNS hostname for the instance"
  value       = "${utho_dns_record.development_instance_dns_record.hostname}.${utho_dns_record.development_instance_dns_record.domain}"
}

output "github_ssh_key_id" {
  description = "The ID of the SSH key added to GitHub"
  value       = github_user_ssh_key.dev_machine_key.id
}