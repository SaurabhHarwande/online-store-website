# Utho Cloud Infrastructure

This directory contains Terraform configuration for provisioning infrastructure on Utho Cloud.

## Prerequisites

1. Install Terraform (version 1.0+)
2. Get your Utho API key from the [Utho Dashboard](https://console.utho.com/)
3. Have an SSH key pair ready

## Setup

1. Copy the example tfvars file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` and add your Utho API key and other configuration

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the plan:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Configuration Variables

- `utho_api_key`: Your Utho Cloud API key (required)
- `instance_name`: Name for your instance (default: "development-machine")
- `instance_dcslug`: Data center location (default: "innoida")
- `instance_image`: OS image to use (default: "ubuntu-22.04-x64")
- `instance_planid`: Instance size plan ID (default: "10001")

## Available Data Centers

Common Utho data center slugs:
- `innoida` - Noida, India
- `inmumbaizone2` - Mumbai Zone 2, India
- Check Utho documentation for complete list

## SSH Access

After provisioning, SSH into your instance:
```bash
ssh root@<instance-ip>
```

The instance IP will be shown in the Terraform output.

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Security Notes

- Add `terraform.tfvars` to `.gitignore` to avoid committing sensitive data
- Restrict firewall rules to specific IP addresses instead of 0.0.0.0/0
- Update the SSH key path in `development-machine.tf` to match your key location