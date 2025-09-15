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

