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
  keep_disk   = !var.server_disk_scaling
  user_data   = local.server_user_data
  labels      = merge(var.labels, { "Name" = var.prefix })

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}

resource "remote_file" "consul_config" {
  conn {
    host        = local.server_ipv4_addresses[0]
    user        = "root"
    private_key = file(var.ssh_key)
  }

  path        = "/etc/consul.d/consul.hcl"
  permissions = "0644"
  content = templatefile("${path.module}/templates/consul.hcl.tmpl", {
    "servers"   = []
    "interface" = "eth0"
  })

  depends_on = [null_resource.nomad]
}

resource "null_resource" "consul_config" {
  connection {
    host        = local.server_ipv4_addresses[0]
    user        = "root"
    private_key = file(var.ssh_key)
  }

  triggers = {
    content_hash = sha256(remote_file.consul_config.content)
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl restart consul",
    ]
  }
}

resource "remote_file" "nomad_config" {
  conn {
    host        = local.server_ipv4_addresses[0]
    user        = "root"
    private_key = file(var.ssh_key)
  }

  path        = "/etc/nomad.d/nomad.hcl"
  permissions = "0644"
  content = templatefile("${path.module}/templates/nomad.hcl.tmpl", {
    "node_class" = "nomad-server"
    "datacenter" = "dc1"
    "servers"    = []
    "interface"  = "eth0"
  })

  depends_on = [null_resource.nomad]
}

resource "null_resource" "nomad_config" {
  connection {
    host        = local.server_ipv4_addresses[0]
    user        = "root"
    private_key = file(var.ssh_key)
  }

  triggers = {
    content_hash = sha256(remote_file.nomad_config.content)
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl restart nomad",
    ]
  }
}

locals {
  locations             = [for dc in data.hcloud_datacenters.dc.names : dc if var.location != null && can(regex("^${var.location}-dc\\d+$", dc))]
  server_ipv4_addresses = hcloud_server.server.*.ipv4_address
  server_ids            = hcloud_server.server.*.id
}
