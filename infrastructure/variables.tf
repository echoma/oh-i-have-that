# 全局变量定义
variable "project_name" {
  description = "项目名称"
  type        = string
  default     = "oh-i-have-that"
}

variable "environment" {
  description = "环境名称"
  type        = string
  # 不设置默认值，强制通过tfvars文件指定
}

variable "region" {
  description = "腾讯云地域"
  type        = string
  default     = "ap-guangzhou"
}

variable "app_id" {
  description = "腾讯云账户 App ID"
  type        = string
  default     = "1256219290"
}

variable "common_tags" {
  description = "通用标签"
  type        = map(string)
  default = {
    Project   = "oh-i-have-that"
    ManagedBy = "terraform"
    # Environment 标签通过各环境的tfvars文件设置
  }
}

# COS相关变量
variable "cos_static_bucket_name" {
  description = "COS静态资源存储桶名称"
  type        = string
  default     = ""
}

variable "cos_data_bucket_name" {
  description = "COS数据存储桶名称"
  type        = string
  default     = ""
}

variable "backend_allowed_origins" {
  description = "允许访问数据桶的后端应用域名"
  type        = list(string)
  default     = ["*"]
}

variable "backend_service_principals" {
  description = "允许访问数据桶的后端服务主体"
  type        = list(string)
  default     = ["qcs::cam::anyone:anyone"]
}

# 兼容性变量（保持向后兼容）
variable "cos_bucket_name" {
  description = "COS存储桶名称（兼容性变量，映射到静态资源桶）"
  type        = string
  default     = ""
}

variable "static_files_path" {
  description = "静态网站文件路径"
  type        = string
  default     = "../frontend/dist"
}

variable "enable_auto_upload" {
  description = "是否自动上传静态文件到COS"
  type        = bool
  default     = true
}

# 应用相关变量
variable "app_names" {
  description = "应用名称列表"
  type        = list(string)
  default     = ["website-api", "user-service", "notification-service"]
}

# SCF相关变量
variable "scf_function_name" {
  description = "SCF函数名称"
  type        = string
  default     = "website-handler"
}

variable "scf_memory_size" {
  description = "SCF函数内存大小(MB)"
  type        = number
  default     = 128
}

variable "scf_timeout" {
  description = "SCF函数超时时间(秒)"
  type        = number
  default     = 30
}

# TCR相关变量
variable "enable_tcr" {
  description = "是否启用TCR容器注册表功能"
  type        = bool
  default     = false
}