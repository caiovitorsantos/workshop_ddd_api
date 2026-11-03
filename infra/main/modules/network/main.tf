# VPC with two public and two private subnets across two AZs (EKS and RDS
# both require subnets in at least two AZs).
#
# ponytail: no NAT Gateway. The nodes live in the public subnets (public IP,
# straight to the Internet Gateway) so they can pull images from ECR; the
# private subnets hold only RDS, which needs no Internet at all. A NAT is the
# priciest hourly item in an AWS Academy budget and may not even be allowed.
# Upgrade path: NAT + nodes in the private subnets.
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${var.azs[count.index]}"
    # Where Kubernetes places internet-facing load balancers
    # (the API's Service type LoadBalancer).
    "kubernetes.io/role/elb" = "1"
  }
}

# No route to the Internet: the VPC's main route table only has the local
# route, and these subnets are not associated with the public one.
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 101) # 10.0.101.0/24, 10.0.102.0/24
  availability_zone = var.azs[count.index]

  tags = { Name = "${var.name}-private-${var.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
