# 容器镜像注册表模块
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}

# 使用CCR个人版（免费）而不是TCR企业版
# CCR个人版在完成实名认证后可免费使用
# 注意：CCR个人版通过控制台管理，不需要通过Terraform创建实例

# 本地变量 - 使用CCR个人版的镜像仓库地址
locals {
  # CCR个人版的镜像仓库地址格式
  registry_url = "ccr.ccs.tencentyun.com"
  
  # 为每个应用生成完整的镜像URI（使用CCR个人版）
  image_uris = {
    for app_name in var.app_names : app_name => "${local.registry_url}/${var.project_name}/${app_name}:latest"
  }
}

# CCR个人版不需要创建实例，直接使用命名空间和仓库
# 需要手动在腾讯云控制台创建命名空间和镜像仓库，或使用API

# CCR个人版使用说明：
# 1. 完成腾讯云实名认证
# 2. 登录容器镜像服务控制台：https://console.cloud.tencent.com/tke2/registry
# 3. 创建命名空间（如：oh-i-have-that）
# 4. 在命名空间下创建镜像仓库（website-api, user-service, notification-service）

# 模拟仓库信息用于输出（实际仓库需要在控制台创建）
locals {
  repositories = {
    for app_name in var.app_names : app_name => {
      name        = app_name
      namespace   = var.project_name
      full_name   = "${var.project_name}/${app_name}"
      description = "用于SCF云函数的 ${app_name} 应用容器镜像"
    }
  }
}