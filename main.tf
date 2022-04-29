provider "aws" {
  region = "us-east-2"
}

terraform {
   backend "s3" {
      bucket = "vedre1"  
      key    = "gitaction/terraform.tfstate"
      region = "us-east-2"
   }
}

resource "aws_vpc" "vpc1" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  tags = {
    Name = "vpc1"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "192.168.2.0/24"
  tags = {
    Name = "private"
  }
}

resource "aws_default_route_table" "test" {
  default_route_table_id = aws_vpc.vpc1.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "test"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "rt"
  }
}

resource "aws_route_table_association" "public-rt" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_default_route_table.test.id
}


resource "aws_route_table_association" "private-rt" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "gw"
  }
}

resource "aws_security_group" "sg" {
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sg"
  }
}

resource "aws_instance" "mysql" {
  ami                         = "ami-0fb653ca2d3203ac1"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.sg.id}"]
  key_name = "testkanan"
  
  connection {
    type = "ssh"
    host = self.public_ip
    user = "ubuntu"
    private_key = file("./testkanan.pem")
  }

  provisioner "file" {
    source = "user.sql"
    destination = "/home/ubuntu/user.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt install mysql-server -y",
      "sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo service mysql restart",
      "sudo mysql < user.sql",
    ]
  }

  }

resource "aws_instance" "app" {
  ami                         = "ami-0fb653ca2d3203ac1"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.sg.id}"] 
  key_name = "testkanan"

  connection {
    type = "ssh"
    host = self.public_ip
    user = "ubuntu"
    private_key = file("./testkanan.pem")
  }

  provisioner "remote-exec" { 
    inline = [
      "sudo apt update -y",
      "sudo apt upgrade -y",
      "sudo apt install default-jre -y",
      "sudo apt install maven -y",
      "sudo apt install git -y",
      "git clone https://github.com/ibrahimovkanan/spring-petclinic.git",
      "cd spring-petclinic",
      "sudo sed -i 's/localhost/${aws_instance.mysql.private_ip}/g' src/main/resources/application-mysql.properties",
      "mvn spring-boot:run -Dspring-boot.run.profiles=mysql",
    ]
    
  }
}

