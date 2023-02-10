locals {
  user_data_input = {
    "node_class"   = "nomad-server"
    "datacenter"   = "dc1"
    "servers"      = []
    "interface"    = "eth0"
    "consul_token" = ""
    "nomad_token"  = ""
  }

  server_init_config = {
    apt = {
      sources = {
        "hashicorp-releases.list" = {
          keyid  = "798AEC654E5C15428C8E42EEAA16FCBCA621E701"
          source = "deb [arch=amd64] https://apt.releases.hashicorp.com $RELEASE main"
        }
        "docker.list" = {
          keyid  = "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
          source = "deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable"
        }
      }
    }
    packages = [
      "nomad",
      "consul",
      "docker-ce",
      "docker-ce-cli",
      "containerd.io",
      "jq",
    ]
    runcmd = [
      ["/usr/bin/bootstrap.sh"],
    ]
    write_files = [
      {
        path        = "/etc/nomad.d/nomad.hcl"
        permissions = "0644"
        content     = templatefile("${path.module}/templates/nomad.hcl.tmpl", local.user_data_input)
        }, {
        path        = "/etc/consul.d/consul.hcl"
        permissions = "0644"
        content     = templatefile("${path.module}/templates/consul.hcl.tmpl", local.user_data_input)
        }, {
        path        = "/usr/bin/bootstrap.sh"
        permissions = "0755"
        content     = templatefile("${path.module}/templates/bootstrap.sh", local.user_data_input)
      }
    ]
  }

  server_user_data = "#cloud-config\n${yamlencode(local.server_init_config)}"
}
