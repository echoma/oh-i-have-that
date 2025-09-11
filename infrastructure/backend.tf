# Terraform远程状态存储配置
# 注意：这个文件定义了状态存储的配置，但不包含敏感信息

terraform {
  # 使用腾讯云COS作为远程状态存储
  backend "cos" {
    # 存储桶配置 - 需要提前创建
    # 建议使用专门的状态存储桶，与网站存储桶分离
    bucket = "terraform-state-bucket-${random_id.state_suffix.hex}"
    prefix = "oh-i-have-that/"
    region = "ap-guangzhou"
    
    # 启用状态加密（推荐）
    encrypt = true
    
    # 状态锁定配置（防止并发修改）
    # 使用DynamoDB表进行状态锁定
    # dynamodb_table = "terraform-state-lock"
    
    # 认证信息通过环境变量提供，不在代码中硬编码
    # TENCENTCLOUD_SECRET_ID
    # TENCENTCLOUD_SECRET_KEY
  }
}

# 生成随机后缀用于状态存储桶名称
resource "random_id" "state_suffix" {
  byte_length = 4
}

# 创建专用的状态存储桶（如果不存在）
resource "tencentcloud_cos_bucket" "terraform_state" {
  bucket = "terraform-state-bucket-${random_id.state_suffix.hex}"
  acl    = "private"  # 私有访问
  
  # 启用版本控制（重要：用于状态文件版本管理）
  versioning {
    enabled = true
  }
  
  # 生命周期管理（可选：自动清理旧版本）
  lifecycle_rules {
    id     = "state_cleanup"
    status = "Enabled"
    
    # 保留最近30个版本
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
  
  # 服务端加密
  encryption_configuration {
    sse_algorithm = "AES256"
  }
  
  tags = {
    Name        = "Terraform State Storage"
    Purpose     = "terraform-state"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}