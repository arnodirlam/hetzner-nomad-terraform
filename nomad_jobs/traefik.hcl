job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "nomad-server"
    }

    network {
      mode = "bridge"

      port "http" {
        to     = 80
        static = 80
      }

      port "https" {
        to     = 443
        static = 443
      }

      port "api" {
        to     = 8080
        static = 8080
      }

      port "metrics" {
        to = 8082
      }
    }

    service {
      name = "traefik"
      port = "http"

      connect {
        native = true
      }

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:latest"
        args  = ["--configFile=local/traefik.toml"]
        ports = ["http", "https", "api", "metrics"]
      }

      template {
        destination = "local/traefik.toml"

        data = <<EOF
[entryPoints]
    [entryPoints.web]
    address = ":80"
    [entryPoints.websecure]
    address = ":443"
    [entryPoints.metrics]
    address = ":8082"

# Traefik's built-in feature to request and renew Let's Encrypt certificates.
# Can be used for single-machine setups instead of a dedicated certbot Nomad job,
# because there is no coordination or certificate distribution between Traefik instances.
# Use by adding the following tags to a Nomad service:
#   - "traefik.http.routers.myservice.tls=true"
#   - "traefik.http.routers.myservice.tls.certresolver=traefik"
[certificatesResolvers.traefik.acme]
  email = "{{ key "letsencrypt/email" }}"
  storage = "{{ env "NOMAD_ALLOC_DIR" }}/data/certs.json"
  [certificatesResolvers.traefik.acme.tlsChallenge]

[api]
    dashboard = true
    insecure  = true

[log]
    level = "DEBUG"

[accessLog]

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false
    connectAware     = true
    connectByDefault = true

    [providers.consulCatalog.endpoint]
      address = "{{ env "NOMAD_IP_api" }}:8500"
      scheme  = "http"
      token   = "{{ key "secrets/consul/token" }}"

[providers.file]
    directory = "/local/config"
    watch     = true
EOF
      }

      template {
        destination = "local/config/tls.toml"
        change_mode = "noop" # hot-reloaded by Traefik on change

        data = <<EOF
# Dynamic configuration

[tls.options]
  [tls.options.default]
    sniStrict = true

{{ range $key, $pairs := tree "tls/certs" | byKey }}
# Domain {{ $key }}
[[tls.certificates]]
  stores = ["default"]
  certFile = """
{{ key (print "tls/certs/" $key "/cert") }}"""
  keyFile = """
{{ key (print "tls/certs/" $key "/key") }}"""

{{ end }}
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
