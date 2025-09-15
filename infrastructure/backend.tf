# Terraform远程状态存储配置
# 注意：状态存储桶需要提前在腾讯云控制台手工创建

terraform {
  # 使用腾讯云COS作为远程状态存储
  # 注意：实际的backend配置通过 -backend-config 参数指定
  # 测试环境: terraform init -backend-config=environments/test/backend.hcl
  # 生产环境: terraform init -backend-config=environments/prod/backend.hcl
  backend "cos" {
    # 基础配置，具体值通过backend.hcl文件覆盖
  }
}

# 注意：状态存储桶已在腾讯云控制台手工创建
# 存储桶名称: tfstate-oihavethat-1256219290
# 存储桶地域: ap-guangzhou
# 存储桶URL: https://tfstate-oihavethat-1256219290.cos.ap-guangzhou.myqcloud.com