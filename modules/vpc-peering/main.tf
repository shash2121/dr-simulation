terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.accepter]
    }
  }
}

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  peer_region = var.accepter_region
  auto_accept = false

  tags = merge(var.tags, {
    Name = "${var.environment_name}-vpc-peering"
  })
}

resource "aws_vpc_peering_connection_accepter" "this" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true
}

resource "aws_route" "requester_to_accepter" {
  route_table_id            = var.requester_route_table_id
  destination_cidr_block    = var.accepter_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "requester_public_to_accepter" {
  route_table_id            = var.requester_public_route_table_id
  destination_cidr_block    = var.accepter_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter_to_requester" {
  provider                  = aws.accepter
  route_table_id            = var.accepter_route_table_id
  destination_cidr_block    = var.requester_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter_public_to_requester" {
  provider                  = aws.accepter
  route_table_id            = var.accepter_public_route_table_id
  destination_cidr_block    = var.requester_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
