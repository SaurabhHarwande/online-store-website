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