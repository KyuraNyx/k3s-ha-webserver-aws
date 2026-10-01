provider "aws" {
  region = "us-east-1"
}

# -----------------------------------------------------------------
# Mencari AMI Ubuntu 24.04 terbaru secara otomatis
# -----------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# -----------------------------------------------------------------
# Mendaftarkan SSH Public Key laptop ke AWS
# -----------------------------------------------------------------
resource "aws_key_pair" "kunci_proyek" {
  key_name   = "kunci-otomatis-ass"
  public_key = file("~/.ssh/id_rsa.pub")
}

# -----------------------------------------------------------------
# Security Group: mengatur aturan akses jaringan ke semua node
# -----------------------------------------------------------------
resource "aws_security_group" "sg_proyek" {
  name        = "sg_proyek_ass"
  description = "Izinkan akses HTTP, SSH, dan Komunikasi Internal Klaster"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (Load Balancer)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nginx NodePort (K3s)
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Komunikasi internal antar semua node dalam klaster
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Semua trafik keluar diizinkan
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------------------------
# Node 1: Load Balancer (HAProxy)
# -----------------------------------------------------------------
resource "aws_instance" "load_balancer" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.kunci_proyek.key_name
  vpc_security_group_ids = [aws_security_group.sg_proyek.id]
  tags                   = { Name = "Node-LoadBalancer" }
}

# -----------------------------------------------------------------
# Node 2: Kubernetes Master (K3s Server)
# -----------------------------------------------------------------
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.kunci_proyek.key_name
  vpc_security_group_ids = [aws_security_group.sg_proyek.id]
  tags                   = { Name = "Node-Master" }
}

# -----------------------------------------------------------------
# Node 3: Kubernetes Worker 1 (K3s Agent) + EBS Volume LVM
# -----------------------------------------------------------------
resource "aws_instance" "worker1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.kunci_proyek.key_name
  vpc_security_group_ids = [aws_security_group.sg_proyek.id]
  tags                   = { Name = "Node-Worker-1" }

  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_size = 5
    volume_type = "gp3"
  }
}

# -----------------------------------------------------------------
# Node 4: Kubernetes Worker 2 (K3s Agent) + EBS Volume LVM
# -----------------------------------------------------------------
resource "aws_instance" "worker2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.kunci_proyek.key_name
  vpc_security_group_ids = [aws_security_group.sg_proyek.id]
  tags                   = { Name = "Node-Worker-2" }

  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_size = 5
    volume_type = "gp3"
  }
}

# -----------------------------------------------------------------
# Output: Menampilkan IP publik setiap node setelah deployment
# -----------------------------------------------------------------
output "ip_load_balancer" { value = aws_instance.load_balancer.public_ip }
output "ip_master"        { value = aws_instance.master.public_ip }
output "ip_worker1"       { value = aws_instance.worker1.public_ip }
output "ip_worker2"       { value = aws_instance.worker2.public_ip }
