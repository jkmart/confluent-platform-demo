# "timestamp" template function replacement
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}
variable "aws_access_key" {
  type = string
  default = ""
}

variable "aws_secret_key" {
  type = string
  default = ""
}
source "amazon-ebs" "base-ebs" {
  access_key = "${var.aws_access_key}"
  ami_name = "confluent-repo-6.0.1 ${local.timestamp}"
  instance_type = "t2.micro"
  region = "us-east-1"
  secret_key = "${var.aws_secret_key}"
  source_ami_filter {
    filters = {
      name = "RHEL-7*"
      root-device-type = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners = [
      "309956199498"]
  }
  ssh_username = "ec2-user"

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 20
}
}

build {
  sources = [
    "source.amazon-ebs.base-ebs"]

  provisioner "ansible" {
    use_proxy = false
    playbook_file = "ansible/confluent-repo.yml"
  }
}
