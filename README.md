# HCloud Nomad Cluster

Sets up a working consul+nomad cluster on hcloud using Terraform, so you can easily run containers
(and other workloads) with high availability on Hetzner Cloud.

## Setup

### Prerequisites

1. Create or choose a project in the [Hetzner Cloud Console](https://console.hetzner.cloud/projects)
2. Under Security > SSH Keys, ensure it has a SSH key named `nomad`
3. Under Security > API Tokens, ensure there is a token that you have copied (not the "fingerprint")
4. Create a file `config.auto.tfvars` with the content:

```
hcloud_token = "your hcloud token"
ssh_key      = "~/.ssh/nomad"
```

### Iterating

Run `terraform apply`.

## Adding services

All `*.hcl` files under `nomad_jobs` will be synced to the running Nomad server/cluster.

Using Consul Connect a.k.a. Service Mesh requires also setting up Consul intentions to configure
what services are allowed to connect to each other. The file `consul_intentions.tf.example` has
some examples on how to do that.

## Monitoring

### Prometheus metrics on services

Prometheus will scrape any service that has `metrics` configured in its `meta` tags:

```hcl
meta {
  # scrape /metrics endpoint on the main service port
  metrics = true
}
```

```hcl
meta {
  # scrape /v1/metrics endpoint on the main service port
  metrics_path = "/v1/metrics"
}
```

```hcl
port "metrics" {
  to = 8082
}

# ...

meta {
  # scrape /metrics endpoint on given port
  metrics_port = "${NOMAD_HOST_PORT_metrics}"
}
```

### Prometheus metrics on Consul proxies

The Envoy proxy that's set up by Consul when using Consul Connect (a.k.a. Service Mesh) can expose its
own Prometheus metrics on the traffic it's routing. To enable scraping it:

```hcl
port "envoy_metrics" {
  to = 9999
}

# ...

meta {
  envoy_metrics_port = "${NOMAD_HOST_PORT_envoy_metrics}"
}

# ...

connect {
  sidecar_service {
    proxy {
      config {
        envoy_prometheus_bind_addr = "0.0.0.0:9999"
      }
    }
  }
}
```

## Acknowledgements

- All the great companies and organizations fostering open-source projects:
  HashiCorp, Traefik Labs, Internet Security Research Group (ISRG), GitHub
- [@AndrewChubatiuk](https://github.com/AndrewChubatiuk) for the demo setup in
  [AndrewChubatiuk/nomad-hcloud-autoscaler](https://github.com/AndrewChubatiuk/nomad-hcloud-autoscaler/tree/main/demo).
  This was initially copied from there.
- [@icicimov](https://github.com/icicimov) for the in-depth
  [blog post](https://icicimov.github.io/blog/devops/Automated-SSL-Certificates-management-HAProxy-Consul-LetsEncrypt-AWS/)
  on running Certbot with Consul
- [@mjm](https://github.com/mjm) for the in-depth
  [blog post](https://www.mattmoriarity.com/2021-02-21-scraping-prometheus-metrics-with-nomad-and-consul-connect/)
  on scraping Prometheus metrics through Consul Connect
