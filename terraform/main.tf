terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Adding tags for easy search within the AWS console
locals {
  tags = {
    Group = "confluent"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Use a VPC
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Provide a security group that can optionally allow specific traffic into the cluster.
data "aws_security_group" "selected" {
  vpc_id = data.aws_vpc.selected.id
  id     = var.sg_id
}

# Using the latest RHEL 7 image
data "aws_ami" "base" {
  most_recent = true

  filter {
    name = "name"
    values = [
      "RHEL-7*"
    ]
  }

  filter {
    name = "virtualization-type"
    values = [
      "hvm"
    ]
  }

  owners = [
    "309956199498"
  ]
}

resource "aws_security_group" "confluent-sg" {

  vpc_id = data.aws_vpc.selected.id

  # Allow inbound traffic within the security group
  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    self      = true
  }

  # Allow outbound traffic within the security group
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Uncomment to enable external network access
  //  egress {
  //    from_port   = 0
  //    to_port     = 0
  //    protocol    = "-1"
  //    cidr_blocks = ["0.0.0.0/0"]
  //  }
}

resource "aws_instance" "data_blade" {
  count         = 9
  ami           = data.aws_ami.base.id
  instance_type = "t3.large"
  vpc_security_group_ids = [
    aws_security_group.confluent-sg.id,
    data.aws_security_group.selected.id
  ]
  key_name = var.key_name

  tags = merge(local.tags, {
    Name = "data-${count.index}"
  })

  # Removing all extra repos files. If not removed, these time out and will fail the cp-ansible run if attempting an offline installation.
  provisioner "remote-exec" {
    connection {
      host        = self.public_dns
      user        = "ec2-user"
      type        = "ssh"
      private_key = file(var.private_key_path)
    }
    inline = [
      "sudo rm /etc/yum.repos.d/*.repo*"
    ]
  }
}

resource "aws_instance" "util_blade" {
  count         = 3
  ami           = data.aws_ami.base.id
  instance_type = "t3.large"
  vpc_security_group_ids = [
    aws_security_group.confluent-sg.id,
    data.aws_security_group.selected.id
  ]
  key_name = var.key_name

  tags = merge(local.tags, {
    Name = "util-${count.index}"
  })

  # Removing all extra repos files. If not removed, these time out and will fail the cp-ansible run if attempting an offline installation.
  provisioner "remote-exec" {
    connection {
      host        = self.public_dns
      user        = "ec2-user"
      type        = "ssh"
      private_key = file(var.private_key_path)
    }
    inline = [
      "sudo rm /etc/yum.repos.d/*.repo*"
    ]
  }
}

# To simulate an offline setup, the below image and instance act as a YUM repository and webserver for use during
# cp-ansible playbook runs.
data "aws_ami" "repo" {
  most_recent = true

  filter {
    name = "name"
    values = [
      # This is the naming convention used for the custom AMI created using Packer.
      "confluent-repo-6.0.1*"
    ]
  }

  filter {
    name = "virtualization-type"
    values = [
      "hvm"
    ]
  }

  owners = [
    "self"
  ]
}

resource "aws_instance" "satellite" {
  count         = 1
  ami           = data.aws_ami.repo.id
  instance_type = "t3.small"
  vpc_security_group_ids = [
    aws_security_group.confluent-sg.id,
    data.aws_security_group.selected.id
  ]
  key_name = var.key_name

  tags = merge(local.tags, {
    Name = "repo-${count.index}"
  })
}

# This the custom YUM repo file to be used during cp-ansible run, which is set using the custom repository_configuration
# and custom_yum_repofile_filepath: local.repo variables
resource "local_file" "local_repo" {
  count    = length(aws_instance.satellite) > 0 ? 1 : 0
  filename = "local.repo"
  content = templatefile("${path.module}/local.repo.tpl", {
    repo_url = "http://${aws_instance.satellite[count.index].public_dns}/repos/"
  })
}

# Create a Ansible inventory file hosts.yml for the cp-ansible playbook.
resource "local_file" "inventory" {
  # dependent on local_repo when using offline RPM install
  count      = length(local_file.local_repo)
  depends_on = [local_file.local_repo]

  filename = "hosts.yml"
  content = templatefile("${path.module}/hosts.yml.tpl", {
    private_key_path = var.private_key_path,

    # Note: Using only public_dns for non-TLS setup
    zookeepers = zipmap(range(length(aws_instance.util_blade)), aws_instance.util_blade.*.public_dns)

    brokers = [
      aws_instance.data_blade[0].public_dns,
      aws_instance.data_blade[2].public_dns,
      aws_instance.data_blade[3].public_dns,
      aws_instance.data_blade[5].public_dns,
      aws_instance.data_blade[6].public_dns
    ]

    schema_registries = [
      aws_instance.util_blade[1].public_dns,
      aws_instance.util_blade[2].public_dns
    ]

    connector_download_url = "http://${aws_instance.satellite[count.index].public_dns}/confluent"

    bootstrap_servers = join(",", formatlist("%s:9092", [
      aws_instance.data_blade[0].public_dns,
      aws_instance.data_blade[2].public_dns,
      aws_instance.data_blade[3].public_dns,
      aws_instance.data_blade[5].public_dns,
      aws_instance.data_blade[6].public_dns
    ]))

    connect_syslog = [
      aws_instance.util_blade[0].public_dns,
      aws_instance.util_blade[1].public_dns,
      aws_instance.util_blade[2].public_dns
    ]


    kafka_rest = [
      aws_instance.data_blade[1].public_dns,
      aws_instance.data_blade[8].public_dns
    ]

    ksql_syslog = [
      aws_instance.data_blade[1].public_dns,
      aws_instance.data_blade[4].public_dns,
      aws_instance.data_blade[7].public_dns
    ]

    control_center = [aws_instance.data_blade[8].public_dns]

  })
}
