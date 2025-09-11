# 网络模块输出
output "vpc_id" {
  description = "VPC ID"
  value       = tencentcloud_vpc.main.id
}

output "subnet_id" {
  description = "子网ID"
  value       = tencentcloud_subnet.main.id
}

output "security_group_id" {
  description = "安全组ID"
  value       = tencentcloud_security_group.scf.id
}

output "availability_zone" {
  description = "可用区"
  value       = data.tencentcloud_availability_zones.available.zones[0].name
}