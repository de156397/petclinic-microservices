//This Terraform Template creates a Nexus server on AWS EC2 Instance
//Nexus server will run on Amazon Linux 2 with custom security group
//allowing SSH (22) and TCP (8081) connections from anywhere.


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_instance" "tf-nexus-server" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.mykey
  vpc_security_group_ids = [aws_security_group.tf-nexus-sec-gr.id]
  tags = {
    Name = var.nexus-server-tag
  }
  user_data = <<-EOF
  #! /bin/bash -x
  # update os
  yum update -y
  # set server hostname as nexus-server
  hostnamectl set-hostname nexus-server
  # install docker
  yum install docker -y
  # start docker
  systemctl start docker
  # enable docker service
  systemctl enable docker
  # add ec2-user to docker group
  usermod -aG docker ec2-user
  newgrp docker
  # create a docker volume for nexus persistent data
  docker volume create --name nexus-data
  # run the nexus container
  docker run -d -p 8081:8081 --name nexus -v nexus-data:/nexus-data sonatype/nexus3
  EOF
}


resource "null_resource" "forpasswd" {
  depends_on = [aws_instance.tf-nexus-server]

  provisioner "local-exec" {
    command = "sleep 3m"
  }

  # Do not forget to define your key file path correctly!
  provisioner "local-exec" {
    command = "ssh -i ~/.ssh/${var.mykey}.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@${aws_instance.tf-nexus-server.public_ip} 'docker cp nexus:/nexus-data/admin.password  admin.password && cat /home/ec2-user/admin.password' > initialpasswd.txt"
  }
}



resource "aws_security_group" "tf-nexus-sec-gr" {
  name = var.nexus_server_secgr
  tags = {
    Name = var.nexus_server_secgr
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8081
    to_port     = 8081
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8081
    to_port     = 8081
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "nexus" {
  value = "http://${aws_instance.tf-nexus-server.public_ip}:8081"
}
