variable "utho_api_key" {
  description = "Utho Cloud API Key"
  type        = string
  sensitive   = true
}

variable "instance_name" {
  description = "Name of the cloud instance"
  type        = string
  default     = "development-machine"
}

variable "instance_dcslug" {
  description = "Data center slug (e.g., innoida, inmumbaizone2)"
  type        = string
  default     = "innoida"
}

variable "instance_image" {
  description = "Operating system image (e.g., ubuntu-20.04-x64, ubuntu-22.04-x64)"
  type        = string
  default     = "ubuntu-22.04-x64"
}

variable "instance_planid" {
  description = "Plan ID for the instance size"
  type        = string
  default     = "10001" # Adjust based on your requirements
}

variable "instance_password" {
  description = "Password for the root account"
  type        = string
  default     = "randomStrongPassword" # Adjust based on your requirements
}

variable "github_token" {
  description = "GitHub Personal Access Token for SSH key setup"
  type        = string
  sensitive   = true
  default     = ""
}

variable "git_user_name" {
  description = "Git user name for configuration"
  type        = string
  default     = "Dev Machine"
}

variable "git_user_email" {
  description = "Git user email for configuration"
  type        = string
  default     = "dev@example.com"
}