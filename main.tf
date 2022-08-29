provider "aws" {
  region                  = "us-east-1"
  access_key              = var.access_key
  secret_key              = var.secret_key  
}

resource "tls_private_key" "private-key" {
  algorithm   = "RSA"
  rsa_bits    = 2048
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key-win"
  public_key = tls_private_key.private-key.public_key_openssh
}

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

resource "aws_security_group" "student-sg-win" {
  name = "Hello-World-SG-win"
  description = "Student security group"

  tags = {
    Name = "Hello-World-SG-win"
    Environment = terraform.workspace
  }
}

resource "aws_security_group_rule" "create-sgr-ssh" {
  security_group_id = aws_security_group.student-sg-win.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-inbound" {
  security_group_id = aws_security_group.student-sg-win.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-outbound" {
  security_group_id = aws_security_group.student-sg-win.id
  cidr_blocks         = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "egress"
}

resource "aws_instance" "webwin" {
  count         = 2 
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = ["Hello-World-SG-win"]
  tags = {
    Name = "Webwin${count.index}"
  }
}

resource "null_resource" "control-node" {
    depends_on = [aws_instance.webwin]
  
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.private-key.private_key_pem
      host        = aws_instance.webwin.*.public_dns[0]
    }
    provisioner "local-exec" {
      command = "echo '${tls_private_key.private-key.private_key_pem}' > ~/Desktop/studentwin.pem && chmod 600 ~/Desktop/studentwin.pem "
    }
    provisioner "remote-exec" {
      inline = [
        "sudo apt-get update -y",
	"sudo apt install python3-pip -y",
        "sudo apt install ansible -y",
        "echo '[ciservers]' > ~/hosts",
        "echo '${aws_instance.webwin.*.public_dns[1]}' >> ~/hosts",
        "echo '${tls_private_key.private-key.private_key_pem}' > ~/.ssh/studentwin.pem && chmod 600 ~/.ssh/studentwin.pem",
        "sudo sed -i '71s/.*/host_key_checking = False/' /etc/ansible/ansible.cfg"        
      ]
    }

    
}
