# 容器注册表模块输出（CCR个人版）
output "registry_url" {
  description = "CCR个人版镜像仓库URL"
  value       = local.registry_url
}

output "image_uris" {
  description = "所有应用的镜像URI映射"
  value       = local.image_uris
}

output "repositories" {
  description = "镜像仓库信息"
  value       = local.repositories
}

output "namespace_name" {
  description = "命名空间名称（需要在CCR控制台手动创建）"
  value       = var.project_name
}

# CCR个人版使用说明
output "ccr_setup_instructions" {
  description = "CCR个人版设置说明"
  value = {
    step1 = "完成腾讯云实名认证"
    step2 = "访问容器镜像服务控制台: https://console.cloud.tencent.com/tke2/registry"
    step3 = "创建命名空间: ${var.project_name}"
    step4 = "创建镜像仓库: ${join(", ", var.app_names)}"
    note  = "CCR个人版免费使用，完成实名认证后即可使用"
  }
}