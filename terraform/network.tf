resource "aws_vpc" "main_network" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "s3-vector-test-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_network.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "s3-vector-test-public-subnet"
    Type = "Public"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main_network.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "s3-vector-test-private-subnet"
    Type = "Private"
  }
}

resource "aws_security_group" "lambda" {
  name        = "lambda_search_sg"
  description = "Security group for Lambda in private subnet"
  vpc_id      = aws_vpc.main_network.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-search-sg"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main_network.id

  tags = {
    Name = "s3-vector-test-private-rt"
    Type = "Private"
  }
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main_network.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "s3-gateway-endpoint"
  }
}

resource "aws_security_group" "bedrock_endpoint" {
  name        = "bedrock_endpoint_sg"
  description = "Security group for Bedrock interface endpoint"
  vpc_id      = aws_vpc.main_network.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bedrock-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = aws_vpc.main_network.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet.id]
  security_group_ids  = [aws_security_group.bedrock_endpoint.id]
  private_dns_enabled = true
  

  tags = {
    Name = "bedrock-interface-endpoint"
  }
}