# 容器镜像注册表模块
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}

# 创建TCR实例（容器镜像仓库）
resource "tencentcloud_tcr_instance" "main" {
  name          = "${var.project_name}-${var.environment}-tcr"
  instance_type = "basic"
  delete_bucket = true
  
  tags = var.tags
}

# 创建容器镜像服务命名空间
resource "tencentcloud_tcr_namespace" "main" {
  instance_id    = tencentcloud_tcr_instance.main.id
  name           = "${var.project_name}-${var.environment}"
  is_public      = false
  is_auto_scan   = true
  is_prevent_vul = true
  severity       = "medium"
  cve_whitelist_items {
    cve_id = "CVE-2021-44228"
  }
}

# 为每个应用创建镜像仓库
resource "tencentcloud_tcr_repository" "apps" {
  for_each = toset(var.app_names)
  
  instance_id     = tencentcloud_tcr_instance.main.id
  namespace_name  = tencentcloud_tcr_namespace.main.name
  repository_name = each.value
  brief_desc      = "${each.value} 应用容器镜像"
  description     = "用于SCF云函数的 ${each.value} 应用容器镜像"
}

# 获取当前用户信息用于构建镜像URI
data "tencentcloud_user_info" "current" {}

# 本地变量
locals {
  registry_url = tencentcloud_tcr_instance.main.public_domain
  
  # 为每个应用生成完整的镜像URI
  image_uris = {
    for app_name in var.app_names : app_name => "${local.registry_url}/${tencentcloud_tcr_namespace.main.name}/${app_name}:latest"
  }
}