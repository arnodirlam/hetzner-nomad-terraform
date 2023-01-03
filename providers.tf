provider "hcloud" {
  token = var.hcloud_token
}

provider "nomad" {
  address   = "http://${local.server_ipv4_addresses[0]}:4646"
  secret_id = jsondecode(data.local_file.creds.content)["nomad"]
}

provider "consul" {
  address = "http://${local.server_ipv4_addresses[0]}:8500"
  token   = jsondecode(data.local_file.creds.content)["consul"]
}

provider "remote" {
}
