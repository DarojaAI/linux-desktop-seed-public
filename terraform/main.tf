# =============================================================================
# Linux Desktop - Hetzner Terraform Configuration
# =============================================================================
# Provisions a single VM on Hetzner and outputs its IP for deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.46"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# =============================================================================
# Variables
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

variable "public_ipv4_enabled" {
  description = "Enable public IPv4"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project    = "linux-desktop-seed"
    managed_by = "terraform"
  }
}

# =============================================================================
# Server
# =============================================================================

resource "hcloud_server" "main" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = var.image

  # SSH keys - use directly, not dynamic block
  ssh_keys = var.ssh_keys

  labels = var.labels
}

# Conditional provisioner resource
resource "null_resource" "server_ready" {
  count = var.ssh_private_key != "" ? 1 : 0

  triggers = {
    server_id = hcloud_server.main.id
  }

  provisioner "remote-exec" {
    inline = ["echo 'Server ready'"]

    connection {
      type        = "ssh"
      user        = "root"
      host        = hcloud_server.main.ipv4_address
      private_key = var.ssh_private_key
      timeout     = "10m"
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.main.id
}

output "server_name" {
  description = "Server name"
  value       = hcloud_server.main.name
}

output "ipv4_address" {
  description = "Public IPv4 address"
  value       = hcloud_server.main.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address"
  value       = hcloud_server.main.ipv6_address
}

output "connection_info" {
  description = "Connection information for deployment"
  value       = "ssh -o StrictHostKeyChecking=no root@${hcloud_server.main.ipv4_address}"
  sensitive   = true
}