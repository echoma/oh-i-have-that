# 生产环境远程状态存储配置
terraform {
  backend "cos" {
    # 生产环境状态存储配置
    # 重要：存储桶需要提前手动创建，不要在代码中管理状态存储桶本身
    
    # 存储桶配置（请替换为您的实际存储桶名称）
    bucket = "terraform-state-prod-oh-i-have-that"
    prefix = "oh-i-have-that/prod/"
    region = "ap-guangzhou"
    
    # 安全配置
    encrypt = true  # 启用服务端加密
    
    # 认证信息通过环境变量提供（安全最佳实践）
    # export TENCENTCLOUD_SECRET_ID="your_secret_id"
    # export TENCENTCLOUD_SECRET_KEY="your_secret_key"
    
    # 可选：使用临时凭证（推荐用于CI/CD）
    # export TENCENTCLOUD_SECURITY_TOKEN="your_temp_token"
  }
}

# 注意事项：
# 1. 状态存储桶应该提前手动创建
# 2. 启用存储桶版本控制以保护状态文件历史
# 3. 配置适当的IAM权限，限制状态文件访问
# 4. 定期备份状态文件
# 5. 在团队中共享存储桶信息，但不要提交到代码仓库