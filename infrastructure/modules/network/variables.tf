# 网络模块变量
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

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}