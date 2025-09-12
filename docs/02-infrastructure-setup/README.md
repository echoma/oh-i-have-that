# 🏗️ 第二步: 基础设施搭建

本文档说明如何使用Terraform在腾讯云上创建项目所需的基础设施。

## 🎯 目标

- 初始化Terraform环境
- 部署网络基础设施
- 创建存储服务
- 配置容器注册表

## 📋 前置条件

- 完成 [第一步: 开发环境搭建](../01-environment-setup/README.md)
- 腾讯云认证配置正确
- Terraform已安装并可正常使用

## 🚀 部署流程

基础设施部署分为以下步骤：

1. **手工创建状态存储桶**（必须在腾讯云控制台进行）
2. **管理Terraform工作空间**（使用脚本）
3. **部署基础设施**（使用脚本）

```bash
# 1. 手工创建状态存储桶（见下方详细步骤）

# 2. 初始化并部署测试环境
./scripts/02-infrastructure-setup/workspace.sh init test
./scripts/02-infrastructure-setup/deploy-infrastructure.sh test

# 3. 初始化并部署生产环境
./scripts/02-infrastructure-setup/workspace.sh init prod
./scripts/02-infrastructure-setup/deploy-infrastructure.sh prod
```

详细的脚本使用方法请参考 `scripts/02-infrastructure-setup/` 目录中的脚本文件。

## 🔧 Terraform状态存储桶创建（手工操作）

在使用Terraform之前，需要先在腾讯云控制台手动创建用于存储Terraform状态的COS存储桶：

### 步骤1: 登录腾讯云控制台
1. 访问 [腾讯云COS控制台](https://console.cloud.tencent.com/cos)
2. 使用你的腾讯云账号登录

### 步骤2: 创建存储桶
1. 点击"创建存储桶"
2. 填写存储桶配置：
   - **存储桶名称**: `tfstate-oihavethat` (腾讯云会自动添加后缀，最终名称如: `tfstate-oihavethat-1256219290`)
   - **所属地域**: 选择你的主要部署地域 (例如: 广州 `ap-guangzhou`)
   - **访问权限**: 私有读写
   - **存储桶标签**: 可选，建议添加 `Purpose=terraform-state`

### 步骤3: 配置版本控制（推荐）
1. 进入创建好的存储桶
2. 点击"基础配置" → "版本控制"
3. 启用版本控制（用于状态文件的版本管理）

### 步骤4: 配置生命周期管理（可选）
1. 点击"基础配置" → "生命周期"
2. 添加规则：
   - 规则名称: `terraform-state-cleanup`
   - 应用范围: 整个存储桶
   - 历史版本管理: 30天后删除历史版本

### 步骤5: 记录存储桶信息
创建完成后，记录以下信息用于后续配置：
- 存储桶名称: `tfstate-oihavethat-1256219290` (实际名称，包含腾讯云自动添加的后缀)
- 存储桶地域: `ap-guangzhou`
- 存储桶URL: `https://tfstate-oihavethat-1256219290.cos.ap-guangzhou.myqcloud.com`

## 🔑 验证腾讯云认证

状态存储桶创建完成后，验证腾讯云认证配置：

```bash
# 确保腾讯云认证已配置
echo "SecretId: $TENCENTCLOUD_SECRET_ID"
echo "SecretKey: ${TENCENTCLOUD_SECRET_KEY:0:10}..."
echo "Region: $TENCENTCLOUD_REGION"
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

## 🔄 环境管理

使用工作空间管理脚本进行环境切换和管理：

```bash
# 工作空间管理
./scripts/02-infrastructure-setup/workspace.sh list      # 查看所有环境
./scripts/02-infrastructure-setup/workspace.sh show     # 查看当前环境
./scripts/02-infrastructure-setup/workspace.sh select test  # 切换到测试环境
```

## 📋 完成检查清单

- [ ] 状态存储桶已在腾讯云控制台手工创建
- [ ] 测试环境初始化和部署成功（运行 `./scripts/02-infrastructure-setup/workspace.sh init test` 和 `./scripts/02-infrastructure-setup/deploy-infrastructure.sh test`）
- [ ] 生产环境初始化和部署成功（运行 `./scripts/02-infrastructure-setup/workspace.sh init prod` 和 `./scripts/02-infrastructure-setup/deploy-infrastructure.sh prod`）

## 🆘 故障排除

遇到问题请查看: [基础设施搭建故障排除](troubleshooting.md)

---

**✅ 基础设施搭建完成！**

下一步: [03-build-and-package](../03-build-and-package/README.md)