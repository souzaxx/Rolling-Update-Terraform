source "amazon-ebs" "main" {
  ami_name = "rolling_update_{{timestamp}}"
  region   = "us-east-2"

  spot_instance_types = ["t3.small", "t3.medium", "t3.large"]
  spot_price          = "auto"

  source_ami_filter {
    filters = {
      virtualization-type  = "hvm"
      name = "amzn2-ami-hvm-2.0.*-x86_64-gp2"
      root-device-type = "ebs"
    }
    owners = ["amazon"]
    most_recent = true
  }

  communicator = "ssh"
  ssh_username = "ec2-user"

  vpc_filter {
    filters = {
      isDefault = true
    }
  }

  subnet_filter {
    random = false
  }
}

build {
  name = "rolling_update_{{timestamp}}"

  sources = [
    "source.amazon-ebs.main"
  ]

  provisioner "shell" {
    script = "scripts/basic-website.sh"
    environment_vars = [
      "COLOR=${var.color}",
    ]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }
}
