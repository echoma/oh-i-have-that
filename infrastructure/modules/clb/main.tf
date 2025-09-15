# CLB模块 - 负载均衡器配置
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.82"
    }
  }
}

# 创建CLB实例
resource "tencentcloud_clb_instance" "main" {
  network_type = "OPEN"
  clb_name     = "${var.project_name}-${var.environment}-clb"
  project_id   = 0
  vpc_id       = var.vpc_id
  subnet_id    = var.subnet_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-clb"
    Type = "LoadBalancer"
  })
}

# HTTP监听器
resource "tencentcloud_clb_listener" "http" {
  clb_id        = tencentcloud_clb_instance.main.id
  listener_name = "http-listener"
  port          = 80
  protocol      = "HTTP"
  
  # 健康检查配置
  health_check_switch = true
  health_check_time_out = 5
  health_check_interval_time = 10
  health_check_health_num = 3
  health_check_unhealth_num = 3
  health_check_http_code = 31
  health_check_http_path = "/health"
  health_check_http_domain = ""
  health_check_http_method = "GET"
}

# HTTPS监听器（可选，需要SSL证书）
resource "tencentcloud_clb_listener" "https" {
  count = var.ssl_certificate_id != "" ? 1 : 0
  
  clb_id        = tencentcloud_clb_instance.main.id
  listener_name = "https-listener"
  port          = 443
  protocol      = "HTTPS"
  
  # SSL证书配置
  certificate_ssl_mode = "UNIDIRECTIONAL"
  certificate_id = var.ssl_certificate_id
  
  # 健康检查配置
  health_check_switch = true
  health_check_time_out = 5
  health_check_interval_time = 10
  health_check_health_num = 3
  health_check_unhealth_num = 3
  health_check_http_code = 31
  health_check_http_path = "/health"
  health_check_http_domain = ""
  health_check_http_method = "GET"
}

# HTTP转发规则 - API路由
resource "tencentcloud_clb_listener_rule" "http_api" {
  clb_id              = tencentcloud_clb_instance.main.id
  listener_id         = tencentcloud_clb_listener.http.listener_id
  domain              = var.domain_name != "" ? var.domain_name : tencentcloud_clb_instance.main.clb_vips[0]
  url                 = "/api/*"
  
  # 转发到后端服务器组（这里暂时留空，实际使用时需要配置后端服务器）
  health_check_switch = true
  health_check_time_out = 5
  health_check_interval_time = 10
  health_check_health_num = 3
  health_check_unhealth_num = 3
  health_check_http_code = 31
  health_check_http_path = "/health"
  health_check_http_domain = ""
  health_check_http_method = "GET"
}

# HTTP转发规则 - 静态文件路由
resource "tencentcloud_clb_listener_rule" "http_static" {
  clb_id              = tencentcloud_clb_instance.main.id
  listener_id         = tencentcloud_clb_listener.http.listener_id
  domain              = var.domain_name != "" ? var.domain_name : tencentcloud_clb_instance.main.clb_vips[0]
  url                 = "/"
  
  # 转发到后端服务器组
  health_check_switch = true
  health_check_time_out = 5
  health_check_interval_time = 10
  health_check_health_num = 3
  health_check_unhealth_num = 3
  health_check_http_code = 31
  health_check_http_path = "/"
}

# HTTPS转发规则 - API路由（如果启用HTTPS）
resource "tencentcloud_clb_listener_rule" "https_api" {
  count = var.ssl_certificate_id != "" ? 1 : 0
  
  clb_id              = tencentcloud_clb_instance.main.id
  listener_id         = tencentcloud_clb_listener.https[0].listener_id
  domain              = var.domain_name != "" ? var.domain_name : tencentcloud_clb_instance.main.clb_vips[0]
  url                 = "/api/*"
  
  health_check_switch = true
  health_check_time_out = 5
  health_check_interval_time = 10
  health_check_health_num = 3
  health_check_unhealth_num = 3
  health_check_http_code = 31
  health_check_http_path = "/health"
  health_check_http_domain = ""
  health_check_http_method = "GET"
}

# HTTPS转发规则 - 静态文件路由（如果启用HTTPS）
resource "tencentcloud_clb_listener_rule" "https_static" {
  count = var.ssl_certificate_id != "" ? 1 : 0
  
  clb_id              = tencentcloud_clb_instance.main.id
  listener_id         = tencentcloud_clb_listener.https[0].listener_id
  domain              = var.domain_name != "" ? var.domain_name : tencentcloud_clb_instance.main.clb_vips[0]
  url                 = "/"
  
  health_check_switch = true
  health_check_time_out = 5
  health_check_interval_time = 10
  health_check_health_num = 3
  health_check_unhealth_num = 3
  health_check_http_code = 31
  health_check_http_path = "/"
}