# COS模块输出
# 静态资源桶输出
output "static_bucket_name" {
  description = "静态资源存储桶名称"
  value       = tencentcloud_cos_bucket.website.bucket
}

output "static_bucket_url" {
  description = "静态资源存储桶访问URL"
  value       = "https://${tencentcloud_cos_bucket.website.bucket}.cos.${var.region}.myqcloud.com"
}

output "website_endpoint" {
  description = "静态网站访问端点"
  value       = "https://${tencentcloud_cos_bucket.website.bucket}.cos-website.${var.region}.myqcloud.com"
}

output "static_bucket_domain_name" {
  description = "静态资源桶域名"
  value       = "${tencentcloud_cos_bucket.website.bucket}.cos.${var.region}.myqcloud.com"
}

# 数据存储桶输出
output "data_bucket_name" {
  description = "数据存储桶名称"
  value       = tencentcloud_cos_bucket.data.bucket
}

output "data_bucket_url" {
  description = "数据存储桶访问URL"
  value       = "https://${tencentcloud_cos_bucket.data.bucket}.cos.${var.region}.myqcloud.com"
}

output "data_bucket_domain_name" {
  description = "数据存储桶域名"
  value       = "${tencentcloud_cos_bucket.data.bucket}.cos.${var.region}.myqcloud.com"
}

# 兼容性输出（保持向后兼容）
output "bucket_name" {
  description = "COS存储桶名称（兼容性输出，指向静态资源桶）"
  value       = tencentcloud_cos_bucket.website.bucket
}

output "bucket_url" {
  description = "COS存储桶访问URL（兼容性输出，指向静态资源桶）"
  value       = "https://${tencentcloud_cos_bucket.website.bucket}.cos.${var.region}.myqcloud.com"
}

output "bucket_domain_name" {
  description = "存储桶域名（兼容性输出，指向静态资源桶）"
  value       = "${tencentcloud_cos_bucket.website.bucket}.cos.${var.region}.myqcloud.com"
}