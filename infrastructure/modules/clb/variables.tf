# CLB模块变量
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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "子网ID"
  type        = string
}

variable "scf_function_name" {
  description = "SCF函数名称"
  type        = string
}

variable "cos_bucket_url" {
  description = "COS存储桶URL"
  type        = string
}

variable "domain_name" {
  description = "自定义域名"
  type        = string
  default     = ""
}

variable "ssl_certificate_id" {
  description = "SSL证书ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}