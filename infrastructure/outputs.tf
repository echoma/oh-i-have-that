# 输出值定义
# 静态资源桶输出
output "cos_static_bucket_url" {
  description = "COS静态资源存储桶访问URL"
  value       = module.cos.static_bucket_url
}

output "cos_static_bucket_name" {
  description = "COS静态资源存储桶名称"
  value       = module.cos.static_bucket_name
}

output "website_endpoint" {
  description = "静态网站访问端点"
  value       = module.cos.website_endpoint
}

# 数据存储桶输出
output "cos_data_bucket_url" {
  description = "COS数据存储桶访问URL"
  value       = module.cos.data_bucket_url
}

output "cos_data_bucket_name" {
  description = "COS数据存储桶名称"
  value       = module.cos.data_bucket_name
}

# 兼容性输出（保持向后兼容）
output "cos_bucket_url" {
  description = "COS存储桶访问URL（兼容性输出，指向静态资源桶）"
  value       = module.cos.bucket_url
}

output "cos_bucket_name" {
  description = "COS存储桶名称（兼容性输出，指向静态资源桶）"
  value       = module.cos.bucket_name
}

output "scf_function_name" {
  description = "SCF函数名称"
  value       = module.scf.function_name
}

output "scf_function_id" {
  description = "SCF函数ID"
  value       = module.scf.function_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "子网ID"
  value       = module.network.subnet_id
}

output "clb_id" {
  description = "CLB实例ID"
  value       = module.clb.clb_id
}

output "clb_vip" {
  description = "CLB VIP地址"
  value       = module.clb.clb_vip
}

output "api_url" {
  description = "API访问URL (HTTP)"
  value       = module.clb.api_url
}

output "api_url_https" {
  description = "API访问URL (HTTPS)"
  value       = module.clb.api_url_https
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