# 🏗️ 第二步: 基础设施搭建

本文档详细说明如何使用Terraform在腾讯云上创建项目所需的基础设施。

## 🎯 目标

- 初始化Terraform环境
- 部署网络基础设施
- 创建存储服务
- 配置容器注册表

## 📋 前置条件

- 完成 [第一步: 开发环境搭建](../01-environment-setup/README.md)
- 腾讯云认证配置正确
- Terraform已安装并可正常使用

## 🚀 自动化部署（推荐）

使用我们提供的自动化脚本来简化基础设施部署：

```bash
# 1. 初始化Terraform状态存储
./scripts/02-infrastructure-setup/init-state-storage.sh

# 2. 管理Terraform工作空间
./scripts/02-infrastructure-setup/workspace.sh create test
./scripts/02-infrastructure-setup/workspace.sh create prod

# 3. 部署基础设施
./scripts/02-infrastructure-setup/deploy-infrastructure.sh test
```

### 📋 脚本详细说明

#### 1. init-state-storage.sh - 状态存储初始化
**功能**: 初始化Terraform远程状态存储
- 创建COS存储桶用于状态管理
- 配置状态锁定机制
- 验证状态存储配置
- 支持多环境状态隔离

**使用方法**:
```bash
# 基本初始化
./scripts/02-infrastructure-setup/init-state-storage.sh

# 指定存储桶名称
./scripts/02-infrastructure-setup/init-state-storage.sh --bucket-name my-terraform-state

# 指定地域
./scripts/02-infrastructure-setup/init-state-storage.sh --region ap-beijing
```

#### 2. workspace.sh - 工作空间管理
**功能**: 创建和管理Terraform工作空间
- 创建测试和生产环境工作空间
- 切换不同环境
- 列出所有工作空间
- 验证工作空间状态

**使用方法**:
```bash
# 创建工作空间
./scripts/02-infrastructure-setup/workspace.sh create test
./scripts/02-infrastructure-setup/workspace.sh create prod

# 切换工作空间
./scripts/02-infrastructure-setup/workspace.sh select test

# 列出工作空间
./scripts/02-infrastructure-setup/workspace.sh list

# 查看当前工作空间
./scripts/02-infrastructure-setup/workspace.sh show
```

#### 3. deploy-infrastructure.sh - 基础设施部署
**功能**: 部署腾讯云基础设施
- 部署网络资源（VPC、子网）
- 部署存储资源（COS存储桶）
- 部署计算资源（云函数、API网关）
- 部署容器注册表
- 配置安全组和访问策略

**使用方法**:
```bash
# 部署到测试环境
./scripts/02-infrastructure-setup/deploy-infrastructure.sh test

# 部署到生产环境
./scripts/02-infrastructure-setup/deploy-infrastructure.sh prod

# 自动确认部署
./scripts/02-infrastructure-setup/deploy-infrastructure.sh test --auto-approve

# 仅显示计划不执行
./scripts/02-infrastructure-setup/deploy-infrastructure.sh test --plan-only
```

## 🔧 Terraform环境初始化

### 1.1 配置环境变量

```bash
# 确保腾讯云认证已配置
echo "SecretId: $TENCENTCLOUD_SECRET_ID"
echo "SecretKey: ${TENCENTCLOUD_SECRET_KEY:0:10}..."
echo "Region: $TENCENTCLOUD_REGION"
```

### 1.2 配置项目环境

```bash
# 复制配置文件模板（如果存在）
if [ -f "infrastructure/environments/test/terraform.tfvars.example" ]; then
  cp infrastructure/environments/test/terraform.tfvars.example infrastructure/environments/test/terraform.tfvars
fi

if [ -f "infrastructure/environments/prod/terraform.tfvars.example" ]; then
  cp infrastructure/environments/prod/terraform.tfvars.example infrastructure/environments/prod/terraform.tfvars
fi

# 编辑测试环境配置
vim infrastructure/environments/test/terraform.tfvars
```

### 1.3 初始化Terraform后端

```bash
# 初始化测试环境状态存储
make init-state-test

# 如果make命令不可用，手动执行：
cd infrastructure
terraform init -backend-config="environments/test/backend.tf"
cd ..

# 初始化测试环境工作空间
make init-test

# 验证环境初始化
make list-envs
```

## 🌐 网络基础设施部署

### 2.1 切换到测试环境

```bash
# 切换到测试环境
make switch-test

# 验证当前环境
terraform workspace show
```

### 2.2 查看部署计划

```bash
# 查看完整部署计划
make plan-test

# 或手动执行
cd infrastructure
terraform plan -var-file="environments/test/terraform.tfvars"
cd ..
```

### 2.3 部署网络基础设施

```bash
cd infrastructure

# 第一步：部署网络基础设施
echo "🌐 部署网络基础设施..."
terraform apply -target=module.network -var-file="environments/test/terraform.tfvars" -auto-approve

# 验证网络部署
terraform output network_info
cd ..
```

## 💾 存储服务部署

### 3.1 部署COS存储桶

```bash
cd infrastructure

# 第二步：部署存储基础设施
echo "💾 部署COS存储服务..."
terraform apply -target=module.cos -var-file="environments/test/terraform.tfvars" -auto-approve

# 获取COS信息
COS_BUCKET_URL=$(terraform output -raw cos_bucket_url)
echo "COS存储桶URL: $COS_BUCKET_URL"

cd ..
```

### 3.2 验证存储服务

```bash
# 测试COS存储桶访问
curl -I $COS_BUCKET_URL

# 上传测试文件
echo "Hello World" > test.txt
# 注意：实际上传需要使用腾讯云CLI或SDK
echo "COS存储桶创建成功: $COS_BUCKET_URL"
rm test.txt
```

## 🐳 容器注册表部署

### 4.1 部署容器注册表

```bash
cd infrastructure

# 第三步：部署容器注册表
echo "🐳 部署容器注册表..."
terraform apply -target=module.container_registry -var-file="environments/test/terraform.tfvars" -auto-approve

# 获取容器注册表信息
CONTAINER_REGISTRY_URL=$(terraform output -raw container_registry_url 2>/dev/null || echo 'Not available')
echo "容器注册表URL: $CONTAINER_REGISTRY_URL"

cd ..
```

### 4.2 配置Docker认证

```bash
# 配置Docker登录到腾讯云容器注册表
# 注意：需要根据实际的注册表地址配置
echo "配置Docker认证..."
echo "请手动配置Docker登录到腾讯云容器注册表"
echo "参考: https://cloud.tencent.com/document/product/1141"
```

## ✅ 基础设施验证

### 5.1 查看部署结果

```bash
cd infrastructure

echo "=== 基础设施部署信息 ==="
terraform output

# 记录重要信息
echo "=== 重要信息记录 ==="
echo "COS Bucket: $(terraform output -raw cos_bucket_url 2>/dev/null || echo 'Not available')"
echo "Container Registry: $(terraform output -raw container_registry_url 2>/dev/null || echo 'Not available')"
echo "Network ID: $(terraform output -raw network_id 2>/dev/null || echo 'Not available')"

cd ..
```

### 5.2 测试基础设施连通性

```bash
echo "=== 测试基础设施连通性 ==="

# 测试COS访问
if [ -n "$COS_BUCKET_URL" ]; then
  echo "测试COS访问..."
  curl -I $COS_BUCKET_URL
  echo "COS访问测试完成"
fi

# 测试网络连接
echo "测试腾讯云网络连接..."
ping -c 3 cloud.tencent.com
echo "网络连接测试完成"
```

## 📊 资源清单

部署完成后，你将拥有以下资源：

### 网络资源
- VPC (虚拟私有云)
- 子网配置
- 安全组规则

### 存储资源  
- COS存储桶 (用于静态网站托管)
- 存储桶访问策略

### 容器资源
- 容器镜像仓库
- 镜像推送权限配置

## 📋 完成检查清单

- [ ] Terraform环境初始化成功
- [ ] 测试环境工作空间创建完成
- [ ] 网络基础设施部署成功
- [ ] COS存储桶创建并可访问
- [ ] 容器注册表创建成功
- [ ] 所有资源输出信息正确显示
- [ ] 基础设施连通性测试通过

## 🔄 环境管理命令

```bash
# 查看所有环境
make list-envs

# 查看当前环境状态
make env-status

# 切换环境
make switch-test    # 切换到测试环境
make switch-prod    # 切换到生产环境

# 查看资源状态
terraform state list
terraform show
```

## 🆘 故障排除

遇到问题请查看: [基础设施搭建故障排除](troubleshooting.md)

---

**✅ 基础设施搭建完成！**

下一步: [03-build-and-package](../03-build-and-package/README.md)