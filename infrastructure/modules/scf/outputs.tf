# SCF模块输出
output "function_name" {
  description = "SCF函数名称"
  value       = tencentcloud_scf_function.main.name
}

output "function_arn" {
  description = "SCF函数ARN"
  value       = "qcs::scf:${var.region}:uin/${data.tencentcloud_user_info.current.uin}:function:${tencentcloud_scf_function.main.name}"
}

output "api_gateway_service_id" {
  description = "API网关服务ID"
  value       = tencentcloud_api_gateway_service.main.id
}

output "api_gateway_api_id" {
  description = "API网关API ID"
  value       = tencentcloud_api_gateway_api.main.id
}

output "trigger_url" {
  description = "API网关触发器URL"
  value       = local.api_gateway_url
}

output "api_gateway_url" {
  description = "API网关访问URL"
  value       = local.api_gateway_url
}

output "cls_logset_id" {
  description = "CLS日志集ID"
  value       = tencentcloud_cls_logset.scf.id
}

output "cls_topic_id" {
  description = "CLS日志主题ID"
  value       = tencentcloud_cls_topic.scf.id
}