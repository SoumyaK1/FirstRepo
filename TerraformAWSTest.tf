provider "aws" {
	access_key = ""
	secret_key = ""
 	region = "ap-south-1"
}



resource "aws_vpc" "terra_vpc" {
	cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "terra_igw" {
	vpc_id = aws_vpc.terra_vpc.id
}

resource "aws_subnet" "lab_subnet1" {
  
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  vpc_id            = aws_vpc.terra_vpc.id
  tags = {
    Name = "new Subnet-1"
  }
}

resource "aws_subnet" "lab_subnet2" {
  
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  vpc_id            = aws_vpc.terra_vpc.id
  tags = {
    Name = "new Subnet-2"
  }
}

resource "aws_security_group" "first-ssh-http" {
	name = "first-ssh-http"
	description = "allow ssh and http traffic"
    vpc_id            = aws_vpc.terra_vpc.id

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]		
	}

	ingress{
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_instance" "Instance-with-volume" {
	ami = "ami-0940d6aae6fdb0ea6"
	instance_type = "t2.micro"
	availability_zone = "ap-south-1a"
    #security_groups = ["${aws_security_group.first-ssh-http.name}"]
	vpc_security_group_ids = [aws_security_group.first-ssh-http.id]
    subnet_id = aws_subnet.lab_subnet1.id
	key_name = "first"
	tags = {
		Name = "Instance-with-volume"
	}
}
#creating and attchoing EBS volume

resource "aws_ebs_volume" "data-vol" {
	availability_zone = "ap-south-1a"
	size = 1
	tags = {
		Name = "data-volume"
	}

}

resource "aws_volume_attachment" "first-vol" {
	device_name = "/dev/sdc"
	volume_id = aws_ebs_volume.data-vol.id
	instance_id = aws_instance.Instance-with-volume.id
	#skip_destroy = true

}

resource "aws_eip" "default" {
    instance = aws_instance.Instance-with-volume.id
    vpc      = true
}

data "aws_availability_zones" "all" {}


resource "aws_lb_target_group" "tg1" {
  name     = "FirstTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terra_vpc.id
}

resource "aws_lb_target_group_attachment" "TGAttachment1" {
  target_group_arn = aws_lb_target_group.tg1.arn
  target_id        = aws_instance.Instance-with-volume.id
  port             = 80
}

resource "aws_lb" "lb1" {
  name               = "FirstLB"
  internal           = false
  load_balancer_type = "application"
  ip_address_type = "ipv4"
  security_groups    = [aws_security_group.first-ssh-http.id]
  subnets            = [aws_subnet.lab_subnet1.id, aws_subnet.lab_subnet2.id]

  tags = {
    Name = "my-elb1"
  }
}

resource "aws_lb_listener" "elbListen" {
  load_balancer_arn = aws_lb.lb1.arn
  port              = "80"
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg1.arn
  }
}