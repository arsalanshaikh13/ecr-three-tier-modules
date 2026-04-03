
#---------------------------------------------
#  NAT Gateway Setup
#---------------------------------------------
data "aws_availability_zones" "available_zones" {} 

# create private app subnet pri-sub-3a
resource "aws_subnet" "pri_sub_3a" {
  vpc_id                   = var.vpc_id
  cidr_block               = var.pri_sub_3a_cidr
  availability_zone        = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch  = false

  tags      = {
    Name    = "pri-sub-3a"
  }
}

# create private app pri-sub-4b
resource "aws_subnet" "pri_sub_4b" {
  vpc_id                   = var.vpc_id
  cidr_block               = var.pri_sub_4b_cidr
  availability_zone        = data.aws_availability_zones.available_zones.names[1]
  map_public_ip_on_launch  = false

  tags      = {
    Name    = "pri-sub-4b"
  }
}

# Creating route table for vpc endpoint for vpc flow logs
# create private route table Pri-RT-A and add route through NAT-GW-A
resource "aws_route_table" "pri-rt-a" {
  vpc_id            = var.vpc_id

  # route {
  #   cidr_block      = "0.0.0.0/0"
  #   # nat_gateway_id  = aws_nat_gateway.nat-a.id
  #   network_interface_id   = aws_instance.nat_ec2_instance.primary_network_interface_id
  # }

  tags   = {
    Name = "Pri-rt-a"
  }
}

# NAT GATEWAY setup
# Web tier
# associate private subnet pri-sub-3-a with private route table Pri-RT-A
resource "aws_route_table_association" "pri-sub-3a-with-Pri-rt-a" {
  subnet_id         = aws_subnet.pri_sub_3a.id
  route_table_id    = aws_route_table.pri-rt-a.id
}

# associate private subnet pri-sub-4b with private route table Pri-rt-b
resource "aws_route_table_association" "pri-sub-4b-with-Pri-rt-b" {
  subnet_id         = aws_subnet.pri_sub_4b.id
  route_table_id    = aws_route_table.pri-rt-a.id
}

# allocate elastic ip. this eip will be used for the nat-gateway in the public subnet pub-sub-1-a
resource "aws_eip" "eip-nat-a" {
  # vpc    = true

  tags   = {
    Name = "eip-nat-a"
  }
}


# create nat gateway in public subnet pub-sub-1a
resource "aws_nat_gateway" "nat-a" {
  allocation_id = aws_eip.eip-nat-a.id
  subnet_id     = var.pub_sub_1a_id

  tags   = {
    Name = "nat-a"
  }

}


##########################################
# Route Table Configuration
##########################################

# # Add route for private subnet traffic through NAT instance
resource "aws_route" "nat_ec2_route" {
    route_table_id         = aws_route_table.pri-rt-a.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id   = aws_nat_gateway.nat-a.id
}

