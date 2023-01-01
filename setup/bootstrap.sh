#!/bin/bash
set -ex

terraform init
terraform apply -target local_sensitive_file.creds $@
