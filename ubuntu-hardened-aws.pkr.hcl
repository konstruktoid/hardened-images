variable "aws_region" {
  description = "The AWS Region to use."
  type        = string
}

variable "instance_type" {
  description = "The Amazon EC2 Instance Type to use."
  type        = string
}

variable "release" {
  description = "The Ubuntu release to use, YY-MM format."
  type        = string
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "hardened" {
  ami_name      = "hardened-ubuntu-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/*ubuntu-*${var.release}-amd64-server*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_clear_authorized_keys = "true"
  ssh_keep_alive_interval   = "15s"
  ssh_pty                   = "true"
  ssh_timeout               = "10m"
  ssh_username              = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.hardened"]

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
      "${path.root}/scripts/aws.sh"
    ]
  }
}
