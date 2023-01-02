terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    random = {
      source = "hashicorp/random"
    }
    remote = {
      source = "tenstad/remote"
    }
  }
  required_version = ">= 0.13"
}
