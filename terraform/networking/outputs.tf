output "vpc_id" {
  value = aws_vpc.cloud_siwe_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.cloud_siwe_private_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.cloud_siwe_public_subnet.id
}
