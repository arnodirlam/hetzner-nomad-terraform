# HCloud Nomad Cluster

Sets up a working consul+nomad cluster on hcloud using Terraform, so you can easily run containers
(and other workloads) with high availability on Hetzner Cloud.

## Setup

### Prerequisites

1. Create or choose a project in the [Hetzner Cloud Console](https://console.hetzner.cloud/projects)
2. Under Security > SSH Keys, ensure it has a SSH key named `nomad`
3. Under Security > API Tokens, ensure there is a token that you have copied (not the "fingerprint")
4. Create a file `config.auto.tfvars` in the `setup` folder with the content:

```
hcloud_token = "your hcloud token"
ssh_key      = "~/.ssh/nomad"
```

### Bootstrap

When starting from scratch, first run this in the `setup` folder:

```
./bootstrap.sh
```

This will bootstrap a Consul and Nomad cluster and run Terraform only up to the point of writing a
`_creds.auto.tfvars.json` file in the directory you're running Terraform in. This is needed for the
subsequent setup of resources.

(This step is needed, because Terraform [does not support dynamic provider configuration](https://github.com/hashicorp/terraform/issues/25244))

### Iterating

Run `terraform apply` in the `setup` folder.

## Components

- nomad server which runs services for:
  - nomad-autoscaler
  - prometheus
  - redis

Autoscaler scales hcloud nodes for redis. After successful run both Nomad and Consul are wide-world open and credentials for both you can find in terraform output

## Acknowledgements

Thanks to [@AndrewChubatiuk](https://github.com/AndrewChubatiuk) for the demo setup in [AndrewChubatiuk/nomad-hcloud-autoscaler](https://github.com/AndrewChubatiuk/nomad-hcloud-autoscaler/tree/main/demo).
This was initially copied from there.
