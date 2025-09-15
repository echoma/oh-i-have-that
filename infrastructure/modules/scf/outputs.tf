# SCF模块输出
output "function_name" {
  description = "SCF函数名称"
  value       = tencentcloud_scf_function.main.name
}

output "function_id" {
  description = "SCF函数ID"
  value       = tencentcloud_scf_function.main.id
}

output "logset_id" {
  description = "CLS日志集ID"
  value       = tencentcloud_cls_logset.scf.id
}

output "topic_id" {
  description = "CLS日志主题ID"
  value       = tencentcloud_cls_topic.scf.id
}