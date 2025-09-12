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
  availability_zone = data.tencentcloud_availability_zones_by_product.available.zones[0].name
  cidr_block        = "10.0.1.0/24"
  is_multicast      = false
  tags              = var.tags
}

# 获取可用区信息
data "tencentcloud_availability_zones_by_product" "available" {
  product = "cvm"
}

# 创建安全组
resource "tencentcloud_security_group" "scf" {
  name        = "${var.project_name}-${var.environment}-scf-sg"
  description = "Security group for SCF functions"
  tags        = var.tags
}

# 安全组规则集
resource "tencentcloud_security_group_rule_set" "scf" {
  security_group_id = tencentcloud_security_group.scf.id

  ingress {
    action      = "ACCEPT"
    cidr_block  = "0.0.0.0/0"
    protocol    = "TCP"
    port        = "80"
    description = "Allow HTTP"
  }

  ingress {
    action      = "ACCEPT"
    cidr_block  = "0.0.0.0/0"
    protocol    = "TCP"
    port        = "443"
    description = "Allow HTTPS"
  }

  ingress {
    action      = "ACCEPT"
    cidr_block  = "0.0.0.0/0"
    protocol    = "TCP"
    port        = "9000"
    description = "Allow SCF default port"
  }

  egress {
    action      = "ACCEPT"
    cidr_block  = "0.0.0.0/0"
    protocol    = "ALL"
    port        = "ALL"
    description = "Allow all outbound"
  }
}