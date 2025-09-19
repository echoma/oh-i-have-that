# COS模块变量
variable "project_name" {
  description = "项目名称"
  type        = string
}

variable "environment" {
  description = "环境名称"
  type        = string
}

variable "region" {
  description = "腾讯云地域"
  type        = string
}

variable "static_bucket_name" {
  description = "静态资源存储桶名称，如果为空则自动生成"
  type        = string
  default     = ""
}

variable "data_bucket_name" {
  description = "数据存储桶名称，如果为空则自动生成"
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
  default     = ["qcs::cam::anyone:anyone"]  # 在生产环境中应该限制为特定的服务角色
}

variable "static_files_path" {
  description = "静态文件路径"
  type        = string
  default     = "../../../frontend/dist"
}

variable "enable_auto_upload" {
  description = "是否自动上传静态文件"
  type        = bool
  default     = true
}

variable "app_id" {
  description = "腾讯云账户 App ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}