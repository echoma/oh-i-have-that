# 🆘 基础设施搭建故障排除

## Terraform初始化问题

### 问题: Terraform初始化失败

```bash
# 错误信息
Error: Failed to install provider
```

**解决方案**:

```bash
# 1. 清理Terraform缓存
rm -rf .terraform .terraform.lock.hcl

# 2. 重新初始化
cd infrastructure
terraform init

# 3. 如果仍然失败，使用镜像源
export TF_REGISTRY_MIRROR=https://registry.terraform.io
terraform init -upgrade

# 4. 验证初始化
terraform version
terraform providers
```

### 问题: 后端配置错误

```bash
# 错误信息
Error: Backend configuration changed
```

**解决方案**:

```bash
# 1. 重新配置后端
terraform init -reconfigure

# 2. 或者迁移状态
terraform init -migrate-state

# 3. 验证后端配置
terraform init -backend=true
```

## 腾讯云认证问题

### 问题: 认证失败

```bash
# 错误信息
[TencentCloudSDKException] Code=AuthFailure.SignatureFailure
```

**解决方案**:

```bash
# 1. 检查环境变量
echo "SecretId: $TENCENTCLOUD_SECRET_ID"
echo "SecretKey: ${TENCENTCLOUD_SECRET_KEY:0:10}..."
echo "Region: $TENCENTCLOUD_REGION"

# 2. 重新设置认证
export TENCENTCLOUD_SECRET_ID="your-correct-secret-id"
export TENCENTCLOUD_SECRET_KEY="your-correct-secret-key"
export TENCENTCLOUD_REGION="ap-guangzhou"

# 3. 测试认证
terraform plan -var-file="environments/test/terraform.tfvars"
```

### 问题: 权限不足

```bash
# 错误信息
[TencentCloudSDKException] Code=AuthFailure.UnauthorizedOperation
```

**解决方案**:

```bash
# 检查API密钥权限
# 1. 登录腾讯云控制台
# 2. 进入访问管理 -> API密钥管理
# 3. 确保密钥有以下权限：
#    - COS (对象存储)
#    - SCF (云函数)
#    - API Gateway (API网关)
#    - VPC (私有网络)
#    - TCR (容器镜像服务)

echo "请检查API密钥权限配置"
echo "控制台地址: https://console.cloud.tencent.com/cam/capi"
```

## 网络基础设施问题

### 问题: VPC创建失败

```bash
# 错误信息
Error: Error creating VPC: [TencentCloudSDKException] Code=LimitExceeded
```

**解决方案**:

```bash
# 1. 检查VPC配额
echo "检查VPC配额限制..."

# 2. 删除不用的VPC
echo "请在腾讯云控制台删除不用的VPC"
echo "控制台地址: https://console.cloud.tencent.com/vpc"

# 3. 或者修改配置使用现有VPC
vim infrastructure/environments/test/terraform.tfvars
# 添加: use_existing_vpc = true
# 添加: existing_vpc_id = "vpc-xxxxxxxx"
```

### 问题: 子网配置冲突

```bash
# 错误信息
Error: CIDR block conflicts with existing subnet
```

**解决方案**:

```bash
# 1. 修改CIDR配置
vim infrastructure/environments/test/terraform.tfvars

# 2. 使用不冲突的CIDR块
# vpc_cidr = "10.1.0.0/16"
# subnet_cidr = "10.1.1.0/24"

# 3. 重新应用配置
terraform plan -var-file="environments/test/terraform.tfvars"
terraform apply -var-file="environments/test/terraform.tfvars"
```

## COS存储问题

### 问题: 存储桶名称冲突

```bash
# 错误信息
Error: Bucket name already exists
```

**解决方案**:

```bash
# 1. 修改项目名称
vim infrastructure/environments/test/terraform.tfvars
# 修改: project_name = "your-unique-project-name"

# 2. 或者添加随机后缀
# 在Terraform配置中已包含随机后缀，检查配置

# 3. 重新部署
terraform apply -target=module.cos -var-file="environments/test/terraform.tfvars"
```

### 问题: COS访问权限问题

```bash
# 错误信息
Error: Access Denied
```

**解决方案**:

```bash
# 1. 检查存储桶策略
terraform output cos_bucket_policy

# 2. 修改存储桶ACL
# 在Terraform配置中设置正确的ACL

# 3. 验证访问权限
curl -I $(terraform output -raw cos_bucket_url)
```

## 容器注册表问题

### 问题: 容器注册表创建失败

```bash
# 错误信息
Error: TCR instance creation failed
```

**解决方案**:

```bash
# 1. 检查地域支持
echo "当前地域: $TENCENTCLOUD_REGION"
echo "支持的地域: ap-guangzhou, ap-shanghai, ap-beijing"

# 2. 切换到支持的地域
export TENCENTCLOUD_REGION="ap-guangzhou"

# 3. 重新部署
terraform apply -target=module.container_registry -var-file="environments/test/terraform.tfvars"
```

### 问题: Docker认证失败

```bash
# 错误信息
Error response from daemon: unauthorized
```

**解决方案**:

```bash
# 1. 获取登录命令
echo "请在腾讯云控制台获取Docker登录命令"
echo "控制台地址: https://console.cloud.tencent.com/tcr"

# 2. 执行登录命令
# docker login --username=xxx --password=xxx xxx.tencentcloudcr.com

# 3. 验证登录
docker info
```

## 资源配额问题

### 问题: 资源配额不足

```bash
# 错误信息
Error: Quota exceeded for resource
```

**解决方案**:

```bash
# 1. 检查资源配额
echo "请检查以下资源配额："
echo "- VPC配额"
echo "- COS存储桶配额"
echo "- 云函数配额"
echo "- API网关配额"

# 2. 申请配额提升
echo "如需提升配额，请提交工单"
echo "工单地址: https://console.cloud.tencent.com/workorder"

# 3. 或者清理不用的资源
echo "清理不用的资源以释放配额"
```

## 网络连接问题

### 问题: 网络超时

```bash
# 错误信息
Error: timeout while waiting for state to become 'success'
```

**解决方案**:

```bash
# 1. 检查网络连接
ping cloud.tencent.com

# 2. 检查防火墙设置
echo "检查本地防火墙和企业网络策略"

# 3. 使用代理（如果需要）
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080

# 4. 重试部署
terraform apply -var-file="environments/test/terraform.tfvars"
```

## 状态文件问题

### 问题: 状态文件锁定

```bash
# 错误信息
Error: Error locking state
```

**解决方案**:

```bash
# 1. 强制解锁（谨慎使用）
terraform force-unlock <lock-id>

# 2. 等待锁定超时
echo "等待其他操作完成..."

# 3. 检查是否有其他Terraform进程
ps aux | grep terraform
```

### 问题: 状态文件损坏

```bash
# 错误信息
Error: Failed to load state
```

**解决方案**:

```bash
# 1. 备份当前状态
cp terraform.tfstate terraform.tfstate.backup

# 2. 从远程后端拉取状态
terraform state pull > terraform.tfstate

# 3. 验证状态文件
terraform state list

# 4. 如果状态文件完全损坏，重新导入资源
# terraform import <resource_type>.<resource_name> <resource_id>
```

## 完整诊断脚本

创建诊断脚本 `diagnose-infrastructure.sh`:

```bash
#!/bin/bash

echo "🔍 诊断基础设施环境..."

# 检查Terraform
if command -v terraform &> /dev/null; then
    echo "✅ Terraform: $(terraform version | head -1)"
    terraform validate
else
    echo "❌ Terraform未安装"
fi

# 检查腾讯云认证
if [ -n "$TENCENTCLOUD_SECRET_ID" ]; then
    echo "✅ 腾讯云认证已配置"
    echo "   SecretId: ${TENCENTCLOUD_SECRET_ID:0:10}..."
    echo "   Region: $TENCENTCLOUD_REGION"
else
    echo "❌ 腾讯云认证未配置"
fi

# 检查网络连接
echo "🌐 检查网络连接..."
if ping -c 1 cloud.tencent.com &> /dev/null; then
    echo "✅ 腾讯云网络连接正常"
else
    echo "❌ 腾讯云网络连接失败"
fi

# 检查Terraform状态
if [ -f ".terraform/terraform.tfstate" ]; then
    echo "✅ Terraform已初始化"
else
    echo "❌ Terraform未初始化"
fi

# 检查工作空间
if terraform workspace list &> /dev/null; then
    echo "✅ 当前工作空间: $(terraform workspace show)"
else
    echo "❌ 无法获取工作空间信息"
fi

echo "🔍 诊断完成"
```

使用脚本:

```bash
chmod +x diagnose-infrastructure.sh
./diagnose-infrastructure.sh
```

## 紧急恢复步骤

如果基础设施部署完全失败：

```bash
# 1. 完全清理环境
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*

# 2. 重新初始化
terraform init

# 3. 创建新的工作空间
terraform workspace new test-recovery

# 4. 重新部署
terraform apply -var-file="environments/test/terraform.tfvars"
```

---

如果以上解决方案都无法解决问题，请：

1. 查看Terraform详细日志: `TF_LOG=DEBUG terraform apply`
2. 检查腾讯云控制台的资源状态
3. 查看腾讯云API文档获取最新信息
4. 在项目Issues中搜索类似问题