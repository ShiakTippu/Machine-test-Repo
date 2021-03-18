/*======= VPC ==========*/
resource "aws_vpc" "my_vpc" {
	cidr_block = "10.0.0.0/16"
	enable_dns_hostnames = true
	enable_dns_support = true

}

/*=========subnets ======*/

#public subnet


#Internet Gateway
resource "aws_internet_gateway" "myig" {
	vpc_id = aws_vpc.my_vpc.id
}

# EIP for NAT

resource "aws_eip" "mynat_eip" {
	vpc = true
	depends_on = [aws_internet_gateway.myig]
}


/*======= NAT GW =====*/
resource "aws_nat_gateway" "mynatgw" {
	allocation_id = aws_eip.mynat_eip.id
	subnet_id = aws_subnet.app_subnet.id
	depends_on = [aws_internet_gateway.myig]

}

/*==== public subnet =====*/


resource "aws_subnet" "app_subnet" {
	vpc_id = aws_vpc.my_vpc.id
	availability_zone = "us-east-1a"
	cidr_block = "10.0.0.0/24"
	map_public_ip_on_launch = true
}

resource "aws_subnet" "db_subnet1" {
	vpc_id = aws_vpc.my_vpc.id
	availability_zone = "us-east-1b"
	cidr_block = "10.0.1.0/24"
	map_public_ip_on_launch = false
}

resource "aws_subnet" "db_subnet2" {
	vpc_id = aws_vpc.my_vpc.id
	availability_zone = "us-east-1c"
	cidr_block = "10.0.2.0/24"
	map_public_ip_on_launch = false
}


/*====routing table for private subnet ======*/
resource "aws_route_table" "private" {
	vpc_id = aws_vpc.my_vpc.id
}


/*======routing table for public subnet ==== */

resource "aws_route_table" "public" {
	vpc_id = aws_vpc.my_vpc.id
}


resource "aws_route" "public_internet_gateway" {
	route_table_id = aws_route_table.public.id
	destination_cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.myig.id
}

resource "aws_route" "private_nat_gateway" {
	route_table_id = aws_route_table.private.id
	destination_cidr_block = "0.0.0.0/0"
	gateway_id = aws_nat_gateway.mynatgw.id
}


resource "aws_route_table_association" "public" {
	subnet_id = aws_subnet.app_subnet.id
	route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
	subnet_id = aws_subnet.db_subnet1.id
	route_table_id = aws_route_table.private.id
}


resource "aws_route_table_association" "private2" {
	subnet_id = aws_subnet.db_subnet2.id
	route_table_id = aws_route_table.private.id
}

resource "aws_db_subnet_group" "dbsg" {
  name       = "main"
  subnet_ids = [ "${aws_subnet.db_subnet1.id}", "${aws_subnet.db_subnet2.id}"]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_security_group" "app_security_group" {
	vpc_id = aws_vpc.my_vpc.id
	name = "app security group"
	description = "app security group"

	ingress {
		from_port = 80
		to_port = 80
		protocol = "TCP"
		description = "any"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port = 443
		to_port = 443
		protocol = "TCP"
		description = "any"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port = 22
		to_port = 22
		protocol = "TCP"
		description = "any"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}
resource "aws_instance" "app1" {
	ami = "ami-038f1ca1bd58a5790"
	instance_type = "t2.micro"
	vpc_security_group_ids = [ "${aws_security_group.app_security_group.id}" ]
	subnet_id = "${aws_subnet.app_subnet.id}"
}

resource "aws_instance" "app2" {
	ami = "ami-038f1ca1bd58a5790"
	instance_type = "t2.micro"
	subnet_id = "${aws_subnet.app_subnet.id}"
	vpc_security_group_ids = [ "${aws_security_group.app_security_group.id}" ]
}


resource "aws_db_instance" "db" {
	allocated_storage = 10
	engine	= "mysql"
	engine_version = "5.7"
	instance_class = "db.t3.micro"
	name	= "mydb"
	username = "tippu"
	password = "tippu123"
	parameter_group_name = "default.mysql5.7"
	skip_final_snapshot  = true
	vpc_security_group_ids = [ "${aws_security_group.app_security_group.id}" ]
	db_subnet_group_name = "${aws_db_subnet_group.dbsg.id}"
}

resource "aws_s3_bucket" "stweb" {
	bucket = "tippumastans3bucket"
	acl = "public-read"
}
