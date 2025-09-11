# Docker构建模块变量
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

variable "apps_path" {
  description = "应用代码路径"
  type        = string
  default     = "../../apps"
}

variable "registry_url" {
  description = "TCR注册表URL"
  type        = string
}

variable "image_uris" {
  description = "镜像URI映射"
  type        = map(string)
}

variable "image_tag" {
  description = "镜像标签"
  type        = string
  default     = "latest"
}

variable "tcr_token" {
  description = "TCR访问令牌"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}