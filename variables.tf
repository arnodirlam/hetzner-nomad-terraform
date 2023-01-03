variable "ssh_key" {
  default = "~/.ssh/id_rsa"
}

variable "hcloud_token" {
  sensitive = true
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

variable "image" {
  default = "ubuntu-20.04"
}
