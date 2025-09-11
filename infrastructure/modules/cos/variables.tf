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

variable "bucket_name" {
  description = "COS存储桶名称，如果为空则自动生成"
  type        = string
  default     = ""
}

variable "static_files_path" {
  description = "静态文件路径"
  type        = string
  default     = "../../../static-website/dist"
}

variable "enable_auto_upload" {
  description = "是否自动上传静态文件"
  type        = bool
  default     = true
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}