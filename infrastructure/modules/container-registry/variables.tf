# 容器注册表模块变量
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

variable "app_names" {
  description = "应用名称列表"
  type        = list(string)
  default     = ["website-api", "user-service", "notification-service"]
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