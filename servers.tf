data "hcloud_datacenters" "dc" {}

resource "random_shuffle" "dc" {
  count        = var.server_count
  input        = local.locations
  result_count = 1
}

resource "hcloud_server" "server" {
  count       = var.server_count
  name        = "${var.prefix}-${count.index}"
  image       = var.image
  datacenter  = random_shuffle.dc[count.index].result[0]
  ssh_keys    = var.ssh_keys
  server_type = var.server_type
  user_data   = local.server_user_data
  labels      = merge(var.labels, { "Name" = var.prefix })
}

locals {
  locations             = [for dc in data.hcloud_datacenters.dc.names : dc if var.location != null && can(regex("^${var.location}-dc\\d+$", dc))]
  server_ipv4_addresses = hcloud_server.server.*.ipv4_address
  server_ids            = hcloud_server.server.*.id
}
