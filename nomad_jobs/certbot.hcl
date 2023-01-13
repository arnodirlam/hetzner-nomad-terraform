job "certbot" {
  # Nomad job to request, store and distribute Let's Encrypt certificates
  # to all Traefik instances via Consul keys.
  # Use by adding one or more of the following tags to a Nomad service:
  #   - "certbot.domain=app.example.com"
  #   - "certbot.domains=example.com,*.example.com"

  datacenters = ["dc1"]
  type        = "service"

  group "certbot" {
    restart {
      mode = "delay"
    }

    network {
      mode = "bridge"

      port "certbot" {
        to = 80
      }
    }

    ephemeral_disk {
      sticky  = true
      migrate = true
    }

    service {
      name = "certbot"
      port = "certbot"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.certbot.rule=PathPrefix(`/.well-known/acme-challenge/`)",
        "traefik.http.routers.certbot.priority=1024",
        "traefik.http.routers.certbot.entrypoints=web",
        "traefik.consulcatalog.connect=false",
      ]
    }

    task "certbot" {
      driver = "docker"

      config {
        image      = "arnodirlam/alpine-watchexec-curl:certbot"
        entrypoint = ["watchexec"]
        args = [
          "--watch", "local",
          "--on-busy-update", "queue",
          "local/get_certs.sh",
        ]
      }

      template {
        destination = "local/get_certs.sh"
        perms       = "744"
        data        = <<EOD
#!/usr/bin/env bash

{{ range $tag, $services := services | byTag }}
{{- if $tag | regexMatch "^certbot\\.domains?=[^=]+$" }}
{{- $domains := $tag | trimPrefix "certbot.domain=" | trimPrefix "certbot.domains=" }}
echo -e "\n`date --utc +%FT%TZ` Checking certificate for {{ $domains }} ..."
{{ if $domains | regexMatch "\\*" }}
certbot \
  certonly \
  --manual \
  --non-interactive \
  --no-bootstrap \
  --no-self-upgrade \
  --no-eff-email \
  --staple-ocsp \
  --expand \
  --agree-tos \
  --preferred-challenges dns \
  --manual-auth-hook local/certbot-hetzner-auth.sh \
  --manual-cleanup-hook local/certbot-hetzner-cleanup.sh \
  --config-dir "{{ env "NOMAD_ALLOC_DIR" }}/data/" \
  --email "{{ key "certbot/email" }}" \
  --domains {{ $domains }}
{{- else }}
certbot \
  certonly \
  --standalone \
  --non-interactive \
  --no-bootstrap \
  --no-self-upgrade \
  --no-eff-email \
  --staple-ocsp \
  --expand \
  --agree-tos \
  --preferred-challenges http \
  --config-dir "{{ env "NOMAD_ALLOC_DIR" }}/data/" \
  --email "{{ key "certbot/email" }}" \
  --domains {{ $domains }}
{{- end }}
{{- end }}
{{ end }}
echo -e "\n`date --utc +%FT%TZ` Done. Waiting for config changes ...\n"
EOD
        change_mode = "noop"
      }

      template {
        destination = "local/certbot-hetzner-auth.sh"
        perms       = "744"
        data        = <<EOD
#!/usr/bin/env bash

token="{{ key "secrets/hetznerdns/token" }}"
search_name=$( echo $CERTBOT_DOMAIN | rev | cut -d'.' -f 1,2 | rev)

zone_id=$(curl \
        -H "Auth-API-Token: ${token}" \
        "https://dns.hetzner.com/api/v1/zones?search_name=${search_name}" | \
        jq ".\"zones\"[] | select(.name == \"${search_name}\") | .id" 2>/dev/null | tr -d '"')

curl -X "POST" "https://dns.hetzner.com/api/v1/records" \
     -H 'Content-Type: application/json' \
     -H "Auth-API-Token: ${token}" \
     -d "{ \"value\": \"${CERTBOT_VALIDATION}\", \"ttl\": 300, \"type\": \"TXT\", \"name\": \"_acme-challenge.${CERTBOT_DOMAIN}.\", \"zone_id\": \"${zone_id}\" }" > /dev/null 2>/dev/null

# just make sure we sleep for a while (this should be a dig poll loop)
sleep 30
EOD
      }

      template {
        destination = "local/certbot-hetzner-cleanup.sh"
        perms       = "777"
        data        = <<EOD
#!/usr/bin/env bash

token="{{ key "secrets/hetznerdns/token" }}"
search_name=$( echo $CERTBOT_DOMAIN | rev | cut -d'.' -f 1,2 | rev)

zone_id=$(curl \
        -H "Auth-API-Token: ${token}" \
        "https://dns.hetzner.com/api/v1/zones?search_name=${search_name}" | \
        jq ".\"zones\"[] | select(.name == \"${search_name}\") | .id" 2>/dev/null | tr -d '"')

record_ids=$(curl \
        -H "Auth-API-Token: $token" \
        "https://dns.hetzner.com/api/v1/records?zone_id=$zone_id" | \
       jq ".\"records\"[] | select(.name == \"_acme-challenge.${CERTBOT_DOMAIN}.\") | .id" 2>/dev/null | tr -d '"')

for record_id in $record_ids
do
        curl -H "Auth-API-Token: $token" \
                -X "DELETE" "https://dns.hetzner.com/api/v1/records/${record_id}" > /dev/null 2> /dev/null
done
EOD
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "certsync" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image      = "arnodirlam/alpine-watchexec-curl:terraform-openssl"
        force_pull = true
        command    = "local/watch-and-sync.sh"
      }

      template {
        destination = "local/watch-and-sync.sh"
        perms       = "744"

        data = <<EOD
#!/usr/bin/env bash
set -eo pipefail

echo "`date --utc +%FT%TZ` Initializing ..."

cd /local
./domain_dirs.sh
terraform init -input=false
terraform import consul_key_prefix.certs tls/certs/ || \
  echo "consul_key_prefix.certs already imported."

watchexec \
  --watch ${NOMAD_ALLOC_DIR}/data/live \
  --watch /local \
  --exts 'pem,tf' \
  --debounce 10000 \
  --on-busy-update queue \
  /local/sync.sh
EOD
      }

      template {
        destination = "/local/sync.sh"
        perms       = "744"

        data = <<EOD
#!/usr/bin/env bash
set -o pipefail

cd /local
./domain_dirs.sh
cd /local
terraform apply -auto-approve -input=false

echo -e "\n`date --utc +%FT%TZ` Done. Waiting for file changes ..."
EOD
      }
      template {
        destination = "/local/domain_dirs.sh"
        perms       = "744"

        data = <<EOD
#!/usr/bin/env bash
set -o pipefail

cd {{ env "NOMAD_ALLOC_DIR" }}/data/live
echo -n "" > domain_dirs.yaml
for dir in *; do
  if [ -d "${dir}" ]; then
    domain=$(openssl x509 -in ${dir}/fullchain.pem -noout -ext subjectAltName | grep -E 'DNS:[^ ,]+' -o | cut -d':' -f2 | sort | paste -sd ',' -)
    echo "'${domain}': ${dir}" >> domain_dirs.yaml
  fi
done
EOD
      }

      template {
        destination = "/local/consul_certs.tf"
        change_mode = "noop"

        data = <<EOD
provider "consul" {
  address = "http://{{ env "attr.unique.network.ip-address" }}:8500"
  token   = "{{ key "secrets/consul/token" }}"
}

locals {
  domain_dirs = yamldecode(file("{{ env "NOMAD_ALLOC_DIR" }}/data/live/domain_dirs.yaml"))
  domain_tags = [
{{- range $tag, $services := services | byTag }}
  {{- if $tag | regexMatch "^certbot\\.domains?=[^=]+$" }}
    "{{ $tag | trimPrefix "certbot.domain=" | trimPrefix "certbot.domains=" }}",
  {{- end }}
{{- end }}
  ]
  domains = [ for tag in local.domain_tags : join(",", sort(split(",", tag))) ]
  domain_paths = {
    for domain in local.domains :
      domain => "{{ env "NOMAD_ALLOC_DIR" }}/data/live/${local.domain_dirs[domain]}"
  }
}

resource "consul_key_prefix" "certs" {
  path_prefix = "tls/certs/"

  subkeys = merge(
    { for domain, path in local.domain_paths : "${domain}/cert" => sensitive(file("${path}/fullchain.pem")) },
    { for domain, path in local.domain_paths : "${domain}/key" => sensitive(file("${path}/privkey.pem")) }
  )
}
EOD
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}