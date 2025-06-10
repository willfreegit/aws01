resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_as" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-ssh-access"
  description = "allow ssh"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
  key_name = aws_key_pair.example_key_pair.key_name

  tags = {
    Name = "example"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y python3 python3-pip
              sudo pip3 install ansible
  EOF
}

resource "tls_private_key" "example_ssh_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "example_key_pair" {
  key_name = "example"
  public_key = tls_private_key.example_ssh_key.public_key_openssh
}

resource "local_file" "example_private_key" {
  content = tls_private_key.example_ssh_key.private_key_pem
  filename = "example.pem"
  file_permission = "0400"
}

output "key_pair_name" {
  description = "Name of my kp"
  value = aws_key_pair.example_key_pair.key_name
}

output "private_key_file_path" {
  description = "path to my key"
  value = local_file.example_private_key.filename
}

output "instance_public_ip" {
  value = aws_instance.example.public_ip
}