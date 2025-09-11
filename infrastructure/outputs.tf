# 输出值定义
output "cos_bucket_url" {
  description = "COS存储桶访问URL"
  value       = module.cos.bucket_url
}

output "cos_bucket_name" {
  description = "COS存储桶名称"
  value       = module.cos.bucket_name
}

output "scf_function_name" {
  description = "SCF函数名称"
  value       = module.scf.function_name
}

output "scf_trigger_url" {
  description = "SCF触发器URL"
  value       = module.scf.trigger_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "子网ID"
  value       = module.network.subnet_id
}

output "container_registry_url" {
  description = "容器注册表URL"
  value       = module.container_registry.registry_url
}

output "image_uris" {
  description = "所有应用的镜像URI"
  value       = module.container_registry.image_uris
}

output "repositories" {
  description = "镜像仓库信息"
  value       = module.container_registry.repositories
}