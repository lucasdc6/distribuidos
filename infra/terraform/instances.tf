data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "SSH from VPC my IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.ip_ingress_ips
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "server" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Network
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [
    aws_security_group.ssh.id
  ]
  
  # Auth
  key_name = var.key_name

  tags = {
    Name = format("distribuidos-%02d", count.index + 1)
  }

}

resource "local_file" "ansible_hosts" {
  content  = templatefile(
    "${path.module}/templates/ansible_hosts.yaml.tpl",
    {
      ips = "${aws_instance.server[*].public_ip}"
    }
  )
  filename        = "${path.cwd}/../ansible/hosts.yaml"
  file_permission = "0644"
}

output "public_ips" {
  value = aws_instance.server[*].public_ip
}