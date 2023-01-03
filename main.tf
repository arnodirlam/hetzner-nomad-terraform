resource "null_resource" "nomad" {

  triggers = {
    servers = join(",", hcloud_server.server.*.id)
  }

  connection {
    host        = local.server_ipv4_addresses[0]
    user        = "root"
    private_key = file(var.ssh_key)
  }

  provisioner "file" {
    source      = "${path.module}/wait.sh"
    destination = "/tmp/wait.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/wait.sh",
      "/tmp/wait.sh http://${local.server_ipv4_addresses[0]}:4646/v1/status/leader",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/wait.sh",
      "/tmp/wait.sh http://${local.server_ipv4_addresses[0]}:8500/v1/status/leader",
    ]
  }

  provisioner "local-exec" {
    command = "scp -i ${var.ssh_key} root@${local.server_ipv4_addresses[0]}:/tmp/creds.json ${path.root}/creds.json"
  }
}

data "local_file" "creds" {
  filename   = "${path.root}/creds.json"
  depends_on = [null_resource.nomad]
}

resource "consul_key_prefix" "secrets" {
  path_prefix = "secrets/"

  subkeys = {
    "hcloud/token" = var.hcloud_token
    "consul/token" = jsondecode(data.local_file.creds.content)["consul"]
    "nomad/token"  = jsondecode(data.local_file.creds.content)["nomad"]
  }
}

resource "nomad_job" "service" {
  for_each = fileset("${path.module}/nomad_jobs", "*.hcl")
  jobspec  = file("${path.module}/nomad_jobs/${each.key}")
}
