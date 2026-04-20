# =============================================================================
# Variables - Linux Desktop Terraform
# =============================================================================

variable "hcloud_token" {
  description = "Hetzner API token"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "linux-desktop"
}

variable "server_type" {
  description = "Hetzner server type (e.g., cpx21, cpx41)"
  type        = string
  default     = "cpx41"
}

variable "location" {
  description = "Hetzner datacenter location (e.g., fsn1, nbg1)"
  type        = string
  default     = "fsn1"
}

variable "image" {
  description = "OS image to use"
  type        = string
  default     = "ubuntu-22.04"
}

variable "ssh_keys" {
  description = "SSH key IDs or names to attach"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}