# SCF模块变量
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

variable "function_name" {
  description = "SCF函数名称"
  type        = string
  default     = "website-handler"
}

variable "memory_size" {
  description = "SCF函数内存大小(MB)"
  type        = number
  default     = 128
  
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 3008 && var.memory_size % 128 == 0
    error_message = "内存大小必须在128MB到3008MB之间，且必须是128MB的倍数。"
  }
}

variable "timeout" {
  description = "SCF函数超时时间(秒)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "超时时间必须在1秒到900秒之间。"
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "子网ID"
  type        = string
}

variable "image_uri" {
  description = "容器镜像URI"
  type        = string
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}