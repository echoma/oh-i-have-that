# 容器注册表模块输出
output "tcr_instance_id" {
  description = "TCR实例ID"
  value       = tencentcloud_tcr_instance.main.id
}

output "tcr_public_domain" {
  description = "TCR公网访问域名"
  value       = tencentcloud_tcr_instance.main.public_domain
}

output "namespace_name" {
  description = "命名空间名称"
  value       = tencentcloud_tcr_namespace.main.name
}

output "registry_url" {
  description = "镜像仓库URL"
  value       = local.registry_url
}

output "image_uris" {
  description = "所有应用的镜像URI映射"
  value       = local.image_uris
}

output "repositories" {
  description = "镜像仓库信息"
  value = {
    for app_name, repo in tencentcloud_tcr_repository.apps : app_name => {
      name = repo.repository_name
      url  = "${local.registry_url}/${tencentcloud_tcr_namespace.main.name}/${repo.repository_name}"
    }
  }
}