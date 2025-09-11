# 测试环境远程状态存储配置
terraform {
  backend "cos" {
    # 测试环境状态存储配置
    # 重要：使用与生产环境不同的存储桶和路径
    
    # 存储桶配置（请替换为您的实际存储桶名称）
    bucket = "terraform-state-test-oh-i-have-that"
    prefix = "oh-i-have-that/test/"
    region = "ap-guangzhou"
    
    # 安全配置
    encrypt = true  # 启用服务端加密
    
    # 认证信息通过环境变量提供
    # export TENCENTCLOUD_SECRET_ID="your_secret_id"
    # export TENCENTCLOUD_SECRET_KEY="your_secret_key"
  }
}

# 测试环境也可以使用本地状态存储（仅用于开发测试）
# terraform {
#   backend "local" {
#     path = "terraform-test.tfstate"
#   }
# }

# 注意事项：
# 1. 测试环境可以使用相对宽松的权限配置
# 2. 可以定期清理测试环境的状态文件
# 3. 建议测试环境和生产环境使用不同的腾讯云账号或项目