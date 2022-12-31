# HCloud Nomad Cluster

Sets up a working consul+nomad cluster on hcloud using Terraform, so you can easily run containers
(and other workloads) with high availability on Hetzner Cloud.

## Setup

Run `terraform apply` in the `setup` folder to create:

- nomad server which runs services for:
  - nomad-autoscaler
  - prometheus
  - redis

Autoscaler scales hcloud nodes for redis. After successful run both Nomad and Consul are wide-world open and credentials for both you can find in terraform output

## Acknowledgements

Thanks to [@AndrewChubatiuk](https://github.com/AndrewChubatiuk) for the demo setup in [AndrewChubatiuk/nomad-hcloud-autoscaler](https://github.com/AndrewChubatiuk/nomad-hcloud-autoscaler/tree/main/demo).
This was initially copied from there.
