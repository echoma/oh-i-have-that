# CLB模块输出
output "clb_id" {
  description = "CLB实例ID"
  value       = tencentcloud_clb_instance.main.id
}

output "clb_vip" {
  description = "CLB VIP地址"
  value       = tencentcloud_clb_instance.main.clb_vips[0]
}

output "clb_domain" {
  description = "CLB域名"
  value       = tencentcloud_clb_instance.main.domain
}

output "http_listener_id" {
  description = "HTTP监听器ID"
  value       = tencentcloud_clb_listener.http.listener_id
}

output "https_listener_id" {
  description = "HTTPS监听器ID"
  value       = var.ssl_certificate_id != "" ? tencentcloud_clb_listener.https[0].listener_id : null
}

output "api_url" {
  description = "API访问URL"
  value       = "http://${tencentcloud_clb_instance.main.clb_vips[0]}/api"
}

output "api_url_https" {
  description = "API HTTPS访问URL"
  value       = var.ssl_certificate_id != "" ? "https://${tencentcloud_clb_instance.main.clb_vips[0]}/api" : null
}