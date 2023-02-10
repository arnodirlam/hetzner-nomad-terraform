job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "monitoring" {
    count = 1

    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "nomad-server"
    }

    network {
      mode = "bridge"

      port "prom" {
        static = 9090
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      sticky  = true
      migrate = true
    }

    task "prometheus" {
      template {
        destination   = "local/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"

        data = <<EOH
---
global:
  scrape_interval:     15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'consul_metrics'
    static_configs:
    - targets:
        - '{{ env "NOMAD_IP_prom" }}:8500'

    metrics_path: '/v1/agent/metrics'
    params:
      format: ['prometheus']
    bearer_token: '{{ key "secrets/consul/token" }}'

  - job_name: 'nomad_metrics'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prom" }}:8500'
      token: '{{ key "secrets/consul/token" }}'
      services: ['nomad-client', 'nomad']

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  # See https://www.mattmoriarity.com/2021-02-21-scraping-prometheus-metrics-with-nomad-and-consul-connect/
  - job_name: consul-services
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prom" }}:8500'
      token: '{{ key "secrets/consul/token" }}'
    relabel_configs:
    - source_labels: [__meta_consul_service]
      action: drop
      regex: (.+)-sidecar-proxy
    - source_labels:
      - __meta_consul_service_metadata_metrics
      - __meta_consul_service_metadata_metrics_path
      - __meta_consul_service_metadata_metrics_port
      separator: ;
      action: drop
      regex: false;.*|;;
    - source_labels: [__meta_consul_service_metadata_metrics_path]
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_consul_service_metadata_metrics_port]
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: ${1}:${2}
      target_label: __address__

  - job_name: consul-connect-proxies
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prom" }}:8500'
      token: '{{ key "secrets/consul/token" }}'
    relabel_configs:
    - source_labels: [__meta_consul_service]
      action: drop
      regex: (.+)-sidecar-proxy
    - source_labels: [__meta_consul_service_metadata_envoy_metrics_port]
      action: keep
      regex: (.+)
    - source_labels: [__address__, __meta_consul_service_metadata_envoy_metrics_port]
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: ${1}:${2}
      target_label: __address__
EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        args  = ["--config.file=/local/prometheus.yml", "--log.level=debug"]

        ports = ["prom"]
      }

      service {
        name = "prometheus"
        port = "prom"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}