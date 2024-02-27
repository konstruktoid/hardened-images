variable "client_id" {
  type        = string
  default     = env("ARM_CLIENT_ID")
  description = "The Azure Active Directory service principal client ID"
}

variable "client_secret" {
  type        = string
  default     = env("ARM_CLIENT_SECRET")
  description = "The Azure Active Directory service principal client secret"
}

variable "image_offer" {
  description = "The offer to use."
  type        = string
}

variable "image_sku" {
  description = "The SKU to use."
  type        = string
}

variable "resource_group" {
  type        = string
  description = "Resource group."
}

variable "principal_name" {
  type        = string
  description = "Principal name."
}

variable "subscription_id" {
  type        = string
  default     = env("ARM_SUBSCRIPTION_ID")
  description = "The ID of the Azure subscription"
}

variable "tenant_id" {
  type        = string
  default     = env("ARM_TENANT_ID")
  description = "The ID of the Azure Active Directory tenant"
}

variable "vm_size" {
  description = "The SKU to use."
  type        = string
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

source "azure-arm" "hardened" {
  image_offer                       = var.image_offer
  image_publisher                   = "canonical"
  image_sku                         = var.image_sku
  managed_image_name                = "hardened-ubuntu-${var.image_sku}-${local.timestamp}"
  os_type                           = "Linux"
  vm_size                           = var.vm_size
  ssh_clear_authorized_keys         = "true"
  ssh_keep_alive_interval           = "15s"
  ssh_pty                           = "true"
  ssh_timeout                       = "10m"
  ssh_username                      = "ubuntu"
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  subscription_id                   = var.subscription_id
  tenant_id                         = var.tenant_id
  managed_image_resource_group_name = var.resource_group
  build_resource_group_name         = var.resource_group
}

build {
  sources = ["source.azure-arm.hardened"]

  provisioner "file" {
    sources     = ["config/ansible.cfg", "config/local.yml"]
    destination = "/tmp/"
  }

  provisioner "shell" {
    environment_vars  = ["ANSIBLE_CONFIG=/tmp/ansible.cfg", "HOME_DIR=/home/ubuntu", "TMPDIR=/var/tmp"]
    execute_command   = "echo 'ubuntu' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    expect_disconnect = true
    pause_before      = "10s"
    remote_folder     = "/var/tmp"
    scripts = [
      "${path.root}/scripts/hardening.sh",
      "${path.root}/scripts/cleanup.sh",
      "${path.root}/scripts/azure.sh"
    ]
  }
}
