# =============================================================================
# Variables - Linux Desktop Terraform
# =============================================================================

variable "ssh_private_key" {
  description = "Private SSH key for remote access (for provisioner)"
  type        = string
  sensitive   = true
  default     = ""
}