# 网络模块 - VPC和子网配置
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}

# 创建VPC
resource "tencentcloud_vpc" "main" {
  name       = "${var.project_name}-${var.environment}-vpc"
  cidr_block = "10.0.0.0/16"
  tags       = var.tags
}

# 创建子网
resource "tencentcloud_subnet" "main" {
  name              = "${var.project_name}-${var.environment}-subnet"
  vpc_id            = tencentcloud_vpc.main.id
  availability_zone = data.tencentcloud_availability_zones.available.zones[0].name
  cidr_block        = "10.0.1.0/24"
  is_multicast      = false
  tags              = var.tags
}

# 获取可用区信息
data "tencentcloud_availability_zones" "available" {
  include_unavailable = false
}

# 创建安全组
resource "tencentcloud_security_group" "scf" {
  name        = "${var.project_name}-${var.environment}-scf-sg"
  description = "Security group for SCF functions"
  tags        = var.tags
}

# 安全组规则 - 允许出站流量
resource "tencentcloud_security_group_lite_rule" "scf_egress" {
  security_group_id = tencentcloud_security_group.scf.id

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL",
  ]
}

# 安全组规则 - 允许HTTP/HTTPS入站流量
resource "tencentcloud_security_group_lite_rule" "scf_ingress" {
  security_group_id = tencentcloud_security_group.scf.id

  ingress = [
    "ACCEPT#0.0.0.0/0#80#TCP",
    "ACCEPT#0.0.0.0/0#443#TCP",
    "ACCEPT#0.0.0.0/0#9000#TCP", # SCF默认端口
  ]
}