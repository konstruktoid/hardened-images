packer {
  required_version = "~> 1.16.0"

  required_plugins {
    azure = {
      version = "~> 2.5.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "client_id" {
  type        = string
  default     = env("ARM_CLIENT_ID")
  description = "The Azure Active Directory service principal client ID. Exported by `source azure_vars_export`."
}

variable "client_secret" {
  type        = string
  default     = env("ARM_CLIENT_SECRET")
  sensitive   = true
  description = "The Azure Active Directory service principal client secret. Exported by `source azure_vars_export`; never written to disk."
}

variable "subscription_id" {
  type        = string
  default     = env("ARM_SUBSCRIPTION_ID")
  description = "The ID of the Azure subscription."
}

variable "tenant_id" {
  type        = string
  default     = env("ARM_TENANT_ID")
  description = "The ID of the Azure Active Directory tenant."
}

variable "image_offer" {
  type        = string
  description = "The offer to use."
}

variable "image_sku" {
  type        = string
  description = "The SKU to use."

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.image_sku))
    error_message = "The image_sku variable must only contain [A-Za-z0-9._-]; it becomes part of the image name and of a shell-local command."
  }
}

variable "managed_image_storage_account_type" {
  type        = string
  default     = "Standard_LRS"
  description = "Managed image OS disk SKU. Only Standard_LRS and Premium_LRS are accepted; managed images cannot use StandardSSD."

  validation {
    condition     = contains(["Standard_LRS", "Premium_LRS"], var.managed_image_storage_account_type)
    error_message = "The managed_image_storage_account_type must be Standard_LRS or Premium_LRS."
  }
}

variable "vm_size" {
  type        = string
  description = "Size of the VM used to build the image."
}

variable "resource_group" {
  type        = string
  description = "Resource group the build VM and the resulting managed image live in."
}

variable "principal_name" {
  type        = string
  description = "Service principal display name. Consumed by azure_vars_export, not by this template."
}

variable "my_ip_address" {
  type        = string
  default     = env("MY_IP_ADDRESS")
  description = "Public IP address allowed to reach the build VM over SSH. Detected by azure_vars_export."

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.my_ip_address))
    error_message = "The my_ip_address variable must be a single IPv4 address; run \"source azure_vars_export\" or set MY_IP_ADDRESS."
  }
}

variable "username" {
  type        = string
  default     = "ubuntu"
  description = "Login and SSH username on the build VM."
}

variable "password" {
  type        = string
  default     = "ubuntu"
  sensitive   = true
  description = "Password used to authenticate sudo on the build VM during provisioning."

  validation {
    condition     = can(regex("^[A-Za-z0-9_@%+=:,./-]+$", var.password))
    error_message = "The password variable must only contain [A-Za-z0-9_@%+=:,./-]; other characters break the single-quoted shell values it is passed through."
  }
}

variable "hardening_collection_version" {
  type        = string
  default     = "v0.3.2"
  description = "Tag of konstruktoid/ansible-collection-hardening to provision with. Must match the default in scripts/hardening.sh."
}

variable "syft_version" {
  type        = string
  default     = "v1.46.0"
  description = "Tag of anchore/syft used to generate the SBOM."
}

locals {
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "hardened-ubuntu-${var.image_sku}-${local.timestamp}"
  build_dir  = "${path.root}/output/${local.image_name}"

  sudo_command = ". {{ .EnvVarFile }}; echo \"$SUDO_PASSWORD\" | sudo -S --preserve-env=ANSIBLE_CONFIG,BUILD_USERNAME,HARDENING_COLLECTION_VERSION,SYFT_VERSION bash -eux -o pipefail '{{ .Path }}'"

  provisioner_env = [
    "ANSIBLE_CONFIG=/tmp/ansible.cfg",
    "BUILD_USERNAME=${var.username}",
    "HARDENING_COLLECTION_VERSION=${var.hardening_collection_version}",
    "SUDO_PASSWORD=${var.password}",
    "SYFT_VERSION=${var.syft_version}",
  ]
}

source "azure-arm" "hardened" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  image_publisher = "canonical"
  image_offer     = var.image_offer
  image_sku       = var.image_sku
  os_type         = "Linux"
  vm_size         = var.vm_size

  build_resource_group_name          = var.resource_group
  managed_image_storage_account_type = var.managed_image_storage_account_type

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = local.image_name

  allowed_inbound_ip_addresses = ["${var.my_ip_address}/32"]

  ssh_username              = var.username
  ssh_clear_authorized_keys = true
  ssh_keep_alive_interval   = "15s"
  ssh_pty                   = true
  ssh_timeout               = "10m"
  temporary_key_pair_type   = "ed25519"
}

build {
  name    = "hardened-azure"
  sources = ["source.azure-arm.hardened"]

  provisioner "file" {
    sources     = ["config/ansible.cfg", "config/local.yml", "config/requirements.yml"]
    destination = "/tmp/"
  }

  provisioner "shell" {
    environment_vars  = local.provisioner_env
    execute_command   = local.sudo_command
    use_env_var_file  = true
    expect_disconnect = true
    pause_before      = "10s"
    remote_folder     = "/var/tmp"
    scripts = [
      "${path.root}/scripts/hardening.sh",
      "${path.root}/scripts/azure.sh",
      "${path.root}/scripts/sbom.sh",
    ]
  }

  provisioner "shell-local" {
    inline = ["mkdir -p '${local.build_dir}'"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/sbom.spdx.json"
    destination = "${local.build_dir}/${local.image_name}.spdx.json"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/sbom.cdx.json"
    destination = "${local.build_dir}/${local.image_name}.cdx.json"
  }

  provisioner "shell" {
    environment_vars  = local.provisioner_env
    execute_command   = local.sudo_command
    use_env_var_file  = true
    expect_disconnect = true
    pause_before      = "10s"
    remote_folder     = "/var/tmp"
    scripts           = ["${path.root}/scripts/cleanup.sh"]
  }

  error-cleanup-provisioner "shell" {
    environment_vars  = local.provisioner_env
    execute_command   = local.sudo_command
    use_env_var_file  = true
    expect_disconnect = true
    remote_folder     = "/var/tmp"
    scripts           = ["${path.root}/scripts/cleanup.sh"]
  }
}
