#us-east-1 vpc
resource "aws_vpc" "main_vpc" {
  provider             = aws.region-main
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main_vpc_jenkins"
  }
}

#us-west-1 vpc
resource "aws_vpc" "secondary_vpc" {
  provider             = aws.region-secondary
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "secondary_vpc_jenkins"
  }
}

#us-east-1 internet gateway
resource "aws_internet_gateway" "igw-east" {
  provider = aws.region-main
  vpc_id   = aws_vpc.main_vpc.id
}

#us-west-1 internet gateway
resource "aws_internet_gateway" "igw-west" {
  provider = aws.region-secondary
  vpc_id   = aws_vpc.secondary_vpc.id
}

#get available AZ's in main region
data "aws_availability_zones" "azs-east" {
  provider = aws.region-main
  state    = "available"
}

#create subnet #1 in main vpc
resource "aws_subnet" "subnet_1_east" {
  provider          = aws.region-main
  availability_zone = element(data.aws_availability_zones.azs-east.names, 0)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
}


#create subnet #2 in main vpc
resource "aws_subnet" "subnet_2_east" {
  provider          = aws.region-main
  availability_zone = element(data.aws_availability_zones.azs-east.names, 1)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
}

#create subnet for west vpc
resource "aws_subnet" "subnet_1_west" {
  provider   = aws.region-secondary
  vpc_id     = aws_vpc.secondary_vpc.id
  cidr_block = "192.168.1.0/24"
}

#peering request from us-east-1
resource "aws_vpc_peering_connection" "useast1-uswest2" {
  provider    = aws.region-main
  peer_vpc_id = aws_vpc.secondary_vpc.id
  vpc_id      = aws_vpc.main_vpc.id
  peer_region = var.region-secondary
}

#accept peering in us-west-2
resource "aws_vpc_peering_connection_accepter" "accept_peering" {
  provider                  = aws.region-secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
  auto_accept               = true
}

#create route table in us-east-1
resource "aws_route_table" "internet_route" {
  provider = aws.region-main
  vpc_id   = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-east.id
  }
  route {
    cidr_block                = "192.168.1.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Main-Region-RT"
  }
}

#vverwrite default route table of main vpc with route table entries
resource "aws_main_route_table_association" "set-master-default-rt-assoc" {
  provider       = aws.region-main
  vpc_id         = aws_vpc.main_vpc.id
  route_table_id = aws_route_table.internet_route.id
}

#create route table in us-west-2
resource "aws_route_table" "internet_route_west" {
  provider = aws.region-secondary
  vpc_id   = aws_vpc.secondary_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-west.id
  }
  route {
    cidr_block                = "10.0.1.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Secondary-Region-RT"
  }
}

#Overwrite default route table of secondary vpc with route table entries
resource "aws_main_route_table_association" "set-worker-default-rt-assoc" {
  provider       = aws.region-secondary
  vpc_id         = aws_vpc.secondary_vpc.id
  route_table_id = aws_route_table.internet_route_west.id
}
