# Docker构建模块 - 负责构建和推送应用镜像
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

# 获取当前用户信息
data "tencentcloud_user_info" "current" {}

# 为每个应用构建Docker镜像
resource "null_resource" "build_images" {
  for_each = toset(var.app_names)
  
  triggers = {
    dockerfile_hash = fileexists("${var.apps_path}/${each.value}/Dockerfile") ? filemd5("${var.apps_path}/${each.value}/Dockerfile") : "no-dockerfile"
    main_go_hash   = fileexists("${var.apps_path}/${each.value}/main.go") ? filemd5("${var.apps_path}/${each.value}/main.go") : "no-main-go"
    go_mod_hash    = fileexists("${var.apps_path}/${each.value}/go.mod") ? filemd5("${var.apps_path}/${each.value}/go.mod") : "no-go-mod"
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${var.apps_path}/${each.value}
      docker build -t ${each.value}:${var.image_tag} .
      docker tag ${each.value}:${var.image_tag} ${var.image_uris[each.value]}
    EOT
  }
}

# 推送镜像到TCR
resource "null_resource" "push_images" {
  for_each = toset(var.app_names)
  
  triggers = {
    build_trigger = null_resource.build_images[each.value].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      # 登录到TCR
      docker login --username=${data.tencentcloud_user_info.current.app_id} --password-stdin ${var.registry_url} <<< "${var.tcr_token}"
      
      # 推送镜像
      docker push ${var.image_uris[each.value]}
    EOT
  }

  depends_on = [
    null_resource.build_images
  ]
}