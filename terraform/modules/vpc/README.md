# Module: vpc

Provisions the main application VPC (lks-vpc) with all networking components.

## Resources to create

- `aws_vpc` — lks-vpc, CIDR 10.0.0.0/16, DNS enabled
- `aws_subnet` × 6 — public (×2), private (×2), isolated (×2) across two AZs
- `aws_internet_gateway` — lks-igw, attached to lks-vpc
- `aws_eip` — Elastic IP for the NAT Gateway
- `aws_nat_gateway` — lks-nat-gw, placed in public subnet us-east-1a
- `aws_route_table` × 3 — public-rt, private-rt, isolated-rt
- `aws_route` — 0.0.0.0/0 → IGW (public), 0.0.0.0/0 → NAT (private)
- `aws_route_table_association` × 6 — one per subnet

## Required inputs

| Variable | Type | Description |
|---|---|---|
| `vpc_name` | string | Name tag for the VPC |
| `vpc_cidr` | string | CIDR block, e.g. "10.0.0.0/16" |
| `public_subnet_cidrs` | list(string) | Two CIDR blocks |
| `private_subnet_cidrs` | list(string) | Two CIDR blocks |
| `isolated_subnet_cidrs` | list(string) | Two CIDR blocks |
| `availability_zones` | list(string) | ["us-east-1a", "us-east-1b"] |

## Required outputs

| Output | Description |
|---|---|
| `vpc_id` | Used by almost every other module |
| `public_subnet_ids` | Used by ALB module |
| `private_subnet_ids` | Used by ECS module |
| `isolated_subnet_ids` | Used by database module |
| `private_route_table_id` | Used by vpc_peering module |
