
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.virginia, aws.oregon]
    }
  }
}


resource "aws_vpc_peering_connection" "this" {
  provider    = aws.virginia
  vpc_id      = var.virginia_vpc_id
  peer_vpc_id = var.oregon_vpc_id
  peer_region = "us-west-2"

  tags = {
    Name = "pcx-lks-2026"
  }
}

resource "aws_vpc_peering_connection_accepter" "this" {
  provider                  = aws.oregon
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true

  tags = {
    Name = "pcx-lks-2026"
  }
}


resource "aws_route" "virginia_to_oregon" {
  provider                  = aws.virginia
  route_table_id            = var.virginia_private_route_table_id
  destination_cidr_block    = var.oregon_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}


resource "aws_route" "oregon_to_virginia" {
  provider                  = aws.oregon
  route_table_id            = var.oregon_private_route_table_id
  destination_cidr_block    = var.virginia_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}
