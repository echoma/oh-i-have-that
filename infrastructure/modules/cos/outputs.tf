# COS模块输出
output "bucket_name" {
  description = "COS存储桶名称"
  value       = tencentcloud_cos_bucket.website.bucket
}

output "bucket_url" {
  description = "COS存储桶访问URL"
  value       = "https://${tencentcloud_cos_bucket.website.bucket}.cos.${var.region}.myqcloud.com"
}

output "website_endpoint" {
  description = "静态网站访问端点"
  value       = "https://${tencentcloud_cos_bucket.website.bucket}.cos-website.${var.region}.myqcloud.com"
}

output "bucket_domain_name" {
  description = "存储桶域名"
  value       = "${tencentcloud_cos_bucket.website.bucket}.cos.${var.region}.myqcloud.com"
}