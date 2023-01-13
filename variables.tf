variable "ssh_key" {
  default = "~/.ssh/id_rsa"
}

variable "hcloud_token" {
  sensitive = true
}

variable "hetznerdns_token" {
  sensitive   = true
  description = "API token for Hetzner DNS (different from HCloud etc.) for requesting Let's Encrypt wildcard certificates such as *.example.com"
  default     = null
}

variable "letsencrypt_email" {
  type        = string
  description = "E-mail address for requesting Let's Encrypt SSL certifictes"
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "labels" {
  type = map(string)
  default = {
    Environment = "demo"
    Role        = "server"
  }
}

variable "prefix" {
  default = "nomad-server"
}

variable "server_count" {
  default = 1
}

variable "ssh_keys" {
  type    = list(string)
  default = ["nomad"]
}

variable "server_type" {
  default = "cx11"
}

variable "server_disk_scaling" {
  description = "Increase disk size when scaling up servers? Warning: Servers cannot be scaled down again when this is enabled"
  default     = false
}

variable "image" {
  default = "ubuntu-20.04"
}
