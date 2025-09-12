# SCF模块 - 云函数配置
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}

# 创建SCF函数
resource "tencentcloud_scf_function" "main" {
  name        = var.function_name
  description = "SCF网站后端API函数"
  handler     = "main"
  mem_size    = var.memory_size
  timeout     = var.timeout
  runtime     = "CustomRuntime"
  
  # 使用容器镜像
  image_config {
    image_type = "personal"
    image_uri  = var.image_uri
  }
  
  # VPC配置
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  
  # 环境变量
  environment = {
    TENCENTCLOUD_REGION = var.region
    SCF_FUNCTIONNAME   = var.function_name
    GIN_MODE          = "release"
  }
  
  # 异步执行配置
  async_run_enable = "FALSE"
  
  # 日志配置
  cls_logset_id = tencentcloud_cls_logset.scf.id
  cls_topic_id  = tencentcloud_cls_topic.scf.id
  
  tags = var.tags
}

# 创建API网关服务
resource "tencentcloud_api_gateway_service" "main" {
  service_name = "${var.project_name}-${var.environment}-api"
  protocol     = "http&https"
  service_desc = "SCF网站API网关服务"
  net_type     = ["OUTER"]
  ip_version   = "IPv4"
  
  tags = var.tags
}

# 创建API网关API
resource "tencentcloud_api_gateway_api" "main" {
  service_id            = tencentcloud_api_gateway_service.main.id
  api_name             = "oh-i-have-that-api"
  api_desc             = "Oh I Have That网站API"
  auth_type            = "NONE"
  protocol             = "HTTP"
  enable_cors          = true
  request_config_path  = "/"
  request_config_method = "ANY"
  
  request_parameters {
    name          = "X-Forwarded-For"
    position      = "HEADER"
    type          = "string"
    desc          = "客户端IP"
    default_value = ""
    required      = false
  }
  
  service_config_type      = "SCF"
  service_config_timeout   = var.timeout
  service_config_product   = "SCF"
  service_config_vpc_id    = var.vpc_id
  service_config_scf_function_name      = tencentcloud_scf_function.main.name
  service_config_scf_function_namespace = "default"
  service_config_scf_function_qualifier = "$LATEST"
  service_config_scf_function_type      = "Event"
  
  response_type    = "JSON"
  response_success_example = jsonencode({
    message = "success"
  })
  response_fail_example = jsonencode({
    error = "error message"
  })
  
  # 启用响应集成
  service_config_scf_is_integrated_response = true
}

# 发布API网关服务
resource "tencentcloud_api_gateway_service_release" "main" {
  service_id       = tencentcloud_api_gateway_service.main.id
  environment_name = "release"
  release_desc     = "发布SCF网站API"
  
  depends_on = [tencentcloud_api_gateway_api.main]
}

# 创建CLS日志集
resource "tencentcloud_cls_logset" "scf" {
  logset_name = "${var.project_name}-${var.environment}-scf-logs"
  tags        = var.tags
}

# 创建CLS日志主题
resource "tencentcloud_cls_topic" "scf" {
  topic_name           = "${var.project_name}-${var.environment}-scf-topic"
  logset_id           = tencentcloud_cls_logset.scf.id
  auto_split          = true
  max_split_partitions = 20
  partition_count     = 1
  period              = 10
  storage_type        = "hot"
  
  tags = var.tags
}

# 创建CLS索引
resource "tencentcloud_cls_index" "scf" {
  topic_id = tencentcloud_cls_topic.scf.id
  
  rule {
    full_text {
      case_sensitive = false
      tokenizer      = "!@#%^&*()_=\"', <>/?|\\;:\n\t\r[]{}"
      contain_z_h    = true
    }
    
    key_value {
      case_sensitive = false
      
      key_values {
        key = "level"
        value {
          type        = "text"
          contain_z_h = true
          sql_flag    = true
          tokenizer   = "!@#%^&*()_=\"', <>/?|\\;:\n\t\r[]{}"
        }
      }
      
      key_values {
        key = "message"
        value {
          type        = "text"
          contain_z_h = true
          sql_flag    = true
          tokenizer   = "!@#%^&*()_=\"', <>/?|\\;:\n\t\r[]{}"
        }
      }
    }
  }
}

# 注意：SCF触发器需要通过腾讯云控制台手动配置，或使用其他方式创建
# tencentcloud_scf_trigger 资源在当前provider版本中不可用

# 本地变量
locals {
  api_gateway_url = "https://${tencentcloud_api_gateway_service.main.id}-${data.tencentcloud_user_info.current.app_id}.${var.region}.apigw.tencentcs.com/release"
}

# 获取当前用户信息
data "tencentcloud_user_info" "current" {}