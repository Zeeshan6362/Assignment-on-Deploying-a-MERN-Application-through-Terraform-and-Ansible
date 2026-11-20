output "vpc_id" {
  description = "ID of the TravelMemory VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet for the web server."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet for the database server."
  value       = aws_subnet.private.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway used for private subnet egress."
  value       = aws_nat_gateway.main.id
}

output "web_public_ip" {
  description = "Public IPv4 address of the TravelMemory web server."
  value       = aws_instance.web.public_ip
}

output "web_public_dns" {
  description = "Public DNS name of the TravelMemory web server."
  value       = aws_instance.web.public_dns
}

output "database_private_ip" {
  description = "Private IPv4 address of the MongoDB server."
  value       = aws_instance.database.private_ip
}
