provider "hcloud" {
  token = var.hcloud_token
}

provider "nomad" {
  address   = var.nomad_address
  secret_id = var.nomad_secret_id
}

provider "consul" {
  address = var.consul_address
  token   = var.consul_token
}

provider "remote" {
}
