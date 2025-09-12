# Terraform远程状态存储配置
# 注意：状态存储桶需要提前在腾讯云控制台手工创建

terraform {
  # 使用腾讯云COS作为远程状态存储
  backend "cos" {
    # 存储桶配置 - 使用手工创建的存储桶
    bucket = "tfstate-oihavethat-1256219290"
    prefix = "oh-i-have-that/"
    region = "ap-guangzhou"
    
    # 启用状态加密（推荐）
    encrypt = true
    
    # 认证信息通过环境变量提供，不在代码中硬编码
    # TENCENTCLOUD_SECRET_ID
    # TENCENTCLOUD_SECRET_KEY
  }
}

# 注意：状态存储桶已在腾讯云控制台手工创建
# 存储桶名称: tfstate-oihavethat-1256219290
# 存储桶地域: ap-guangzhou
# 存储桶URL: https://tfstate-oihavethat-1256219290.cos.ap-guangzhou.myqcloud.com