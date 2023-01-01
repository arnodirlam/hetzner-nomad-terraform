variable "ssh_key" {
  default = "~/.ssh/id_rsa"
}

variable "hcloud_token" {
  sensitive = true
}

variable "consul_address" {
  default = null
}

variable "consul_token" {
  sensitive = true
  default   = null
}

variable "nomad_address" {
  default = null
}

variable "nomad_secret_id" {
  sensitive = true
  default   = null
}
