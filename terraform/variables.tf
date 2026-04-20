# =============================================================================
# Variables - Linux Desktop Terraform
# =============================================================================

variable "hcloud_token" {
  description = "Hetzner API token"
  type        = string
  sensitive   = true
}