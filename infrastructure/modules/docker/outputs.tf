# Docker构建模块输出
output "built_images" {
  description = "已构建的镜像列表"
  value       = var.app_names
}

output "image_uris" {
  description = "镜像URI映射"
  value       = var.image_uris
}

output "build_status" {
  description = "构建状态"
  value = {
    for app_name in var.app_names : app_name => {
      built  = null_resource.build_images[app_name].id != null
      pushed = null_resource.push_images[app_name].id != null
    }
  }
}