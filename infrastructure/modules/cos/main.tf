# COS模块 - 对象存储配置
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}

# 生成随机后缀确保存储桶名称唯一
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# 创建静态资源存储桶（公开访问）
resource "tencentcloud_cos_bucket" "website" {
  bucket = var.static_bucket_name != "" ? var.static_bucket_name : "oihavethat-static-${var.environment}-${random_string.bucket_suffix.result}-${local.app_id}"
  acl    = "public-read"
  
  # 启用静态网站托管
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  
  # 跨域配置
  cors_rules {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 300
  }
  
  # 移除标签以避免保留标签前缀问题
  # tags = var.tags
}

# 创建数据存储桶（私有访问）
resource "tencentcloud_cos_bucket" "data" {
  bucket = var.data_bucket_name != "" ? var.data_bucket_name : "oihavethat-data-${var.environment}-${random_string.bucket_suffix.result}-${local.app_id}"
  acl    = "private"
  
  # 数据桶的跨域配置（仅允许后端应用访问）
  cors_rules {
    allowed_origins = var.backend_allowed_origins
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 300
  }
  
  # 启用版本控制（数据安全）
  versioning_enable = true
  
  # 移除标签以避免保留标签前缀问题
  # tags = var.tags
}

# 创建静态资源桶策略，允许公开读取
resource "tencentcloud_cos_bucket_policy" "website" {
  bucket = tencentcloud_cos_bucket.website.bucket
  
  policy = jsonencode({
    version = "2.0"
    statement = [
      {
        principal = {
          qcs = ["qcs::cam::anyone:anyone"]
        }
        effect = "allow"
        action = [
          "cos:GetObject"
        ]
        resource = [
          "${tencentcloud_cos_bucket.website.bucket}/*"
        ]
      }
    ]
  })
}

# 创建数据存储桶策略，仅允许后端应用访问
resource "tencentcloud_cos_bucket_policy" "data" {
  bucket = tencentcloud_cos_bucket.data.bucket
  
  policy = jsonencode({
    version = "2.0"
    statement = [
      {
        principal = {
          qcs = var.backend_service_principals
        }
        effect = "allow"
        action = [
          "cos:GetObject",
          "cos:PutObject",
          "cos:DeleteObject",
          "cos:GetObjectVersion",
          "cos:ListBucket"
        ]
        resource = [
          "${tencentcloud_cos_bucket.data.bucket}",
          "${tencentcloud_cos_bucket.data.bucket}/*"
        ]
      }
    ]
  })
}

# 获取当前用户信息 - 使用本地数据源避免权限问题
locals {
  # 从环境变量或配置中获取 app_id，避免调用 cam:DescribeSubAccounts
  app_id = var.app_id != "" ? var.app_id : "1256219290"  # 使用默认值或从变量传入
}

# 上传静态网站文件
resource "tencentcloud_cos_bucket_object" "website_files" {
  for_each = var.enable_auto_upload && fileexists("${var.static_files_path}/index.html") ? fileset(var.static_files_path, "**/*") : []
  
  bucket = tencentcloud_cos_bucket.website.bucket
  key    = each.value
  source = "${var.static_files_path}/${each.value}"
  acl    = "public-read"
  
  # 根据文件扩展名设置Content-Type
  content_type = lookup({
    "html" = "text/html; charset=utf-8"
    "css"  = "text/css; charset=utf-8"
    "js"   = "application/javascript; charset=utf-8"
    "json" = "application/json; charset=utf-8"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "gif"  = "image/gif"
    "svg"  = "image/svg+xml"
    "ico"  = "image/x-icon"
    "woff" = "font/woff"
    "woff2" = "font/woff2"
    "ttf"  = "font/ttf"
    "eot"  = "application/vnd.ms-fontobject"
    "pdf"  = "application/pdf"
    "txt"  = "text/plain; charset=utf-8"
    "xml"  = "application/xml; charset=utf-8"
  }, reverse(split(".", each.value))[0], "application/octet-stream")
  
  # 设置缓存控制
  cache_control = lookup({
    "html" = "no-cache"
    "css"  = "max-age=31536000"
    "js"   = "max-age=31536000"
    "png"  = "max-age=31536000"
    "jpg"  = "max-age=31536000"
    "jpeg" = "max-age=31536000"
    "gif"  = "max-age=31536000"
    "svg"  = "max-age=31536000"
    "ico"  = "max-age=31536000"
    "woff" = "max-age=31536000"
    "woff2" = "max-age=31536000"
    "ttf"  = "max-age=31536000"
  }, reverse(split(".", each.value))[0], "max-age=86400")
  
  depends_on = [tencentcloud_cos_bucket_policy.website]
}

# 创建默认的index.html文件（如果静态文件不存在）
resource "tencentcloud_cos_bucket_object" "default_index" {
  count = var.enable_auto_upload ? 0 : 1
  
  bucket = tencentcloud_cos_bucket.website.bucket
  key    = "index.html"
  content = templatefile("${path.module}/templates/index.html.tpl", {
    project_name = var.project_name
    environment  = var.environment
  })
  acl    = "public-read"
  content_type = "text/html; charset=utf-8"
  
  depends_on = [tencentcloud_cos_bucket_policy.website]
}

# 创建默认的error.html文件（如果静态文件不存在）
resource "tencentcloud_cos_bucket_object" "default_error" {
  count = var.enable_auto_upload ? 0 : 1
  
  bucket = tencentcloud_cos_bucket.website.bucket
  key    = "error.html"
  content = templatefile("${path.module}/templates/error.html.tpl", {
    project_name = var.project_name
    environment  = var.environment
  })
  acl    = "public-read"
  content_type = "text/html; charset=utf-8"
  
  depends_on = [tencentcloud_cos_bucket_policy.website]
}

# 创建空的用户数据文件到数据存储桶（将由用户管理工具管理）
resource "tencentcloud_cos_bucket_object" "users_data" {
  bucket = tencentcloud_cos_bucket.data.bucket
  key    = "auth/users.json"
  content = jsonencode([])
  acl    = "private"
  content_type = "application/json; charset=utf-8"
  
  depends_on = [tencentcloud_cos_bucket_policy.data]
}

# 创建应用配置文件到数据存储桶
resource "tencentcloud_cos_bucket_object" "app_config" {
  bucket = tencentcloud_cos_bucket.data.bucket
  key    = "config/app.json"
  content = jsonencode({
    project_name = var.project_name
    environment  = var.environment
    version      = "1.0.0"
    created_at   = timestamp()
    buckets = {
      static = tencentcloud_cos_bucket.website.bucket
      data   = tencentcloud_cos_bucket.data.bucket
    }
  })
  acl    = "private"
  content_type = "application/json; charset=utf-8"
  
  depends_on = [tencentcloud_cos_bucket_policy.data]
}